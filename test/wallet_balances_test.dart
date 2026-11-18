import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'asset_test_helpers.dart';
import 'network_management_test.dart' show rpcResult;
import 'widget_test.dart' show MapSecretStore;

String _key(int number) => number.toRadixString(16).padLeft(64, '0');

class _WalletFixture {
  _WalletFixture(this.number, this.name, this.network)
    : address = WalletAccount.fromPrivateKey(_key(number));

  final int number;
  final String name;
  final EvmNetwork network;
  final WalletAccount address;

  String get id => 'wallet-$number';
  Map<String, Object?> get account => {
    'id': '$id:0',
    'group_id': id,
    'group_name': name,
    'kind': 'privateKey',
    'network_id': network.id,
    'group_count': 1,
    'name': name,
    'account_index': 0,
    'evm': address.checksumAddress,
    'tron': address.tronAddress,
  };
  Map<String, Object?> get group => {
    'id': id,
    'name': name,
    'kind': 'privateKey',
    'network_id': network.id,
    'sequence': number,
    'accounts': [account],
  };
}

void main() {
  testWidgets(
    'bulk balances run in background and rank public-address results',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final smaller = _WalletFixture(1, 'BNB wallet', bnbSmartChainNetwork);
      final bigger = _WalletFixture(2, 'TRON wallet', tronMainnetNetwork);
      final failed = _WalletFixture(
        3,
        'Unavailable wallet',
        tronMainnetNetwork,
      );
      final zero = _WalletFixture(4, 'Empty wallet', bnbSmartChainNetwork);
      final entries = [smaller, bigger, failed, zero];
      final store = MapSecretStore({
        WalletVault.walletBookKey: jsonEncode({
          'version': 2,
          'activeAccountId': '${smaller.id}:0',
          'groups': [
            for (final entry in entries)
              {
                'id': entry.id,
                'name': entry.name,
                'kind': 'privateKey',
                'networkId': entry.network.id,
                'secret': _key(entry.number),
                'accounts': [
                  {'index': 0, 'name': entry.name},
                ],
              },
          ],
        }),
        WalletVault.selectedNetworkKey: bnbSmartChainNetwork.id.toString(),
      });

      final addressesRead = <(int, String)>[];
      final started = Completer<void>();
      final releaseTron = Completer<void>();
      EvmNetworkService service(EvmNetwork network) => EvmNetworkService(
        network: network,
        httpClient: MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          if (network.isTron) {
            if (request.url.path.endsWith('/wallet/getblockbynum')) {
              return http.Response(
                jsonEncode({'blockID': TronNetworkService.genesisBlockId}),
                200,
              );
            }
            if (request.url.path.endsWith('/wallet/getaccount')) {
              final address = data['address'] as String;
              addressesRead.add((network.id, address));
              if (address == failed.address.tronAddress) {
                return http.Response('{}', 503);
              }
              expect(address, bigger.address.tronAddress);
              if (!started.isCompleted) started.complete();
              await releaseTron.future;
              return http.Response(jsonEncode({'address': address}), 200);
            }
            expect(
              request.url.path,
              endsWith('/wallet/triggerconstantcontract'),
            );
            final owner = data['parameter'] as String;
            final tronOwner = bigger.address.addressHex
                .substring(2)
                .toLowerCase();
            if (owner.endsWith(tronOwner)) {
              return http.Response(
                jsonEncode({
                  'result': {'result': true},
                  'constant_result': [
                    BigInt.from(800000000).toRadixString(16).padLeft(64, '0'),
                  ],
                }),
                200,
              );
            }
            return http.Response('{}', 503);
          }
          final params = data['params'] as List;
          return switch (data['method']) {
            'eth_chainId' => rpcResult(request, '0x38'),
            'eth_call' => rpcResult(request, '0x${'0' * 64}'),
            'eth_getBalance' => () {
              final address = (params.first as String).toLowerCase();
              addressesRead.add((network.id, address));
              return rpcResult(
                request,
                address == smaller.address.addressHex.toLowerCase()
                    ? '0xde0b6b3a7640000'
                    : '0x0',
              );
            }(),
            _ => throw StateError('Unexpected RPC method ${data['method']}'),
          };
        }),
      );
      final vault = WalletVault(store: store);
      await tester.pumpWidget(
        StoneWalletApp(
          vault: vault,
          quoteService: TestQuoteService(),
          networkServiceBuilder: service,
        ),
      );
      await tester.pumpAndSettle();
      addressesRead.clear();
      final open = find.byKey(const ValueKey('portfolio-wallet-balances'));
      final close = find.byKey(const ValueKey('wallet-nav-assets'));
      final reopen = find.byKey(const ValueKey('wallet-nav-wallets'));
      final control = find.byKey(const ValueKey('manage-query-balances'));
      Finder row(_WalletFixture wallet) =>
          find.byKey(ValueKey('manage-wallet-${wallet.id}'));

      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(started.isCompleted, isTrue);
      expect(row(smaller), findsOneWidget);
      expect(row(bigger), findsOneWidget);

      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(find.text('继续查询'), findsOneWidget);
      await assetTap(tester, close);
      releaseTron.complete();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        addressesRead,
        isNot(contains((56, zero.address.addressHex.toLowerCase()))),
      );

      await assetTap(tester, reopen);
      expect(row(bigger), findsOneWidget);
      expect(find.text(r'≈ $800.00'), findsOneWidget);
      await tester.tap(control);
      await tester.pumpAndSettle();
      await assetTap(tester, close);
      await tester.pump(const Duration(milliseconds: 300));
      await assetTap(tester, reopen);
      final complete = find.text('查询完成 · 4 / 4 个账户');
      for (var i = 0; i < 10 && complete.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(complete, findsOneWidget);
      expect(
        find.descendant(of: row(smaller), matching: find.text(r'≈ $600.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(zero), matching: find.text(r'≈ $0.00')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(failed), matching: find.text('—')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(row(bigger)).dy,
        lessThan(tester.getTopLeft(row(smaller)).dy),
      );
      expect(
        tester.getTopLeft(row(smaller)).dy,
        lessThan(tester.getTopLeft(row(zero)).dy),
      );
      expect(
        tester.getTopLeft(row(zero)).dy,
        lessThan(tester.getTopLeft(row(failed)).dy),
      );
      expect(addressesRead.toSet(), {
        (56, smaller.address.addressHex.toLowerCase()),
        (56, zero.address.addressHex.toLowerCase()),
        (tronMainnetNetwork.id, bigger.address.tronAddress),
        (tronMainnetNetwork.id, failed.address.tronAddress),
      });
      expect(
        (await vault.loadWalletSummary()).activeAccountId,
        '${smaller.id}:0',
      );
      expect(await vault.loadSelectedNetworkId(), bnbSmartChainNetwork.id);

      await assetTap(tester, row(bigger));
      expect(find.text('800 USDT'), findsOneWidget);
      expect(find.text(bigger.address.tronAddress), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
