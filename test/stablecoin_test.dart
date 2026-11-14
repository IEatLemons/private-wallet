import 'asset_test_helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart' show tap, input, rpcResult;
import 'widget_test.dart' show MapSecretStore;

const phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const phraseB = 'test test test test test test test test test test test junk';
String word(BigInt n) => n.toRadixString(16).padLeft(64, '0');
String symbolWord(String s) => utf8
    .encode(s)
    .map((n) => n.toRadixString(16).padLeft(2, '0'))
    .join()
    .padRight(64, '0');
final seedAccount = WalletAccount.fromMnemonic(phrase);
final snapshotKey = GlobalKey();

class TokenRpc {
  final requests = <http.Request>[];
  bool failBnb = false;
  Completer<void>? oldAccountDelay;
  EvmNetworkService service(EvmNetwork network) => EvmNetworkService(
    network: network,
    httpClient: MockClient((request) async {
      requests.add(request);
      final body = jsonDecode(request.body) as Map;
      if (network.isTron) {
        if (request.url.path.endsWith('getblockbynum')) {
          return http.Response(
            jsonEncode({'blockID': TronNetworkService.genesisBlockId}),
            200,
          );
        }
        if (request.url.path.endsWith('getaccount')) {
          return http.Response(
            jsonEncode({'address': body['address'], 'balance': 1000000}),
            200,
          );
        }
        expect(request.url.path.endsWith('triggerconstantcontract'), true);
        expect(body['function_selector'], 'balanceOf(address)');
        expect(
          body['parameter'],
          '0' * 24 + seedAccount.addressFor(tronMainnetNetwork).letTronHex(),
        );
        return http.Response(
          jsonEncode({
            'result': {'result': true},
            'constant_result': [word(BigInt.from(6250000))],
          }),
          200,
        );
      }
      final method = body['method'];
      if (method == 'eth_chainId') {
        return rpcResult(request, '0x${network.id.toRadixString(16)}');
      }
      if (method == 'eth_getBalance') {
        return rpcResult(request, '0xde0b6b3a7640000');
      }
      expect(method, 'eth_call');
      final call = (body['params'] as List).first as Map;
      final data = call['data'] as String;
      final contract = (call['to'] as String).toLowerCase();
      final custom = contract == '0x${'22' * 20}';
      if (data == '0x313ce567') {
        return rpcResult(
          request,
          '0x${word(BigInt.from(custom
              ? 8
              : network.id == 56
              ? 18
              : 6))}',
        );
      }
      if (data == '0x95d89b41') {
        return rpcResult(request, '0x${symbolWord(custom ? 'CASH' : 'USDT')}');
      }
      expect(data.substring(0, 10), '0x70a08231');
      if (failBnb && network.id == 56) return http.Response('limited', 429);
      final firstOwner = data.endsWith(
        seedAccount.addressHex.substring(2).toLowerCase(),
      );
      if (firstOwner && oldAccountDelay != null) await oldAccountDelay!.future;
      final units = custom
          ? BigInt.from(900000000)
          : contract == builtinTokens[4].contract.toLowerCase()
          ? BigInt.from(3000000)
          : network.id == 56
          ? BigInt.parse('1250000000000000000')
          : network.id == 137
          ? BigInt.zero
          : BigInt.from(firstOwner ? 12500000 : 25000000);
      return rpcResult(request, '0x${word(units)}');
    }),
  );
}

