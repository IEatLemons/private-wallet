import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart' show RpcFixture, start, tap;
import 'widget_test.dart' show MapSecretStore;
import 'responsive_layout_test.dart' show panelHarness;

const phraseA =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const phraseB = 'test test test test test test test test test test test junk';

class FailingBookStore extends MapSecretStore {
  FailingBookStore(super.values);
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail && key == WalletVault.walletBookKey) {
      throw StateError('synthetic write failure');
    }
    await super.write(key, value);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'compact manager supports keyboard and large text ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 640);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final vault = WalletVault(store: MapSecretStore({}));
        final book = await vault.addMnemonicWallet(
          phraseA,
          name: '用于长期储蓄和日常使用的钱包名称',
        );
        await tester.pumpWidget(
          panelHarness(
            (_) => WalletManagerPanel(
              theme: dark ? WalletTheme.dark : WalletTheme.light,
              initial: book,
              vault: vault,
            ),
            width: 640,
          ),
        );
        await tap(tester, find.text('open'));
        await tester.tap(find.byKey(const ValueKey('wallet-search')));
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        expect(find.text('创建新钱包').hitTestable(), findsOneWidget);
        expect(find.text('导入钱包').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test(
    'legacy migration preserves addresses, old keys and stable identities',
    () async {
      final legacyKeys = jsonEncode([
        {'chainId': 137, 'privateKey': '1'.padLeft(64, '0')},
      ]);
      final store = MapSecretStore({
        WalletVault.mnemonicKey: phraseA,
        WalletVault.privateKeyWalletsKey: legacyKeys,
      });
      final vault = WalletVault(store: store);
      final loaded = await Future.wait([
        vault.loadPortfolio(),
        vault.loadPortfolio(),
      ]);
      final data = loaded.first;
      expect(data.groups, hasLength(2));
      expect(
        data.groups.first.accounts.first.account.checksumAddress,
        '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      );
      expect(data.selected!.displayName, '私钥账户 1');
      expect(loaded.last.activeAccountId, data.activeAccountId);
      final reloaded = await WalletVault(store: store).loadPortfolio();
      expect(reloaded.groups.map((g) => g.id), data.groups.map((g) => g.id));
      expect(store.values[WalletVault.mnemonicKey], phraseA);
      expect(store.values[WalletVault.privateKeyWalletsKey], legacyKeys);
    },
  );

  test(
    'multiple roots and derived accounts persist without replacing earlier wallets',
    () async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final first = await vault.addMnemonicWallet(phraseA);
      final groupId = first.groups.single.id;
      final rootAddress = first.selected!.account.checksumAddress;
      final derived = await vault.addDerivedAccount(groupId);
      expect(derived.selected!.derivationPath, "m/44'/60'/0'/0/1");
      expect(
        derived.selected!.account.checksumAddress,
        '0x6Fac4D18c912343BF86fa7049364Dd4E424Ab9C0',
      );
      final derivedId = derived.selected!.id;
      await vault.renameWallet(groupId, '日常钱包');
      await vault.renameAccount(derivedId, '储蓄账户');
      await vault.addMnemonicWallet(phraseB);
      var book = await vault.loadPortfolio();
      expect(book.groups, hasLength(2));
      expect(book.groups.first.accounts, hasLength(2));
      expect(
        book.groups.first.accounts.first.account.checksumAddress,
        rootAddress,
      );
      expect(
        book.selected!.account.checksumAddress,
        '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      );
      await vault.selectAccount(derivedId);
      book = await WalletVault(store: store).loadPortfolio();
      expect(book.selected!.id, derivedId);
      expect(book.selected!.displayName, '日常钱包 · 储蓄账户');
      // Re-importing the same root keeps every derived index and name.
      book = await vault.addMnemonicWallet('  $phraseA  ');
      expect(book.groups, hasLength(2));
      expect(book.groups.first.accounts.last.name, '储蓄账户');
      expect(book.groups.first.accounts.last.id, derivedId);
    },
  );

  test(
    'concurrent derivations are serialized and never reuse an account index',
    () async {
      final vault = WalletVault(store: MapSecretStore({}));
      final id = (await vault.addMnemonicWallet(phraseA)).groups.single.id;
      await Future.wait(List.generate(5, (_) => vault.addDerivedAccount(id)));
      final book = await vault.loadPortfolio();
      expect(book.accounts.map((a) => a.index), [0, 1, 2, 3, 4, 5]);
      expect(
        book.accounts.map((a) => a.account.addressHex).toSet(),
        hasLength(6),
      );
      expect(book.selected!.index, 5);
      await expectLater(
        vault.selectAccount('missing'),
        throwsA(isA<WalletInputException>()),
      );
      expect((await vault.loadPortfolio()).selected!.index, 5);
    },
  );

  test(
    'failed writes preserve all wallets and mutation queue recovers',
    () async {
      final store = FailingBookStore({WalletVault.mnemonicKey: phraseA});
      final vault = WalletVault(store: store);
      final original = await vault.loadPortfolio();
      final snapshot = Map.of(store.values);
      store.fail = true;
      await expectLater(
        vault.addMnemonicWallet(phraseB),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        vault.addDerivedAccount(original.groups.single.id),
        throwsA(isA<StateError>()),
      );
      expect(store.values, snapshot);
      store.fail = false;
      expect((await vault.loadPortfolio()).groups, hasLength(1));
      expect((await vault.addMnemonicWallet(phraseB)).groups, hasLength(2));
    },
  );

  test(
    'corrupt legacy or new records are never migrated or overwritten',
    () async {
      for (final values in [
        {
          WalletVault.mnemonicKey: phraseA,
          WalletVault.privateKeyWalletsKey: 'broken',
        },
        {WalletVault.walletBookKey: 'broken', WalletVault.mnemonicKey: phraseA},
      ]) {
        final store = MapSecretStore(values);
        final before = Map.of(values);
        final vault = WalletVault(store: store);
        await expectLater(
          vault.loadPortfolio(),
          throwsA(isA<WalletInputException>()),
        );
        await expectLater(
          vault.addMnemonicWallet(phraseB),
          throwsA(isA<WalletInputException>()),
        );
        expect(store.values, before);
      }
    },
  );

  test(
    'private-key groups cannot derive children and do not replace mnemonic roots',
    () async {
      final vault = WalletVault(store: MapSecretStore({}));
      await vault.addMnemonicWallet(phraseA);
      await vault.importPrivateKeyWallet(
        privateKey: '1'.padLeft(64, '0'),
        networkId: 137,
      );
      final book = await vault.loadPortfolio();
      expect(book.groups, hasLength(2));
      expect(book.selected!.kind, WalletKind.privateKey);
      await expectLater(
        vault.addDerivedAccount(book.selected!.groupId),
        throwsA(isA<WalletInputException>()),
      );
      expect((await vault.loadPortfolio()).accounts, hasLength(2));
      await expectLater(
        vault.renameWallet(book.groups.first.id, ''),
        throwsA(isA<WalletInputException>()),
      );
      expect((await vault.loadPortfolio()).groups.first.name, '主钱包');
    },
  );

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      'manage derive rename switch and continue import at ${size.width}',
      (tester) async {
        final store = MapSecretStore({WalletVault.mnemonicKey: phraseA});
        final vault = WalletVault(store: store);
        final rpc = RpcFixture();
        await start(tester, vault, rpc, size: size);
        await tap(tester, find.text('主钱包'));
        expect(find.byType(WalletManagerPanel), findsOneWidget);
        expect(find.text('1 个钱包 · 1 个账户'), findsOneWidget);
        await tap(tester, find.text('添加账户'));
        var data = await vault.loadPortfolio();
        expect(data.accounts, hasLength(2));
        expect(find.text('账户 2'), findsOneWidget);
        await tap(
          tester,
          find.byKey(ValueKey('rename-wallet-${data.groups.first.id}')),
        );
        await tester.enterText(find.byType(TextField).last, '我的钱包');
        await tap(tester, find.text('保存名称'));
        final childId = data.accounts.last.id;
        await tap(tester, find.byKey(ValueKey('rename-account-$childId')));
        await tester.enterText(find.byType(TextField).last, '长期账户');
        await tap(tester, find.text('保存名称'));
        await tap(tester, find.byKey(ValueKey('wallet-account-$childId')));
        expect(find.text('我的钱包 · 长期账户'), findsOneWidget);
        expect(rpc.calls, isEmpty);

        await tap(tester, find.text('我的钱包 · 长期账户'));
        await tap(tester, find.text('导入钱包'));
        await tap(tester, find.text('导入助记词'));
        await tester.enterText(find.byType(TextField), phraseB);
        await tap(tester, find.text('导入'));
        data = await vault.loadPortfolio();
        expect(data.groups, hasLength(2));
        expect(data.accounts, hasLength(3));
        expect(find.text('钱包 2'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await start(tester, WalletVault(store: store), rpc, size: size);
        expect(find.text('钱包 2'), findsOneWidget);
        await tap(tester, find.text('钱包 2'));
        await tester.enterText(
          find.byKey(const ValueKey('wallet-search')),
          '长期账户',
        );
        await tester.pumpAndSettle();
        final matchedAccount = find.byKey(ValueKey('wallet-account-$childId'));
        expect(
          find.descendant(of: matchedAccount, matching: find.text('长期账户')),
          findsOneWidget,
        );
        expect(find.text('账户 1'), findsNothing);
        await tap(tester, matchedAccount);
        expect(find.text('我的钱包 · 长期账户'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'settings exposes create, mnemonic import and management after onboarding',
    (tester) async {
      final vault = WalletVault(
        store: MapSecretStore({WalletVault.mnemonicKey: phraseA}),
      );
      await start(tester, vault, RpcFixture());
      await tap(tester, find.byTooltip('设置'));
      expect(find.text('管理钱包与账户'), findsOneWidget);
      expect(find.text('创建新钱包'), findsOneWidget);
      expect(find.text('导入助记词'), findsOneWidget);
      await tap(tester, find.text('创建新钱包'));
      expect(find.byType(RecoveryPhraseSheet), findsOneWidget);
      await tap(tester, find.byTooltip('关闭'));
      expect((await vault.loadPortfolio()).groups, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
