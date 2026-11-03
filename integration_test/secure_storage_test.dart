import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native secure storage survives write read update and delete', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('安全存储测试'))),
    );
    // Use only this test's unique key. Never read, overwrite or delete wallet keys.
    final key =
        'stone_wallet.test.keychain.${DateTime.now().microsecondsSinceEpoch}';
    final store = FlutterSecretStore();
    try {
      expect(await store.read(key), isNull);
      await store.write(key, 'synthetic-storage-probe');
      expect(await FlutterSecretStore().read(key), 'synthetic-storage-probe');
      await store.write(key, 'synthetic-updated-probe');
      expect(await store.read(key), 'synthetic-updated-probe');
      await store.delete(key);
      expect(await store.read(key), isNull);
      await store.delete(key);
    } finally {
      await store.delete(key);
    }
  });
}
