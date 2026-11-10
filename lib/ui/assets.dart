part of '../main.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({
    required this.theme,
    required this.positions,
    required this.quotes,
    required this.networks,
    required this.addresses,
    required this.refreshing,
    required this.onRefresh,
    required this.onHoldingTap,
    required this.onManageNetworks,
    required this.onManageTokens,
    required this.onDiscovery,
    required this.onDisplaySettings,
    required this.discovery,
    required this.discoveryConfigured,
    required this.onContinueDiscovery,
    super.key,
  });
  final WalletTheme theme;
  final List<PortfolioHolding> positions;
  final Map<QuoteAsset, PriceQuote> quotes;
  final List<EvmNetwork> networks;
  final Map<AddressScope, String> addresses;
  final bool refreshing, discoveryConfigured;
  final Map<int, DiscoverySnapshot> discovery;
  final Future<void> Function() onRefresh, onContinueDiscovery;
  final ValueChanged<PortfolioHolding> onHoldingTap;
  final VoidCallback onManageNetworks,
      onManageTokens,
      onDiscovery,
      onDisplaySettings;
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  final searchController = TextEditingController();
  bool expanded = false, searchOpen = false;
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  WalletTheme get theme => widget.theme;
  List<PortfolioHolding> scoped(AppPreferences p) => widget.positions
      .where(
        (h) =>
            (p.addressScope == AddressScope.all ||
                (p.addressScope == AddressScope.tron) == h.network.isTron) &&
            (p.networkFilter == 0 ||
                !widget.networks.any((n) => n.id == p.networkFilter) ||
                h.network.id == p.networkFilter) &&
            (p.showSpam || !h.spam) &&
            (p.filter == AssetFilter.all ||
                (p.filter == AssetFilter.stablecoins) == h.stablecoin),
      )
      .toList();
  bool matches(PortfolioAssetGroup g) {
    final q = searchController.text.toLowerCase();
    return '${g.symbol} ${g.holdings.map((h) => '${h.name} ${h.network.name} ${h.token?.contract ?? ''}').join(' ')}'
        .toLowerCase()
        .contains(q);
  }

  Map<int, DiscoverySnapshot> get activeDiscovery {
    final p = AppSettingsScope.of(context).value;
    final ids = widget.networks
        .where(
          (n) =>
              (p.addressScope == AddressScope.all ||
                  (p.addressScope == AddressScope.tron) == n.isTron) &&
              (p.networkFilter == 0 ||
                  !widget.networks.any((v) => v.id == p.networkFilter) ||
                  n.id == p.networkFilter),
        )
        .map((n) => n.id)
        .toSet();
    return Map.fromEntries(
      widget.discovery.entries.where((e) => ids.contains(e.key)),
    );
  }

  Future<void> info(List<PortfolioHolding> holdings) async {
    final known = holdings.where((h) => h.known).length;
    final missing = holdings
        .where(
          (h) =>
              h.known && !h.network.isTestnet && h.value(widget.quotes) == null,
        )
        .length;
    final times =
        holdings
            .where((h) => h.known && h.units != BigInt.zero)
            .map((h) => h.quoteAsset)
            .toSet()
            .map((asset) => widget.quotes[asset]?.fetchedAt)
            .whereType<DateTime>()
            .toList()
          ..sort();
    final action = await showWalletPanel<String>(
      context: context,
      width: 560,
      builder: (context) => WalletPanel(
        theme: theme,
        title: tr(context, MessageCode.portfolioInformation),
        footer: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => closeWalletPanel(context, 'refresh'),
              child: Text(tr(context, MessageCode.portfolioRefresh)),
            ),
            TextButton(
              onPressed: () => closeWalletPanel(context, 'configure'),
              child: Text(tr(context, MessageCode.discoveryConfigure)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, MessageCode.portfolioValueExplanation),
              style: TextStyle(color: theme.text, height: 1.6),
            ),
            const SizedBox(height: 12),
            Text(
              tr(context, MessageCode.portfolioCoverage, [
                known,
                holdings.length,
                missing,
              ]),
            ),
            const SizedBox(height: 12),
            Text(tr(context, MessageCode.portfolioVersionExplanation)),
            const SizedBox(height: 12),
            Text(tr(context, MessageCode.portfolioPriceSource)),
            if (times.isNotEmpty)
              Text(
                tr(context, MessageCode.portfolioUpdated, [
                  DateFormat.Hm(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(times.first.toLocal()),
                ]),
              ),
            if (holdings.any((h) => h.stale(widget.quotes)))
              Text(
                tr(context, MessageCode.portfolioStalePrices),
                style: TextStyle(color: theme.warning),
              ),
            const SizedBox(height: 12),
            Text(tr(context, MessageCode.portfolioTestnetExcluded)),
            const SizedBox(height: 18),
            Text(
              tr(context, MessageCode.portfolioAddressDetails),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final e in widget.addresses.entries)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(
                  '${e.key == AddressScope.evm ? 'EVM' : 'TRON'} · ${e.value}',
                ),
              ),
            for (final e in activeDiscovery.entries)
              if (e.value.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${widget.networks.where((n) => n.id == e.key).firstOrNull?.name ?? e.key}: ${localized(context, e.value.error)}',
                    style: TextStyle(color: theme.danger),
                  ),
                ),
            if (activeDiscovery.values.any((s) => s.incomplete))
              Text(tr(context, MessageCode.discoveryPartial)),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'refresh') await widget.onRefresh();
    if (action == 'configure') widget.onDiscovery();
  }

  Widget scopeSelectors(
    AppPreferences p,
    PreferencesController preferences,
  ) => Row(
    children: [
      Expanded(
        child: DropdownButton<AddressScope>(
          key: const ValueKey('address-filter'),
          value: p.addressScope,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: theme.muted, fontSize: 12),
          items: [
            DropdownMenuItem(
              value: AddressScope.all,
              child: Text(
                tr(context, MessageCode.portfolioAllAddresses),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final entry in widget.addresses.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  '${entry.key == AddressScope.evm ? 'EVM' : 'TRON'} · ${shortAddress(entry.value)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) preferences.update(addressScope: v);
          },
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: DropdownButton<int>(
          key: const ValueKey('network-filter'),
          value: widget.networks.any((n) => n.id == p.networkFilter)
              ? p.networkFilter
              : 0,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall!.copyWith(color: theme.muted, fontSize: 12),
          items: [
            DropdownMenuItem(
              value: 0,
              child: Text(
                tr(context, MessageCode.portfolioAllNetworks),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            for (final n in widget.networks)
              DropdownMenuItem(
                value: n.id,
                child: Text(
                  n.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) preferences.update(networkFilter: v);
          },
        ),
      ),
    ],
  );
  Widget tools(AppPreferences p, PreferencesController preferences) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            for (final view in AssetView.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: TextButton(
                    key: ValueKey('view-${view.name}'),
                    onPressed: () => preferences.update(view: view),
                    style: TextButton.styleFrom(
                      backgroundColor: p.view == view
                          ? theme.primary.withValues(alpha: 0.12)
                          : null,
                      foregroundColor: p.view == view
                          ? theme.primary
                          : theme.muted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(
                      tr(
                        context,
                        view == AssetView.overview
                            ? MessageCode.portfolioOverview
                            : MessageCode.portfolioByCoin,
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      IconButton(
        key: const ValueKey('toggle-asset-display'),
        tooltip: tr(
          context,
          p.display == AssetDisplay.simple
              ? MessageCode.portfolioDetailed
              : MessageCode.portfolioSimple,
        ),
        onPressed: () => preferences.update(
          display: p.display == AssetDisplay.simple
              ? AssetDisplay.detailed
              : AssetDisplay.simple,
        ),
        icon: Icon(
          p.display == AssetDisplay.simple
              ? Icons.view_agenda_outlined
              : Icons.view_headline,
          color: theme.muted,
          size: 20,
        ),
      ),
      PopupMenuButton<String>(
        key: const ValueKey('asset-menu'),
        tooltip: tr(context, MessageCode.portfolioDisplaySettings),
        icon: Icon(Icons.more_horiz, color: theme.muted),
        onSelected: (v) {
          switch (v) {
            case 'search':
              setState(() => searchOpen = !searchOpen);
            case 'tokens':
              widget.onManageTokens();
            case 'networks':
              widget.onManageNetworks();
            case 'discovery':
              widget.onDiscovery();
            case 'settings':
              widget.onDisplaySettings();
            case 'all':
              preferences.update(filter: AssetFilter.all);
            case 'stable':
              preferences.update(filter: AssetFilter.stablecoins);
            case 'other':
              preferences.update(filter: AssetFilter.tokens);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'search',
            child: Text(tr(context, MessageCode.portfolioSearch)),
          ),
          PopupMenuItem(
            value: 'all',
            child: Text(tr(context, MessageCode.portfolioAllAssets)),
          ),
          PopupMenuItem(
            value: 'stable',
            child: Text(tr(context, MessageCode.msgStablecoins)),
          ),
          PopupMenuItem(
            value: 'other',
            child: Text(tr(context, MessageCode.msgOtherCoins)),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'tokens',
            child: Text(tr(context, MessageCode.msgAddTokens)),
          ),
          PopupMenuItem(
            value: 'networks',
            child: Text(tr(context, MessageCode.msgManageNetworks)),
          ),
          PopupMenuItem(
            value: 'discovery',
            child: Text(tr(context, MessageCode.discoveryServices)),
          ),
          PopupMenuItem(
            value: 'settings',
            child: Text(tr(context, MessageCode.portfolioDisplaySettings)),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final preferences = AppSettingsScope.of(context), p = preferences.value;
    final holdings = scoped(p);
    final groups = groupPortfolio(holdings, widget.quotes, p.sort);
    final filtered = groups
        .where((g) => (!p.hideZero || !g.zero) && matches(g))
        .toList();
    final visible = expanded || p.limit == 0 || searchController.text.isNotEmpty
        ? filtered
        : filtered.take(p.limit).toList();
    final discoveryIncomplete = activeDiscovery.values.any(
      (s) => s.pending || s.incomplete || s.error != null,
    );
    final complete =
        holdings.any((h) => !h.network.isTestnet) &&
        holdings
            .where((h) => !h.network.isTestnet)
            .every((h) => h.value(widget.quotes) != null) &&
        !discoveryIncomplete;
    final total = sumValues(holdings, widget.quotes);
    final coinChoices = groups
        .where(
          (g) =>
              (!p.hideZero || !g.zero || g.id == p.selectedAssetId) &&
              matches(g),
        )
        .toList();
    final selected =
        coinChoices.where((g) => g.id == p.selectedAssetId).firstOrNull ??
        coinChoices.firstOrNull;
    final chainRows =
        selected?.holdings
            .where(
              (h) =>
                  (!p.hideZero || !h.known || h.units != BigInt.zero) &&
                  '${h.symbol} ${h.name} ${h.network.name} ${h.token?.contract ?? ''}'
                      .toLowerCase()
                      .contains(searchController.text.toLowerCase()),
            )
            .toList() ??
        <PortfolioHolding>[];
    final detailed = p.display == AssetDisplay.detailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        scopeSelectors(p, preferences),
        tools(p, preferences),
        if (searchOpen || searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              key: const ValueKey('asset-search'),
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: tr(context, MessageCode.portfolioSearch),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (p.view == AssetView.overview) ...[
          Container(
            key: const ValueKey('portfolio-summary'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          complete
                              ? MessageCode.portfolioReferenceValue
                              : MessageCode.portfolioValuedSubtotal,
                        ),
                        style: TextStyle(color: theme.muted, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      tooltip: tr(
                        context,
                        holdings.any((h) => h.stale(widget.quotes))
                            ? MessageCode.portfolioStalePrices
                            : MessageCode.portfolioInformation,
                      ),
                      onPressed: () => info(holdings),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        holdings.any((h) => h.stale(widget.quotes))
                            ? Icons.history
                            : Icons.info_outline,
                        size: 18,
                        color: holdings.any((h) => h.stale(widget.quotes))
                            ? theme.warning
                            : theme.muted,
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('refresh-portfolio'),
                      tooltip: tr(context, MessageCode.portfolioRefresh),
                      onPressed: widget.refreshing
                          ? null
                          : () => widget.onRefresh(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.refresh, size: 20, color: theme.primary),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      total == null
                          ? '—'
                          : '≈ \$${displayQuantity(context, total.fixed(2))}',
                      key: const ValueKey('portfolio-total'),
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${tr(context, MessageCode.portfolioCoinCount, [groups.length])} · ${tr(context, MessageCode.portfolioChainCount, [holdings.map((h) => h.network.id).toSet().length])}${complete ? '' : ' · ${tr(context, MessageCode.portfolioPartial)}'}',
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (filtered.isEmpty) _empty(p, preferences),
          for (final g in visible)
            PortfolioAssetRow(
              group: g,
              quotes: widget.quotes,
              theme: theme,
              detailed: detailed,
              onTap: () => preferences.update(
                view: AssetView.coin,
                selectedAssetId: g.id,
              ),
            ),
          if (filtered.length > visible.length || expanded)
            TextButton(
              key: const ValueKey('expand-assets'),
              onPressed: () => setState(() => expanded = !expanded),
              child: Text(
                tr(
                  context,
                  expanded
                      ? MessageCode.portfolioCollapse
                      : MessageCode.portfolioExpand,
                  expanded ? [] : [filtered.length],
                ),
              ),
            ),
        ] else ...[
          if (selected == null)
            _empty(p, preferences)
          else ...[
            DropdownButton<String>(
              key: const ValueKey('coin-selector'),
              value: selected.id,
              isExpanded: true,
              items: coinChoices
                  .map(
                    (g) => DropdownMenuItem(
                      value: g.id,
                      child: Text(
                        g.holdings.first.quoteAsset != null
                            ? g.symbol
                            : '${g.symbol} · ${g.holdings.first.network.name}${g.holdings.first.token == null ? '' : ' · ${shortAddress(g.holdings.first.token!.contract)}'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) preferences.update(selectedAssetId: id);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${displayQuantity(context, selected.amount)} ${selected.symbol}',
                    key: ValueKey('coin-total-${selected.id}'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: theme.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(
                    context,
                    selected.holdings.any((h) => h.stale(widget.quotes))
                        ? MessageCode.portfolioStalePrices
                        : MessageCode.portfolioInformation,
                  ),
                  onPressed: () => info(selected.holdings),
                  icon: Icon(Icons.info_outline, color: theme.muted, size: 18),
                ),
                IconButton(
                  key: const ValueKey('refresh-portfolio'),
                  tooltip: tr(context, MessageCode.portfolioRefresh),
                  onPressed: widget.refreshing
                      ? null
                      : () => widget.onRefresh(),
                  icon: Icon(Icons.refresh, color: theme.primary, size: 20),
                ),
              ],
            ),
            if (!selected.completeQuantity)
              Text(
                tr(context, MessageCode.portfolioPartial),
                style: TextStyle(color: theme.warning, fontSize: 11),
              ),
            if (detailed)
              Text(
                _usd(context, selected.value(widget.quotes)),
                style: TextStyle(color: theme.muted, fontSize: 13),
              ),
            const SizedBox(height: 12),
            if (chainRows.isEmpty) _empty(p, preferences),
            for (final h in chainRows)
              PortfolioChainRow(
                holding: h,
                quotes: widget.quotes,
                theme: theme,
                detailed: detailed,
                onTap: () => widget.onHoldingTap(h),
              ),
          ],
        ],
        if (widget.networks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: widget.onManageNetworks,
              icon: const Icon(Icons.public),
              label: Text(tr(context, MessageCode.msgManageNetworks)),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('discovery-status'),
            onPressed: () => _discoveryAction(),
            icon: Icon(
              activeDiscovery.values.any((s) => s.error != null)
                  ? Icons.sync_problem_outlined
                  : Icons.radar,
              size: 16,
            ),
            label: Text(
              tr(
                context,
                (!widget.discoveryConfigured || activeDiscovery.isEmpty)
                    ? MessageCode.discoveryNotConfigured
                    : activeDiscovery.values.any((s) => s.pending)
                    ? MessageCode.discoveryQuerying
                    : activeDiscovery.values.any((s) => s.error != null)
                    ? MessageCode.discoveryUnavailable
                    : activeDiscovery.values.any((s) => s.incomplete)
                    ? MessageCode.discoveryPartial
                    : MessageCode.discoveryServices,
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        if (activeDiscovery.values.any((s) => s.cursor != null && !s.pending))
          TextButton(
            onPressed: () => widget.onContinueDiscovery(),
            child: Text(tr(context, MessageCode.discoveryLoadMore)),
          ),
      ],
    );
  }

  void _discoveryAction() {
    if (activeDiscovery.values.any((s) => s.error != null)) {
      info(scoped(AppSettingsScope.of(context).value));
    } else {
      widget.onDiscovery();
    }
  }

  Widget _empty(AppPreferences p, PreferencesController prefs) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, MessageCode.portfolioNoAssets),
          style: TextStyle(color: theme.muted),
        ),
        if (p.hideZero)
          TextButton(
            onPressed: () => prefs.update(hideZero: false),
            child: Text(tr(context, MessageCode.portfolioShowZero)),
          ),
      ],
    ),
  );
}

String _usd(BuildContext context, ExactDecimal? value) =>
    value == null ? '—' : '≈ \$${displayQuantity(context, value.fixed(2))}';

class PortfolioAssetRow extends StatelessWidget {
  const PortfolioAssetRow({
    required this.group,
    required this.quotes,
    required this.theme,
    required this.detailed,
    required this.onTap,
    super.key,
  });
  final PortfolioAssetGroup group;
  final Map<QuoteAsset, PriceQuote> quotes;
  final WalletTheme theme;
  final bool detailed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: theme.surface,
    child: InkWell(
      key: ValueKey('asset-group-${group.id}'),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.border)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.primary.withValues(alpha: 0.1),
              child: Text(
                group.symbol.isEmpty ? '?' : group.symbol[0],
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.symbol,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${group.holdings.first.quoteAsset == null ? '${group.holdings.first.network.name}${group.holdings.first.token == null ? '' : ' · ${shortAddress(group.holdings.first.token!.contract)}'}' : tr(context, MessageCode.portfolioChainCount, [group.holdings.map((h) => h.network.id).toSet().length])}${group.completeQuantity ? '' : ' · ${tr(context, MessageCode.portfolioPartial)}'}',
                    style: TextStyle(color: theme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    displayQuantity(context, group.amount),
                    key: ValueKey('group-amount-${group.id}'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.text,
                    ),
                  ),
                  if (detailed)
                    Text(
                      '${_usd(context, group.value(quotes))}${group.valued(quotes) ? '' : ' *'}',
                      key: ValueKey('group-value-${group.id}'),
                      style: TextStyle(color: theme.muted, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: theme.muted),
          ],
        ),
      ),
    ),
  );
}

class PortfolioChainRow extends StatelessWidget {
  const PortfolioChainRow({
    required this.holding,
    required this.quotes,
    required this.theme,
    required this.detailed,
    required this.onTap,
    super.key,
  });
  final PortfolioHolding holding;
  final Map<QuoteAsset, PriceQuote> quotes;
  final WalletTheme theme;
  final bool detailed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final h = holding;
    return Material(
      color: theme.surface,
      child: InkWell(
        key: ValueKey('chain-holding-${h.key}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.network.name,
                      style: TextStyle(
                        color: theme.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      h.token == null
                          ? shortAddress(h.address)
                          : tokenRepresentation(context, h.token!),
                      style: TextStyle(color: theme.muted, fontSize: 11),
                    ),
                    if (h.state != TokenState.ready)
                      Text(
                        localized(context, h.status),
                        style: TextStyle(
                          color: h.state == TokenState.failed
                              ? theme.danger
                              : theme.muted,
                          fontSize: 11,
                        ),
                      ),
                    if (h.network.isTestnet)
                      Text(
                        tr(context, MessageCode.msgTestnet),
                        style: TextStyle(color: theme.warning, fontSize: 11),
                      ),
                    if (h.spam)
                      Text(
                        tr(context, MessageCode.portfolioSpam),
                        style: TextStyle(color: theme.warning, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayQuantity(context, h.quantityText),
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (detailed)
                      Text(
                        _usd(context, h.value(quotes)),
                        style: TextStyle(color: theme.muted, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class AssetDetailsPanel extends StatefulWidget {
  const AssetDetailsPanel({
    required this.theme,
    required this.asset,
    required this.network,
    required this.address,
    required this.onRefresh,
    required this.onActivate,
    required this.onAction,
    super.key,
  });
  final WalletTheme theme;
  final AssetRow asset;
  final EvmNetwork network;
  final String address;
  final Future<AssetRow> Function() onRefresh;
  final Future<void> Function() onActivate;
  final Future<void> Function(WalletAction) onAction;
  @override
  State<AssetDetailsPanel> createState() => _AssetDetailsPanelState();
}

class _AssetDetailsPanelState extends State<AssetDetailsPanel> {
  late AssetRow asset = widget.asset;
  bool refreshing = false;
  Future<void> _refresh() async {
    setState(() => refreshing = true);
    try {
      final next = await widget.onRefresh();
      if (mounted) setState(() => asset = next);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localized(context, label),
          style: TextStyle(color: widget.theme.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        SelectableText(
          localized(context, value),
          style: TextStyle(color: widget.theme.text, fontSize: 14, height: 1.6),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: tr(context, MessageCode.msgAssetDetails, [asset.symbol]),
    footer: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => widget.onAction(WalletAction.send),
          icon: const Icon(Icons.north_east, size: 18),
          label: Text(tr(context, MessageCode.msgSend)),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onAction(WalletAction.receive),
          icon: const Icon(Icons.south_west, size: 18),
          label: Text(tr(context, MessageCode.msgReceive)),
        ),
        TextButton(
          onPressed: widget.onActivate,
          child: Text(tr(context, MessageCode.msgUseThisNetwork)),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          displayQuantity(context, asset.amount),
          style: TextStyle(
            color: widget.theme.text,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          localized(
            context,
            refreshing
                ? tr(context, MessageCode.msgSyncing)
                : asset.error ?? asset.change,
          ),
          style: TextStyle(
            color: asset.error == null
                ? widget.theme.muted
                : widget.theme.danger,
            fontSize: 13,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(tr(context, MessageCode.msgRefreshBalance)),
          ),
        ),
        _info(
          tr(context, MessageCode.msgNetwork),
          '${widget.network.name} · ${widget.network.identifierLabel}',
        ),
        _info(tr(context, MessageCode.msgWalletAddress), widget.address),
        _info(
          tr(context, MessageCode.msgRpcUrl),
          widget.network.rpcUrls.join('\n'),
        ),
        if (widget.network.explorerUrl.isNotEmpty) ...[
          _info(
            tr(context, MessageCode.msgBlockExplorer),
            widget.network.explorerUrl,
          ),
          TextButton.icon(
            onPressed: () async {
              final url =
                  '${widget.network.explorerUrl.replaceFirst(RegExp(r'/$'), '')}/address/${widget.address}';
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr(context, MessageCode.msgExplorerLinkCopied),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(tr(context, MessageCode.msgCopyExplorerLink)),
          ),
        ],
      ],
    ),
  );
}
