import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'asset_discovery.dart';
import 'portfolio_assets.dart';
import 'quotes.dart';
import 'wallet_core.dart';

class WalletBalance {
  WalletBalance({
    required this.entry,
    required this.networks,
    required List<PortfolioHolding> holdings,
    required this.incompleteDiscovery,
    required this.tokenCatalogIncomplete,
    required Map<QuoteAsset, PriceQuote> quotes,
  }) : subtotal = sumValues(holdings, quotes),
       holdings = List.unmodifiable(
         holdings.where((h) => !h.known || h.units != BigInt.zero),
       ),
       queryFailed =
           incompleteDiscovery.isNotEmpty || holdings.any((h) => !h.known),
       unpriced = holdings.any(
         (h) => h.known && !h.network.isTestnet && h.value(quotes) == null,
       );

  final WalletEntry entry;
  final List<EvmNetwork> networks;
  final List<PortfolioHolding> holdings;
  final List<EvmNetwork> incompleteDiscovery;
  final ExactDecimal? subtotal;
  final bool queryFailed, unpriced, tokenCatalogIncomplete;

  bool get noNetworks => networks.isEmpty;
  bool get partial => queryFailed || unpriced || tokenCatalogIncomplete;
  ExactDecimal? get rankedValue {
    final value = subtotal;
    if (value == null || (value.units == BigInt.zero && partial)) return null;
    return value;
  }

  static int compare(WalletBalance a, WalletBalance b) {
    final av = a.rankedValue, bv = b.rankedValue;
    if (av == null || bv == null) {
      if (av != null) return -1;
      if (bv != null) return 1;
    } else {
      final amountOrder = bv.compareTo(av);
      if (amountOrder != 0) return amountOrder;
    }
    return a.entry.id.compareTo(b.entry.id);
  }
}

/// A read-only scan. The wallet book and the signing account stay independent.
class WalletBalanceScan extends ChangeNotifier {
  WalletBalanceScan({
    required this.vault,
    required this.quoteService,
    required this.makeRpc,
    required this.makeIndexer,
    this.batchDelay = const Duration(milliseconds: 250),
    this.persistResults = false,
  });

  final WalletVault vault;
  final QuoteService quoteService;
  final EvmNetworkService Function(EvmNetwork) makeRpc;
  final AssetDiscoveryService Function(IndexerConfig) makeIndexer;
  final Duration batchDelay;
  final bool persistResults;
  final _results = SplayTreeSet<WalletBalance>(WalletBalance.compare);
  int _checked = 0;
  int _generation = 0;
  final _rpc = <int, EvmNetworkService>{};
  final _indexers = <int, AssetDiscoveryService>{};
  Completer<void>? _resume;
  Timer? _update;
  bool _disposed = false;

  bool get paused => _resume != null;
  bool running = false;
  bool loadFailed = false;
  int total = 0, incompleteCount = 0;
  int get checked => _checked;
  DateTime? startedAt;
  Map<QuoteAsset, PriceQuote> quotes = const {};

  List<WalletBalance> page(int offset, int limit) =>
      _results.skip(offset).take(limit).toList();

  void togglePause() {
    if (!running || _disposed) return;
    final resume = _resume;
    if (resume == null) {
      _resume = Completer<void>();
    } else {
      _resume = null;
      resume.complete();
    }
    _publishNow();
  }

