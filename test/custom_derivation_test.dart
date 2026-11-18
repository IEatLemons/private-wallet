import 'dart:convert';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3dart/crypto.dart' as ec;
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart' show tap;
import 'responsive_layout_test.dart' show panelHarness;
import 'wallet_management_test.dart' show phraseA;
import 'widget_test.dart' show MapSecretStore;
import 'tron_test.dart' show headBlock, reply, addressOne;

const evmPath = "m/49'/60'/7'/1/12345";
const tronPath = "m/44'/195'/0'/0/925183485";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes full paths and validates every index before derivation', () {
    expect(
      normalizeDerivationPath("  m/044h/195H/0'/0/0925183485  "),
      tronPath,
    );
    expect(
      normalizeDerivationPath("m/2147483647'/2147483647"),
      "m/2147483647'/2147483647",
    );
    for (final path in [
      'm',
      '44/60/0/0/0',
      'm//0',
      'm/-1',
      'm/1.5',
      'm/2147483648',
      "m/2147483648'",
      'm/999999999999999999999999999',
      'm/0/',
      'm/${List.filled(256, '0').join('/')}',
    ]) {
      expect(
        () => normalizeDerivationPath(path),
        throwsA(isA<WalletInputException>()),
        reason: path,
      );
    }
  });

  test(
    'custom addresses, signing keys and public paths survive reopening',
    () async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final original = await vault.addMnemonicWallet(phraseA);
      final result = await vault.addDerivedAccount(
        original.groups.single.id,
        name: 'Custom',
        evmPath: evmPath,
        tronPath: tronPath,
      );
      final root = BIP32.fromSeed(bip39.mnemonicToSeed(phraseA));
      final expectedEvm = WalletAccount.fromPrivateKey(
        root
            .derivePath(evmPath)
            .privateKey!
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      );
      final expectedTron = WalletAccount.fromPrivateKey(
        root
            .derivePath(tronPath)
            .privateKey!
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
      );
      final reopened = WalletVault(store: store);
      final selected = (await reopened.loadPortfolio()).selected!;
      expect(selected.id, result.selected!.id);
      expect(
        selected.index,
        1,
      ); // Storage ID is independent of the final path index.
      expect(selected.derivationPath, evmPath);
      expect(selected.derivationPathFor(tronMainnetNetwork), tronPath);
      expect(selected.account.privateKeyHex, expectedEvm.privateKeyHex);
      await verifyTronSignature(selected.account, expectedTron.tronAddress);
      expect(
        selected.addressFor(ethereumMainnetNetwork),
        expectedEvm.checksumAddress,
      );
      expect(selected.addressFor(tronMainnetNetwork), expectedTron.tronAddress);
      final balances = await reopened.walletBalanceEntries().toList();
      expect(balances.last.derivationPathFor(tronMainnetNetwork), tronPath);
      expect(
        balances.last.addressFor(tronMainnetNetwork),
        expectedTron.tronAddress,
      );
      expect(
        balances.first.addressFor(ethereumMainnetNetwork),
        original.selected!.addressFor(ethereumMainnetNetwork),
      );
      await reopened.renameAccount(selected.id, 'Renamed');
      expect(
        (await reopened.loadPortfolio()).selected!.derivationPath,
        evmPath,
      );
      expect(
        (await reopened.addMnemonicWallet(phraseA)).accounts,
        hasLength(2),
      );
    },
  );

  test('invalid and duplicate paths preserve storage and selection', () async {
    final store = MapSecretStore({});
    final vault = WalletVault(store: store);
    final id = (await vault.addMnemonicWallet(phraseA)).groups.single.id;
    final before = Map.of(store.values);
    for (final paths in [
      ("m/44'/60'/0'/0/0", tronPath),
      (evmPath, "m/44h/195h/0h/0/00"),
      ('m/2147483648', tronPath),
      (evmPath, 'm/1//2'),
    ]) {
      await expectLater(
        vault.addDerivedAccount(id, evmPath: paths.$1, tronPath: paths.$2),
        throwsA(isA<WalletInputException>()),
      );
      expect(store.values, before);
    }
    await vault.addDerivedAccount(
      id,
      evmPath: "m/44'/60'/0'/0/2",
      tronPath: "m/44'/195'/0'/0/2",
    );
    final group = (await vault.loadPortfolio()).groups.single;
    expect(group.nextEvmPath, "m/44'/60'/0'/0/3");
    expect(group.nextTronPath, "m/44'/195'/0'/0/3");
    final automatic = await vault.addDerivedAccount(id);
    expect(automatic.selected!.index, 2);
    expect(automatic.selected!.derivationPath, "m/44'/60'/0'/0/3");
  });

  test(
    'macOS channel stores actual paths and reloads their signing keys',
    () async {
      const channel = MethodChannel('asterkeel/wallet_database');
      Map<Object?, Object?>? saved;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final row = saved;
        return switch (call.method) {
          'needsMigration' => false,
          'derive' => {
            'secret': phraseA,
            'next_index': 1,
            'next_evm_path': "m/44'/60'/0'/0/1",
            'next_tron_path': "m/44'/195'/0'/0/1",
          },
          'addDerived' => () {
            saved = Map<Object?, Object?>.from(
              call.arguments['account'] as Map,
            );
            return {
              'active_id': 'root:1',
              'groups_count': 1,
              'accounts_count': 2,
              'selected': {
                ...saved!,
                'id': 'root:1',
                'group_id': 'root',
                'group_name': 'Wallet',
                'kind': 'mnemonic',
                'group_count': 2,
                'secret': phraseA,
              },
            };
          }(),
          'summary' => {
            'active_id': 'root:1',
            'groups_count': 1,
            'accounts_count': 2,
            'selected': {
              ...row!,
              'id': 'root:1',
              'group_id': 'root',
              'group_name': 'Wallet',
              'kind': 'mnemonic',
              'group_count': 2,
              'secret': phraseA,
            },
          },
          _ => throw StateError(call.method),
        };
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final vault = WalletVault(
        store: MapSecretStore({}),
        useMacWalletDatabase: true,
      );
      final created = (await vault.addDerivedAccount(
        'root',
        evmPath: evmPath,
        tronPath: tronPath,
      )).selected!;
      expect(saved!['evm_path'], evmPath);
      expect(saved!['tron_path'], tronPath);
      final selected = (await WalletVault(
        store: MapSecretStore({}),
        useMacWalletDatabase: true,
      ).loadWalletSummary()).selected!;
      expect(selected.derivationPathFor(tronMainnetNetwork), tronPath);
      expect(selected.account.tronAddress, saved!['tron']);
      await verifyTronSignature(selected.account, created.account.tronAddress);
      expect(selected.account.checksumAddress, saved!['evm']);
    },
  );

  test(
    'legacy book migration sends custom paths and matching addresses to macOS',
    () async {
      const channel = MethodChannel('asterkeel/wallet_database');
      final store = MapSecretStore({});
      final legacy = WalletVault(store: store);
      final id = (await legacy.addMnemonicWallet(phraseA)).groups.single.id;
      final custom = (await legacy.addDerivedAccount(
        id,
        evmPath: evmPath,
        tronPath: tronPath,
      )).selected!;
      Map<Object?, Object?>? migrated;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'needsMigration':
            return true;
          case 'migrate':
            migrated = call.arguments as Map<Object?, Object?>;
            return null;
          case 'summary':
            return {'groups_count': 1, 'accounts_count': 2};
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      await WalletVault(
        store: store,
        useMacWalletDatabase: true,
      ).loadWalletSummary();
      final entry =
          ((migrated!['groups'] as List).single['accounts'] as List).last;
      expect(entry['evm_path'], evmPath);
      expect(entry['tron_path'], tronPath);
      expect(entry['evm'], custom.account.checksumAddress);
      expect(entry['tron'], custom.account.tronAddress);
      expect(
        jsonDecode(store.values[WalletVault.walletBookKey]!)['version'],
        2,
      );
    },
  );

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets('add account accepts full custom paths at ${size.width}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final vault = WalletVault(store: MapSecretStore({}));
      final book = await vault.addMnemonicWallet(phraseA);
      await tester.pumpWidget(
        panelHarness(
          (_) => WalletManagerPanel(
            theme: WalletTheme.dark,
            initial: book,
            vault: vault,
            network: tronMainnetNetwork,
          ),
          width: 640,
        ),
      );
      await tap(tester, find.text('open'));
      await tap(tester, find.text('添加账户'));
      final evm = find.byKey(const ValueKey('derived-evm-path'));
      final tron = find.byKey(const ValueKey('derived-tron-path'));
      await tester.enterText(evm, 'm/2147483648');
      await tap(tester, find.byKey(const ValueKey('confirm-derived-account')));
      expect((await vault.loadPortfolio()).accounts, hasLength(1));
      expect(find.byType(DerivedAccountPanel), findsOneWidget);
      await tester.enterText(evm, evmPath);
      await tester.enterText(tron, tronPath);
      await tap(tester, find.byKey(const ValueKey('confirm-derived-account')));
      final selected = (await vault.loadPortfolio()).selected!;
      expect(selected.derivationPath, evmPath);
      expect(selected.derivationPathFor(tronMainnetNetwork), tronPath);
      expect(find.byType(DerivedAccountPanel), findsNothing);
      expect(find.textContaining(tronPath), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> verifyTronSignature(WalletAccount account, String expected) async {
  Map<String, dynamic>? broadcast;
  final service = EvmNetworkService(
    network: tronMainnetNetwork,
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('getblockbynum')) {
        return reply({'blockID': TronNetworkService.genesisBlockId});
      }
      if (request.url.path.endsWith('getnowblock')) return reply(headBlock());
      broadcast = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      return http.Response(
        jsonEncode({'result': true, 'txid': broadcast!['txID']}),
        200,
      );
    }),
  );
  try {
    await service.sendNative(
      account: account,
      recipient: addressOne,
      amountWei: BigInt.one,
    );
    final sig = ec.hexToBytes(
      (broadcast!['signature'] as List).single as String,
    );
    final publicKey = ec.ecRecover(
      ec.hexToBytes(broadcast!['txID'] as String),
      ec.MsgSignature(
        ec.bytesToUnsignedInt(sig.sublist(0, 32)),
        ec.bytesToUnsignedInt(sig.sublist(32, 64)),
        sig.last + 27,
      ),
    );
    expect([
      0x41,
      ...ec.keccak256(publicKey).sublist(12),
    ], decodeTronAddress(expected));
  } finally {
    await service.dispose();
  }
}
