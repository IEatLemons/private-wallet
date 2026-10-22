import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'widget_test.dart' show MapSecretStore;

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const base = EvmNetwork(
  id: 8453,
  name: 'Base',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://base.example/rpc',
  explorerUrl: 'https://base.example',
  isTestnet: false,
);

http.Response rpcResult(http.Request request, Object value) => http.Response(
  jsonEncode({
    'jsonrpc': '2.0',
    'id': (jsonDecode(request.body) as Map)['id'],
    'result': value,
  }),
  200,
  headers: {'content-type': 'application/json'},
);

class RpcFixture {
  final List<Uri> calls = [];
  Future<http.Response> Function(http.Request, EvmNetwork)? handler;

  EvmNetworkService service(EvmNetwork network) => EvmNetworkService(
    network: network,
    httpClient: MockClient((request) async {
      calls.add(request.url);
      if (handler != null) return handler!(request, network);
      final method = (jsonDecode(request.body) as Map)['method'];
      return rpcResult(
        request,
        method == 'eth_chainId'
            ? '0x${network.id.toRadixString(16)}'
            : '0x11200c7644d50000',
      ); // 1.234 ETH/POL
    }),
  );
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);
Future<void> input(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(field(label));
  await tester.enterText(field(label), text);
}

Future<void> tap(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> start(
  WidgetTester tester,
  WalletVault vault,
  RpcFixture rpc, {
  Size size = const Size(1200, 800),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    StoneWalletApp(vault: vault, networkServiceBuilder: rpc.service),
  );
  await tester.pumpAndSettle();
}

WalletVault memoryVault() =>
    WalletVault(store: MapSecretStore({WalletVault.mnemonicKey: mnemonic}));

void main() {
  test(
    'network overrides and custom networks round-trip without losing old selections',
    () async {
      final store = MapSecretStore({
        WalletVault.mnemonicKey: mnemonic,
        WalletVault.selectedNetworkKey: '137',
      });
      final vault = WalletVault(store: store);
      expect(await vault.loadSelectedNetworkIds(), [137]);
      final overridden = ethereumMainnetNetwork.copyWith(
        rpcUrl: 'https://custom.example/ethereum',
      );
      await vault.saveNetwork(overridden);
      await vault.saveNetwork(base);
      final loaded = await WalletVault(store: store).loadNetworks();
      expect(loaded, hasLength(5));
      expect(loaded.singleWhere((n) => n.id == 1).rpcUrl, overridden.rpcUrl);
      expect(
        loaded.singleWhere((n) => n.id == 137).rpcUrl,
        polygonMainnetNetwork.rpcUrl,
      );
      expect(loaded.singleWhere((n) => n.id == 8453).toJson(), base.toJson());
      expect(await vault.loadSelectedNetworkIds(), [137]);
      expect(networkForValue('Base', networks: loaded)?.id, 8453);
      final imported = await vault.importPrivateKeyWallets([
        WalletImportRow(chain: '8453', privateKey: '1'.padLeft(64, '0')),
      ]);
      expect(imported.imported.single.networkId, 8453);
    },
  );

  test('invalid chain IDs and RPC URLs are rejected before storage', () async {
    final vault = memoryVault();
    for (final url in [
      '',
      'not a url',
      'file:///tmp/rpc',
      'ftp://node.example',
    ]) {
      await expectLater(
        vault.saveNetwork(base.copyWith(rpcUrl: url)),
        throwsA(isA<WalletInputException>()),
      );
    }
    expect(
      () => const EvmNetwork(
        id: 0,
        name: 'bad',
        nativeSymbol: 'BAD',
        rpcUrl: 'https://node.example',
        explorerUrl: '',
        isTestnet: false,
      ).validate(),
      throwsA(isA<WalletInputException>()),
    );
    await vault.saveNetwork(base.copyWith(rpcUrl: 'http://127.0.0.1:8545'));
    expect((await vault.loadNetworks()).last.rpcUrl, 'http://127.0.0.1:8545');
  });

  test(
    'wrong RPC chain is rejected before reading a balance or signing',
    () async {
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add((jsonDecode(request.body) as Map)['method'] as String);
        return rpcResult(request, '0x89');
      });
      final service = EvmNetworkService(
        network: ethereumMainnetNetwork,
        httpClient: client,
      );
      final account = WalletAccount.fromMnemonic(mnemonic);
      await expectLater(
        service.getNativeBalance(account),
        throwsA(isA<WalletInputException>()),
      );
      await expectLater(
        service.sendNative(
          account: account,
          recipient: account.checksumAddress,
          amountWei: BigInt.one,
        ),
        throwsA(isA<WalletInputException>()),
      );
      expect(methods, everyElement('eth_chainId'));
      await service.dispose();
    },
  );

  test('Android release manifest grants RPC networking', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:usesCleartextTraffic="true"'));
  });

  testWidgets(
    'receive opens immediately while its RPC refresh is still pending',
    (tester) async {
      final vault = memoryVault(), rpc = RpcFixture();
      await vault.saveSelectedNetwork(ethereumMainnetNetwork);
      await start(tester, vault, rpc);
      await tap(tester, find.byType(AssetListRow));
      final pending = Completer<http.Response>();
      http.Request? request;
      rpc.handler = (value, _) async {
        request = value;
        return pending.future;
      };
      await tap(tester, find.text('接收').last);
      expect(find.byType(ActionSheet), findsOneWidget);
      expect(pending.isCompleted, isFalse);
      rpc.handler = null;
      pending.complete(rpcResult(request!, '0x1'));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('关闭'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      '${size.width}: selecting a chain persists and updates its actual balance',
      (tester) async {
        final vault = memoryVault(), rpc = RpcFixture();
        await start(tester, vault, rpc, size: size);
        expect(rpc.calls, isEmpty);
        await tap(tester, find.text('选择网络'));
        await tap(tester, find.text('Polygon'));
        await tap(tester, find.text('保存网络选择'));
        expect(await vault.loadSelectedNetworkId(), 137);
        expect(await vault.loadSelectedNetworkIds(), [137]);
        final hero = tester.widget<PortfolioHero>(find.byType(PortfolioHero));
        expect(hero.network, 'Polygon');
        expect(hero.balance, '1.234 POL');
        expect(hero.syncLabel, contains('RPC 已连接'));
        expect(
          rpc.calls,
          everyElement(Uri.parse(polygonMainnetNetwork.rpcUrl)),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('custom chain can be added, checked, selected and reloaded', (
    tester,
  ) async {
    final vault = memoryVault(), rpc = RpcFixture();
    await start(tester, vault, rpc);
    await tap(tester, find.byTooltip('设置'));
    await tap(tester, find.text('添加自定义链'));
    await input(tester, '网络名称', 'Base');
    await input(tester, 'Chain ID', '8453');
    await input(tester, '原生代币符号', 'ETH');
    await input(tester, 'RPC 地址', base.rpcUrl);
    await tap(tester, find.text('检测 RPC 连接'));
    expect(find.text('RPC 可用，Chain ID 与网络配置一致。'), findsOneWidget);
    await tap(tester, find.text('保存网络配置'));
    expect((await vault.loadNetworks()).last.rpcUrl, base.rpcUrl);
    expect(await vault.loadSelectedNetworkId(), base.id);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      StoneWalletApp(vault: vault, networkServiceBuilder: rpc.service),
    );
    await tester.pumpAndSettle();
    final hero = tester.widget<PortfolioHero>(find.byType(PortfolioHero));
    expect(hero.network, 'Base');
    expect(hero.balance, '1.234 ETH');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing a failed RPC replaces the live client without restarting',
    (tester) async {
      final vault = memoryVault(), rpc = RpcFixture();
      final old = ethereumMainnetNetwork.copyWith(
        rpcUrl: 'https://old.example',
      );
      await vault.saveNetwork(old);
      await vault.saveSelectedNetwork(old);
      rpc.handler = (request, network) async =>
          request.url.host == 'old.example'
          ? http.Response('unavailable', 503)
          : rpcResult(
              request,
              (jsonDecode(request.body) as Map)['method'] == 'eth_chainId'
                  ? '0x1'
                  : '0x11200c7644d50000',
            );
      await start(tester, vault, rpc);
      expect(
        tester.widget<PortfolioHero>(find.byType(PortfolioHero)).balance,
        '— ETH',
      );
      expect(
        tester.widget<PortfolioHero>(find.byType(PortfolioHero)).syncLabel,
        'RPC 连接失败',
      );
      await tap(tester, find.byTooltip('设置'));
      await tap(tester, find.byKey(const ValueKey('edit-rpc-1')));
      await input(tester, 'RPC 地址', 'https://new.example');
      await tap(tester, find.text('保存网络配置'));
      expect(rpc.calls.any((u) => u.host == 'new.example'), isTrue);
      expect((await vault.loadNetworks()).first.rpcUrl, 'https://new.example');
      await tap(tester, find.byTooltip('首页'));
      expect(
        tester.widget<PortfolioHero>(find.byType(PortfolioHero)).balance,
        '1.234 ETH',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late responses from an old RPC cannot overwrite the new RPC status',
    (tester) async {
      final vault = memoryVault(), rpc = RpcFixture();
      final old = ethereumMainnetNetwork.copyWith(
        rpcUrl: 'https://old.example',
      );
      await vault.saveNetwork(old);
      await vault.saveSelectedNetwork(old);
      final late = Completer<http.Response>();
      http.Request? oldRequest;
      rpc.handler = (request, network) async {
        if (request.url.host == 'old.example') {
          oldRequest = request;
          return late.future;
        }
        return rpcResult(
          request,
          (jsonDecode(request.body) as Map)['method'] == 'eth_chainId'
              ? '0x1'
              : '0x11200c7644d50000',
        );
      };
      await start(tester, vault, rpc);
      await tap(tester, find.byTooltip('设置'));
      await tap(tester, find.byKey(const ValueKey('edit-rpc-1')));
      await input(tester, 'RPC 地址', 'https://new.example');
      await tap(tester, find.text('保存网络配置'));
      late.complete(rpcResult(oldRequest!, '0x89'));
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('首页'));
      final hero = tester.widget<PortfolioHero>(find.byType(PortfolioHero));
      expect(hero.balance, '1.234 ETH');
      expect(hero.syncLabel, contains('RPC 已连接'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mobile network editor rejects duplicates and reports a mismatched RPC',
    (tester) async {
      final vault = memoryVault(), rpc = RpcFixture();
      rpc.handler = (request, _) async => rpcResult(request, '0x1');
      await start(tester, vault, rpc, size: const Size(360, 640));
      addTearDown(tester.view.resetViewInsets);
      await tap(tester, find.text('设置'));
      await tap(tester, find.text('添加自定义链'));
      await input(tester, '网络名称', 'Base');
      await input(tester, 'Chain ID', '1');
      await input(tester, '原生代币符号', 'ETH');
      await input(tester, 'RPC 地址', base.rpcUrl);
      await tap(tester, find.text('保存网络配置'));
      expect(find.text('该 Chain ID 已存在，请编辑现有网络的 RPC。'), findsOneWidget);
      expect(await vault.loadNetworks(), hasLength(4));
      await input(tester, 'Chain ID', '8453');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(find.text('保存网络配置').hitTestable(), findsOneWidget);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tap(tester, find.text('检测 RPC 连接'));
      expect(find.text('RPC 链不匹配：预期 8453，实际 1。'), findsOneWidget);
      expect(await vault.loadNetworks(), hasLength(4));
      await tap(tester, find.byTooltip('关闭'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one failed chain does not mark another chain as disconnected', (
    tester,
  ) async {
    final vault = memoryVault(), rpc = RpcFixture();
    await vault.saveSelectedNetworks([
      ethereumMainnetNetwork,
      polygonMainnetNetwork,
    ]);
    rpc.handler = (request, network) async => network.id == 137
        ? http.Response('unavailable', 503)
        : rpcResult(
            request,
            (jsonDecode(request.body) as Map)['method'] == 'eth_chainId'
                ? '0x1'
                : '0x11200c7644d50000',
          );
    await start(tester, vault, rpc);
    final hero = tester.widget<PortfolioHero>(find.byType(PortfolioHero));
    expect(hero.balance, '1.234 ETH');
    expect(hero.syncLabel, contains('RPC 已连接'));
    final table = tester.widget<AssetTable>(find.byType(AssetTable));
    expect(table.assets.singleWhere((a) => a.networkId == 137).amount, '— POL');
    expect(table.assets.singleWhere((a) => a.networkId == 137).change, '连接失败');
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      '${size.width}: asset title, view all, search, detail and receive work',
      (tester) async {
        final vault = memoryVault(), rpc = RpcFixture();
        await vault.saveNetwork(base);
        await vault.saveSelectedNetworks([...supportedEvmNetworks, base]);
        await start(tester, vault, rpc, size: size);
        expect(find.byType(AssetListRow), findsNWidgets(4));
        await tap(tester, find.text('查看全部'));
        expect(find.byType(AssetsPage), findsOneWidget);
        expect(find.byType(AssetListRow), findsNWidgets(5));
        await tester.enterText(find.byType(TextField), 'Base');
        await tester.pumpAndSettle();
        expect(find.byType(AssetListRow), findsOneWidget);
        await tap(tester, find.byType(AssetListRow));
        expect(find.byType(AssetDetailsPanel), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AssetDetailsPanel),
            matching: find.text('1.234 ETH'),
          ),
          findsOneWidget,
        );
        expect(find.text(base.rpcUrl), findsOneWidget);
        await tap(tester, find.text('刷新余额'));
        await tap(tester, find.text('接收'));
        expect(find.byType(ActionSheet), findsOneWidget);
        expect(await vault.loadSelectedNetworkId(), base.id);
        await tap(tester, find.byTooltip('关闭'));
        await tap(tester, find.text('返回首页'));
        expect(find.byType(AssetsPage), findsNothing);
        await tap(tester, find.text('链上资产'));
        expect(find.byType(AssetsPage), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AssetsPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
