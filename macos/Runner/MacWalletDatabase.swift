import Foundation
import FlutterMacOS
import Security
import SQLCipher

struct WalletDatabaseError: Error {
    let code: String
    init(_ code: String = "wallet_database") { self.code = code }
}

final class MacWalletDatabase {
    private let directory: URL
    private let keychainService: String
    private var handle: OpaquePointer?
    private var lockDescriptor: Int32 = -1
    private var statements: [String: OpaquePointer] = [:]
    private var managementCounts: [String: (revision: Int, count: Int)] = [:]
    #if DEBUG
    var failNextCommit = false
    #endif

    init(directory: URL, keychainService: String) {
        self.directory = directory
        self.keychainService = keychainService
    }

    static func register(with messenger: FlutterBinaryMessenger) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let bundle = Bundle.main.bundleIdentifier ?? "com.example.stoneWallet"
        var directory = support.appendingPathComponent(bundle).appendingPathComponent("Wallet")
        var service = bundle + ".wallet-database"
        #if WALLET_TEST_DATABASE
        if let token = ProcessInfo.processInfo.environment["ASTERKEEL_TEST_DATABASE"],
           let id = UUID(uuidString: token) {
            directory = directory.deletingLastPathComponent().appendingPathComponent("WalletTest-" + id.uuidString)
            service += ".test." + id.uuidString
        } else {
            fatalError("A synthetic wallet database ID is required")
        }
        #endif
        let database = MacWalletDatabase(directory: directory, keychainService: service)
        let queue = DispatchQueue(label: bundle + ".wallet-database", qos: .userInitiated)
        let channel = FlutterMethodChannel(name: "asterkeel/wallet_database", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            let method = call.method
            let arguments = call.arguments as? [String: Any] ?? [:]
            queue.async {
                let response: Any?
                do {
                    response = try database.call(method, arguments)
                } catch {
                    #if WALLET_TEST_DATABASE
                    let code = (error as? WalletDatabaseError)?.code ?? "wallet_database"
                    fputs("synthetic native failure: \(method) \(code)\n", stderr)
                    #endif
                    response = FlutterError(
                        code: (error as? WalletDatabaseError)?.code ?? "wallet_database",
                        message: nil, details: nil
                    )
                }
                DispatchQueue.main.async { result(response) }
            }
        }
    }

    deinit { close() }

    private func close() {
        for statement in statements.values { sqlite3_finalize(statement) }
        statements.removeAll()
        if let handle { sqlite3_close(handle) }
        handle = nil
        if lockDescriptor >= 0 { Darwin.close(lockDescriptor) }
        lockDescriptor = -1
    }

    private func open() throws {
        if handle != nil { return }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            var directory = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try directory.setResourceValues(values)

            lockDescriptor = Darwin.open(directory.appendingPathComponent("wallet.lock").path, O_CREAT | O_RDWR, 0o600)
            guard lockDescriptor >= 0, flock(lockDescriptor, LOCK_EX | LOCK_NB) == 0 else {
                throw WalletDatabaseError()
            }
            let path = directory.appendingPathComponent("wallet.db").path
            let exists = FileManager.default.fileExists(atPath: path)
            var key = try databaseKey(existingFile: exists)
            defer { key.resetBytes(in: key.indices) }
            guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
                throw WalletDatabaseError()
            }
            let keyed = key.withUnsafeBytes { sqlite3_key(handle, $0.baseAddress, Int32($0.count)) }
            guard keyed == SQLITE_OK,
                  try !query("PRAGMA cipher_version").isEmpty else { throw WalletDatabaseError() }
            _ = try query("SELECT count(*) FROM sqlite_master")
            try registerLowercase()
            _ = try query("PRAGMA foreign_keys = ON")
            _ = try query("PRAGMA journal_mode = WAL")
            _ = try query("PRAGMA synchronous = FULL")
            _ = try query("PRAGMA temp_store = MEMORY")
            _ = try query("PRAGMA secure_delete = ON")
            let version = try query("PRAGMA user_version").first?["user_version"] as? Int ?? 0
            guard (0...6).contains(version) else { throw WalletDatabaseError() }
            try transaction {
                if version == 0 {
                    for sql in Self.schema { try execute(sql) }
                }
                // Both released branches used schema 2 for different features.
                // Inspect the actual schema so either installation can migrate safely.
                if try query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'pool_seeds'").isEmpty {
                    for sql in Self.poolSchema { try execute(sql) }
                }
                let accountColumns = try query("PRAGMA table_info(accounts)").compactMap { $0["name"] as? String }
                if !accountColumns.contains("evm_path") {
                    for sql in Self.derivationSchema { try execute(sql) }
                }
                if !accountColumns.contains("legacy_address_mode") {
                    for sql in Self.legacyAddressSchema { try execute(sql) }
                }
                if try query("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'recovery_tasks'").isEmpty {
                    for sql in Self.recoverySchema { try execute(sql) }
                }
                let groupColumns = try query("PRAGMA table_info(wallet_groups)").compactMap { $0["name"] as? String }
                if !groupColumns.contains("next_account_index") {
                    for sql in Self.managementSchema { try execute(sql) }
                    try execute("UPDATE wallet_groups SET next_account_index = (SELECT coalesce(max(account_index), 0) + 1 FROM accounts WHERE group_id = wallet_groups.id)")
                }
                try execute("PRAGMA user_version = 6")
                try clearPreview()
                try execute("DELETE FROM removal_targets")
                try execute("DELETE FROM removal_state")
            }
        } catch {
            close()
            throw error
        }
    }

    private func databaseKey(existingFile: Bool) throws -> Data {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "wallet-database-v1",
            kSecAttrSynchronizable as String: false,
        ]
        var lookup = attributes
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess, let key = result as? Data, key.count == 32 {
            return key
        }
        guard status == errSecItemNotFound, !existingFile else { throw WalletDatabaseError("wallet_keychain") }
        var key = Data(count: 32)
        guard key.withUnsafeMutableBytes({ SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!) }) == errSecSuccess else {
            throw WalletDatabaseError("wallet_keychain")
        }
        var item = attributes
        item[kSecValueData as String] = key
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw WalletDatabaseError("wallet_keychain") }
        return key
    }

    private static let schema = [
        """
        CREATE TABLE state (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            migrated INTEGER NOT NULL DEFAULT 0,
            active_id TEXT,
            pending_network INTEGER,
            revision INTEGER NOT NULL DEFAULT 0,
            groups_count INTEGER NOT NULL DEFAULT 0,
            accounts_count INTEGER NOT NULL DEFAULT 0,
            private_count INTEGER NOT NULL DEFAULT 0
        )
        """,
        "INSERT INTO state (id) VALUES (1)",
        """
        CREATE TABLE wallet_groups (
            sequence INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            secret TEXT NOT NULL,
            network_id INTEGER,
            identity TEXT
        )
        """,
        "CREATE UNIQUE INDEX wallet_identity ON wallet_groups(network_id, identity) WHERE identity IS NOT NULL",
        "CREATE INDEX wallet_kind ON wallet_groups(kind, sequence)",
        "CREATE INDEX mnemonic_identity ON wallet_groups(identity) WHERE kind = 'mnemonic'",
        """
        CREATE TABLE accounts (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL REFERENCES wallet_groups(id),
            account_index INTEGER NOT NULL,
            name TEXT NOT NULL,
            evm TEXT NOT NULL,
            tron TEXT NOT NULL,
            UNIQUE(group_id, account_index)
        )
        """,
        """
        CREATE TABLE aliases (
            id INTEGER PRIMARY KEY,
            group_id TEXT NOT NULL REFERENCES wallet_groups(id),
            platform TEXT NOT NULL,
            uid TEXT NOT NULL,
            UNIQUE(group_id, platform, uid)
        )
        """,
        "CREATE INDEX aliases_by_wallet ON aliases(group_id, id)",
        """
        CREATE TABLE search_terms (
            term TEXT NOT NULL COLLATE NOCASE,
            group_id TEXT NOT NULL,
            account_index INTEGER NOT NULL,
            PRIMARY KEY(term, group_id, account_index)
        ) WITHOUT ROWID
        """,
        "CREATE INDEX search_group ON search_terms(group_id, account_index, term)",
        """
        CREATE TABLE preview (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            session TEXT NOT NULL,
            revision INTEGER NOT NULL,
            account_name TEXT NOT NULL,
            ready INTEGER NOT NULL DEFAULT 0
        )
        """,
        """
        CREATE TABLE preview_wallets (
            source_line INTEGER PRIMARY KEY,
            id TEXT NOT NULL UNIQUE,
            name TEXT NOT NULL,
            secret TEXT NOT NULL,
            network_id INTEGER NOT NULL,
            identity TEXT NOT NULL,
            evm TEXT NOT NULL,
            tron TEXT NOT NULL,
            UNIQUE(network_id, identity)
        )
        """,
        """
        CREATE TABLE preview_aliases (
            source_line INTEGER PRIMARY KEY,
            group_id TEXT NOT NULL,
            platform TEXT NOT NULL,
            uid TEXT NOT NULL,
            UNIQUE(group_id, platform, uid)
        )
        """,
        """
        CREATE TABLE preview_rows (
            source_line INTEGER PRIMARY KEY,
            status TEXT NOT NULL,
            error TEXT,
            platform TEXT,
            uid TEXT,
            address TEXT,
            network_id INTEGER
        )
        """,
        "CREATE INDEX preview_row_status ON preview_rows(status, source_line)",
    ]

    private static let recoverySchema = [
        "CREATE TABLE recovery_tasks (id TEXT PRIMARY KEY, payload TEXT NOT NULL, updated_at INTEGER NOT NULL)",
    ]

    private static let legacyAddressSchema = [
        "ALTER TABLE accounts ADD COLUMN legacy_address_mode INTEGER NOT NULL DEFAULT 0 CHECK(legacy_address_mode IN (0,1))",
    ]

    private static let derivationSchema = [
        "ALTER TABLE accounts ADD COLUMN evm_path TEXT",
        "ALTER TABLE accounts ADD COLUMN tron_path TEXT",
    ]

    private static let poolSchema = [
        """
        CREATE TABLE pool_seeds (
            id TEXT PRIMARY KEY, service TEXT NOT NULL, platform TEXT NOT NULL,
            mnemonic TEXT NOT NULL, identity TEXT NOT NULL UNIQUE, active INTEGER NOT NULL,
            bsc_next INTEGER NOT NULL, tron_next INTEGER NOT NULL
        )
        """,
        "CREATE UNIQUE INDEX pool_active_seed ON pool_seeds(service,platform) WHERE active = 1",
        """
        CREATE TABLE pool_batches (
            id TEXT PRIMARY KEY, seed TEXT NOT NULL REFERENCES pool_seeds(id),
            chain TEXT NOT NULL, first_index INTEGER NOT NULL, payload TEXT NOT NULL,
            backed_up INTEGER NOT NULL DEFAULT 0, uploaded INTEGER NOT NULL DEFAULT 0
        )
        """,
        "CREATE INDEX pool_batches_seed ON pool_batches(seed)",
        """
        CREATE TABLE pool_snapshots (
            service TEXT NOT NULL, platform TEXT NOT NULL, payload TEXT NOT NULL,
            PRIMARY KEY(service,platform)
        )
        """,
    ]

    private func poolDeviceKey() throws -> SecKey {
        let attrs: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "omni-pool-device-rsa",
            kSecAttrSynchronizable as String: false,
        ]
        var lookup = attrs
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        let keyAttrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 3072,
        ]
        if status == errSecSuccess, let data = item as? Data,
           let key = SecKeyCreateWithData(data as CFData, keyAttrs as CFDictionary, nil) {
            return key
        }
        guard status == errSecItemNotFound,
              let key = SecKeyCreateRandomKey(keyAttrs as CFDictionary, nil),
              let data = SecKeyCopyExternalRepresentation(key, nil) else {
            throw WalletDatabaseError("wallet_keychain")
        }
        var record = attrs
        record[kSecValueData as String] = data
        guard SecItemAdd(record as CFDictionary, nil) == errSecSuccess else {
            throw WalletDatabaseError("wallet_keychain")
        }
        return key
    }

    private func insertPoolSeed(_ seed: [String: Any], _ service: String, _ platform: String, active: Bool) throws {
        try execute("""
            INSERT INTO pool_seeds(id,service,platform,mnemonic,identity,active,bsc_next,tron_next)
            VALUES (?,?,?,?,?,?,?,?)
            """, [try seed.string("id"), service, platform, try seed.string("mnemonic"),
                  try seed.string("identity"), active ? 1 : 0, try seed.int("bsc_next"), try seed.int("tron_next")])
    }

    private func insertPoolBatch(_ batch: [String: Any], backedUp: Bool) throws {
        try execute("""
            INSERT INTO pool_batches(id,seed,chain,first_index,payload,backed_up) VALUES (?,?,?,?,?,?)
            """, [try batch.string("id"), try batch.string("seed"), try batch.string("chain"),
                  try batch.int("first_index"), try batch.string("payload"), backedUp ? 1 : 0])
    }

    private func poolCall(_ method: String, _ args: [String: Any]) throws -> Any? {
        switch method {
        case "pool.device":
            let key = try poolDeviceKey()
            guard let publicKey = SecKeyCopyPublicKey(key),
                  let data = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                throw WalletDatabaseError("wallet_keychain")
            }
            return FlutterStandardTypedData(bytes: data)
        case "pool.sign":
            let key = try poolDeviceKey()
            guard let message = args["message"] as? FlutterStandardTypedData,
                  let signature = SecKeyCreateSignature(key, .rsaSignatureMessagePSSSHA256, message.data as CFData, nil) as Data? else {
                throw WalletDatabaseError("wallet_keychain")
            }
            return FlutterStandardTypedData(bytes: signature)
        case "pool.verify":
            guard let key = args["key"] as? FlutterStandardTypedData,
                  let message = args["message"] as? FlutterStandardTypedData,
                  let signature = args["signature"] as? FlutterStandardTypedData else { throw WalletDatabaseError() }
            let attrs: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
                kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            ]
            guard let publicKey = SecKeyCreateWithData(key.data as CFData, attrs as CFDictionary, nil),
                  SecKeyGetBlockSize(publicKey) >= 384 else { return false }
            return SecKeyVerifySignature(publicKey, .rsaSignatureMessagePSSSHA256, message.data as CFData, signature.data as CFData, nil)
        default:
            break
        }

        let service = try args.string("service")
        let platform = try args.string("platform")
        let scope = [service, platform]
        switch method {
        case "pool.active":
            return try query("SELECT id,mnemonic,bsc_next,tron_next FROM pool_seeds WHERE service=? AND platform=? AND active=1", scope).first
        case "pool.hasSeed":
            return try !query("SELECT 1 FROM pool_seeds WHERE service=? AND platform=? AND active=1", scope).isEmpty
        case "pool.create":
            try insertPoolSeed(args, service, platform, active: true)
        case "pool.generate":
            let column: String
            switch try args.string("chain") {
            case "bsc": column = "bsc_next"
            case "tron": column = "tron_next"
            default: throw WalletDatabaseError()
            }
            let first = try args.int("first_index")
            let count = try args.int("count")
            let seed = try args.string("seed")
            guard (1...1000).contains(count), first >= 0, first <= 0x80000000 - count else { throw WalletDatabaseError() }
            try transaction {
                let bind: [Any?] = [first + count, seed, service, platform, first]
                try execute("UPDATE pool_seeds SET \(column)=? WHERE id=? AND service=? AND platform=? AND active=1 AND \(column)=?", bind)
                guard try integer("SELECT changes() AS value") == 1 else { throw WalletDatabaseError("wallet_changed") }
                try insertPoolBatch(args, backedUp: false)
            }
        case "pool.list":
            return try query("""
                SELECT b.id,b.chain,b.backed_up,b.uploaded FROM pool_batches b JOIN pool_seeds s ON s.id=b.seed
                WHERE s.service=? AND s.platform=? ORDER BY b.rowid DESC
                """, scope)
        case "pool.batch":
            return try query("""
                SELECT b.*,s.service,s.platform FROM pool_batches b JOIN pool_seeds s ON s.id=b.seed
                WHERE s.service=? AND s.platform=? AND b.id=?
                """, scope + [try args.string("id")]).first
        case "pool.backup":
            return [
                "seeds": try query("SELECT id,mnemonic,identity,bsc_next,tron_next FROM pool_seeds WHERE service=? AND platform=? ORDER BY id", scope),
                "batches": try query("""
                    SELECT b.id,b.seed,b.chain,b.first_index,b.payload FROM pool_batches b JOIN pool_seeds s ON s.id=b.seed
                    WHERE s.service=? AND s.platform=? ORDER BY b.rowid
                    """, scope),
            ]
        case "pool.markBackedUp", "pool.markUploaded":
            let column = method == "pool.markBackedUp" ? "backed_up" : "uploaded"
            let ids = try args.records("ids")
            try transaction {
                for item in ids {
                    try execute("""
                        UPDATE pool_batches SET \(column)=1 WHERE id=? AND seed IN
                        (SELECT id FROM pool_seeds WHERE service=? AND platform=?)
                        """, [try item.string("id"), service, platform])
                }
            }
        case "pool.restore":
            try transaction {
                guard try query("SELECT id FROM pool_seeds WHERE service=? AND platform=?", scope).isEmpty else {
                    throw WalletDatabaseError("wallet_changed")
                }
                for seed in try args.records("seeds") { try insertPoolSeed(seed, service, platform, active: false) }
                for batch in try args.records("batches") { try insertPoolBatch(batch, backedUp: true) }
                guard let active = args["active"] as? [String: Any] else { throw WalletDatabaseError() }
                try insertPoolSeed(active, service, platform, active: true)
            }
        case "pool.snapshot":
            return try query("SELECT payload FROM pool_snapshots WHERE service=? AND platform=?", scope).first?["payload"]
        case "pool.saveSnapshot":
            try execute("""
                INSERT INTO pool_snapshots(service,platform,payload) VALUES (?,?,?)
                ON CONFLICT(service,platform) DO UPDATE SET payload=excluded.payload
                """, scope + [try args.string("payload")])
        default:
            throw WalletDatabaseError()
        }
        return nil
    }

    func call(_ method: String, _ arguments: [String: Any]) throws -> Any? {
        try open()
        if method.hasPrefix("pool.") { return try poolCall(method, arguments) }
        switch method {
        case "recovery.export":
            let data = Data(try arguments.string("payload").utf8)
            guard data.count <= 65536 else { throw WalletDatabaseError() }
            let url = URL(fileURLWithPath: try arguments.string("path"))
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return nil
        case "recovery.list":
            return try query("SELECT payload FROM recovery_tasks ORDER BY updated_at DESC, id DESC LIMIT 50").map { try $0.string("payload") }
        case "recovery.save":
            let payload = try arguments.string("payload")
            guard payload.utf8.count <= 65536 else { throw WalletDatabaseError() }
            try execute("""
                INSERT INTO recovery_tasks(id,payload,updated_at) VALUES (?,?,?)
                ON CONFLICT(id) DO UPDATE SET payload=excluded.payload,updated_at=excluded.updated_at
                """, [try arguments.string("id"), payload, try arguments.int("updated_at")])
            return nil
        case "needsMigration":
            return try integer("SELECT migrated AS value FROM state") == 0
        case "migrate":
            try migrate(arguments)
            return nil
        case "summary":
            return try summary()
        case "initialNetwork":
            return try query("SELECT pending_network FROM state").first?["pending_network"]
        case "ackInitialNetwork":
            try execute("UPDATE state SET pending_network = NULL WHERE pending_network = ?", [try arguments.int("id")])
            return nil
        case "allGroups":
            return try query("SELECT id FROM wallet_groups ORDER BY sequence").map {
                try group($0.string("id"), includeSecret: true)
            }
        case "firstMnemonic":
            guard let row = try query("SELECT id FROM wallet_groups WHERE kind = 'mnemonic' ORDER BY sequence LIMIT 1").first else {
                return nil
            }
            return try group(row.string("id"), includeSecret: true)
        case "addMnemonic":
            try addMnemonic(arguments)
            return try summary()
        case "addPrivate":
            return try addPrivate(arguments)
        case "derive":
            return try derive(arguments)
        case "addDerived":
            try addDerived(arguments)
            return try summary()
        case "select":
            try select(arguments.string("id"))
            return try summary()
        case "rename":
            try rename(arguments)
            return try summary()
        case "walletPage":
            return try walletPage(arguments)
        case "managementPage":
            return try managementPage(arguments)
        case "managementGroup":
            return try managementGroup(arguments.string("id"))
        case "accountPage":
            let id = try arguments.string("id")
            let after = arguments["after"] as? Int ?? -1
            return try query("SELECT * FROM accounts WHERE group_id = ? AND account_index > ? ORDER BY account_index LIMIT 51", [id, after])
        case "platformPage":
            return try query("SELECT DISTINCT platform FROM aliases WHERE platform > ? COLLATE NOCASE ORDER BY platform COLLATE NOCASE LIMIT 51", [arguments["after"] as? String ?? ""])
        case "prepareRemoval":
            return try prepareRemoval(arguments)
        case "removalPage":
            return try removalPage(arguments)
        case "cancelRemoval":
            try cancelRemoval(arguments.string("token"))
            return nil
        case "commitRemoval":
            try commitRemoval(arguments.string("token"))
            return try summary()
        case "saveBalance":
            return try saveBalance(arguments)
        case "balanceDetails":
            return try query("SELECT * FROM balance_cache WHERE account_id IN (SELECT id FROM accounts WHERE group_id = ? AND account_index > ? ORDER BY account_index LIMIT 50) ORDER BY account_id, network_id", [try arguments.string("id"), arguments["after"] as? Int ?? -1])
        case "aliasPage":
            return try query("""
                SELECT id, platform, uid FROM aliases WHERE group_id = ? AND id > ?
                ORDER BY id LIMIT ?
                """, [try arguments.string("id"), try arguments.int("after"), 51])
        case "beginPreview":
            try transaction {
                try clearPreview()
                try execute("""
                    INSERT INTO preview (id, session, revision, account_name) SELECT 1, ?, revision, ? FROM state
                    """, [try arguments.string("session"), try arguments.string("accountName")])
            }
            return nil
        case "stage":
            try stage(arguments)
            return nil
        case "finishPreview":
            let session = try arguments.string("session")
            try requirePreview(session)
            try execute("UPDATE preview SET ready = 1 WHERE session = ?", [session])
            return try query("SELECT status, count(*) AS count FROM preview_rows GROUP BY status")
        case "previewPage":
            try requirePreview(arguments.string("session"), ready: true, current: false)
            let after = try arguments.int("after")
            if let status = arguments["status"] as? String {
                return try query("""
                    SELECT * FROM preview_rows WHERE status = ? AND source_line > ? ORDER BY source_line LIMIT 51
                    """, [status, after])
            }
            return try query("SELECT * FROM preview_rows WHERE source_line > ? ORDER BY source_line LIMIT 51", [after])
        case "commitPreview":
            return try commit(arguments.string("session"))
        case "cancelPreview":
            let session = try arguments.string("session")
            if try !query("SELECT 1 FROM preview WHERE session = ?", [session]).isEmpty {
                try transaction { try clearPreview() }
            }
            return nil
        default:
            throw WalletDatabaseError()
        }
    }

    private func migrate(_ args: [String: Any]) throws {
        try transaction {
            guard try integer("SELECT migrated AS value FROM state") == 0 else { return }
            for record in try args.records("groups") {
                // Preserve even historical duplicates. Only the first wallet becomes the deduplication target.
                try insertGroup(record, keepDuplicate: true)
            }
            let selected = args["activeId"] as? String
            let valid = try selected.flatMap { try account($0, includeSecret: false) }
            let active = valid == nil ? try firstAccountID() : selected
            try execute("UPDATE state SET migrated = 1, active_id = ? WHERE id = 1", [active])
        }
    }

    private func summary() throws -> [String: Any] {
        guard var result = try query("SELECT groups_count, accounts_count, private_count, active_id FROM state").first else {
            throw WalletDatabaseError()
        }
        if let active = result["active_id"] as? String {
            guard let selected = try account(active, includeSecret: true) else { throw WalletDatabaseError() }
            result["selected"] = selected
        }
        return result
    }

    private func account(_ id: String, includeSecret: Bool) throws -> [String: Any]? {
        let columns = includeSecret ? ", g.secret" : ""
        return try query("""
            SELECT a.*, g.name AS group_name, g.kind, g.network_id \(columns),
              (SELECT count(*) FROM accounts WHERE group_id = g.id) AS group_count
            FROM accounts a JOIN wallet_groups g ON g.id = a.group_id WHERE a.id = ?
            """, [id]).first
    }

    private func firstAccountID() throws -> String? {
        try query("""
            SELECT a.id FROM wallet_groups g JOIN accounts a ON a.group_id = g.id
            WHERE a.account_index = 0 ORDER BY g.sequence LIMIT 1
            """).first?["id"] as? String
    }

    private func group(_ id: String, includeSecret: Bool = false) throws -> [String: Any] {
        let columns = includeSecret ? ", secret" : ""
        guard var row = try query("""
            SELECT id, name, kind, network_id, sequence, next_account_index \(columns),
              (SELECT count(*) FROM accounts WHERE group_id = wallet_groups.id) AS account_count,
              EXISTS(SELECT 1 FROM aliases WHERE group_id = wallet_groups.id) AS has_aliases
            FROM wallet_groups WHERE id = ?
            """, [id]).first else { throw WalletDatabaseError() }
        let entries = try query("SELECT * FROM accounts WHERE group_id = ? ORDER BY account_index", [id])
        row["accounts"] = entries
        if row["kind"] as? String == "mnemonic", let defaults = try? derivationDefaults(entries, nextIndex: row["next_account_index"] as? Int) {
            row.merge(defaults) { _, value in value }
        }
        return row
    }

    private func insertGroup(_ record: [String: Any], keepDuplicate: Bool = false) throws {
        let id = try record.string("id")
        let kind = try record.string("kind")
        let name = try record.string("name")
        let network = record["network_id"] as? Int
        var identity = record["identity"] as? String
        if keepDuplicate, let identityValue = identity, let network,
           try !query("SELECT 1 FROM wallet_groups WHERE network_id = ? AND identity = ?", [network, identityValue]).isEmpty {
            identity = nil
        }
        try execute("""
            INSERT INTO wallet_groups (id, name, kind, secret, network_id, identity) VALUES (?, ?, ?, ?, ?, ?)
            """, [id, name, kind, try record.string("secret"), network, identity])
        try term(name, group: id, index: -1)
        for entry in try record.records("accounts") {
            try insertAccount(entry, group: id)
        }
        try execute("UPDATE wallet_groups SET next_account_index = max(?, (SELECT coalesce(max(account_index), 0) + 1 FROM accounts WHERE group_id = ?)) WHERE id = ?", [record["nextAccountIndex"] as? Int ?? 1, id, id])
        try execute("""
            UPDATE state SET groups_count = groups_count + 1, private_count = private_count + ? WHERE id = 1
            """, [kind == "privateKey" ? 1 : 0])
    }

    private func insertAccount(_ entry: [String: Any], group id: String) throws {
        let index = try entry.int("account_index")
        let name = try entry.string("name")
        let evm = try entry.string("evm")
        let tron = try entry.string("tron")
        try execute("""
            INSERT INTO accounts (id, group_id, account_index, name, evm, tron, evm_path, tron_path, legacy_address_mode)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, ["\(id):\(index)", id, index, name, evm, tron, entry["evm_path"] as? String, entry["tron_path"] as? String, entry["legacy_address_mode"] as? Int ?? 0])
        try term(name, group: id, index: index)
        try term(evm, group: id, index: index)
        try term(tron, group: id, index: index)
        try execute("UPDATE state SET accounts_count = accounts_count + 1 WHERE id = 1")
    }

    private func term(_ text: String, group id: String, index: Int) throws {
        try execute("INSERT OR IGNORE INTO search_terms VALUES (?, ?, ?)", [text.lowercased(), id, index])
    }

    private func addMnemonic(_ record: [String: Any]) throws {
        try transaction {
            let identity = try record.string("identity")
            let duplicate = try query("""
                SELECT id FROM wallet_groups WHERE kind = 'mnemonic' AND identity = ? ORDER BY sequence LIMIT 1
                """, [identity]).first
            let id: String
            if let duplicate { id = try duplicate.string("id") }
            else {
                id = try record.string("id")
                try insertGroup(record)
            }
            try setActive("\(id):0")
        }
    }

    private func addPrivate(_ args: [String: Any]) throws -> [String] {
        try transaction {
            var results: [String] = []
            var added = 0
            let groups = try args.records("groups")
            guard let names = args["names"] as? [String], names.count == groups.count else {
                throw WalletDatabaseError()
            }
            for var record in groups {
                let exists = try query("SELECT 1 FROM wallet_groups WHERE network_id = ? AND identity = ?", [
                    try record.int("network_id"), try record.string("identity")
                ])
                if !exists.isEmpty { results.append("duplicate"); continue }
                let name = names[added]
                guard !name.isEmpty, name.utf16.count <= 64 else {
                    results.append("invalid_name")
                    continue
                }
                record["name"] = name
                try insertGroup(record)
                let hasActive = try query("SELECT active_id FROM state").first?["active_id"] != nil
                if args["select"] as? Bool == true || !hasActive {
                    try setActive("\(record.string("id")):0")
                } else {
                    try changed()
                }
                results.append("new")
                added += 1
            }
            return results
        }
    }

    private func derivationDefaults(_ entries: [[String: Any]], nextIndex: Int? = nil) throws -> [String: Any] {
        let next = max(nextIndex ?? 0, try entries.map { try $0.int("account_index") }.max().map { $0 + 1 } ?? 0)
        guard next < 0x80000000 else { throw WalletDatabaseError("derive_index") }
        var result: [String: Any] = ["next_index": next]
        for (column, coin) in [("evm_path", 60), ("tron_path", 195)] {
            let used = try Set(entries.map { entry in
                if let path = entry[column] as? String { return path }
                let index = try entry.int("account_index")
                return "m/44'/\(coin)'/0'/0/\(index)"
            })
            var index = next
            while used.contains("m/44'/\(coin)'/0'/0/\(index)") {
                index += 1
                guard index < 0x80000000 else { throw WalletDatabaseError("derive_index") }
            }
            result["next_" + column] = "m/44'/\(coin)'/0'/0/\(index)"
        }
        return result
    }

    private func derive(_ args: [String: Any]) throws -> [String: Any] {
        let id = try args.string("id")
        guard var row = try query("SELECT secret, next_account_index AS next_index FROM wallet_groups WHERE kind = 'mnemonic' AND id = ?", [id]).first else {
            throw WalletDatabaseError("derive_kind")
        }
        let entries = try query("SELECT account_index, evm_path, tron_path FROM accounts WHERE group_id = ?", [id])
        row.merge(try derivationDefaults(entries, nextIndex: row["next_index"] as? Int)) { _, value in value }
        return row
    }

    private func addDerived(_ args: [String: Any]) throws {
        try transaction {
            let id = try args.string("id")
            guard let entry = args["account"] as? [String: Any],
                  try derive(args).int("next_index") == entry.int("account_index") else {
                throw WalletDatabaseError("wallet_changed")
            }
            let evm = try entry.string("evm")
            let tron = try entry.string("tron")
            guard try query("SELECT 1 FROM accounts WHERE group_id = ? AND (evm = ? COLLATE NOCASE OR tron = ?) LIMIT 1", [id, evm, tron]).isEmpty else {
                throw WalletDatabaseError("derive_duplicate")
            }
            try insertAccount(entry, group: id)
            try execute("UPDATE wallet_groups SET next_account_index = ? WHERE id = ?", [try entry.int("account_index") + 1, id])
            try setActive("\(id):\(entry.int("account_index"))")
        }
    }

    private func select(_ id: String) throws {
        guard try account(id, includeSecret: false) != nil else { throw WalletDatabaseError("account_missing") }
        try setActive(id)
    }

    private func setActive(_ id: String) throws {
        try execute("UPDATE state SET active_id = ?, revision = revision + 1 WHERE id = 1", [id])
    }

    private func changed() throws {
        try execute("UPDATE state SET revision = revision + 1 WHERE id = 1")
    }

    private func rename(_ args: [String: Any]) throws {
        let id = try args.string("id")
        let name = try args.string("name")
        try transaction {
            if args["account"] as? Bool == true {
                guard let row = try account(id, includeSecret: false) else { throw WalletDatabaseError("account_missing") }
                let group = try row.string("group_id")
                let index = try row.int("account_index")
                try execute("UPDATE accounts SET name = ? WHERE id = ?", [name, id])
                try execute("DELETE FROM search_terms WHERE group_id = ? AND account_index = ?", [group, index])
                try term(name, group: group, index: index)
                try term(row.string("evm"), group: group, index: index)
                try term(row.string("tron"), group: group, index: index)
            } else {
                guard try !query("SELECT 1 FROM wallet_groups WHERE id = ?", [id]).isEmpty else {
                    throw WalletDatabaseError("wallet_missing")
                }
                try execute("UPDATE wallet_groups SET name = ? WHERE id = ?", [name, id])
                try execute("DELETE FROM search_terms WHERE group_id = ? AND account_index = -1", [id])
                try term(name, group: id, index: -1)
            }
            try changed()
        }
    }

    private func walletPage(_ args: [String: Any]) throws -> [[String: Any]] {
        let prefix = try args.string("query").lowercased()
        if prefix.isEmpty {
            let after = args["sequence"] as? Int ?? 0
            return try query("SELECT id FROM wallet_groups WHERE sequence > ? ORDER BY sequence LIMIT 51", [after]).map {
                try group($0.string("id"))
            }
        }

        let pattern = prefix.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_") + "%"
        let afterTerm = args["term"] as? String ?? ""
        let afterGroup = args["group"] as? String ?? ""
        // Keep only the first matching term per wallet before applying LIMIT.
        let matches = try query("""
            SELECT s.term, s.group_id FROM search_terms s
            WHERE s.term LIKE ? ESCAPE '\\' AND (s.term, s.group_id) > (?, ?)
              AND NOT EXISTS (
                SELECT 1 FROM search_terms t
                WHERE t.group_id = s.group_id AND t.term LIKE ? ESCAPE '\\'
                  AND (t.term, t.account_index) < (s.term, s.account_index)
              )
            ORDER BY s.term, s.group_id LIMIT 51
            """, [pattern, afterTerm, afterGroup, pattern])
        return try matches.map { match in
            let id = try match.string("group_id")
            var row = try group(id)
            row["term"] = match["term"]
            if try row.string("kind") == "mnemonic" {
                let indices = try query("""
                    SELECT DISTINCT account_index FROM search_terms
                    WHERE group_id = ? AND term LIKE ? ESCAPE '\\'
                    """, [id, pattern]).map { try $0.int("account_index") }
                if !indices.contains(-1), let entries = row["accounts"] as? [[String: Any]] {
                    let visible = Set(indices)
                    row["accounts"] = try entries.filter { visible.contains(try $0.int("account_index")) }
                }
            }
            return row
        }
    }

    private func requirePreview(_ session: String, ready: Bool = false, current: Bool = true) throws {
        let row = try query("""
            SELECT p.ready, p.revision = s.revision AS current
            FROM preview p JOIN state s ON s.id = p.id WHERE p.session = ?
            """, [session]).first
        guard let row, !ready || row["ready"] as? Int == 1,
              !current || row["current"] as? Int == 1 else { throw WalletDatabaseError("wallet_changed") }
    }

    private func clearPreview() throws {
        try execute("DELETE FROM preview_rows")
        try execute("DELETE FROM preview_aliases")
        try execute("DELETE FROM preview_wallets")
        try execute("DELETE FROM preview")
    }

    private func stage(_ args: [String: Any]) throws {
        try transaction {
            let session = try args.string("session")
            try requirePreview(session)
            for row in try args.records("rows") {
                let line = try row.int("line")
                var status = try row.string("status")
                let platform = row["platform"] as? String
                let uid = row["uid"] as? String
                let network = row["network"] as? Int
                if status == "valid" {
                    guard let platform, let uid, let network else { throw WalletDatabaseError() }
                    let identity = try row.string("identity")
                    let existing = try query("""
                        SELECT id FROM wallet_groups WHERE network_id = ? AND identity = ?
                        UNION ALL SELECT id FROM preview_wallets WHERE network_id = ? AND identity = ? LIMIT 1
                        """, [network, identity, network, identity]).first
                    let id: String
                    if let existing {
                        id = try existing.string("id")
                        let duplicate = try query("""
                            SELECT 1 FROM aliases WHERE group_id = ? AND platform = ? AND uid = ?
                            UNION ALL SELECT 1 FROM preview_aliases WHERE group_id = ? AND platform = ? AND uid = ? LIMIT 1
                            """, [id, platform, uid, id, platform, uid])
                        status = duplicate.isEmpty ? "alias" : "duplicate"
                    } else {
                        id = UUID().uuidString.lowercased()
                        status = "new"
                        try execute("""
                            INSERT INTO preview_wallets VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                            """, [line, id, "\(platform) · \(uid)", try row.string("secret"), network, identity,
                                  try row.string("evm"), try row.string("tron")])
                    }
                    if status != "duplicate" {
                        try execute("INSERT INTO preview_aliases VALUES (?, ?, ?, ?)", [line, id, platform, uid])
                    }
                }
                try execute("INSERT INTO preview_rows VALUES (?, ?, ?, ?, ?, ?, ?)", [
                    line, status, row["error"], platform, uid, row["address"], network
                ])
            }
        }
    }

    private func commit(_ session: String) throws -> [String: Any] {
        // Keep dirty pages in the cache during the bulk copy. Random index
        // inserts otherwise cause repeated encrypted WAL page spills and reads.
        _ = try query("PRAGMA cache_size = -98304")
        _ = try query("PRAGMA cache_spill = OFF")
        defer {
            _ = try? query("PRAGMA cache_spill = ON")
            _ = try? query("PRAGMA cache_size = -2000")
        }
        return try transaction {
            try requirePreview(session, ready: true)
            let count = try integer("SELECT count(*) AS value FROM preview_wallets")
            let first = try query("SELECT id, network_id FROM preview_wallets ORDER BY source_line LIMIT 1").first
            let wasEmpty = try integer("SELECT groups_count AS value FROM state") == 0
            try execute("""
                INSERT INTO wallet_groups (id, name, kind, secret, network_id, identity)
                SELECT id, name, 'privateKey', secret, network_id, identity FROM preview_wallets ORDER BY source_line
                """)
            try execute("""
                INSERT INTO accounts (id, group_id, account_index, name, evm, tron)
                SELECT w.id || ':0', w.id, 0, p.account_name, w.evm, w.tron
                FROM preview_wallets w CROSS JOIN preview p ORDER BY w.source_line
                """)
            try execute("""
                INSERT INTO aliases (group_id, platform, uid)
                SELECT group_id, platform, uid FROM preview_aliases ORDER BY source_line
                """)
            #if DEBUG
            if failNextCommit {
                failNextCommit = false
                throw WalletDatabaseError()
            }
            #endif
            // Use the same Unicode lowercase function as interactive renames.
            try execute("""
                INSERT OR IGNORE INTO search_terms
                SELECT * FROM (
                SELECT wallet_lower(name), id, -1 FROM preview_wallets
                UNION ALL SELECT wallet_lower(p.account_name), w.id, 0 FROM preview_wallets w CROSS JOIN preview p
                UNION ALL SELECT wallet_lower(evm), id, 0 FROM preview_wallets
                UNION ALL SELECT wallet_lower(tron), id, 0 FROM preview_wallets
                UNION ALL SELECT wallet_lower(platform), group_id, -2 FROM preview_aliases
                UNION ALL SELECT wallet_lower(uid), group_id, -2 FROM preview_aliases
                UNION ALL SELECT wallet_lower(platform || ' · ' || uid), group_id, -2 FROM preview_aliases
                ) ORDER BY 1 COLLATE NOCASE, 2, 3
                """)
            try execute("""
                UPDATE state SET groups_count = groups_count + ?, accounts_count = accounts_count + ?,
                private_count = private_count + ?, revision = revision + 1 WHERE id = 1
                """, [count, count, count])
            if wasEmpty, let first {
                try setActive("\(first.string("id")):0")
                try execute("UPDATE state SET pending_network = ? WHERE id = 1", [try first.int("network_id")])
            }
            // Keep redacted results available for pagination until the panel closes.
            try execute("DELETE FROM preview_aliases")
            try execute("DELETE FROM preview_wallets")
            var result = try summary()
            if wasEmpty, let first { result["initial_network"] = first["network_id"] }
            return result
        }
    }

    private static let managementSchema = [
        "ALTER TABLE wallet_groups ADD COLUMN next_account_index INTEGER NOT NULL DEFAULT 1",
        "CREATE INDEX wallet_network ON wallet_groups(network_id, sequence)",
        "CREATE INDEX wallet_name ON wallet_groups(name COLLATE NOCASE, id)",
        "CREATE INDEX alias_platform ON aliases(platform COLLATE NOCASE, group_id)",
        """
        CREATE TABLE balance_cache (
            account_id TEXT NOT NULL REFERENCES accounts(id), network_id INTEGER NOT NULL,
            amount TEXT, payload TEXT NOT NULL, attempted_at INTEGER NOT NULL,
            updated_at INTEGER, incomplete INTEGER NOT NULL, failed INTEGER NOT NULL,
            PRIMARY KEY(account_id, network_id)
        )
        """,
        """
        CREATE TABLE balance_totals (
            group_id TEXT NOT NULL REFERENCES wallet_groups(id), network_id INTEGER NOT NULL,
            amount TEXT, sort_key TEXT NOT NULL, incomplete INTEGER NOT NULL,
            updated_at INTEGER, attempted_at INTEGER,
            PRIMARY KEY(group_id, network_id)
        )
        """,
        "CREATE INDEX balance_rank ON balance_totals(network_id, sort_key DESC, group_id)",
        "CREATE TABLE removal_state (token TEXT PRIMARY KEY, revision INTEGER NOT NULL, account_id TEXT)",
        "CREATE TABLE removal_targets (token TEXT NOT NULL, group_id TEXT NOT NULL, PRIMARY KEY(token, group_id))",
    ]

    private func managementFilter(_ args: [String: Any]) -> (String, [Any?]) {
        var conditions: [String] = []
        var bindings: [Any?] = []
        let prefix = (args["query"] as? String ?? "").lowercased()
        if !prefix.isEmpty {
            let escaped = prefix.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_") + "%"
            conditions.append("g.id IN (SELECT group_id FROM search_terms WHERE term LIKE ? ESCAPE '\\')")
            bindings.append(escaped)
        }
        if let kind = args["kind"] as? String {
            conditions.append("g.kind = ?")
            bindings.append(kind)
        }
        if let chain = args["chain"] as? Int {
            let enabled = (args["enabled"] as? [Int] ?? []).contains(chain)
            conditions.append(enabled ? "(g.network_id = ? OR g.network_id IS NULL)" : "g.network_id = ?")
            bindings.append(chain)
        }
        if let platform = args["platform"] as? String {
            if platform.isEmpty {
                conditions.append("NOT EXISTS (SELECT 1 FROM aliases p WHERE p.group_id = g.id)")
            } else {
                conditions.append("EXISTS (SELECT 1 FROM aliases p WHERE p.group_id = g.id AND p.platform = ? COLLATE NOCASE)")
                bindings.append(platform)
            }
        }
        return (conditions.isEmpty ? "1" : conditions.joined(separator: " AND "), bindings)
    }

    private func managementGroup(_ id: String) throws -> [String: Any] {
        guard var row = try query("""
            SELECT g.id, g.name, g.kind, g.network_id, g.sequence, g.next_account_index,
              (SELECT count(*) FROM accounts WHERE group_id = g.id) AS account_count,
              EXISTS(SELECT 1 FROM aliases WHERE group_id = g.id) AS has_aliases,
              (SELECT platform FROM aliases WHERE group_id = g.id ORDER BY id LIMIT 1) AS platform
            FROM wallet_groups g WHERE g.id = ?
            """, [id]).first else { throw WalletDatabaseError("wallet_missing") }
        row["accounts"] = try query("SELECT * FROM accounts WHERE group_id = ? ORDER BY account_index LIMIT 1", [id])
        if row["kind"] as? String == "mnemonic" {
            row.merge(try derive(["id": id]).filter { $0.key != "secret" }) { _, value in value }
        }
        return row
    }

    private func managementPage(_ args: [String: Any]) throws -> [String: Any] {
        let (filter, bindings) = managementFilter(args)
        let revision = try integer("SELECT revision AS value FROM state")
        let countKey = filter + bindings.map { String(describing: $0) }.joined(separator: "\u{1f}")
        let count: Int
        if let cached = managementCounts[countKey], cached.revision == revision {
            count = cached.count
        } else {
            count = filter == "1"
                ? try integer("SELECT groups_count AS value FROM state")
                : try query("SELECT count(*) AS value FROM wallet_groups g WHERE \(filter)", bindings).first?["value"] as? Int ?? 0
            if managementCounts.count > 32 { managementCounts.removeAll() }
            managementCounts[countKey] = (revision, count)
        }
        let chain = args["chain"] as? Int ?? 0
        let sort = args["sort"] as? String ?? "value"
        let order: String
        switch sort {
        case "name": order = "g.name COLLATE NOCASE, g.id"
        case "newest": order = "g.sequence DESC, g.id"
        default: order = "coalesce(b.sort_key, '') DESC, g.id"
        }
        let offset = max(0, args["offset"] as? Int ?? 0)
        let matches = try query("""
            SELECT g.id, b.amount, b.incomplete, b.updated_at, b.attempted_at
            FROM wallet_groups g LEFT JOIN balance_totals b ON b.group_id = g.id AND b.network_id = ?
            WHERE \(filter) ORDER BY \(order) LIMIT 51 OFFSET ?
            """, [chain] + bindings + [offset])
        return [
            "total": count,
            "more": matches.count > 50,
            "groups": try matches.prefix(50).map { item -> [String: Any] in
                var row = try managementGroup(item.string("id"))
                for key in ["amount", "incomplete", "updated_at", "attempted_at"] {
                    row[key] = item[key]
                }
                return row
            },
        ]
    }

    private func prepareRemoval(_ args: [String: Any]) throws -> [String: Any] {
        try transaction {
            let token = UUID().uuidString
            let accountID = args["account"] as? String
            try execute("INSERT INTO removal_state SELECT ?, revision, ? FROM state", [token, accountID])
            if let accountID {
                guard let account = try account(accountID, includeSecret: false),
                      try account.int("account_index") > 0,
                      try account.string("kind") == "mnemonic" else {
                    throw WalletDatabaseError("protected_account")
                }
                try execute("INSERT INTO removal_targets VALUES (?, ?)", [token, try account.string("group_id")])
            } else if let ids = args["ids"] as? [String] {
                guard !ids.isEmpty else { throw WalletDatabaseError("wallet_missing") }
                for id in Set(ids) {
                    guard try !query("SELECT 1 FROM wallet_groups WHERE id = ?", [id]).isEmpty else {
                        throw WalletDatabaseError("removal_changed")
                    }
                    try execute("INSERT INTO removal_targets VALUES (?, ?)", [token, id])
                }
            } else {
                let (filter, bindings) = managementFilter(args)
                try execute("INSERT INTO removal_targets SELECT ?, g.id FROM wallet_groups g WHERE \(filter)", [token] + bindings)
                for id in args["excluded"] as? [String] ?? [] {
                    try execute("DELETE FROM removal_targets WHERE token = ? AND group_id = ?", [token, id])
                }
            }
            let groups = try query("SELECT count(*) AS value FROM removal_targets WHERE token = ?", [token]).first?["value"] as? Int ?? 0
            guard groups > 0 else { throw WalletDatabaseError("wallet_missing") }
            let count = accountID == nil
                ? try query("SELECT count(*) AS value FROM accounts WHERE group_id IN (SELECT group_id FROM removal_targets WHERE token = ?)", [token]).first?["value"] as? Int ?? 0
                : 1
            let active = try query("SELECT active_id FROM state").first?["active_id"] as? String
            let containsActive: Bool
            if let accountID { containsActive = active == accountID }
            else {
                containsActive = try !query("SELECT 1 FROM accounts WHERE id = ? AND group_id IN (SELECT group_id FROM removal_targets WHERE token = ?)", [active, token]).isEmpty
            }
            return ["token": token, "wallets": accountID == nil ? groups : 0, "accounts": count, "active": containsActive]
        }
    }

    private func removalPage(_ args: [String: Any]) throws -> [[String: Any]] {
        try query("""
            SELECT g.id, g.name, g.kind, g.network_id, b.amount, b.incomplete
            FROM removal_targets t JOIN wallet_groups g ON g.id = t.group_id
            LEFT JOIN balance_totals b ON b.group_id = g.id AND b.network_id = 0
            WHERE t.token = ? ORDER BY g.sequence LIMIT 51 OFFSET ?
            """, [try args.string("token"), max(0, args["offset"] as? Int ?? 0)])
    }

    private func cancelRemoval(_ token: String) throws {
        try transaction {
            try execute("DELETE FROM removal_targets WHERE token = ?", [token])
            try execute("DELETE FROM removal_state WHERE token = ?", [token])
        }
    }

    private func commitRemoval(_ token: String) throws {
        try transaction {
            guard let preview = try query("""
                SELECT r.account_id FROM removal_state r JOIN state s ON r.revision = s.revision WHERE r.token = ?
                """, [token]).first else { throw WalletDatabaseError("removal_changed") }
            let accountID = preview["account_id"] as? String
            let target = "SELECT group_id FROM removal_targets WHERE token = ?"
            let fallbackGroup = accountID.flatMap { id in
                try? account(id, includeSecret: false)?["group_id"] as? String
            }
            if let accountID {
                guard let row = try account(accountID, includeSecret: false), try row.int("account_index") > 0 else {
                    throw WalletDatabaseError("protected_account")
                }
                try execute("DELETE FROM balance_cache WHERE account_id = ?", [accountID])
                try execute("DELETE FROM search_terms WHERE group_id = ? AND account_index = ?", [try row.string("group_id"), try row.int("account_index")])
                try execute("DELETE FROM accounts WHERE id = ?", [accountID])
                try refreshTotals(row.string("group_id"))
            } else {
                try execute("DELETE FROM balance_cache WHERE account_id IN (SELECT id FROM accounts WHERE group_id IN (\(target)))", [token])
                for table in ["balance_totals", "aliases", "search_terms", "accounts"] {
                    try execute("DELETE FROM \(table) WHERE group_id IN (\(target))", [token])
                }
                try execute("DELETE FROM wallet_groups WHERE id IN (\(target))", [token])
            }
            let active = try query("SELECT active_id FROM state").first?["active_id"] as? String
            if let active, try account(active, includeSecret: false) == nil {
                let fallback: String?
                if let fallbackGroup { fallback = "\(fallbackGroup):0" }
                else { fallback = try firstAccountID() }
                try execute("UPDATE state SET active_id = ?, pending_network = NULL WHERE id = 1", [fallback])
            }
            try execute("""
                UPDATE state SET
                  groups_count = (SELECT count(*) FROM wallet_groups),
                  accounts_count = (SELECT count(*) FROM accounts),
                  private_count = (SELECT count(*) FROM wallet_groups WHERE kind = 'privateKey'),
                  revision = revision + 1 WHERE id = 1
                """)
            try execute("DELETE FROM removal_targets WHERE token = ?", [token])
            try execute("DELETE FROM removal_state WHERE token = ?", [token])
            #if DEBUG
            if failNextCommit {
                failNextCommit = false
                throw WalletDatabaseError()
            }
            #endif
        }
    }

    /// Adds integer strings in units of 10^-72 without floating-point conversion.
    private func addAmounts(_ a: String, _ b: String) -> String {
        let left = Array(a.utf8.reversed()), right = Array(b.utf8.reversed())
        var carry = 0, output: [UInt8] = []
        for i in 0..<max(left.count, right.count) {
            let sum = (i < left.count ? Int(left[i]) - 48 : 0) +
                (i < right.count ? Int(right[i]) - 48 : 0) + carry
            output.append(UInt8(sum % 10 + 48))
            carry = sum / 10
        }
        if carry > 0 { output.append(UInt8(carry + 48)) }
        return String(decoding: output.reversed(), as: UTF8.self)
    }

    private func refreshTotals(_ id: String) throws {
        let rows = try query("""
            SELECT c.* FROM balance_cache c JOIN accounts a ON a.id = c.account_id WHERE a.group_id = ?
            """, [id])
        let accountCount = try query("SELECT count(*) AS value FROM accounts WHERE group_id = ?", [id]).first?["value"] as? Int ?? 0
        try execute("DELETE FROM balance_totals WHERE group_id = ?", [id])
        let chains = Set(rows.compactMap { $0["network_id"] as? Int })
        for chain in [0] + chains.sorted() {
            let scoped = chain == 0 ? rows : rows.filter { $0["network_id"] as? Int == chain }
            var amount: String?
            for row in scoped {
                if let value = row["amount"] as? String { amount = addAmounts(amount ?? "0", value) }
            }
            let represented = Set(scoped.compactMap { $0["account_id"] as? String }).count
            // Coverage bits match BalanceCoverage in wallet_management.dart.
            var incomplete = represented < accountCount ? 8 : 0
            for row in scoped {
                incomplete |= row["incomplete"] as? Int ?? 1
                if row["failed"] as? Int == 1 { incomplete |= 4 }
            }
            let timestamps = scoped.compactMap { $0["updated_at"] as? Int }
            let attempts = scoped.compactMap { $0["attempted_at"] as? Int }
            let key = amount.map { String(format: "%010d", $0.count) + $0 } ?? ""
            try execute("INSERT INTO balance_totals VALUES (?, ?, ?, ?, ?, ?, ?)", [
                id, chain, amount, key, incomplete,
                timestamps.count == scoped.count ? timestamps.min() : nil, attempts.min(),
            ])
        }
    }

    private func saveBalance(_ args: [String: Any]) throws -> Bool {
        try transaction {
            let id = try args.string("id")
            guard let owner = try account(id, includeSecret: false) else { return false }
            let records = try args.records("records")
            let time = try args.int("time")
            let chains = try records.map { try $0.int("chain") }
            if chains.isEmpty {
                try execute("DELETE FROM balance_cache WHERE account_id = ?", [id])
            } else {
                let placeholders = chains.map { _ in "?" }.joined(separator: ",")
                try execute("DELETE FROM balance_cache WHERE account_id = ? AND network_id NOT IN (\(placeholders))", [id] + chains.map { $0 as Any? })
            }
            for record in records {
                let chain = try record.int("chain")
                let failed = try record.int("failed")
                let rawAmount = record["amount"] as? String
                let amount = rawAmount.map { value -> String in
                    let digits = value.drop(while: { $0 == "0" })
                    return digits.isEmpty ? "0" : String(digits)
                }
                if let amount, amount.isEmpty || !amount.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }) {
                    throw WalletDatabaseError()
                }
                let previous = try query("SELECT * FROM balance_cache WHERE account_id = ? AND network_id = ?", [id, chain]).first
                let keepPrevious = failed != 0 && previous?["updated_at"] != nil
                try execute("INSERT OR REPLACE INTO balance_cache VALUES (?, ?, ?, ?, ?, ?, ?, ?)", [
                    id, chain, keepPrevious ? previous?["amount"] : amount,
                    keepPrevious ? previous?["payload"] : try record.string("payload"),
                    time, keepPrevious ? previous?["updated_at"] : (failed == 0 ? time : nil),
                    try record.int("incomplete"), failed,
                ])
            }
            try refreshTotals(owner.string("group_id"))
            return true
        }
    }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try operation()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func integer(_ sql: String) throws -> Int {
        guard let value = try query(sql).first?["value"] as? Int else { throw WalletDatabaseError() }
        return value
    }

    private func statement(_ sql: String, _ bindings: [Any?]) throws -> OpaquePointer {
        let statement: OpaquePointer
        if let cached = statements[sql] {
            statement = cached
        } else {
            var prepared: OpaquePointer?
            let status = sqlite3_prepare_v2(handle, sql, -1, &prepared, nil)
            guard status == SQLITE_OK, let prepared else {
                throw WalletDatabaseError()
            }
            statements[sql] = prepared
            statement = prepared
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case let value as String:
                status = value.withCString { sqlite3_bind_text(statement, index, $0, Int32(value.utf8.count), transient) }
            case let value as Int:
                status = sqlite3_bind_int64(statement, index, Int64(value))
            case nil, is NSNull:
                status = sqlite3_bind_null(statement, index)
            default:
                reset(statement)
                throw WalletDatabaseError()
            }
            guard status == SQLITE_OK else { reset(statement); throw WalletDatabaseError() }
        }
        return statement
    }

    private func registerLowercase() throws {
        let status = sqlite3_create_function_v2(
            handle, "wallet_lower", 1, SQLITE_UTF8 | SQLITE_DETERMINISTIC, nil,
            { context, _, values in
                guard let value = values?[0], let bytes = sqlite3_value_text(value) else {
                    sqlite3_result_null(context)
                    return
                }
                let count = Int(sqlite3_value_bytes(value))
                let text = String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self).lowercased()
                let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                text.withCString { sqlite3_result_text(context, $0, Int32(text.utf8.count), transient) }
            }, nil, nil, nil
        )
        guard status == SQLITE_OK else { throw WalletDatabaseError() }
    }

    private func reset(_ statement: OpaquePointer) {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
    }

    private func execute(_ sql: String, _ bindings: [Any?] = []) throws {
        let statement = try statement(sql, bindings)
        defer { reset(statement) }
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE else {
            throw WalletDatabaseError()
        }
    }

    private func query(_ sql: String, _ bindings: [Any?] = []) throws -> [[String: Any]] {
        let statement = try statement(sql, bindings)
        defer { reset(statement) }
        var rows: [[String: Any]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_DONE: return rows
            case SQLITE_ROW:
                var row: [String: Any] = [:]
                for index in 0..<sqlite3_column_count(statement) {
                    let name = String(cString: sqlite3_column_name(statement, index))
                    switch sqlite3_column_type(statement, index) {
                    case SQLITE_INTEGER: row[name] = Int(sqlite3_column_int64(statement, index))
                    case SQLITE_TEXT:
                        let bytes = sqlite3_column_text(statement, index)!
                        let count = Int(sqlite3_column_bytes(statement, index))
                        row[name] = String(decoding: UnsafeBufferPointer(start: bytes, count: count), as: UTF8.self)
                    case SQLITE_NULL: break
                    default: throw WalletDatabaseError()
                    }
                }
                rows.append(row)
            default:
                throw WalletDatabaseError()
            }
        }
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) throws -> String {
        guard let value = self[key] as? String else { throw WalletDatabaseError() }
        return value
    }

    func int(_ key: String) throws -> Int {
        guard let value = self[key] as? Int else { throw WalletDatabaseError() }
        return value
    }

    func records(_ key: String) throws -> [[String: Any]] {
        guard let value = self[key] as? [[String: Any]] else { throw WalletDatabaseError() }
        return value
    }
}
