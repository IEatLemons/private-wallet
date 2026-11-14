part of '../main.dart';

extension _WalletBalanceActions on _WalletShellState {
  Future<void> _showWalletBalances() async {
    final scan = _walletBalanceScan ??= WalletBalanceScan(
      vault: vault,
      quoteService: quoteService,
      makeRpc: _makeService,
      makeIndexer: makeDiscoveryService,
    );
    void refresh() => unawaited(
      scan.start(
        accountCount: portfolio.accountCount,
        networks: allNetworks,
        enabled: enabledNetworks,
        watchedTokens: watchedTokens,
        configs: indexerSettings.configs,
        tokenCatalogIncomplete: tokenCatalogError != null,
      ),
    );
    await showWalletPanel<void>(
      context: context,
      width: 760,
      mobileFullscreen: true,
      builder: (_) =>
          _WalletBalancesPanel(theme: theme, scan: scan, onRefresh: refresh),
    );
  }
}

class _WalletBalancesPanel extends StatefulWidget {
  const _WalletBalancesPanel({
    required this.theme,
    required this.scan,
    required this.onRefresh,
  });

  final WalletTheme theme;
  final WalletBalanceScan scan;
  final VoidCallback onRefresh;

  @override
  State<_WalletBalancesPanel> createState() => _WalletBalancesPanelState();
}

