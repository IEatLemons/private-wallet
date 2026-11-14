part of '../main.dart';

extension _WalletAssetData on _WalletShellState {
  Map<QuoteAsset, PriceQuote> get effectiveQuotes {
    final now = DateTime.now();
    return quotes.map((asset, q) {
      final age = q.fetchedAt == null
          ? Duration.zero
          : now.difference(q.fetchedAt!);
      return MapEntry(
        asset,
        age > const Duration(minutes: 5)
            ? PriceQuote(asset: asset, state: QuoteState.unavailable)
            : age > const Duration(seconds: 60) && q.available
            ? PriceQuote(
                asset: asset,
                state: QuoteState.stale,
                price: q.price,
                fetchedAt: q.fetchedAt,
              )
            : q,
      );
    });
  }

  List<PortfolioHolding> get portfolioPositions {
    final owner = account;
    if (owner == null) return [];
    final enabled = enabledNetworks.map((n) => n.id).toSet();
    final result = <PortfolioHolding>[
      for (final n in enabledNetworks)
        PortfolioHolding(
          network: n,
          address: owner.addressFor(n),
          state: pendingNetworkIds.contains(n.id)
              ? TokenState.pending
              : networkErrors.containsKey(n.id)
              ? TokenState.failed
              : balancesByNetwork[n.id] == null
              ? TokenState.pending
              : TokenState.ready,
          units: balancesByNetwork[n.id],
          error: networkErrors[n.id],
        ),
      for (final h in tokenHoldings)
        if (enabled.contains(h.network.id))
          PortfolioHolding(
            network: h.network,
            address: owner.addressFor(h.network),
            state: h.state,
            units: h.units,
            token: h.token,
            error: h.error,
          ),
    ];
    final keys = result.map((h) => h.key).toSet();
    for (final entry in discoverySnapshots.entries) {
      final network = _networkForId(entry.key);
      if (network == null || !enabled.contains(network.id)) continue;
      for (final t in entry.value.tokens) {
        final holding = PortfolioHolding(
          network: network,
          address: owner.addressFor(network),
          state: entry.value.pending ? TokenState.pending : TokenState.ready,
          units: t.units,
          token: t.token,
          source: HoldingSource.indexer,
          spam: t.spam,
        );
        if (keys.add(holding.key)) result.add(holding);
      }
    }
    return result;
  }

  Future<void> refreshQuotes({bool force = false}) async {
    final owner = account;
    if (owner == null || !mounted) return;
    final request = ++quoteRequest;
    final needed = portfolioPositions
        .where((h) => h.known && h.units != BigInt.zero)
        .map((h) => h.quoteAsset)
        .whereType<QuoteAsset>()
        .toSet();
    if (needed.isEmpty) {
      if (quoteLoading) _updateView(() => quoteLoading = false);
      return;
    }
    _updateView(() => quoteLoading = true);
    try {
      final loaded = await quoteService.getQuotes(needed, force: force);
      if (mounted && request == quoteRequest && owner == account) {
        _updateView(() => quotes.addAll(loaded));
      }
    } catch (_) {
      // A quote outage must never block balances or the signer.
    } finally {
      if (mounted && request == quoteRequest && owner == account) {
        _updateView(() => quoteLoading = false);
      }
    }
  }

  Future<void> refreshAllAssets() async {
    await _refreshBalance();
    if (mounted) await refreshQuotes(force: true);
  }

  void clearDiscovery() {
    discoveryRequest++;
    for (final s in discoveryClients.values) {
      s.dispose();
    }
    discoveryClients.clear();
    discoverySnapshots.clear();
    discoveryCursors.clear();
  }

  void onIndexerSettingsChanged() {
    if (!mounted) return;
    final next = jsonEncode(
      indexerSettings.configs.map((c) => c.toJson()).toList(),
    );
    if (next != indexerSignature) {
      indexerSignature = next;
      clearDiscovery();
      if (account != null) unawaited(refreshDiscovery());
    }
    _updateView(() {});
  }

  AssetDiscoveryService makeDiscoveryService(IndexerConfig config) =>
      widget.discoveryServiceBuilder?.call(config) ??
      HttpAssetDiscoveryService(config);
  Future<void> refreshDiscovery() async {
    clearDiscovery();
    final owner = account;
    if (!mounted || owner == null) return;
    final generation = discoveryRequest;
    await Future.wait(
      enabledNetworks
          .where((n) => indexerSettings.forNetwork(n.id) != null)
          .map((n) => loadDiscoveryNetwork(n, owner, generation)),
    );
    if (mounted && owner == account && generation == discoveryRequest) {
      unawaited(refreshQuotes());
    }
  }