  Future<void> start({
    required int accountCount,
    required List<EvmNetwork> networks,
    required List<EvmNetwork> enabled,
    required List<TokenDefinition> watchedTokens,
    required List<IndexerConfig> configs,
    bool tokenCatalogIncomplete = false,
  }) async {
    if (running || _disposed) return;
    total = accountCount;
    incompleteCount = 0;
    running = true;
    loadFailed = false;
    startedAt = DateTime.now();
    quotes = const {};
    _results.clear();
    _checked = 0;
    final generation = ++_generation;
    _publishNow();

    final byId = {for (final network in networks) network.id: network};
    final enabledNetworks = List<EvmNetwork>.unmodifiable(enabled);
    final indexerByChain = <int, IndexerConfig>{
      for (final config in configs)
        if (config.enabled)
          for (final id in config.networkIds) id: config,
    };
    final tokens = <int, List<TokenDefinition>>{};
    final tokenByKey = {
      for (final token in [...watchedTokens, ...builtinTokens])
        token.key: token,
    };
    for (final token in tokenByKey.values) {
      (tokens[token.networkId] ??= []).add(token);
    }

    final entries = StreamIterator(vault.walletBalanceEntries());
    try {
      try {
        // Use a single quote snapshot so the ranking stays comparable.
        final loaded = await quoteService.getQuotes(
          QuoteAsset.values.where((asset) => asset != QuoteAsset.usdt).toSet(),
        );
        if (!_disposed) quotes = Map.unmodifiable(loaded);
      } catch (_) {
        // Known quantities, including USDT, still contribute.
      }

      var exhausted = false;
      while (!_disposed && generation == _generation && !exhausted) {
        await _resume?.future;
        if (_disposed || generation != _generation) break;
        final batch = <WalletEntry>[];
        while (batch.length < 3 && !_disposed) {
          if (!await entries.moveNext()) {
            exhausted = true;
            break;
          }
          batch.add(entries.current);
        }
        await _resume?.future;
        if (_disposed || generation != _generation) break;
        await Future.wait(
          batch.map((entry) async {
            final preferred = byId[entry.preferredNetworkId];
            final scope = preferred != null
                ? [preferred]
                : entry.preferredNetworkId != null
                ? const <EvmNetwork>[]
                : enabledNetworks;
            final balance = await _readWallet(
              entry,
              scope,
              tokens,
              indexerByChain,
              tokenCatalogIncomplete: tokenCatalogIncomplete,
            );
            if (_disposed || generation != _generation) return;
            if (persistResults) {
              final records = [
                for (final chain in scope) _cacheRecord(balance, chain),
              ];
              if (!await vault.saveManagementBalance(entry.id, records)) return;
              if (_disposed || generation != _generation) return;
            } else if (!_results.add(balance)) {
              return;
            }
            _checked++;
            if (balance.partial || balance.noNetworks) incompleteCount++;
            _publishLater();
          }),
        );
        if (!exhausted && !_disposed && checked < total) {
          await Future<void>.delayed(batchDelay);
        }
      }
      if (!_disposed) total = checked;
    } catch (_) {
      loadFailed = true;
    } finally {
      final cleanup = _disposeClients();
      running = false;
      _resume?.complete();
      _resume = null;
      if (!_disposed) _publishNow();
      await entries.cancel();
      await cleanup;
    }
  }

  Map<String, Object?> _cacheRecord(WalletBalance balance, EvmNetwork chain) {
    final holdings = balance.holdings
        .where((h) => h.network.id == chain.id)
        .toList();
    final failed =
        holdings.any((h) => !h.known) ||
        balance.incompleteDiscovery.any((n) => n.id == chain.id);
    final unpriced = holdings.any(
      (h) => h.known && !chain.isTestnet && h.value(quotes) == null,
    );
    final value =
        sumValues(holdings, quotes) ??
        (!failed && !chain.isTestnet && holdings.isEmpty
            ? ExactDecimal.zero
            : null);
    return {
      'chain': chain.id,
      'amount': value?.fixed(72, round: false).replaceAll('.', ''),
      'failed': failed ? 1 : 0,
      'incomplete':
          (failed ? BalanceCoverage.failed : 0) |
          (unpriced ? BalanceCoverage.missingPrices : 0) |
          (balance.tokenCatalogIncomplete ? BalanceCoverage.partial : 0),
      'payload': jsonEncode([
        for (final h in holdings)
          {
            'symbol': h.symbol,
            'quantity': h.quantityText,
            'contract': h.token?.contract,
            'ready': h.known,
            'value': h.value(quotes)?.fixed(2),
          },
      ]),
    };
  }

