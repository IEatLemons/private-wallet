import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'import_lifecycle_test.dart' show EphemeralStore;

const phraseA =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const phraseB = 'test test test test test test test test test test test junk';

Future<void> press(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native wallet management derives creates imports and restores selection',
    (tester) async {
      // Never read the user's Keychain or contact an RPC in this UI test.
      final store = EphemeralStore();
      await store.write(WalletVault.mnemonicKey, phraseA);
      final vault = WalletVault(store: store);
      await tester.pumpWidget(StoneWalletApp(vault: vault));
      await tester.pumpAndSettle();
      await press(tester, find.text('主钱包'));
      await press(tester, find.text('添加账户'));
      expect(find.text('账户 2'), findsOneWidget);
      final firstGroup = (await vault.loadPortfolio()).groups.first;
      final childId = firstGroup.accounts.last.id;
      await press(
        tester,
        find.byKey(ValueKey('rename-wallet-${firstGroup.id}')),
      );
      await tester.enterText(find.byType(TextField).last, '日常钱包');
      await press(tester, find.text('保存名称'));
      await press(tester, find.byKey(ValueKey('rename-account-$childId')));
      await tester.enterText(find.byType(TextField).last, '储蓄账户');
      await press(tester, find.text('保存名称'));
      await press(tester, find.text('创建新钱包'));
      final recovery = tester.widget<RecoveryPhraseSheet>(
        find.byType(RecoveryPhraseSheet),
      );
      // This phrase is generated for this in-memory test only, never a real wallet.
      final words = recovery.mnemonic.split(' ');
      await press(tester, find.text('我已记录，继续验证'));
      final fields = find.byType(TextField).evaluate().toList();
      for (var i = 0; i < 3; i++) {
        await tester.enterText(
          find.byWidget(fields[i].widget),
          words[[1, 5, 9][i]],
        );
      }
      await press(tester, find.text('验证并进入钱包'));
      expect((await vault.loadPortfolio()).groups, hasLength(2));
      expect(find.text('钱包 2'), findsOneWidget);
      await press(tester, find.text('钱包 2'));
      await press(tester, find.text('导入钱包'));
      await press(tester, find.text('导入助记词'));
      await tester.enterText(find.byType(TextField), phraseB);
      await press(tester, find.text('导入'));
      expect(find.text('钱包 3'), findsOneWidget);
      await press(tester, find.text('钱包 3'));
      await tester.enterText(
        find.byKey(const ValueKey('wallet-search')),
        '储蓄账户',
      );
      await tester.pumpAndSettle();
      await press(tester, find.byKey(ValueKey('wallet-account-$childId')));
      expect(find.text('日常钱包 · 储蓄账户'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(StoneWalletApp(vault: WalletVault(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('日常钱包 · 储蓄账户'), findsOneWidget);
      final data = await vault.loadPortfolio();
      expect(data.groups, hasLength(3));
      expect(data.accounts, hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
}