  Future<void> continueDiscovery() async {
    final owner = account;
    if (owner == null) return;
    final generation = discoveryRequest;
    await Future.wait(
      enabledNetworks
          .where(
            (n) =>
                discoverySnapshots[n.id]?.cursor != null &&
                discoverySnapshots[n.id]?.pending != true,
          )
          .map((n) => loadDiscoveryNetwork(n, owner, generation, more: true)),
    );
    if (mounted && owner == account && generation == discoveryRequest) {
      unawaited(refreshQuotes());
    }
  }

  Future<void> loadDiscoveryNetwork(
    EvmNetwork n,
    WalletAccount owner,
    int generation, {
    bool more = false,
  }) async {
    final config = indexerSettings.forNetwork(n.id);
    if (config == null) return;
    final service = discoveryClients.putIfAbsent(
      n.id,
      () => makeDiscoveryService(config),
    );
    final previous = more ? discoverySnapshots[n.id] : null;
    final tokens = <String, DiscoveredToken>{
      for (final t in previous?.tokens ?? <DiscoveredToken>[]) t.token.key: t,
    };
    var cursor = previous?.cursor;
    var invalid = previous?.invalidData ?? false;
    bool current() =>
        mounted && generation == discoveryRequest && owner == account;
    void publish({required bool pending, WalletMessage? error}) {
      if (current()) {
        _updateView(
          () => discoverySnapshots[n.id] = DiscoverySnapshot(
            tokens: List.unmodifiable(tokens.values),
            cursor: cursor,
            pending: pending,
            invalidData: invalid,
            incomplete: invalid || cursor != null || error != null,
            error: error,
          ),
        );
      }
    }

    publish(pending: true);
    try {
      for (var page = 0; page < 5; page++) {
        final data = await service.discover(
          n,
          owner.addressFor(n),
          cursor: cursor,
          limit: 100,
        );
        if (!current()) return;
        invalid = mergeDiscoveredTokens(n, data, tokens) || invalid;
        cursor = data.cursor;
        if (cursor != null &&
            !(discoveryCursors[n.id] ??= <String>{}).add(cursor)) {
          throw const WalletInputException(
            MessageCode.discoveryResponseInvalid,
          );
        }
        publish(pending: cursor != null && page < 4);
        if (cursor == null) break;
      }
      publish(pending: false);
    } catch (e) {
      if (current()) publish(pending: false, error: walletMessage(e));
    }
  }

  Future<void> testIndexerConnection(
    IndexerConfig config,
    EvmNetwork network,
  ) async {
    final owner = account;
    if (owner == null) {
      throw const WalletInputException(MessageCode.msgAccountNotFound);
    }
    final service = makeDiscoveryService(config);
    try {
      final page = await service.discover(
        network,
        owner.addressFor(network),
        limit: 1,
      );
      if (page.invalidCount > 0) {
        throw const WalletInputException(MessageCode.discoveryResponseInvalid);
      }
    } finally {
      service.dispose();
    }
  }

  void openIndexerServices() =>
      _openSettings(initial: SettingsDestination.indexers);

  Future<void> showPortfolioHolding(PortfolioHolding h) async {
    if (account?.addressFor(h.network) != h.address) return;
    if (h.token == null) {
      await _showAssetDetails(
        assets.firstWhere((a) => a.networkId == h.network.id),
      );
      return;
    }
    final owner = account;
    final token = h.token!;
    TokenHolding asToken(PortfolioHolding p) => TokenHolding(
      token: p.token!,
      network: p.network,
      state: p.state,
      units: p.units,
      error: p.error,
    );
    final send = await showWalletPanel<bool>(
      context: context,
      width: 560,
      builder: (context) => TokenDetailsPanel(
        theme: theme,
        holding: asToken(h),
        address: h.address,
        onSend: h.spam || !networkServices.containsKey(h.network.id)
            ? null
            : () => closeWalletPanel(context, true),
        onRefresh: () async {
          await refreshAllAssets();
          if (owner != account) {
            throw const WalletInputException(
              MessageCode.msgTheAccountHasChangedReopenThisAsset,
            );
          }
          final current = portfolioPositions
              .where((p) => p.key == h.key)
              .firstOrNull;
          if (current == null) {
            throw const WalletInputException(
              MessageCode.discoveryRequestFailed,
            );
          }
          return asToken(current);
        },
        onWatch: watchedTokens.any((t) => t.key == token.key)
            ? null
            : () async {
                final next = [...watchedTokens, token];
                await vault.saveTokens(next);
                if (mounted) {
                  _updateView(() => watchedTokens = next);
                  unawaited(_refreshBalance());
                }
              },
      ),
    );
    if (mounted && send == true && account == owner) {
      await _showSendSheet(network: h.network, token: token);
    }
  }
}