  /// Stop the current generation before a destructive wallet-book change.
  void invalidate() {
    _generation++;
    _resume?.complete();
    _resume = null;
    _results.clear();
    _checked = 0;
    if (!_disposed) _publishNow();
  }

  Future<WalletBalance> _readWallet(
    WalletEntry entry,
    List<EvmNetwork> scope,
    Map<int, List<TokenDefinition>> tokens,
    Map<int, IndexerConfig> configs, {
    required bool tokenCatalogIncomplete,
  }) async {
    final holdings = <PortfolioHolding>[];
    final incompleteDiscovery = <EvmNetwork>[];
    for (final network in scope) {
      if (_disposed) break;
      final address = entry.addressFor(network);
      final watched = tokens[network.id] ?? const <TokenDefinition>[];
      for (final token in <TokenDefinition?>[null, ...watched]) {
        if (_disposed) break;
        BigInt? units;
        try {
          final service = _rpc.putIfAbsent(network.id, () => makeRpc(network));
          final raw = token == null
              ? (await service.getNativeBalanceForAddress(address)).getInWei
              : await service.getTokenBalanceForAddress(address, token);
          if (raw >= BigInt.zero) units = raw;
        } catch (_) {
          // Keep per-asset failures in the result and continue the scan.
        }
        holdings.add(
          PortfolioHolding(
            network: network,
            address: address,
            token: token,
            state: units == null ? TokenState.failed : TokenState.ready,
            units: units,
          ),
        );
      }
      final config = configs[network.id];
      if (config != null && !_disposed) {
        final complete = await _discover(
          network,
          address,
          config,
          watched,
          holdings,
        );
        if (!complete) incompleteDiscovery.add(network);
      }
    }
    return WalletBalance(
      entry: entry,
      networks: scope,
      holdings: holdings,
      incompleteDiscovery: incompleteDiscovery,
      tokenCatalogIncomplete: tokenCatalogIncomplete && scope.isNotEmpty,
      quotes: quotes,
    );
  }

  Future<bool> _discover(
    EvmNetwork network,
    String address,
    IndexerConfig config,
    List<TokenDefinition> watched,
    List<PortfolioHolding> holdings,
  ) async {
    final tokens = <String, DiscoveredToken>{};
    final cursors = <String>{};
    String? cursor;
    var complete = true;
    try {
      final service = _indexers.putIfAbsent(
        network.id,
        () => makeIndexer(config),
      );
      for (var i = 0; i < 5 && !_disposed; i++) {
        final page = await service.discover(network, address, cursor: cursor);
        if (mergeDiscoveredTokens(network, page, tokens)) complete = false;
        cursor = page.cursor;
        if (cursor == null || !cursors.add(cursor)) break;
      }
    } catch (_) {
      complete = false;
    }
    final configured = watched.map((token) => token.key).toSet();
    for (final t in tokens.values) {
      if (t.spam || configured.contains(t.token.key)) continue;
      holdings.add(
        PortfolioHolding(
          network: network,
          address: address,
          state: TokenState.ready,
          units: t.units,
          token: t.token,
          source: HoldingSource.indexer,
        ),
      );
    }
    return complete && cursor == null;
  }

  void _publishLater() {
    if (_disposed || _update != null) return;
    _update = Timer(const Duration(milliseconds: 200), _publishNow);
  }

  void _publishNow() {
    _update?.cancel();
    _update = null;
    notifyListeners();
  }

  Future<void> _disposeClients() async {
    final services = _rpc.values.toList();
    _rpc.clear();
    for (final indexer in _indexers.values) {
      indexer.dispose();
    }
    _indexers.clear();
    await Future.wait(services.map((service) => service.dispose()));
  }

  @override
  void dispose() {
    _disposed = true;
    _update?.cancel();
    _resume?.complete();
    _resume = null;
    unawaited(_disposeClients());
    super.dispose();
  }
}
