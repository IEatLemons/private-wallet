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
