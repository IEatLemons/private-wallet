import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/quotes.dart';
import 'package:stone_wallet/portfolio_assets.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';

class TestQuoteService extends QuoteService {
  static const prices = {
    QuoteAsset.eth: '3000',
    QuoteAsset.bnb: '600',
    QuoteAsset.pol: '0.3',
    QuoteAsset.trx: '0.15',
    QuoteAsset.usdt: '1',
    QuoteAsset.usdc: '0.9998',
  };
  @override
  Future<Map<QuoteAsset, PriceQuote>> getQuotes(
    Set<QuoteAsset> assets, {
    bool force = false,
  }) async => {
    for (final a in assets)
      a: PriceQuote(
        asset: a,
        state: QuoteState.fresh,
        price: ExactDecimal.parse(prices[a]!),
        fetchedAt: DateTime.now(),
      ),
  };
}

PreferencesController assetPrefs(WidgetTester tester) => AppSettingsScope.of(
  tester.element(find.byType(WalletShell, skipOffstage: false)),
);
Future<void> assetTap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> assetMenu(WidgetTester tester, MessageCode code) async {
  final text = tr(
    tester.element(find.byType(WalletShell, skipOffstage: false)),
    code,
  );
  await assetTap(tester, find.byKey(const ValueKey('asset-menu')));
  await assetTap(tester, find.widgetWithText(PopupMenuItem<String>, text).last);
}

Future<void> allOtherCoins(WidgetTester tester) async {
  assetPrefs(tester).update(
    view: AssetView.overview,
    filter: AssetFilter.tokens,
    hideZero: false,
    limit: 0,
  );
  await tester.pumpAndSettle();
}

PortfolioHolding nativePosition(WidgetTester tester, int id) => tester
    .widget<AssetsPage>(find.byType(AssetsPage))
    .positions
    .singleWhere((h) => h.token == null && h.network.id == id);
Future<void> selectCoin(WidgetTester tester, String id) async {
  final p = assetPrefs(tester);
  p.update(view: AssetView.coin, selectedAssetId: id);
  await tester.pumpAndSettle();
}

Future<void> nativeDetails(WidgetTester tester, int id) async {
  final h = nativePosition(tester, id);
  await selectCoin(tester, h.assetId);
  await assetTap(tester, find.byKey(ValueKey('chain-holding-${h.key}')));
}

Future<void> settingsEntryTap(WidgetTester tester, String id) =>
    assetTap(tester, find.byKey(ValueKey('settings-entry-$id')));

Future<void> settingsNetwork(WidgetTester tester, int id) async {
  await settingsEntryTap(tester, 'networks');
  await assetTap(tester, find.byKey(ValueKey('settings-network-$id')));
}

Future<void> exitSettings(WidgetTester tester) async {
  for (
    var i = 0;
    i < 10 && find.byKey(const ValueKey('settings-hub')).evaluate().isNotEmpty;
    i++
  ) {
    await assetTap(tester, find.byType(BackButton).last);
  }
}
