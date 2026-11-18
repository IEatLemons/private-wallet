import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'widget_test.dart' show MapSecretStore;
import 'wallet_management_test.dart' show phraseA;

class _FailingStore extends MapSecretStore {
  _FailingStore() : super({});
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw StateError('synthetic disk failure');
    return super.write(key, value);
  }
}

List<Map<String, Object?>> _balance(int value, {bool failed = false}) => [
  {
    'chain': 56,
    'amount': value.toString() + '0' * 72,
    'payload': '[]',
    'failed': failed ? 1 : 0,
    'incomplete': failed ? 1 : 0,
  },
];

void main() {
  test(
    'derived removals keep the root and never reuse a deleted index',
    () async {
      final store = _FailingStore();
      final actual = WalletVault(store: store);
      await actual.addMnemonicWallet(phraseA);
      final group = (await actual.loadPortfolio()).groups.single;
      await actual.addDerivedAccount(group.id);
      await actual.addDerivedAccount(group.id);
      final child = (await actual.loadPortfolio()).selected!;
      await actual.saveManagementBalance(child.id, _balance(42));
      final preview = await actual.prepareRemoval(accountId: child.id);
      expect(preview.active, isTrue);
      final before = Map.of(store.values);
      store.fail = true;
      await expectLater(actual.commitRemoval(preview.token), throwsStateError);
      expect(store.values, before);
      store.fail = false;
      final removed = await actual.commitRemoval(preview.token);
      expect(removed.selected!.index, 0);
      expect(removed.accountCount, 2);
      expect(
        await actual.saveManagementBalance(child.id, _balance(999)),
        isFalse,
      );
      final restart = WalletVault(store: store);
      await restart.addDerivedAccount(group.id);
      expect((await restart.loadPortfolio()).selected!.index, 3);
      await expectLater(
        restart.prepareRemoval(accountId: group.accounts.first.id),
        throwsA(isA<WalletInputException>()),
      );
    },
  );

  test(
    'cached exact balances survive restart and failure while deletion targets stay fixed',
    () async {
      final store = MapSecretStore({});
      final actual = WalletVault(store: store);
      for (var i = 1; i <= 3; i++) {
        await actual.importPrivateKeyWallet(
          privateKey: i.toString().padLeft(64, '0'),
          networkId: 56,
        );
      }
      final wallets = (await actual.loadPortfolio()).groups;
      await actual.saveManagementBalance(
        wallets[0].accounts.first.id,
        _balance(9),
      );
      await actual.saveManagementBalance(
        wallets[1].accounts.first.id,
        _balance(10),
      );
      final preview = await actual.prepareRemoval(
        query: const WalletManagementQuery(kind: WalletKind.privateKey),
        excluded: {wallets[0].id},
      );
      expect(preview.wallets, 2);
      await actual.saveManagementBalance(
        wallets[1].accounts.first.id,
        _balance(0, failed: true),
      );
      final ranked = await WalletVault(
        store: store,
      ).managementPage(const WalletManagementQuery());
      expect(ranked.wallets.first.group.id, wallets[1].id);
      expect(ranked.wallets.first.amount!.fixed(0), '10');
      expect(ranked.wallets.first.incomplete, isTrue);
      await actual.commitRemoval(preview.token);
      final remaining = await actual.loadPortfolio();
      expect(remaining.groups.single.id, wallets[0].id);
      expect(remaining.selected!.id, wallets[0].accounts.first.id);
      final last = await actual.prepareRemoval(ids: {wallets[0].id});
      await actual.commitRemoval(last.token);
      expect(
        (await WalletVault(store: store).loadWalletSummary()).accountCount,
        0,
      );
      expect(
        jsonDecode(store.values[WalletVault.walletBookKey]!)['balances'],
        isEmpty,
      );
    },
  );

  test(
    'rename invalidates a frozen removal while cache updates do not',
    () async {
      final vault = WalletVault(store: MapSecretStore({}));
      await vault.importPrivateKeyWallet(
        privateKey: '1'.padLeft(64, '0'),
        networkId: 56,
      );
      final group = (await vault.loadPortfolio()).groups.single;
      final preview = await vault.prepareRemoval(ids: {group.id});
      await vault.renameWallet(group.id, 'Renamed');
      await expectLater(
        vault.commitRemoval(preview.token),
        throwsA(isA<WalletInputException>()),
      );
      expect((await vault.loadPortfolio()).groups.single.name, 'Renamed');
    },
  );
}
