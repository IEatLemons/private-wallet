import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Exact decimal arithmetic. Chain units and quote strings never pass through double.
class ExactDecimal implements Comparable<ExactDecimal> {
  const ExactDecimal(this.units, this.scale);
  static final zero = ExactDecimal(BigInt.zero, 0);
  static final one = ExactDecimal(BigInt.one, 0);
  final BigInt units;
  final int scale;
  factory ExactDecimal.parse(String value) {
    if (!RegExp(r'^\d{1,90}(\.\d{1,36})?$').hasMatch(value)) {
      throw const FormatException('Invalid decimal');
    }
    final parts = value.split('.');
    return ExactDecimal(
      BigInt.parse(parts.join()),
      parts.length == 2 ? parts[1].length : 0,
    );
  }
  ExactDecimal operator +(ExactDecimal other) {
    final digits = scale > other.scale ? scale : other.scale;
    return ExactDecimal(
      units * BigInt.from(10).pow(digits - scale) +
          other.units * BigInt.from(10).pow(digits - other.scale),
      digits,
    );
  }

  ExactDecimal operator *(ExactDecimal other) =>
      ExactDecimal(units * other.units, scale + other.scale);
  @override
  int compareTo(ExactDecimal other) {
    final digits = scale > other.scale ? scale : other.scale;
    return (units * BigInt.from(10).pow(digits - scale)).compareTo(
      other.units * BigInt.from(10).pow(digits - other.scale),
    );
  }

  String fixed(int digits, {bool trim = false, bool round = true}) {
    var value = units;
    if (scale > digits) {
      final divisor = BigInt.from(10).pow(scale - digits);
      value = round
          ? (value + divisor ~/ BigInt.two) ~/ divisor
          : value ~/ divisor;
    } else {
      value *= BigInt.from(10).pow(digits - scale);
    }
    var text = value.toString().padLeft(digits + 1, '0');
    if (digits > 0) {
      text =
          '${text.substring(0, text.length - digits)}.${text.substring(text.length - digits)}';
      if (trim) {
        text = text
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
      }
    }
    return text;
  }
}

enum QuoteAsset { eth, bnb, pol, trx, usdt, usdc }

enum QuoteState { fresh, stale, unavailable }

class PriceQuote {
  const PriceQuote({
    required this.asset,
    required this.state,
    this.price,
    this.fetchedAt,
  });
  final QuoteAsset asset;
  final QuoteState state;
  final ExactDecimal? price;
  final DateTime? fetchedAt;
  bool get available => price != null && state != QuoteState.unavailable;
}

abstract class QuoteService {
  Future<Map<QuoteAsset, PriceQuote>> getQuotes(
    Set<QuoteAsset> assets, {
    bool force = false,
  });
  void dispose() {}
}

class BinanceQuoteService extends QuoteService {
  BinanceQuoteService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;
  final http.Client _client;
  final DateTime Function() _clock;
  final Map<QuoteAsset, PriceQuote> _cache = {};
  final Map<QuoteAsset, Future<PriceQuote>> _pending = {};
  bool _disposed = false;
  static const pairs = {
    QuoteAsset.eth: 'ETHUSDT',
    QuoteAsset.bnb: 'BNBUSDT',
    QuoteAsset.pol: 'POLUSDT',
    QuoteAsset.trx: 'TRXUSDT',
    QuoteAsset.usdc: 'USDCUSDT',
  };
  @override
  Future<Map<QuoteAsset, PriceQuote>> getQuotes(
    Set<QuoteAsset> assets, {
    bool force = false,
  }) async {
    final entries = await Future.wait(
      assets.map((asset) async => MapEntry(asset, await _get(asset, force))),
    );
    return Map.fromEntries(entries);
  }

  Future<PriceQuote> _get(QuoteAsset asset, bool force) async {
    if (asset == QuoteAsset.usdt) {
      return PriceQuote(
        asset: asset,
        state: QuoteState.fresh,
        price: ExactDecimal.one,
      );
    }
    final cached = _cache[asset];
    if (!force &&
        cached != null &&
        _clock().difference(cached.fetchedAt!) < const Duration(seconds: 60)) {
      return cached;
    }
    if (_pending[asset] case final Future<PriceQuote> pending) return pending;
    final future = _request(asset, cached);
    _pending[asset] = future;
    try {
      return await future;
    } finally {
      _pending.remove(asset);
    }
  }

  Future<PriceQuote> _request(QuoteAsset asset, PriceQuote? cached) async {
    try {
      if (_disposed) throw StateError('Disposed');
      // Public market data only: no address, balance, credential or account identifier.
      final uri = Uri.https('data-api.binance.vision', '/api/v3/ticker/price', {
        'symbol': pairs[asset]!,
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw const FormatException('Quote unavailable');
      }
      final json = jsonDecode(response.body) as Map;
      if (json['symbol'] != pairs[asset]) {
        throw const FormatException('Wrong market');
      }
      final price = ExactDecimal.parse(json['price'] as String);
      if (price.units <= BigInt.zero) {
        throw const FormatException('Invalid price');
      }
      final quote = PriceQuote(
        asset: asset,
        state: QuoteState.fresh,
        price: price,
        fetchedAt: _clock(),
      );
      if (!_disposed) _cache[asset] = quote;
      return quote;
    } catch (_) {
      if (cached != null &&
          _clock().difference(cached.fetchedAt!) <=
              const Duration(minutes: 5)) {
        return PriceQuote(
          asset: asset,
          state: QuoteState.stale,
          price: cached.price,
          fetchedAt: cached.fetchedAt,
        );
      }
      return PriceQuote(asset: asset, state: QuoteState.unavailable);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
  }
}
