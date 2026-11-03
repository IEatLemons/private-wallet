import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

class EphemeralStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native import routes open focus and dismiss repeatedly', (
    tester,
  ) async {
    await tester.pumpWidget(
      StoneWalletApp(vault: WalletVault(store: EphemeralStore())),
    );
    await tester.pumpAndSettle();
    for (var pass = 0; pass < 3; pass++) {
      for (final label in ['导入助记词', '导入私钥']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TextField).first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'synthetic-input');
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets(
    'native mnemonic import saves and replaces onboarding while keyboard closes',
    (tester) async {
      final store = EphemeralStore();
      await tester.pumpWidget(
        StoneWalletApp(
          key: UniqueKey(),
          vault: WalletVault(store: store),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('导入助记词'));
      await tester.tap(find.text('导入助记词'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
