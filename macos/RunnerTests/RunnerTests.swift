import Foundation
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

    func testManagementCacheRemovalAndDerivationWatermark() throws {
        let token = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(token)
        let service = "asterkeel.management-test." + token
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
        let accounts: [[String: Any]] = (0...2).map {
            ["account_index": $0, "name": "Account \($0)", "evm": address, "tron": tron]
        }
        let group: [String: Any] = [
            "id": walletID, "kind": "mnemonic", "name": "Original",
            "secret": "synthetic recovery phrase", "identity": address.lowercased(),
            "accounts": accounts,
        ]
        _ = try database!.call("migrate", ["activeId": walletID + ":2", "groups": [group]])
        let page = try XCTUnwrap(database!.call("managementPage", [:]) as? [String: Any])
        XCTAssertEqual(page["total"] as? Int, 1)
        let groups = try XCTUnwrap(page["groups"] as? [[String: Any]])
        XCTAssertNil(groups.first?["secret"])
        XCTAssertEqual((groups.first?["accounts"] as? [[String: Any]])?.count, 1)
        let amount = "12" + String(repeating: "0", count: 72)
        let cache: [String: Any] = [
            "id": walletID + ":2", "time": 1000,
            "records": [["chain": 56, "amount": amount, "payload": "[]", "failed": 0, "incomplete": 0]],
        ]
        XCTAssertEqual(try database!.call("saveBalance", cache) as? Bool, true)
        let preview = try XCTUnwrap(database!.call("prepareRemoval", ["account": walletID + ":2"]) as? [String: Any])
        let previewID = try XCTUnwrap(preview["token"] as? String)
        XCTAssertEqual(preview["accounts"] as? Int, 1)
        XCTAssertEqual(preview["active"] as? Bool, true)
        // Refreshes of replaceable balances must not invalidate deletion approval.
        XCTAssertEqual(try database!.call("saveBalance", cache) as? Bool, true)
        let failed: [String: Any] = [
            "id": walletID + ":2", "time": 2000,
            "records": [["chain": 56, "amount": "0", "payload": "[]", "failed": 1, "incomplete": 4]],
        ]
        XCTAssertEqual(try database!.call("saveBalance", failed) as? Bool, true)
        let refreshed = try XCTUnwrap(database!.call("managementPage", [:]) as? [String: Any])
        let cachedGroup = try XCTUnwrap((refreshed["groups"] as? [[String: Any]])?.first)
        XCTAssertEqual(cachedGroup["amount"] as? String, amount)
        XCTAssertEqual((cachedGroup["incomplete"] as? Int ?? 0) & 4, 4)
        XCTAssertEqual(cachedGroup["updated_at"] as? Int, 1000)
        #if DEBUG
        database!.failNextCommit = true
        XCTAssertThrowsError(try database!.call("commitRemoval", ["token": previewID]))
        XCTAssertEqual(try summary(database!)["accounts_count"] as? Int, 3)
        #endif
        _ = try database!.call("commitRemoval", ["token": previewID])
        XCTAssertEqual(try summary(database!)["accounts_count"] as? Int, 2)
        XCTAssertEqual(try summary(database!)["active_id"] as? String, walletID + ":0")
        let next = try XCTUnwrap(database!.call("derive", ["id": walletID]) as? [String: Any])
        XCTAssertEqual(next["next_index"] as? Int, 3)
        XCTAssertThrowsError(try database!.call("prepareRemoval", ["account": walletID + ":0"]))
        XCTAssertTrue(try XCTUnwrap(database!.call("balanceDetails", ["id": walletID]) as? [[String: Any]]).isEmpty)
        XCTAssertEqual(try database!.call("saveBalance", cache) as? Bool, false)
        let all = try XCTUnwrap(database!.call("prepareRemoval", ["query": "orig"]) as? [String: Any])
        _ = try database!.call("rename", ["id": walletID, "name": "Renamed"])
        XCTAssertThrowsError(try database!.call("commitRemoval", ["token": try XCTUnwrap(all["token"] as? String)]))
        let final = try XCTUnwrap(database!.call("prepareRemoval", ["ids": [walletID]]) as? [String: Any])
        _ = try database!.call("commitRemoval", ["token": try XCTUnwrap(final["token"] as? String)])
        XCTAssertEqual(try summary(database!)["groups_count"] as? Int, 0)
        XCTAssertNil(try summary(database!)["active_id"])
        database = nil
        database = MacWalletDatabase(directory: directory, keychainService: service)
        XCTAssertEqual(try summary(database!)["groups_count"] as? Int, 0)
        XCTAssertEqual(try database!.call("needsMigration", [:]) as? Bool, false)
    }

    func testManagementPaginationAndRankingAtScale() throws {
        let count = Int(ProcessInfo.processInfo.environment["ASTERKEEL_MANAGEMENT_ROWS"] ?? "146")!
        let token = UUID().uuidString
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(token)
        let service = "asterkeel.management-scale." + token
        defer {
            try? FileManager.default.removeItem(at: directory)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                kSecAttrAccount as String: "wallet-database-v1", kSecAttrSynchronizable as String: false,
            ] as CFDictionary)
        }
        let database = MacWalletDatabase(directory: directory, keychainService: service)
        _ = try database.call("migrate", ["groups": []])
        let start = Date()
        for offset in stride(from: 0, to: count, by: 5000) {
            let groups: [[String: Any]] = (offset..<min(offset + 5000, count)).map { index in
                let identity = "0x" + String(repeating: "0", count: 40 - String(index + 1, radix: 16).count) + String(index + 1, radix: 16)
                return [
                    "id": "fixture-\(index)", "kind": "privateKey", "secret": key,
                    "network_id": index.isMultiple(of: 2) ? 56 : 728126428, "identity": identity,
                    "accounts": [["account_index": 0, "name": "Account", "evm": identity, "tron": tron]],
                ]
            }
            let names = (offset..<min(offset + 5000, count)).map { String(format: "Fixture %06d", $0) }
            let results = try XCTUnwrap(database.call("addPrivate", ["groups": groups, "names": names]) as? [String])
            XCTAssertTrue(results.allSatisfy { $0 == "new" })
        }
        for index in stride(from: 0, to: count, by: max(1, count / 100)) {
            _ = try database.call("saveBalance", [
                "id": "fixture-\(index):0", "time": 1000,
                "records": [["chain": index.isMultiple(of: 2) ? 56 : 728126428,
                    "amount": "\(index + 1)" + String(repeating: "0", count: 72),
                    "payload": "[]", "failed": 0, "incomplete": 0]],
            ])
        }
        var timings: [Double] = []
        for index in 0..<30 {
            let watch = Date()
            let args: [String: Any] = index.isMultiple(of: 2)
                ? ["query": "fixture", "chain": 56, "sort": "value"]
                : ["sort": "name", "offset": 50]
            let page = try XCTUnwrap(database.call("managementPage", args) as? [String: Any])
            XCTAssertEqual((page["groups"] as? [[String: Any]])?.count, 50)
            timings.append(Date().timeIntervalSince(watch) * 1000)
        }
        timings.sort()
        let previewStart = Date()
        let removal = try XCTUnwrap(database.call("prepareRemoval", ["chain": 56]) as? [String: Any])
        XCTAssertEqual(removal["wallets"] as? Int, (count + 1) / 2)
        _ = try database.call("commitRemoval", ["token": try XCTUnwrap(removal["token"] as? String)])
        XCTAssertEqual(try summary(database)["groups_count"] as? Int, count / 2)
        let size = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])
            .reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        print("management rows=\(count) query-p95-ms=\(timings[28]) removal-ms=\(Date().timeIntervalSince(previewStart) * 1000) total-seconds=\(Date().timeIntervalSince(start)) disk-bytes=\(size)")
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
