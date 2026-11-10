import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/quotes.dart';
import 'package:stone_wallet/portfolio_assets.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  test('exact decimals sum before rounding and never lose chain precision', () {
    final big = ExactDecimal.parse(
      '123456789012345678901234.123456789012345678',
    );
    expect(
      (big * ExactDecimal.parse('1.00000001')).fixed(18),
      '123456790246913569024690.912469130246913568',
    );
    expect(
      (ExactDecimal.parse('0.0049') + ExactDecimal.parse('0.0049')).fixed(2),
      '0.01',
    );
    expect(ExactDecimal.parse('0.999').fixed(2), '1.00');
    expect(
      ExactDecimal.parse('0.000000000000000001').fixed(18, trim: true),
      '0.000000000000000001',
    );
    for (final value in ['-1', 'NaN', '1e18', '.1', '1.']) {
      expect(() => ExactDecimal.parse(value), throwsFormatException);
    }
  });
  test(
    'USDT aggregation normalizes decimals, separates spoofed symbols and excludes testnet value',
    () {
      PortfolioHolding h(TokenDefinition token, BigInt units) =>
          PortfolioHolding(
            network: supportedNetworks.firstWhere(
              (n) => n.id == token.networkId,
            ),
            address: 'fixture',
            state: TokenState.ready,
            units: units,
            token: token,
          );
      final positions = [
        h(builtinTokens[0], BigInt.from(12500000)),
        h(builtinTokens[2], BigInt.parse('1250000000000000000')),
        h(
          TokenDefinition(
            networkId: 1,
            contract: '0x${'11' * 20}',
            symbol: 'USDT',
            decimals: 6,
            name: 'Fake',
          ),
          BigInt.from(999999999),
        ),
        PortfolioHolding(
          network: ethereumSepoliaNetwork,
          address: 'fixture',
          state: TokenState.ready,
          units: BigInt.from(10).pow(18),
        ),
      ];
      final groups = groupPortfolio(positions, {}, AssetSort.value);
      final usdt = groups.singleWhere((g) => g.id == 'usdt');
      expect(usdt.amount, '13.75');
      expect(usdt.value({})!.fixed(2), '13.75');
      expect(groups, hasLength(3));
      expect(positions[2].quoteAsset, isNull);
      expect(positions.last.value({}), isNull);
      expect(sumValues(positions, {})!.fixed(2), '13.75');
    },
  );
  test(
    'failed or pending holdings are not zero; valued subtotal remains partial',
    () {
      final pending = PortfolioHolding(
        network: ethereumMainnetNetwork,
        address: 'a',
        state: TokenState.failed,
      );
      final zero = PortfolioHolding(
        network: bnbSmartChainNetwork,
        address: 'a',
        state: TokenState.ready,
        units: BigInt.zero,
      );
      final groups = groupPortfolio([pending, zero], {}, AssetSort.value);
      expect(groups.singleWhere((g) => g.id == 'eth').zero, false);
      expect(groups.singleWhere((g) => g.id == 'bnb').zero, true);
      expect(pending.value({}), isNull);
      expect(zero.value({})!.fixed(2), '0.00');
      expect(groupPortfolio([pending], {}, AssetSort.value).single.amount, '—');
    },
  );
  test(
    'preferences restore new view settings and migrate legacy family without changing language',
    () {
      final old = AppPreferences.fromRecord(
        '{"version":1,"language":"zhHant","category":"tokens","family":"USDC"}',
      );
      expect(old.view, AssetView.overview);
      expect(old.selectedAssetId, 'usdc');
      expect(old.language, AppLanguage.zhHant);
      final changed = old.copyWith(
        display: AssetDisplay.detailed,
        limit: 10,
        sort: AssetSort.stableFirst,
        addressScope: AddressScope.tron,
        networkFilter: 728126428,
        filter: AssetFilter.stablecoins,
        hideZero: false,
        showSpam: true,
      );
      expect(
        AppPreferences.fromRecord(jsonEncode(changed.toJson())).toJson(),
        changed.toJson(),
      );
      final invalid = AppPreferences.fromRecord(
        '{"language":"en","view":"wrong","limit":99,"hideZero":"bad","networkFilter":-1}',
      );
      expect(invalid.language, AppLanguage.en);
      expect(invalid.limit, 5);
      expect(invalid.hideZero, true);
      expect(invalid.networkFilter, 0);
    },
  );
  test(
    'quote cache has 60-second TTL, 5-minute stale bound, and sends only market symbols',
    () async {
      var now = DateTime(2026, 11, 10);
      var fail = false, calls = 0;
      final service = BinanceQuoteService(
        clock: () => now,
        client: MockClient((r) async {
          calls++;
          expect(r.url.host, 'data-api.binance.vision');
          expect(r.url.queryParameters, {'symbol': 'ETHUSDT'});
          return fail
              ? http.Response('limited', 429)
              : http.Response(
                  jsonEncode({'symbol': 'ETHUSDT', 'price': '3123.12345678'}),
                  200,
                );
        }),
      );
      addTearDown(service.dispose);
      final first = await service.getQuotes({QuoteAsset.eth, QuoteAsset.usdt});
      expect(first[QuoteAsset.usdt]!.price!.fixed(2), '1.00');
      now = now.add(const Duration(seconds: 59));
      await service.getQuotes({QuoteAsset.eth});
      expect(calls, 1);
      fail = true;
      now = now.add(const Duration(seconds: 2));
      final stale = (await service.getQuotes({
        QuoteAsset.eth,
      }))[QuoteAsset.eth]!;
      expect(stale.state, QuoteState.stale);
      expect(stale.price!.fixed(8), '3123.12345678');
      now = now.add(const Duration(minutes: 5));
      expect(
        (await service.getQuotes({QuoteAsset.eth}))[QuoteAsset.eth]!.state,
        QuoteState.unavailable,
      );
    },
  );
  test(
    'in-flight quotes coalesce and incorrect markets or malformed prices are rejected',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final service = BinanceQuoteService(
        client: MockClient((r) async {
          calls++;
          await gate.future;
          return http.Response('{"symbol":"BNBUSDT","price":"1"}', 200);
        }),
      );
      addTearDown(service.dispose);
      final a = service.getQuotes({QuoteAsset.eth}),
          b = service.getQuotes({QuoteAsset.eth});
      gate.complete();
      expect((await a)[QuoteAsset.eth]!.available, false);
      await b;
      expect(calls, 1);
    },
  );
}
