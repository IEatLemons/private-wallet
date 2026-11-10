import 'wallet_core.dart';
import 'quotes.dart';
import 'preferences.dart';

enum HoldingSource { rpc, indexer }

/// A chain/address-specific holding. Identity is never inferred from a ticker.
class PortfolioHolding {
  const PortfolioHolding({
    required this.network,
    required this.address,
    required this.state,
    this.units,
    this.token,
    this.error,
    this.source = HoldingSource.rpc,
    this.spam = false,
  });
  final EvmNetwork network;
  final String address;
  final TokenState state;
  final BigInt? units;
  final TokenDefinition? token;
  final WalletMessage? error;
  final HoldingSource source;
  final bool spam;
  bool get known => state == TokenState.ready && units != null;
  String get quantityText {
    if (!known) return '—';
    final value = formatNativeAmount(units!, decimals);
    return units! > BigInt.zero && value == '0' ? '< 0.000001' : value;
  }

  String get amount => '$quantityText $symbol';
  WalletMessage get status => switch (state) {
    TokenState.disabled => const WalletMessage(MessageCode.msgNetworkDisabled),
    TokenState.pending => const WalletMessage(MessageCode.msgQueryingMore),
    TokenState.ready => const WalletMessage(MessageCode.msgSynced),
    TokenState.failed => const WalletMessage(MessageCode.msgQueryFailed),
  };
  String get symbol => token?.symbol ?? network.nativeSymbol;
  String get name => token?.name ?? network.name;
  int get decimals => token?.decimals ?? network.nativeDecimals;
  String get key =>
      '${network.id}:${network.isTron ? address : address.toLowerCase()}:${token?.key ?? 'native'}';
  QuoteAsset? get quoteAsset {
    if (network.isTestnet) return null;
    if (token case final TokenDefinition t) {
      return switch (t.trustedFamily) {
        'USDT' => QuoteAsset.usdt,
        'USDC' => QuoteAsset.usdc,
        _ => null,
      };
    }
    return switch (network.id) {
      1 => QuoteAsset.eth,
      56 => QuoteAsset.bnb,
      137 => QuoteAsset.pol,
      728126428 => QuoteAsset.trx,
      _ => null,
    };
  }

  bool get stablecoin => token?.trustedFamily != null;
  String get assetId => network.isTestnet
      ? 'test:${network.id}:${token?.key ?? 'native'}'
      : quoteAsset?.name ??
            (token == null ? 'native:${network.id}' : 'token:${token!.key}');
  ExactDecimal? value(Map<QuoteAsset, PriceQuote> quotes) {
    if (!known || network.isTestnet) return null;
    if (units == BigInt.zero) return ExactDecimal.zero;
    final price = quoteAsset == QuoteAsset.usdt
        ? ExactDecimal.one
        : quotes[quoteAsset]?.price;
    if (price == null || quotes[quoteAsset]?.state == QuoteState.unavailable) {
      return null;
    }
    return ExactDecimal(units!, decimals) * price;
  }

  bool stale(Map<QuoteAsset, PriceQuote> quotes) =>
      known &&
      units != BigInt.zero &&
      quotes[quoteAsset]?.state == QuoteState.stale;
}

class PortfolioAssetGroup {
  PortfolioAssetGroup(this.id, this.holdings);
  final String id;
  final List<PortfolioHolding> holdings;
  String get symbol => switch (id) {
    'usdt' => 'USDT',
    'usdc' => 'USDC',
    _ => holdings.first.symbol,
  };
  bool get stablecoin => holdings.first.stablecoin;
  bool get known => holdings.any((h) => h.known);
  bool get completeQuantity => holdings.every((h) => h.known);
  bool get zero =>
      completeQuantity && holdings.every((h) => h.units == BigInt.zero);
  ExactDecimal get quantity => holdings
      .where((h) => h.known)
      .fold(
        ExactDecimal.zero,
        (sum, h) => sum + ExactDecimal(h.units!, h.decimals),
      );
  String get amount {
    if (!known) return '—';
    final text = quantity.fixed(6, trim: true, round: false);
    return quantity.units > BigInt.zero && text == '0' ? '< 0.000001' : text;
  }

  ExactDecimal? value(Map<QuoteAsset, PriceQuote> quotes) =>
      sumValues(holdings, quotes);
  bool valued(Map<QuoteAsset, PriceQuote> quotes) =>
      holdings
          .where((h) => !h.network.isTestnet)
          .every((h) => h.value(quotes) != null) &&
      holdings.any((h) => !h.network.isTestnet);
}

ExactDecimal? sumValues(
  Iterable<PortfolioHolding> holdings,
  Map<QuoteAsset, PriceQuote> quotes,
) {
  ExactDecimal? sum;
  for (final h in holdings) {
    final v = h.value(quotes);
    if (v != null) sum = (sum ?? ExactDecimal.zero) + v;
  }
  return sum;
}

List<PortfolioAssetGroup> groupPortfolio(
  Iterable<PortfolioHolding> holdings,
  Map<QuoteAsset, PriceQuote> quotes,
  AssetSort sort,
) {
  final map = <String, List<PortfolioHolding>>{};
  for (final h in holdings) {
    (map[h.assetId] ??= []).add(h);
  }
  final groups = map.entries
      .map((e) => PortfolioAssetGroup(e.key, e.value))
      .toList();
  groups.sort((a, b) {
    if (sort == AssetSort.stableFirst && a.stablecoin != b.stablecoin) {
      return a.stablecoin ? -1 : 1;
    }
    if (sort != AssetSort.name) {
      final av = a.value(quotes), bv = b.value(quotes);
      if (av == null && bv != null) return 1;
      if (av != null && bv == null) return -1;
      if (av != null && bv != null) {
        final c = bv.compareTo(av);
        if (c != 0) return c;
      }
    }
    final name = a.symbol.toLowerCase().compareTo(b.symbol.toLowerCase());
    return name != 0 ? name : a.id.compareTo(b.id);
  });
  return groups;
}
