import Foundation
import FlutterMacOS
import Security
import XCTest
@testable import Asterkeel_Wallet

final class RunnerTests: XCTestCase {
    private let session = "synthetic-preview"
    private let walletID = "legacy-private"
    private let key = String(repeating: "0", count: 63) + "1"
    private let address = "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
    private let tron = "TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC"

    func testEncryptedMigrationAliasCommitAndAbandonedPreview() throws {
        let token = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("asterkeel-test-" + token)
        let service = "com.example.stoneWallet.wallet-database.test." + token
        defer {
            try? FileManager.default.removeItem(at: directory)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "wallet-database-v1",
                kSecAttrSynchronizable as String: false,
            ] as CFDictionary)
        }
        var database: MacWalletDatabase? = MacWalletDatabase(directory: directory, keychainService: service)
        let group: [String: Any] = [
            "id": walletID, "kind": "privateKey", "name": "Original",
            "secret": key, "network_id": 56, "identity": address.lowercased(),
            "accounts": [["account_index": 0, "name": "Legacy", "evm": address, "tron": tron]],
        ]
        _ = try database!.call("migrate", ["activeId": walletID + ":0", "groups": [group]])
        XCTAssertEqual(try summary(database!)["active_id"] as? String, walletID + ":0")

        try begin(database!)
        try stage(database!, [
            row(2, "Platform %_A", "00012"),
            row(3, "Other", "09876"),
            row(4, "Other", "09876"),
            row(5, "Other", "09876", network: 728126428),
        ])
        let counts = try finish(database!)
        XCTAssertEqual(counts, ["new": 1, "alias": 2, "duplicate": 1])
        XCTAssertEqual(try summary(database!)["groups_count"] as? Int, 1)
        _ = try database!.call("commitPreview", ["session": session])
        XCTAssertEqual(try summary(database!)["active_id"] as? String, walletID + ":0")
        XCTAssertEqual(try summary(database!)["groups_count"] as? Int, 2)
        XCTAssertEqual(try search(database!, "platform %_").map { $0["name"] as? String }, ["Original"])
        XCTAssertEqual(try search(database!, "098").count, 2)
        let aliases = try database!.call("aliasPage", ["id": walletID, "after": 0]) as? [[String: Any]]
        XCTAssertEqual(aliases?.compactMap { $0["uid"] as? String }, ["00012", "09876"])
        _ = try database!.call("rename", ["id": walletID, "name": "Renamed"])
        XCTAssertEqual(try search(database!, "0001").first?["name"] as? String, "Renamed")
        XCTAssertNil(try search(database!, "0001").first?["secret"])
        _ = try database!.call("cancelPreview", ["session": session])

        try begin(database!)
        try stage(database!, [row(2, "Other", "09876"), row(3, "Abandoned", "09999")])
        XCTAssertEqual(try finish(database!), ["alias": 1, "duplicate": 1])
        // Simulate quitting after a completed preview and before the commit.
        database = nil
        database = MacWalletDatabase(directory: directory, keychainService: service)
        XCTAssertEqual(try summary(database!)["groups_count"] as? Int, 2)
        XCTAssertThrowsError(try database!.call("commitPreview", ["session": session]))
        XCTAssertTrue(try search(database!, "abandoned").isEmpty)
        let selected = try XCTUnwrap(try summary(database!)["selected"] as? [String: Any])
        XCTAssertEqual(selected["evm"] as? String, address)
        XCTAssertEqual(selected["tron"] as? String, tron)

        // A mid-transaction failure must preserve the entire existing wallet book.
        try begin(database!)
        try stage(database!, [row(2, "Retry", "00200")])
        _ = try finish(database!)
        #if DEBUG
        database!.failNextCommit = true
        XCTAssertThrowsError(try database!.call("commitPreview", ["session": session]))
        XCTAssertTrue(try search(database!, "retry").isEmpty)
        #endif
        _ = try database!.call("commitPreview", ["session": session])
        XCTAssertEqual(try search(database!, "retry").count, 1)

        let secret = Data(key.utf8)
        for name in ["wallet.db", "wallet.db-wal", "wallet.db-shm"] {
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let bytes = try Data(contentsOf: url)
            XCTAssertNil(bytes.range(of: secret))
            XCTAssertFalse(bytes.starts(with: Data("SQLite format 3".utf8)))
        }
    }

    func testCustomDerivationPathsPersistAndDuplicateInsertionRollsBack() throws {
        let token = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("asterkeel-paths-" + token)
        let service = "com.example.stoneWallet.wallet-database.test." + token
        defer {
            try? FileManager.default.removeItem(at: directory)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "wallet-database-v1",
                kSecAttrSynchronizable as String: false,
            ] as CFDictionary)
        }
        var database: MacWalletDatabase? = MacWalletDatabase(directory: directory, keychainService: service)
        let group: [String: Any] = [
            "id": "root", "kind": "mnemonic", "name": "Root", "secret": "synthetic-test-phrase",
            "identity": "synthetic-root",
            "accounts": [["account_index": 0, "name": "First", "evm": address, "tron": tron]],
        ]
        _ = try database!.call("migrate", ["activeId": "root:0", "groups": [group]])
        let entry: [String: Any] = [
            "account_index": 1, "name": "Custom", "evm": "synthetic-evm", "tron": "synthetic-tron",
            "evm_path": "m/44'/60'/0'/0/2", "tron_path": "m/44'/195'/0'/0/925183485",
        ]
        _ = try database!.call("addDerived", ["id": "root", "account": entry])
        database = nil
        database = MacWalletDatabase(directory: directory, keychainService: service)
        let selected = try XCTUnwrap(try summary(database!)["selected"] as? [String: Any])
        XCTAssertEqual(selected["evm_path"] as? String, entry["evm_path"] as? String)
        XCTAssertEqual(selected["tron_path"] as? String, entry["tron_path"] as? String)
        let defaults = try XCTUnwrap(database!.call("derive", ["id": "root"]) as? [String: Any])
        XCTAssertEqual(defaults["next_index"] as? Int, 2)
        XCTAssertEqual(defaults["next_evm_path"] as? String, "m/44'/60'/0'/0/3")
        XCTAssertEqual(defaults["next_tron_path"] as? String, "m/44'/195'/0'/0/2")
        var duplicate = entry
        duplicate["account_index"] = 2
        for (column, value) in [("evm", "another-evm"), ("tron", "another-tron")] {
            var candidate = duplicate
            candidate[column] = value
            XCTAssertThrowsError(try database!.call("addDerived", ["id": "root", "account": candidate])) { error in
                XCTAssertEqual((error as? WalletDatabaseError)?.code, "derive_duplicate")
            }
        }
        XCTAssertEqual(try summary(database!)["accounts_count"] as? Int, 2)
        XCTAssertEqual(try summary(database!)["active_id"] as? String, "root:1")
        let page = try search(database!, "Custom")
        let visible = try XCTUnwrap((page.first?["accounts"] as? [[String: Any]])?.first)
        XCTAssertEqual(visible["tron_path"] as? String, entry["tron_path"] as? String)
        XCTAssertEqual(page.first?["next_evm_path"] as? String, "m/44'/60'/0'/0/3")
    }

    func testPlatformPoolsUseIndependentIndicesAndPersistentDeviceKey() throws {
        let token = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("asterkeel-pools-" + token)
        let service = "com.example.stoneWallet.wallet-database.test." + token
        defer {
            try? FileManager.default.removeItem(at: directory)
            for account in ["wallet-database-v1", "omni-pool-device-rsa"] {
                SecItemDelete([
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecAttrSynchronizable as String: false,
                ] as CFDictionary)
            }
        }
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let scope: [String: Any] = ["service": "https://example.test", "platform": "shop"]
        let sibling: [String: Any] = ["service": "https://example.test", "platform": "other"]
        var database: MacWalletDatabase? = MacWalletDatabase(directory: directory, keychainService: service)
        let create: [String: Any] = [
            "id": "seed", "mnemonic": mnemonic, "identity": "synthetic-identity",
            "bsc_next": 0, "tron_next": 0,
        ]
        _ = try database!.call("pool.create", scope.merging(create) { _, b in b })
        XCTAssertThrowsError(try database!.call("pool.create", sibling.merging(create) { _, b in b }))
        XCTAssertEqual(try database!.call("pool.hasSeed", sibling) as? Bool, false)
        let batch = scope.merging([
            "id": "batch", "seed": "seed", "chain": "bsc", "first_index": 0,
            "count": 2, "payload": "{\"addresses\":[]}",
        ]) { _, b in b }
        _ = try database!.call("pool.generate", batch)
        XCTAssertThrowsError(try database!.call("pool.generate", batch))
        let collision = batch.merging(["first_index": 2]) { _, b in b }
        XCTAssertThrowsError(try database!.call("pool.generate", collision))
        let active = try XCTUnwrap(database!.call("pool.active", scope) as? [String: Any])
        XCTAssertEqual(active["bsc_next"] as? Int, 2)
        XCTAssertEqual(active["tron_next"] as? Int, 0)
        let publicKey = try XCTUnwrap(database!.call("pool.device", [:]) as? FlutterStandardTypedData)
        let input = FlutterStandardTypedData(bytes: Data("synthetic request".utf8))
        let proof = try XCTUnwrap(database!.call("pool.sign", ["message": input]) as? FlutterStandardTypedData)
        XCTAssertEqual(try database!.call("pool.verify", [
            "key": publicKey, "message": input, "signature": proof,
        ]) as? Bool, true)
        database = nil
        database = MacWalletDatabase(directory: directory, keychainService: service)
        let reopened = try XCTUnwrap(database!.call("pool.device", [:]) as? FlutterStandardTypedData)
        XCTAssertEqual(reopened.data, publicKey.data)
        let list = try XCTUnwrap(database!.call("pool.list", scope) as? [[String: Any]])
        XCTAssertEqual(list.first?["backed_up"] as? Int, 0)
        XCTAssertEqual(list.count, 1)
        let bytes = try Data(contentsOf: directory.appendingPathComponent("wallet.db"))
        XCTAssertNil(bytes.range(of: Data(mnemonic.utf8)))
        XCTAssertFalse(bytes.starts(with: Data("SQLite format 3".utf8)))
    }

    private func row(_ line: Int, _ platform: String, _ uid: String, network: Int = 56) -> [String: Any] {
        [
            "line": line, "status": "valid", "platform": platform, "uid": uid, "network": network,
            "identity": network == 56 ? address.lowercased() : tron, "evm": address,
            "tron": tron, "address": network == 56 ? address : tron, "secret": key,
        ]
    }

    private func summary(_ database: MacWalletDatabase) throws -> [String: Any] {
        try XCTUnwrap(database.call("summary", [:]) as? [String: Any])
    }

    private func search(_ database: MacWalletDatabase, _ query: String) throws -> [[String: Any]] {
        try XCTUnwrap(database.call("walletPage", ["query": query]) as? [[String: Any]])
    }

    private func begin(_ database: MacWalletDatabase) throws {
        _ = try database.call("beginPreview", ["session": session, "accountName": "Account 1"])
    }

    private func stage(_ database: MacWalletDatabase, _ rows: [[String: Any]]) throws {
        _ = try database.call("stage", ["session": session, "rows": rows])
    }

    private func finish(_ database: MacWalletDatabase) throws -> [String: Int] {
        let rows = try XCTUnwrap(database.call("finishPreview", ["session": session]) as? [[String: Any]])
        return Dictionary(uniqueKeysWithValues: try rows.map { row in
            (try XCTUnwrap(row["status"] as? String), try XCTUnwrap(row["count"] as? Int))
        })
    }
}
