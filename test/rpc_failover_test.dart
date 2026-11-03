import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'package:web3dart/crypto.dart';

import 'network_management_test.dart'
    show rpcResult, RpcFixture, start, input, tap;
import 'widget_test.dart' show MapSecretStore;
import 'responsive_layout_test.dart' show panelHarness;

const pool = EvmNetwork(
  id: 1,
  name: 'Ethereum',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://first.example',
  fallbackRpcUrls: ['https://second.example', 'https://third.example'],
  explorerUrl: '',
  isTestnet: false,
);
final account = WalletAccount.fromPrivateKey('1'.padLeft(64, '0'));
String method(http.Request r) =>
    (jsonDecode(r.body) as Map)['method'] as String;

void main() {
  test(
    'old single-URL settings migrate to pools and new explicit lists persist',
    () async {
      final legacy = ethereumMainnetNetwork.toJson()..remove('rpcUrls');
      legacy['rpcUrl'] = 'https://cloudflare-eth.com';
      final custom = polygonMainnetNetwork.toJson()..remove('rpcUrls');
      custom['rpcUrl'] = 'https://my-node.example';
      final store = MapSecretStore({
        WalletVault.networkConfigsKey: jsonEncode([legacy, custom]),
      });
      final vault = WalletVault(store: store);
      final networks = await vault.loadNetworks();
      expect(networks.first.rpcUrls, ethereumMainnetNetwork.rpcUrls);
      expect(networks.singleWhere((n) => n.id == 137).rpcUrls, [
        'https://my-node.example',
        ...polygonMainnetNetwork.rpcUrls,
      ]);
      await vault.saveNetwork(pool.copyWith(rpcUrls: ['https://only.example']));
      expect((await WalletVault(store: store).loadNetworks()).first.rpcUrls, [
        'https://only.example',
      ]);
      await vault.saveNetwork(
        pool.copyWith(
          rpcUrls: [
            'https://first.example',
            'https://second.example',
            'https://second.example',
          ],
        ),
      );
      expect((await vault.loadNetworks()).first.rpcUrls, [
        'https://first.example',
        'https://second.example',
      ]);
      await expectLater(
        vault.saveNetwork(
          pool.copyWith(rpcUrls: ['https://first.example', 'file:///tmp/rpc']),
        ),
        throwsA(isA<WalletInputException>()),
      );
    },
  );

  for (final failure in [
    '503',
    '429',
    'rpc-error',
    'malformed',
    'timeout',
    'wrong-chain',
  ]) {
    test(
      '$failure falls through to the next endpoint and sticks to it',
      () async {
        final calls = <String>[];
        final hung = Completer<http.Response>();
        final service = EvmNetworkService(
          network: pool,
          endpointTimeout: const Duration(milliseconds: 30),
          httpClient: MockClient((request) async {
            calls.add('${request.url.host}:${method(request)}');
            if (request.url.host == 'first.example') {
              switch (failure) {
                case '503':
                  return http.Response('unavailable', 503);
                case '429':
                  return http.Response('limited', 429);
                case 'rpc-error':
                  return http.Response(
                    jsonEncode({
                      'jsonrpc': '2.0',
                      'id': 1,
                      'error': {'code': -32603, 'message': 'Internal error'},
                    }),
                    200,
                  );
                case 'malformed':
                  return http.Response('{}', 200);
                case 'timeout':
                  return hung.future;
                case 'wrong-chain':
                  return rpcResult(request, '0x89');
              }
            }
            return rpcResult(
              request,
              method(request) == 'eth_chainId' ? '0x1' : '0xde0b6b3a7640000',
            );
          }),
        );
        addTearDown(service.dispose);
        expect(
          (await service.getNativeBalance(account)).getInWei,
          parseEtherToWei('1'),
        );
        expect(service.activeRpcUrl, pool.rpcUrls[1]);
        expect(calls.where((c) => c.startsWith('first')), [
          'first.example:eth_chainId',
        ]);
        calls.clear();
        await service.getNativeBalance(account);
        expect(calls, [
          'second.example:eth_chainId',
          'second.example:eth_getBalance',
        ]);
        if (failure == 'timeout') {
          hung.complete(
            http.Response('{"jsonrpc":"2.0","id":1,"result":"0x1"}', 200),
          );
          await Future<void>.delayed(Duration.zero);
          expect(service.activeRpcUrl, pool.rpcUrls[1]);
          expect(calls.any((c) => c.startsWith('first')), isFalse);
        }
      },
    );
  }

  test(
    'balance errors also fail over; an active node failure wraps to primary',
    () async {
      final calls = <String>[];
      var primaryFails = true;
      final service = EvmNetworkService(
        network: pool,
        httpClient: MockClient((r) async {
          calls.add('${r.url.host}:${method(r)}');
          if (method(r) == 'eth_chainId') return rpcResult(r, '0x1');
          if ((r.url.host == 'first.example') == primaryFails) {
            return http.Response('bad', 503);
          }
          if (r.url.host == 'third.example') return http.Response('bad', 503);
          return rpcResult(r, '0x0');
        }),
      );
      addTearDown(service.dispose);
      expect((await service.getNativeBalance(account)).getInWei, BigInt.zero);
      expect(service.activeRpcUrl, pool.rpcUrls[1]);
      primaryFails = false;
      calls.clear();
      await service.getNativeBalance(account);
      expect(service.activeRpcUrl, pool.rpcUrls.first);
      expect(
        calls
            .where((c) => c.endsWith('eth_getBalance'))
            .map((c) => c.split(':').first),
        ['second.example', 'third.example', 'first.example'],
      );
    },
  );

  test(
    'all endpoints failing returns a bounded error and no balance',
    () async {
      var calls = 0;
      final service = EvmNetworkService(
        network: pool,
        httpClient: MockClient((r) async {
          calls++;
          return http.Response('bad', 503);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.getNativeBalance(account),
        throwsA(
          isA<WalletInputException>().having(
            (e) => e.message,
            'message',
            contains('全部 3 个'),
          ),
        ),
      );
      expect(calls, 3);
    },
  );

  for (final result in ['success', 'already known', 'unknown transaction']) {
    test(
      'broadcast $result reuses identical signed bytes and never signs again',
      () async {
        final raws = <String>[];
        var signingRequests = 0;
        final service = EvmNetworkService(
          network: pool,
          httpClient: MockClient((r) async {
            switch (method(r)) {
              case 'eth_chainId':
                return rpcResult(r, '0x1');
              case 'eth_gasPrice':
                signingRequests++;
                return rpcResult(r, '0x1');
              case 'eth_getTransactionCount':
                return rpcResult(r, '0x0');
              case 'eth_estimateGas':
                return rpcResult(r, '0x5208');
              case 'eth_sendRawTransaction':
                final raw = (jsonDecode(r.body) as Map)['params'][0] as String;
                raws.add(raw);
                if (r.url.host == 'first.example') {
                  return http.Response('bad gateway', 502);
                }
                if (result == 'success') {
                  return rpcResult(
                    r,
                    bytesToHex(keccak256(hexToBytes(raw)), include0x: true),
                  );
                }
                return http.Response(
                  jsonEncode({
                    'jsonrpc': '2.0',
                    'id': 1,
                    'error': {'code': -32000, 'message': result},
                  }),
                  200,
                );
            }
            throw StateError('Unexpected request');
          }),
        );
        addTearDown(service.dispose);
        final future = service.sendNative(
          account: account,
          recipient: account.checksumAddress,
          amountWei: BigInt.one,
        );
        if (result == 'unknown transaction') {
          await expectLater(
            future,
            throwsA(
              isA<RpcBroadcastException>().having(
                (e) => e.transactionHash,
                'hash',
                startsWith('0x'),
              ),
            ),
          );
        } else {
          expect(
            await future,
            bytesToHex(keccak256(hexToBytes(raws.first)), include0x: true),
          );
        }
        expect(raws, hasLength(result == 'unknown transaction' ? 3 : 2));
        expect(raws.toSet(), hasLength(1));
        expect(signingRequests, 1);
      },
    );
  }

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      'multi-node editor saves and restores built-ins at ${size.width}',
      (tester) async {
        final vault = WalletVault(store: MapSecretStore({}));
        await vault.importPrivateKeyWallet(
          privateKey: '1'.padLeft(64, '0'),
          networkId: 1,
        );
        await vault.saveSelectedNetwork(pool);
        await vault.saveNetwork(pool);
        final rpc = RpcFixture();
        rpc.handler = (r, _) async => r.url.host == 'first.example'
            ? http.Response('bad', 503)
            : rpcResult(r, method(r) == 'eth_chainId' ? '0x1' : '0x0');
        await start(tester, vault, rpc, size: size);
        await tap(
          tester,
          size.width < 760 ? find.text('设置') : find.byTooltip('设置'),
        );
        expect(find.text('当前可用节点'), findsOneWidget);
        expect(find.text(pool.rpcUrls[1]), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('edit-rpc-1')));
        await input(
          tester,
          'RPC 地址',
          'https://custom.example\nhttps://backup.example\nhttps://backup.example',
        );
        await tap(tester, find.text('保存网络配置'));
        expect((await vault.loadNetworks()).first.rpcUrls, [
          'https://custom.example',
          'https://backup.example',
        ]);
        await tap(tester, find.byKey(const ValueKey('edit-rpc-1')));
        await input(tester, 'RPC 地址', '');
        await tap(tester, find.text('保存网络配置'));
        expect(find.text('请至少配置一个 RPC 地址。'), findsOneWidget);
        await tap(tester, find.text('恢复内置免费节点'));
        await tap(tester, find.text('保存网络配置'));
        expect(
          (await vault.loadNetworks()).first.rpcUrls,
          ethereumMainnetNetwork.rpcUrls,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('uncertain broadcasts show hash and disable another signature', (
    tester,
  ) async {
    await tester.pumpWidget(
      panelHarness(
        (context) => SendSheet(
          theme: WalletTheme.light,
          network: pool,
          balanceWei: null,
          onSend: (_, _) async => throw RpcBroadcastException('0x${'a' * 64}'),
        ),
      ),
    );
    await tap(tester, find.text('open'));
    await input(tester, '收款地址', account.checksumAddress);
    await input(tester, '金额（ETH）', '1');
    await tap(tester, find.text('签名并广播'));
    expect(find.textContaining('交易哈希：0x'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '请先确认交易状态'))
          .onPressed,
      isNull,
    );
  });
}
