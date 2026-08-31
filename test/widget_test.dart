import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  testWidgets('first launch exposes real wallet onboarding', (tester) async {
    await tester.pumpWidget(
      StoneWalletApp(vault: WalletVault(store: EmptyStore())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('你的密钥，\n你的钱包。'), findsOneWidget);
    expect(find.text('创建新钱包'), findsOneWidget);
    expect(find.text('导入助记词'), findsOneWidget);
    expect(find.text('自托管钱包'), findsOneWidget);
    expect(find.text('网络由你选择'), findsOneWidget);
  });

  testWidgets('import action opens a recovery phrase input', (tester) async {
    await tester.pumpWidget(
      StoneWalletApp(vault: WalletVault(store: EmptyStore())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final importButton = find.text('导入助记词');
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pump();

    expect(find.text('导入钱包'), findsOneWidget);
    expect(find.text('请输入 12 或 24 个助记词单词'), findsOneWidget);
  });

  testWidgets('wallet does not connect to a network until the user chooses one', (
    tester,
  ) async {
    final store = MapSecretStore({
      WalletVault.mnemonicKey:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    });
    await tester.pumpWidget(StoneWalletApp(vault: WalletVault(store: store)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('选择网络'), findsOneWidget);
    expect(find.text('未选择网络'), findsWidgets);

    await tester.tap(find.text('选择网络'));
    await tester.pump();

    expect(find.text('管理网络'), findsOneWidget);
    expect(find.text('Ethereum Sepolia'), findsOneWidget);
    expect(find.text('可同时启用多条链查看余额。只有点击保存后，选中的网络才会访问 RPC。'), findsOneWidget);
  });

  testWidgets('settings exposes RPC details and keeps cloud backup disabled', (
    tester,
  ) async {
    final store = MapSecretStore({
      WalletVault.mnemonicKey:
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
    });
    await tester.pumpWidget(StoneWalletApp(vault: WalletVault(store: store)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('设置'));
    await tester.pump();

    expect(find.text('网络与 RPC'), findsOneWidget);
    expect(find.text('iCloud / Google Drive 云备份（暂未接入）'), findsOneWidget);
    final backupButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'iCloud / Google Drive 云备份（暂未接入）'),
    );
    expect(backupButton.onPressed, isNull);
  });
}

class EmptyStore implements SecretStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

class MapSecretStore implements SecretStore {
  MapSecretStore(this.values);

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
