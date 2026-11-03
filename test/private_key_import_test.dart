import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart'
    show RpcFixture, base, mnemonic, start, tap;
import 'widget_test.dart' show MapSecretStore;

final keyInput = find.byKey(const ValueKey('private-key-input'));
final importAction = find.text('导入并进入钱包');
final testKey = '1'.padLeft(64, '0');

Future<void> openImport(WidgetTester tester) async {
  await tap(tester, find.text('导入私钥'));
}

Future<void> chooseNetwork(WidgetTester tester, String label) async {
  await tap(tester, find.byType(DropdownButtonFormField<int>));
  await tap(tester, find.text(label).last);
}

void main() {
  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets('single import and restart at ${size.width}px', (tester) async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      await vault.saveNetwork(base);
      final rpc = RpcFixture();
      await start(tester, vault, rpc, size: size);
      await openImport(tester);
      expect(rpc.calls, isEmpty);
      expect(tester.widget<TextField>(keyInput).obscureText, isTrue);
      await tester.enterText(keyInput, '0x$testKey');
      await tap(tester, find.byTooltip('显示私钥'));
      expect(tester.widget<TextField>(keyInput).obscureText, isFalse);
      await tap(tester, find.byTooltip('隐藏私钥'));
      await chooseNetwork(tester, 'Base · 主网');
      expect(rpc.calls, isEmpty);
      await tap(tester, importAction);

      expect(find.byType(ImportPrivateKeyPanel), findsNothing);
      expect(find.text('私钥账户 1'), findsOneWidget);
      expect(
        find.text(
          shortAddress(WalletAccount.fromPrivateKey(testKey).checksumAddress),
        ),
        findsOneWidget,
      );
      expect(await vault.loadSelectedNetworkId(), base.id);
      expect(await vault.loadSelectedNetworkIds(), [base.id]);
      expect(await vault.loadWallet(), isNull);
      expect((await vault.loadImportedWallets()).single.networkId, base.id);
      expect(rpc.calls, isNotEmpty);
      expect(rpc.calls.every((url) => url == Uri.parse(base.rpcUrl)), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await start(tester, WalletVault(store: store), rpc, size: size);
      expect(find.text('私钥账户 1'), findsOneWidget);
      expect(
        find.text(
          shortAddress(WalletAccount.fromPrivateKey(testKey).checksumAddress),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'invalid input stays editable and cancel does not persist or connect',
    (tester) async {
      final store = MapSecretStore({});
      final rpc = RpcFixture();
      await start(tester, WalletVault(store: store), rpc);
      await openImport(tester);
      await tap(tester, importAction);
      expect(find.text('请选择导入后要查看的网络。'), findsOneWidget);
      await chooseNetwork(tester, 'Ethereum Sepolia · 测试网');
      await tester.enterText(keyInput, 'bad-key');
      await tap(tester, importAction);
      expect(find.text('私钥无效，应为 64 位十六进制字符串。'), findsOneWidget);
      expect(tester.widget<TextField>(keyInput).controller!.text, 'bad-key');
      await tester.enterText(keyInput, testKey);
      await tap(tester, find.byTooltip('关闭'));
      expect(store.values, isEmpty);
      expect(rpc.calls, isEmpty);
      expect(find.text('创建新钱包'), findsOneWidget);
    },
  );

  testWidgets(
    'settings import preserves existing accounts and rejects duplicates',
    (tester) async {
      final store = MapSecretStore({
        WalletVault.mnemonicKey: mnemonic,
        WalletVault.privateKeyWalletsKey: jsonEncode([
          {'chainId': 1, 'privateKey': testKey},
        ]),
      });
      final vault = WalletVault(store: store);
      final rpc = RpcFixture();
      await start(tester, vault, rpc);
      await tap(tester, find.byTooltip('设置'));
      await openImport(tester);
      await chooseNetwork(tester, 'Ethereum · 主网');
      await tester.enterText(keyInput, testKey);
      await tap(tester, importAction);
      expect(find.text('重复记录，已跳过。'), findsOneWidget);
      expect(await vault.loadImportedWallets(), hasLength(1));
      expect(rpc.calls, isEmpty);

      final secondKey = '2'.padLeft(64, '0');
      await tester.enterText(keyInput, secondKey);
      await tap(tester, importAction);
      expect(find.text('私钥账户 2'), findsOneWidget);
      expect(await vault.loadImportedWallets(), hasLength(2));
      expect(await vault.loadWallet(), isNotNull);
      await tap(tester, find.text('私钥账户 2'));
      await tap(tester, find.text('主钱包'));
      expect(
        find.text(
          shortAddress(WalletAccount.fromMnemonic(mnemonic).checksumAddress),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