class _WalletBalancesPanelState extends State<_WalletBalancesPanel> {
  static const _pageSize = 50;
  final _scroll = ScrollController();
  int _page = 0;
  WalletBalance? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.scan.startedAt == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefresh();
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _changePage(int page) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _page = page);
  }

  String? _status(WalletBalance balance, AppLocalizations strings) {
    if (balance.noNetworks) return strings.walletBalancesNoNetwork;
    final parts = [
      if (balance.queryFailed) strings.walletBalancesQueryIncomplete,
      if (balance.tokenCatalogIncomplete) strings.walletBalancesTokenListError,
      if (balance.unpriced) strings.walletBalancesMissingPrices,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final scan = widget.scan;
    return ListenableBuilder(
      listenable: scan,
      builder: (context, _) {
        final selected = _selected;
        if (selected != null) {
          return _details(context, strings, selected);
        }
        final checked = scan.checked;
        final total = scan.total < checked ? checked : scan.total;
        final pageCount = checked == 0 ? 1 : (checked - 1) ~/ _pageSize + 1;
        final page = _page.clamp(0, pageCount - 1);
        final rows = scan.page(page * _pageSize, _pageSize);
        final theme = widget.theme;
        final state = scan.loadFailed
            ? strings.walletBalancesLoadFailed
            : scan.paused
            ? strings.walletBalancesPaused
            : scan.running || scan.startedAt == null
            ? strings.walletBalancesChecking
            : strings.walletBalancesFinished;
        return WalletPanel(
          title: strings.walletBalancesTitle,
          theme: theme,
          scrollBody: false,
          expandBody: true,
          footer: OverflowBar(
            spacing: 8,
            overflowSpacing: 8,
            children: [
              TextButton(
                key: const ValueKey('wallet-balance-close'),
                onPressed: () => closeWalletPanel(context),
                child: Text(
                  scan.running && !scan.paused
                      ? strings.walletBalancesBackground
                      : strings.msgClose,
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('wallet-balance-control'),
                onPressed: scan.running
                    ? scan.togglePause
                    : () {
                        _changePage(0);
                        widget.onRefresh();
                      },
                icon: Icon(
                  scan.running
                      ? (scan.paused ? Icons.play_arrow : Icons.pause)
                      : Icons.refresh,
                  size: 18,
                ),
                label: Text(
                  scan.running
                      ? (scan.paused
                            ? strings.walletBalancesResume
                            : strings.walletBalancesPause)
                      : strings.msgRefreshBalance,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.walletBalancesProgress(state, checked, total),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (scan.startedAt case final startedAt?)
                      Text(
                        strings.walletBalancesStarted(
                          DateFormat.Md(
                            Localizations.localeOf(context).toLanguageTag(),
                          ).add_Hm().format(startedAt),
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (scan.running || scan.startedAt == null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : checked / total,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      strings.walletBalancesScope,
                      style: TextStyle(color: theme.muted),
                    ),
                    if (scan.incompleteCount > 0)
                      Text(
                        strings.walletBalancesIncompleteCount(
                          scan.incompleteCount,
                        ),
                        style: TextStyle(color: theme.warning),
                      ),
                    if (scan.quotes.values.any(
                      (quote) => quote.state == QuoteState.stale,
                    ))
                      Text(
                        strings.portfolioStalePrices,
                        style: TextStyle(color: theme.muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          scan.running || scan.startedAt == null
                              ? strings.walletBalancesWaiting
                              : scan.loadFailed
                              ? strings.walletBalancesLoadFailed
                              : strings.walletBalancesEmpty,
                          style: TextStyle(color: theme.muted),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('wallet-balance-results'),
                        controller: _scroll,
                        itemCount: rows.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: theme.border),
                        itemBuilder: (context, i) {
                          final balance = rows[i];
                          final status = _status(balance, strings);
                          final chains = balance.networks
                              .map((n) => n.name)
                              .join(' · ');
                          return ListTile(
                            key: ValueKey('wallet-balance-${balance.entry.id}'),
                            onTap: () => setState(() => _selected = balance),
                            title: Text(
                              balance.entry.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (chains.isNotEmpty) chains,
                                ?status,
                              ].join('\n'),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _usd(context, balance.rankedValue),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.text,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              if (pageCount > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: strings.omniPreviousPage,
                      onPressed: page == 0 ? null : () => _changePage(page - 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('${page + 1} / $pageCount'),
                    IconButton(
                      tooltip: strings.omniNextPage,
                      onPressed: page >= pageCount - 1
                          ? null
                          : () => _changePage(page + 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _details(
    BuildContext context,
    AppLocalizations strings,
    WalletBalance balance,
  ) {
    final theme = widget.theme;
    final status = _status(balance, strings);
    final quotes = widget.scan.quotes;
    final holdings = balance.holdings.toList()
      ..sort((a, b) {
        final av = a.value(quotes), bv = b.value(quotes);
        if (av != null && bv != null) {
          final byValue = bv.compareTo(av);
          if (byValue != 0) return byValue;
        } else if ((av == null) != (bv == null)) {
          return av == null ? 1 : -1;
        }
        if (a.known != b.known) return a.known ? -1 : 1;
        return a.symbol.compareTo(b.symbol);
      });
    return WalletPanel(
      theme: theme,
      title: balance.entry.displayName,
      expandBody: true,
      footer: TextButton.icon(
        key: const ValueKey('wallet-balance-back'),
        onPressed: () => setState(() => _selected = null),
        icon: const Icon(Icons.arrow_back, size: 18),
        label: Text(strings.walletBalancesTitle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _usd(context, balance.rankedValue),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (status != null)
            Text(status, style: TextStyle(color: theme.warning)),
          for (final network in balance.networks) ...[
            const SizedBox(height: 12),
            Text(network.name, style: Theme.of(context).textTheme.titleSmall),
            SelectableText(balance.entry.addressFor(network)),
          ],
          const SizedBox(height: 12),
          if (holdings.isEmpty && !balance.noNetworks && !balance.partial)
            Text(strings.walletBalancesNoHoldings),
          for (final holding in holdings)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${displayQuantity(context, holding.quantityText)} ${holding.symbol}',
              ),
              subtitle: Text(
                holding.known
                    ? holding.network.name
                    : '${holding.network.name} · ${strings.msgQueryFailed}',
              ),
              trailing: Text(_usd(context, holding.value(quotes))),
            ),
          for (final network in balance.incompleteDiscovery)
            Text('${network.name} · ${strings.discoveryPartial}'),
        ],
      ),
    );
  }
}
