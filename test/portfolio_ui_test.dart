import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/asset_discovery.dart';
import 'package:stone_wallet/portfolio_assets.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/quotes.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'asset_test_helpers.dart';
import 'stablecoin_test.dart' show TokenRpc, phrase, phraseB;
import 'widget_test.dart' show MapSecretStore;

const extraContract = '0x2222222222222222222222222222222222222222';
final extraToken = TokenDefinition(
  networkId: 1,
  contract: extraContract,
  symbol: 'CASH',
  decimals: 8,
  name: 'Cash',
);

class FixtureDiscovery extends AssetDiscoveryService {
  FixtureDiscovery(this.query);
  final Future<DiscoveryPage> Function(EvmNetwork, String, String?, int) query;
  bool disposed = false;
  @override
  Future<DiscoveryPage> discover(
    EvmNetwork n,
    String address, {
    String? cursor,
    int limit = 100,
  }) => query(n, address, cursor, limit);
  @override
  void dispose() {
    disposed = true;
  }
}

class CachedQuoteFixture extends TestQuoteService {
  @override
  Future<Map<QuoteAsset, PriceQuote>> getQuotes(
    Set<QuoteAsset> assets, {
    bool force = false,
  }) async {
    final quotes = await super.getQuotes(assets, force: force);
    final eth = quotes[QuoteAsset.eth];
    if (eth != null) {
      quotes[QuoteAsset.eth] = PriceQuote(
        asset: QuoteAsset.eth,
        state: QuoteState.stale,
        price: eth.price,
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
    }
    return quotes;
  }
}

Future<WalletVault> launch(
  WidgetTester tester,
  MapSecretStore store, {
  AssetDiscoveryService Function(IndexerConfig)? discover,
  QuoteService? quoteService,
  Size size = const Size(402, 874),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final vault = WalletVault(store: store);
  await vault.saveSelectedNetworks([
    ethereumMainnetNetwork,
    bnbSmartChainNetwork,
    tronMainnetNetwork,
    polygonMainnetNetwork,
  ]);
  await tester.pumpWidget(
    StoneWalletApp(
      vault: vault,
      quoteService: quoteService ?? TestQuoteService(),
      networkServiceBuilder: TokenRpc().service,
      discoveryServiceBuilder: discover,
    ),
  );
  await tester.pumpAndSettle();
  return vault;
}

String indexerRecord() => jsonEncode({
  'version': 1,
  'services': [
    IndexerConfig(
      provider: IndexerProvider.moralis,
      apiKey: 'synthetic',
      networkIds: {1},
    ).toJson(),
  ],
});
void main() {
  testWidgets(
    'compact overview shows four rows on first iPhone viewport and filters by real linked addresses and networks',
    (tester) async {
      await launch(tester, MapSecretStore({WalletVault.mnemonicKey: phrase}));
      expect(
        tester.getSize(find.byKey(const ValueKey('portfolio-summary'))).height,
        lessThanOrEqualTo(120),
      );
      expect(find.byType(PortfolioAssetRow), findsNWidgets(5));
      final bottom = tester.view.physicalSize.height;
      final visible = find
          .byType(PortfolioAssetRow)
          .evaluate()
          .where(
            (e) => tester.getRect(find.byWidget(e.widget)).bottom <= bottom,
          )
          .length;
      expect(visible, greaterThanOrEqualTo(4));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$3,620.45',
      );
      expect(assetPrefs(tester).value.display, AssetDisplay.simple);
      await assetTap(
        tester,
        find.byKey(const ValueKey('toggle-asset-display')),
      );
      expect(find.byKey(const ValueKey('group-value-usdt')), findsOneWidget);
      await assetTap(tester, find.byKey(const ValueKey('address-filter')));
      await assetTap(
        tester,
        find
            .byWidgetPredicate(
              (w) =>
                  w is DropdownMenuItem<AddressScope> &&
                  w.value == AddressScope.tron,
            )
            .last,
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$6.40',
      );
      expect(
        tester
            .widget<AssetsPage>(find.byType(AssetsPage))
            .addresses[AddressScope.tron],
        WalletAccount.fromMnemonic(phrase).tronAddress,
      );
      assetPrefs(
        tester,
      ).update(addressScope: AddressScope.all, networkFilter: 1);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$3,012.50',
      );
      await assetTap(tester, find.byKey(const ValueKey('asset-group-usdt')));
      expect(find.byType(PortfolioChainRow), findsOneWidget);
      expect(
        tester
            .widget<PortfolioChainRow>(find.byType(PortfolioChainRow))
            .holding
            .address,
        WalletAccount.fromMnemonic(phrase).checksumAddress,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'top count, expansion, hidden zero, full-list search, sorting and preferences share state',
    (tester) async {
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      await launch(tester, store);
      assetPrefs(tester).update(limit: 3);
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioAssetRow), findsNWidgets(3));
      final total = tester
          .widget<Text>(find.byKey(const ValueKey('portfolio-total')))
          .data;
      await assetTap(tester, find.byKey(const ValueKey('expand-assets')));
      expect(find.byType(PortfolioAssetRow), findsNWidgets(5));
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        total,
      );
      await assetTap(tester, find.byKey(const ValueKey('expand-assets')));
      await assetMenu(tester, MessageCode.portfolioSearch);
      await tester.enterText(find.byKey(const ValueKey('asset-search')), 'TRX');
      await tester.pumpAndSettle();
      expect(find.byType(PortfolioAssetRow), findsOneWidget);
      expect(
        tester
            .widget<PortfolioAssetRow>(find.byType(PortfolioAssetRow))
            .group
            .id,
        'trx',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        total,
      );
      await tester.enterText(find.byKey(const ValueKey('asset-search')), '');
      assetPrefs(tester).update(
        sort: AssetSort.stableFirst,
        display: AssetDisplay.detailed,
        view: AssetView.coin,
        selectedAssetId: 'usdt',
      );
      await tester.pumpAndSettle();
      await assetPrefs(tester).settled;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await launch(tester, store);
      final p = assetPrefs(tester).value;
      expect(p.limit, 3);
      expect(p.sort, AssetSort.stableFirst);
      expect(p.display, AssetDisplay.detailed);
      expect(p.view, AssetView.coin);
      expect(find.byKey(const ValueKey('coin-total-usdt')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'service guide configures tests and saves a key, discovery deduplicates RPC, supports watching and removal',
    (tester) async {
      final calls = <(IndexerProvider, String, int)>[];
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      final vault = await launch(
        tester,
        store,
        discover: (config) =>
            FixtureDiscovery((n, address, cursor, limit) async {
              calls.add((config.provider, address, limit));
              return DiscoveryPage([
                DiscoveredToken(builtinTokens.first, BigInt.from(999000000)),
                DiscoveredToken(extraToken, BigInt.from(900000000)),
              ]);
            }),
      );
      expect(calls, isEmpty);
      await assetMenu(tester, MessageCode.discoveryServices);
      expect(find.text('Moralis'), findsOneWidget);
      expect(find.text('Alchemy'), findsOneWidget);
      expect(find.text('TronGrid'), findsOneWidget);
      expect(find.text('官方文档'), findsNothing);
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-provider-moralis')),
      );
      expect(find.text('官方文档'), findsOneWidget);
      await assetTap(tester, find.byKey(const ValueKey('configure-moralis')));
      await tester.enterText(
        find.byKey(const ValueKey('indexer-api-key')),
        'synthetic',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('indexer-api-key')))
            .obscureText,
        true,
      );
      assetPrefs(tester).update(language: AppLanguage.en);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('indexer-api-key')))
            .controller!
            .text,
        'synthetic',
      );
      // Keep only Ethereum selected, so this fixture's chain identities are valid.
      for (final n in [bnbSmartChainNetwork, polygonMainnetNetwork]) {
        final check = find.widgetWithText(CheckboxListTile, n.name);
        await assetTap(tester, check);
      }
      await assetTap(tester, find.byKey(const ValueKey('test-indexer')));
      expect(
        find.text('Connected. Credentials and response are valid.'),
        findsOneWidget,
      );
      await assetTap(tester, find.byKey(const ValueKey('save-indexer')));
      await exitSettings(tester);
      expect(
        calls.every(
          (c) => c.$2 == WalletAccount.fromMnemonic(phrase).checksumAddress,
        ),
        true,
      );
      final page = tester.widget<AssetsPage>(find.byType(AssetsPage));
      final duplicate = page.positions
          .where((h) => h.token?.key == builtinTokens.first.key)
          .toList();
      expect(duplicate, hasLength(1));
      expect(duplicate.single.source, HoldingSource.rpc);
      expect(duplicate.single.units, BigInt.from(12500000));
      final found = page.positions.singleWhere(
        (h) => h.token?.key == extraToken.key,
      );
      expect(found.source, HoldingSource.indexer);
      expect(found.quoteAsset, isNull);
      await selectCoin(tester, found.assetId);
      await assetTap(
        tester,
        find.byKey(ValueKey('chain-holding-${found.key}')),
      );
      expect(find.text('Send'), findsNothing);
      await assetTap(tester, find.text('Watch this token'));
      expect(
        (await vault.loadTokens()).any((t) => t.key == extraToken.key),
        true,
      );
      await assetTap(tester, find.byTooltip('Close'));
      expect(
        tester
            .widget<AssetsPage>(find.byType(AssetsPage))
            .positions
            .singleWhere((h) => h.token?.key == extraToken.key)
            .source,
        HoldingSource.rpc,
      );
      await assetMenu(tester, MessageCode.discoveryServices);
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-provider-moralis')),
      );
      await assetTap(tester, find.text('Delete configuration'));
      expect(
        AppPreferences.fromRecord(
          store.values[WalletVault.appPreferencesKey],
        ).language,
        AppLanguage.en,
      );
      expect(
        jsonDecode(
          store.values[WalletVault.assetIndexerConfigsKey]!,
        )['services'],
        isEmpty,
      );
      expect((await vault.loadPortfolio()).groups, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'discovery loads at most 500 per chain initially and continues without losing partial-data flags',
    (tester) async {
      var calls = 0;
      final store = MapSecretStore({
        WalletVault.mnemonicKey: phrase,
        WalletVault.assetIndexerConfigsKey: indexerRecord(),
      });
      await launch(
        tester,
        store,
        discover: (config) =>
            FixtureDiscovery((n, address, cursor, limit) async {
              calls++;
              final page = cursor == null ? 0 : int.parse(cursor);
              return DiscoveryPage(
                List.generate(100, (i) {
                  final id = page * 100 + i + 1;
                  return DiscoveredToken(
                    TokenDefinition(
                      networkId: 1,
                      contract: '0x${id.toRadixString(16).padLeft(40, '0')}',
                      symbol: 'C$id',
                      decimals: 6,
                      name: 'Coin $id',
                    ),
                    BigInt.from(id),
                  );
                }),
                cursor: page < 5 ? '${page + 1}' : null,
                invalidCount: page == 0 ? 1 : 0,
              );
            }),
      );
      expect(calls, 5);
      var page = tester.widget<AssetsPage>(find.byType(AssetsPage));
      expect(
        page.positions.where((h) => h.source == HoldingSource.indexer),
        hasLength(500),
      );
      expect(page.discovery[1]!.incomplete, true);
      await assetTap(tester, find.text('继续加载资产'));
      expect(calls, 6);
      page = tester.widget<AssetsPage>(find.byType(AssetsPage));
      expect(
        page.positions.where((h) => h.source == HoldingSource.indexer),
        hasLength(600),
      );
      expect(page.discovery[1]!.cursor, isNull);
      expect(page.discovery[1]!.incomplete, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'late indexer responses cannot overwrite the next account and suspected spam is hidden by default',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final store = MapSecretStore({
        WalletVault.assetIndexerConfigsKey: indexerRecord(),
      });
      final vault = WalletVault(store: store);
      final first = await vault.addMnemonicWallet(phrase);
      await vault.addMnemonicWallet(phraseB);
      await vault.selectAccount(first.selected!.id);
      await vault.saveSelectedNetwork(ethereumMainnetNetwork);
      final gate = Completer<void>();
      final old = WalletAccount.fromMnemonic(phrase).checksumAddress;
      await tester.pumpWidget(
        StoneWalletApp(
          vault: vault,
          quoteService: TestQuoteService(),
          networkServiceBuilder: TokenRpc().service,
          discoveryServiceBuilder: (c) =>
              FixtureDiscovery((n, address, cursor, limit) async {
                if (address == old) await gate.future;
                return DiscoveryPage([
                  DiscoveredToken(
                    extraToken,
                    BigInt.from(address == old ? 1200000000 : 2500000000),
                  ),
                  DiscoveredToken(
                    TokenDefinition(
                      networkId: 1,
                      contract: '0x${'66' * 20}',
                      symbol: 'SPAM',
                      decimals: 6,
                      name: 'Spam',
                    ),
                    BigInt.from(999),
                    spam: true,
                  ),
                ]);
              }),
        ),
      );
      await tester.pumpAndSettle();
      await assetTap(tester, find.text('主钱包'));
      await assetTap(tester, find.text('钱包 2'));
      gate.complete();
      await tester.pumpAndSettle();
      final p = tester.widget<AssetsPage>(find.byType(AssetsPage));
      expect(
        p.positions.singleWhere((h) => h.token?.key == extraToken.key).units,
        BigInt.from(2500000000),
      );
      assetPrefs(tester).update(limit: 0);
      await tester.pumpAndSettle();
      expect(find.text('SPAM'), findsNothing);
      assetPrefs(tester).update(showSpam: true);
      await tester.pumpAndSettle();
      expect(find.text('SPAM'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'indexer outage preserves watched balances and the information sheet offers retry',
    (tester) async {
      var unavailable = true;
      final store = MapSecretStore({
        WalletVault.mnemonicKey: phrase,
        WalletVault.assetIndexerConfigsKey: indexerRecord(),
      });
      await launch(
        tester,
        store,
        discover: (c) => FixtureDiscovery((n, address, cursor, limit) async {
          if (unavailable) {
            throw const WalletInputException(MessageCode.discoveryUnauthorized);
          }
          return const DiscoveryPage([]);
        }),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$3,620.45',
      );
      expect(find.text('已估值合计'), findsOneWidget);
      assetPrefs(tester).update(addressScope: AddressScope.tron);
      await tester.pumpAndSettle();
      expect(find.text('参考资产估值'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$6.40',
      );
      assetPrefs(tester).update(addressScope: AddressScope.all);
      await tester.pumpAndSettle();

      await assetTap(tester, find.byKey(const ValueKey('discovery-status')));
      expect(find.textContaining('服务密钥无效或权限不足'), findsOneWidget);
      unavailable = false;
      await assetTap(tester, find.text('刷新余额与行情'));
      expect(find.text('参考资产估值'), findsOneWidget);
      expect(
        tester.widget<AssetsPage>(find.byType(AssetsPage)).discovery[1]!.error,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cached prices are marked and retain both the exact estimate and balance quantities',
    (tester) async {
      await launch(
        tester,
        MapSecretStore({WalletVault.mnemonicKey: phrase}),
        quoteService: CachedQuoteFixture(),
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('portfolio-total'))).data,
        '≈ \$3,620.45',
      );
      await assetTap(tester, find.byTooltip('行情已过期，使用近期缓存'));
      expect(find.text('行情已过期，使用近期缓存'), findsOneWidget);
      expect(find.textContaining('1 USDT≈1 USD'), findsOneWidget);
      await assetTap(tester, find.byTooltip('关闭'));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('group-amount-eth')))
            .data,
        '1',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
