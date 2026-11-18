import 'package:bs58check/bs58check.dart' as base58;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'package:web3dart/crypto.dart' as ec;

import 'network_management_test.dart' show RpcFixture, start, tap;
import 'responsive_layout_test.dart' show panelHarness;
import 'wallet_management_test.dart' show phraseA;
import 'widget_test.dart' show MapSecretStore;

const evmPath = "m/44'/60'/0'/0/925183485";
const tronPath = "m/44'/195'/0'/0/925183485";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old hash reproduces 65-byte public keys, signatures still identify standard addresses',
    () {
      final standard = WalletAccount.fromMnemonic(
        phraseA,
        evmPath: evmPath,
        tronPath: tronPath,
      );
      final legacy = WalletAccount.fromMnemonic(
        phraseA,
        evmPath: evmPath,
        tronPath: tronPath,
        legacyAddressMode: true,
      );
      final publicKey = ec.privateKeyBytesToPublic(
        standard.credentials.privateKey,
      );
      final hash = ec.keccak256(Uint8List.fromList([4, ...publicKey]));
      expect(legacy.address.addressBytes, hash.sublist(12));
      expect(legacy.checksumAddress, isNot(standard.checksumAddress));
      expect(
        legacy.standardAddressFor(ethereumMainnetNetwork),
        standard.checksumAddress,
      );
      expect(
        legacy.standardAddressFor(tronMainnetNetwork),
        standard.tronAddress,
      );
      final samePathLegacy = WalletAccount.fromMnemonic(
        phraseA,
        evmPath: evmPath,
        tronPath: evmPath,
        legacyAddressMode: true,
      );
      expect(
        samePathLegacy.tronAddress,
        base58.encode(Uint8List.fromList([0x41, ...hash.sublist(12)])),
      );
      final digest = Uint8List.fromList(List.filled(32, 42));
      final signature = ec.sign(digest, standard.credentials.privateKey);
      final recovered = ec.ecRecover(digest, signature);
      expect(
        ec.keccak256(recovered).sublist(12),
        standard.address.addressBytes,
      );
      expect(
        ec.keccak256(recovered).sublist(12),
        isNot(legacy.address.addressBytes),
      );
      expect(() => legacy.credentials, throwsA(isA<WalletInputException>()));
      expect(() => legacy.privateKeyHex, throwsA(isA<WalletInputException>()));
    },
  );

  test(
    'diagnostic checks standard, old hash and real historical xPub branches',
    () {
      final shared = WalletAccount.fromMnemonic(
        phraseA,
        evmPath: evmPath,
        tronPath: evmPath,
      );
      var result = inspectLegacyMnemonic(
        mnemonic: phraseA,
        path: tronPath,
        expectedAddress: shared.tronAddress,
        network: tronMainnetNetwork,
      );
      expect(result.match, LegacyMnemonicMatch.standard);
      expect(result.matched!.path, evmPath);
      final wrong = WalletAccount.fromMnemonic(
        phraseA,
        tronPath: evmPath,
        legacyAddressMode: true,
      );
      result = inspectLegacyMnemonic(
        mnemonic: phraseA,
        path: tronPath,
        expectedAddress: wrong.tronAddress,
        network: tronMainnetNetwork,
      );
      expect(result.match, LegacyMnemonicMatch.legacyHash);
      expect(result.matched!.path, evmPath);
      expect(result.matched!.standardAddress, shared.tronAddress);
      expect(result.candidates, hasLength(3));
      expect(
        inspectLegacyMnemonic(
          mnemonic: phraseA,
          path: tronPath,
          expectedAddress: WalletAccount.fromPrivateKey(
            '1'.padLeft(64, '0'),
          ).tronAddress,
          network: tronMainnetNetwork,
        ).match,
        LegacyMnemonicMatch.none,
      );
      expect(
        () => inspectLegacyMnemonic(
          mnemonic: 'invalid',
          path: tronPath,
          expectedAddress: shared.tronAddress,
          network: tronMainnetNetwork,
        ),
        throwsA(isA<WalletInputException>()),
      );
    },
  );

  test(
    'legacy mode survives storage, selection and balance metadata alongside standard paths',
    () async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final original = await vault.addMnemonicWallet(phraseA);
      final id = original.groups.single.id;
      final created = await vault.addDerivedAccount(
        id,
        name: 'Legacy',
        evmPath: "m/44'/60'/0'/0/0",
        tronPath: "m/44'/195'/0'/0/0",
        legacyAddressMode: true,
      );
      final reopened = WalletVault(store: store);
      final loaded = await reopened.loadPortfolio();
      expect(loaded.selected!.legacyAddressMode, true);
      expect(loaded.selected!.account.legacyAddressMode, true);
      expect(
        loaded.selected!.addressFor(tronMainnetNetwork),
        created.selected!.account.tronAddress,
      );
      expect(
        loaded.selected!.account.standardAddressFor(tronMainnetNetwork),
        original.selected!.account.tronAddress,
      );
      final entries = await reopened.walletBalanceEntries().toList();
      expect(entries.last.legacyAddressMode, true);
      expect(
        entries.last.addressFor(tronMainnetNetwork),
        created.selected!.account.tronAddress,
      );
      final before = Map.of(store.values);
      await expectLater(
        reopened.addDerivedAccount(
          id,
          evmPath: "m/44'/60'/0'/0/0",
          tronPath: "m/44'/195'/0'/0/0",
          legacyAddressMode: true,
        ),
        throwsA(isA<WalletInputException>()),
      );
      expect(store.values, before);
      final checked = await reopened.inspectLegacyAccount(
        groupId: id,
        path: "m/44'/195'/0'/0/0",
        expectedAddress: created.selected!.account.tronAddress,
        network: tronMainnetNetwork,
      );
      expect(checked.match, LegacyMnemonicMatch.legacyHash);
      await reopened.selectAccount(original.selected!.id);
      expect(
        (await reopened.loadPortfolio()).selected!.account.legacyAddressMode,
        false,
      );
    },
  );

  test(
    'legacy EVM and TRON native/token transfers stop before RPC or broadcast',
    () async {
      final account = WalletAccount.fromMnemonic(
        phraseA,
        legacyAddressMode: true,
      );
      var requests = 0;
      for (final network in [ethereumMainnetNetwork, tronMainnetNetwork]) {
        final service = EvmNetworkService(
          network: network,
          httpClient: MockClient((request) async {
            requests++;
            throw StateError('No RPC should be called');
          }),
        );
        final to = WalletAccount.fromPrivateKey(
          '1'.padLeft(64, '0'),
        ).addressFor(network);
        final error = throwsA(
          isA<WalletInputException>().having(
            (e) => e.message.code,
            'code',
            MessageCode.legacyAddressCannotSign,
          ),
        );
        await expectLater(
          service.sendNative(
            account: account,
            recipient: to,
            amountWei: BigInt.one,
          ),
          error,
        );
        await expectLater(
          service.prepareTransfer(
            account: account,
            recipient: to,
            amount: BigInt.one,
          ),
          error,
        );
        await expectLater(
          service.prepareTransfer(
            account: account,
            recipient: to,
            amount: BigInt.one,
            token: TokenDefinition(
              networkId: network.id,
              contract: to,
              symbol: 'TST',
              name: 'TST',
              decimals: 6,
            ),
          ),
          error,
        );
        await service.dispose();
      }
      expect(requests, 0);
    },
  );

  test(
    'macOS migration and selected-account hydration preserve legacy mode',
    () async {
      const channel = MethodChannel('asterkeel/wallet_database');
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final id = (await vault.addMnemonicWallet(phraseA)).groups.single.id;
      final selected = (await vault.addDerivedAccount(
        id,
        evmPath: evmPath,
        tronPath: tronPath,
        legacyAddressMode: true,
      )).selected!;
      Map<Object?, Object?>? record;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'needsMigration':
            return true;
          case 'migrate':
            record = Map<Object?, Object?>.from(
              (call.arguments['groups'] as List).single,
            );
            return null;
          case 'summary':
            final row = (record!['accounts'] as List).last as Map;
            return {
              'groups_count': 1,
              'accounts_count': 2,
              'selected': {
                ...row,
                'id': selected.id,
                'group_id': id,
                'group_name': 'Root',
                'kind': 'mnemonic',
                'group_count': 2,
                'secret': phraseA,
              },
            };
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final native = WalletVault(store: store, useMacWalletDatabase: true);
      final loaded = (await native.loadWalletSummary()).selected!;
      final migrated = (record!['accounts'] as List).last;
      expect(migrated['legacy_address_mode'], 1);
      expect(migrated['tron'], selected.account.tronAddress);
      expect(loaded.legacyAddressMode, true);
      expect(loaded.account.legacyAddressMode, true);
      expect(loaded.account.tronAddress, migrated['tron']);
      expect(
        () => loaded.account.credentials,
        throwsA(isA<WalletInputException>()),
      );
    },
  );

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      'checkbox, branch check and readonly account creation at ${size.width}',
      (tester) async {
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
        await tap(tester, find.byKey(const ValueKey('legacy-address-mode')));
        await tester.enterText(
          find.byKey(const ValueKey('derived-evm-path')),
          evmPath,
        );
        await tester.enterText(
          find.byKey(const ValueKey('derived-tron-path')),
          tronPath,
        );
        final target = WalletAccount.fromMnemonic(
          phraseA,
          tronPath: evmPath,
          legacyAddressMode: true,
        ).tronAddress;
        await tester.enterText(
          find.byKey(const ValueKey('legacy-check-address')),
          target,
        );
        await tester.ensureVisible(find.byKey(const ValueKey('legacy-check')));
        await tester.tap(find.byKey(const ValueKey('legacy-check')));
        await tester.pump();
        // The diagnostic runs in a real isolate outside the widget fake clock.
        await tester.runAsync(() async {
          for (var i = 0; i < 100; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            await tester.pump();
            if (find
                .byKey(const ValueKey('legacy-use-path'))
                .evaluate()
                .isNotEmpty) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('legacy-use-path')), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('legacy-use-path')));
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('derived-tron-path')),
              )
              .controller!
              .text,
          evmPath,
        );
        await tap(
          tester,
          find.byKey(const ValueKey('confirm-derived-account')),
        );
        final selected = (await vault.loadPortfolio()).selected!;
        expect(selected.legacyAddressMode, true);
        expect(selected.account.tronAddress, target);
        expect(find.textContaining('旧版哈希错误'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selected legacy account displays a banner and cannot open sending',
    (tester) async {
      final vault = WalletVault(store: MapSecretStore({}));
      final book = await vault.addMnemonicWallet(phraseA);
      await vault.addDerivedAccount(
        book.groups.single.id,
        legacyAddressMode: true,
      );
      await start(tester, vault, RpcFixture());
      expect(find.text('旧版哈希错误 · 仅查看'), findsOneWidget);
      expect(find.text('派生密钥实际控制的标准地址'), findsOneWidget);
      await tap(tester, find.text('发送').first);
      expect(find.textContaining('无法用于此地址的转账'), findsOneWidget);
      expect(find.byKey(const ValueKey('send-recipient')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
