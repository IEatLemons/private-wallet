import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  const knownMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  test(
    'single private-key import persists without replacing the mnemonic',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);
      await vault.importWallet(knownMnemonic);
      final original = await vault.loadWallet();
      final key = '1'.padLeft(64, '0');
      final imported = await vault.importPrivateKeyWallet(
        privateKey: ' 0X$key ',
        networkId: ethereumSepoliaNetwork.id,
      );
      expect(
        imported.account.checksumAddress,
        '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf',
      );
      final reloaded = await WalletVault(store: store).loadImportedWallets();
      expect(reloaded.single.networkId, ethereumSepoliaNetwork.id);
      expect(reloaded.single.account.address, imported.account.address);
      expect((await vault.loadWallet())!.address, original!.address);
      expect(await vault.loadSelectedNetworkIds(), isEmpty);

      final snapshot = Map.of(store.values);
      await expectLater(
        vault.importPrivateKeyWallet(
          privateKey: key,
          networkId: ethereumSepoliaNetwork.id,
        ),
        throwsA(isA<WalletInputException>()),
      );
      expect(store.values, snapshot);
    },
  );

  test(
    'invalid private keys and unknown networks never reach storage',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);
      for (final key in [
        '',
        'abc',
        'g' * 64,
        '0' * 64,
        'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
        'f' * 64,
      ]) {
        await expectLater(
          vault.importPrivateKeyWallet(privateKey: key, networkId: 1),
          throwsA(isA<WalletInputException>()),
        );
        expect(store.values, isEmpty);
      }
      await expectLater(
        vault.importPrivateKeyWallet(
          privateKey: '1'.padLeft(64, '0'),
          networkId: 999999,
        ),
        throwsA(isA<WalletInputException>()),
      );
      expect(store.values, isEmpty);
    },
  );

  test('derives the standard Ethereum account at the documented path', () {
    final account = WalletAccount.fromMnemonic(knownMnemonic);

    expect(
      account.checksumAddress,
      '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
    );
  });

  test(
    'vault creates, imports, and reloads a wallet without exposing storage',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);

      expect(await vault.hasWallet(), isFalse);
      final created = await vault.createWallet();
      expect(await vault.hasWallet(), isTrue);

      final loaded = await vault.loadWallet();
      expect(loaded?.checksumAddress, created.checksumAddress);

      final imported = await vault.importWallet(knownMnemonic);
      expect(
        imported.checksumAddress,
        '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      );
    },
  );

  test('ether amount conversion is exact and rejects unsafe precision', () {
    expect(parseEtherToWei('1.25'), BigInt.from(125) * BigInt.from(10).pow(16));
    expect(parseEtherToWei('0.000000000000000001'), BigInt.one);
    expect(
      () => parseEtherToWei('1.0000000000000000001'),
      throwsA(isA<WalletInputException>()),
    );
    expect(
      formatWeiAsEther(BigInt.from(125) * BigInt.from(10).pow(16)),
      '1.25',
    );
  });

  test(
    'network choice is separate from wallet creation and can be cleared',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);

      expect(await vault.loadSelectedNetworkId(), isNull);
      await vault.saveSelectedNetwork(ethereumMainnetNetwork);
      expect(await vault.loadSelectedNetworkId(), ethereumMainnetNetwork.id);

      await vault.clearSelectedNetwork();
      expect(await vault.loadSelectedNetworkId(), isNull);
      expect(await vault.hasWallet(), isFalse);
    },
  );

  test(
    'selected networks persist independently from the current network',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);

      await vault.saveSelectedNetworks(const [
        ethereumMainnetNetwork,
        polygonMainnetNetwork,
      ], current: polygonMainnetNetwork);

      expect(
        await vault.loadSelectedNetworkIds(),
        containsAll(<int>[ethereumMainnetNetwork.id, polygonMainnetNetwork.id]),
      );
      expect(await vault.loadSelectedNetworkId(), polygonMainnetNetwork.id);
    },
  );

  test(
    'batch private-key import validates, deduplicates, and persists',
    () async {
      final store = MemorySecretStore();
      final vault = WalletVault(store: store);
      const privateKey =
          '4f3edf983ac636a65a842ce7c78d9aa706d3b113bce036f9d5a8e7e5d6b7a9c1';

      final result = await vault.importPrivateKeyWallets(const [
        WalletImportRow(chain: 'Ethereum', privateKey: privateKey),
        WalletImportRow(chain: '1', privateKey: privateKey),
        WalletImportRow(chain: 'unknown', privateKey: privateKey),
        WalletImportRow(chain: 'Polygon', privateKey: 'not-a-key'),
      ]);

      expect(result.imported, hasLength(1));
      expect(result.errors, hasLength(3));
      expect(await vault.hasWallet(), isTrue);
      final loaded = await vault.loadImportedWallets();
      expect(loaded, hasLength(1));
      expect(loaded.single.networkId, ethereumMainnetNetwork.id);
    },
  );
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