extension on String {
  String letTronHex() => decodeTronAddress(
    this,
  ).sublist(1).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Future<void> render(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('RENDER_STABLECOINS')) return;
  await tester.pumpAndSettle();
  final boundary =
      snapshotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/stablecoin-previews').create(recursive: true);
    await File(
      'build/stablecoin-previews/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('RENDER_STABLECOINS')) {
      final font = ByteData.sublistView(
        await File('/System/Library/Fonts/STHeiti Light.ttc').readAsBytes(),
      );
      await (FontLoader('Roboto')..addFont(Future.value(font))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test(
    'USDT totals normalize 6/18 decimals exactly and exclude USDC and spoofed tickers',
    () {
      TokenHolding holding(TokenDefinition t, BigInt units) => TokenHolding(
        token: t,
        network: supportedNetworks.firstWhere((n) => n.id == t.networkId),
        state: TokenState.ready,
        units: units,
      );
      final spoof = TokenDefinition(
        networkId: 1,
        contract: '0x${'11' * 20}',
        symbol: 'USDT',
        decimals: 6,
        name: 'Fake',
        family: 'USDT',
      );
      final holdings = [
        holding(builtinTokens[0], BigInt.from(12500000)),
        holding(builtinTokens[1], BigInt.from(6250000)),
        holding(builtinTokens[2], BigInt.parse('1250000000000000000')),
        holding(builtinTokens[3], BigInt.zero),
        holding(builtinTokens[4], BigInt.from(3000000)),
        holding(spoof, BigInt.from(999999999)),
      ];
      final total = StablecoinTotal('USDT', holdings);
      expect(total.amount, '20');
      expect(total.knownCount, 4);
      expect(total.complete, true);
      expect(StablecoinTotal('USDC', holdings).amount, '3');
      expect(spoof.trustedFamily, isNull);
      final partial = StablecoinTotal('USDT', [
        holdings.first,
        TokenHolding(
          token: builtinTokens[2],
          network: bnbSmartChainNetwork,
          state: TokenState.failed,
        ),
      ]);
      expect(partial.amount, '12.5');
      expect(partial.complete, false);
      expect(StablecoinTotal('USDT', []).amount, '—');
      final dust = StablecoinTotal('USDT', [
        holding(builtinTokens[2], BigInt.one),
      ]);
      expect(dust.amount, '< 0.000001');
    },
  );

  test(
    'token preferences persist, deduplicate contracts and preserve corrupt records',
    () async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      expect(await vault.loadTokens(), hasLength(4));
      await vault.saveTokens([builtinTokens[4]]);
      final loaded = await WalletVault(store: store).loadTokens();
      expect(loaded.single.trustedFamily, 'USDC');
      await expectLater(
        vault.saveTokens([builtinTokens[4], builtinTokens[4]]),
        throwsA(isA<WalletInputException>()),
      );
      expect((await vault.loadTokens()).single.key, builtinTokens[4].key);
      store.values[TokenStorage.tokensKey] = 'broken';
      await expectLater(
        vault.loadTokens(),
        throwsA(isA<WalletInputException>()),
      );
      expect(store.values[TokenStorage.tokensKey], 'broken');
    },
  );

  test(
    'ERC20 read-only calls verify chain, calldata and malformed-result failover',
    () async {
      final calls = <http.Request>[];
      final service = EvmNetworkService(
        network: ethereumMainnetNetwork,
        httpClient: MockClient((request) async {
          calls.add(request);
          final body = jsonDecode(request.body) as Map;
          if (body['method'] == 'eth_chainId') return rpcResult(request, '0x1');
          expect(body['method'], 'eth_call');
          final call = (body['params'] as List).first as Map;
          expect(
            call['to'].toString().toLowerCase(),
            builtinTokens.first.contract.toLowerCase(),
          );
          expect(
            call['data'],
            '0x70a08231${seedAccount.addressHex.substring(2).toLowerCase().padLeft(64, '0')}',
          );
          return rpcResult(
            request,
            request.url.host == 'eth.drpc.org'
                ? '0x'
                : '0x${word(BigInt.from(777000000))}',
          );
        }),
      );
      expect(
        await service.getTokenBalance(seedAccount, builtinTokens.first),
        BigInt.from(777000000),
      );
      expect(service.activeRpcUrl, ethereumMainnetNetwork.rpcUrls.last);
      expect(calls.every((r) => !r.body.contains(phrase)), true);
      await service.dispose();
    },
  );

  test(
    'TRC20 balance encodes the 20-byte TRON owner and rejects reverted calls',
    () async {
      final rpc = TokenRpc();
      final service = rpc.service(tronMainnetNetwork);
      expect(
        await service.getTokenBalance(seedAccount, builtinTokens[1]),
        BigInt.from(6250000),
      );
      await service.dispose();
      final bad = EvmNetworkService(
        network: tronMainnetNetwork,
        httpClient: MockClient(
          (r) async => http.Response(
            jsonEncode(
              r.url.path.endsWith('getblockbynum')
                  ? {'blockID': TronNetworkService.genesisBlockId}
                  : {
                      'result': {'result': false},
                      'constant_result': ['0' * 64],
                    },
            ),
            200,
          ),
        ),
      );
      await expectLater(
        bad.getTokenBalance(seedAccount, builtinTokens[1]),
        throwsA(isA<WalletInputException>()),
      );
      await bad.dispose();
    },
  );

  for (final config in [
    (1200.0, 850.0, false, 1.0),
    (390.0, 844.0, false, 1.0),
    (360.0, 740.0, true, 1.3),
  ]) {
    testWidgets('stablecoin flows ${config.$1} ${config.$3}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(config.$1, config.$2);
      tester.platformDispatcher.textScaleFactorTestValue = config.$4;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      final vault = WalletVault(store: store);
      await vault.saveSelectedNetworks([
        ethereumMainnetNetwork,
        bnbSmartChainNetwork,
        tronMainnetNetwork,
        polygonMainnetNetwork,
      ]);
      final rpc = TokenRpc();
      await tester.pumpWidget(
        RepaintBoundary(
          key: snapshotKey,
          child: StoneWalletApp(
            quoteService: TestQuoteService(),
            vault: vault,
            networkServiceBuilder: rpc.service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (config.$3) {
        (tester.state(find.byType(StoneWalletApp)) as dynamic).toggleStyle();
        await tester.pumpAndSettle();
      }
      await render(tester, '${config.$1.toInt()}-overview');
      await selectCoin(tester, 'usdt');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '20 USDT',
      );
      await render(tester, '${config.$1.toInt()}-home');
      expect(find.byType(PortfolioChainRow), findsNWidgets(3));
      await render(tester, '${config.$1.toInt()}-stablecoins');
      await tap(tester, find.byType(PortfolioChainRow).at(1));
      expect(
        tester
            .widget<TokenDetailsPanel>(find.byType(TokenDetailsPanel))
            .address,
        seedAccount.tronAddress,
      );
      expect(
        find.descendant(
          of: find.byType(TokenDetailsPanel),
          matching: find.text('发送'),
        ),
        findsOneWidget,
      );
      await tap(tester, find.byTooltip('关闭'));
      await assetMenu(tester, MessageCode.msgAddTokens);
      await tap(tester, find.byKey(ValueKey('watch-${builtinTokens[4].key}')));
      await tap(tester, find.text('添加自定义代币'));
      await input(tester, '代币合约地址', '0x${'22' * 20}');
      await tap(tester, find.text('读取代币信息'));
      expect(find.text('CASH · 8 位精度'), findsOneWidget);
      await tap(tester, find.text('确认添加'));
      await tap(tester, find.byTooltip('关闭'));
      await selectCoin(tester, 'usdc');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdc'))).data,
        '3 USDC',
      );
      await selectCoin(tester, 'usdt');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '20 USDT',
      );
      rpc.failBnb = true;
      await tap(tester, find.byKey(const ValueKey('refresh-portfolio')));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '18.75 USDT',
      );
      expect(find.text('部分结果'), findsOneWidget);
      expect(find.text('查询失败'), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(
        (await WalletVault(store: store).loadTokens()).map((t) => t.symbol),
        containsAll(['USDC', 'CASH']),
      );
    });
  }

  testWidgets(
    'late token replies cannot leak previous account balances after switching',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final vault = WalletVault(store: MapSecretStore({}));
      final first = await vault.addMnemonicWallet(phrase);
      await vault.addMnemonicWallet(phraseB);
      await vault.selectAccount(first.selected!.id);
      await vault.saveSelectedNetwork(ethereumMainnetNetwork);
      final gate = Completer<void>();
      final rpc = TokenRpc()..oldAccountDelay = gate;
      await tester.pumpWidget(
        StoneWalletApp(
          quoteService: TestQuoteService(),
          vault: vault,
          networkServiceBuilder: rpc.service,
        ),
      );
      await tester.pumpAndSettle();
      await selectCoin(tester, 'usdt');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '— USDT',
      );
      await tap(tester, find.text('主钱包'));
      await tap(tester, find.text('钱包 2'));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '25 USDT',
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('coin-total-usdt'))).data,
        '25 USDT',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
