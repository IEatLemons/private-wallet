part of '../main.dart';

class _WalletManagementView extends StatefulWidget {
  const _WalletManagementView({required this.shell, required this.active});
  final _WalletShellState shell;
  final bool active;
  @override
  State<_WalletManagementView> createState() => _WalletManagementViewState();
}

class _WalletManagementViewState extends State<_WalletManagementView> {
  final _search = TextEditingController();
  final _selected = <String>{};
  final _excluded = <String>{};
  final _platforms = <String>[];
  String? _platform;
  int? _chain;
  WalletKind? _kind;
  WalletManagementSort _sort = WalletManagementSort.value;
  WalletManagementPage? _page;
  WalletGroup? _detail;
  int _request = 0, _offset = 0, _detailRevision = 0;
  bool _loading = false, _busy = false, _all = false, _morePlatforms = false;
  Timer? _debounce, _scanRefresh;
  WalletMessage? _error;
  _WalletShellState get shell => widget.shell;
  bool _isSelected(String id) =>
      _all ? !_excluded.contains(id) : _selected.contains(id);
  void _setSelected(String id, bool selected) {
    final set = _all ? _excluded : _selected;
    if (selected != _all) {
      set.add(id);
    } else {
      set.remove(id);
    }
  }

  WalletManagementQuery get query => WalletManagementQuery(
    search: _search.text,
    chain: _chain,
    platform: _platform,
    kind: _kind,
    sort: _sort,
    enabled: shell.enabledNetworks.map((n) => n.id).toList(),
  );

  @override
  void initState() {
    super.initState();
    shell.balanceScan.addListener(_onScan);
    unawaited(_load());
    unawaited(_loadPlatforms());
  }

  @override
  void dispose() {
    shell.balanceScan.removeListener(_onScan);
    _debounce?.cancel();
    _scanRefresh?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _WalletManagementView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (_chain != null && !shell.allNetworks.any((n) => n.id == _chain)) {
        _chain = null;
        _offset = 0;
        _all = false;
        _selected.clear();
        _excluded.clear();
      }
      unawaited(_load(background: true));
      _platforms.clear();
      unawaited(_loadPlatforms());
    }
  }

  void _onScan() {
    if (!mounted || !widget.active || _scanRefresh != null) return;
    _scanRefresh = Timer(const Duration(milliseconds: 400), () {
      _scanRefresh = null;
      if (mounted) unawaited(_load(background: true));
    });
    setState(() {});
  }

  Future<void> _loadPlatforms() async {
    try {
      final rows = await shell.vault.managementPlatforms(
        after: _platforms.lastOrNull ?? '',
      );
      if (mounted) {
        setState(() {
          _platforms.addAll(rows.take(50));
          _morePlatforms = rows.length > 50;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = walletMessage(e));
    }
  }

  Future<void> _load({bool background = false}) async {
    final request = ++_request;
    if (!background) setState(() => _loading = true);
    try {
      final page = await shell.vault.managementPage(query, offset: _offset);
      if (!mounted || request != _request) return;
      if (page.wallets.isEmpty && _offset > 0) {
        _offset = _offset >= 50 ? _offset - 50 : 0;
        await _load(background: background);
        return;
      }
      setState(() {
        _page = page;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = walletMessage(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _filterChanged() {
    _debounce?.cancel();
    _request++;
    setState(() {
      _selected.clear();
      _excluded.clear();
      _all = false;
      _offset = 0;
    });
    _debounce = Timer(const Duration(milliseconds: 180), _load);
  }

  Future<void> _change(
    Future<WalletPortfolio> Function() operation, {
    bool use = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await operation();
      if (!mounted || !shell.mounted) return;
      shell._applyPortfolio(result);
      if (!use) unawaited(shell._refreshBalance());
      if (use) {
        await shell._reloadPortfolio(useAccountNetwork: true);
        if (shell.mounted) shell._goToAssets();
      } else if (_detail case final detail?) {
        final group = await shell.vault.managementGroup(detail.id);
        if (mounted) {
          setState(() {
            _detail = group;
            _detailRevision++;
          });
        }
      }
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = walletMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rename(WalletGroup group, [WalletEntry? account]) async {
    final s = AppLocalizations.of(context);
    final name = await showWalletPanel<String>(
      context: context,
      width: 440,
      builder: (_) => WalletNamePanel(
        theme: shell.theme,
        title: account == null ? s.msgRenameWallet : s.msgRenameAccount,
        initialName: account?.name ?? group.name,
      ),
    );
    if (!mounted || name == null) return;
    await _change(
      () => account == null
          ? shell.vault.renameWallet(group.id, name)
          : shell.vault.renameAccount(account.id, name),
    );
  }

  Future<void> _remove({WalletGroup? wallet, WalletEntry? account}) async {
    if (_busy) return;
    setState(() => _busy = true);
    WalletRemovalPreview? preview;
    try {
      preview = await shell.vault.prepareRemoval(
        ids: wallet != null
            ? {wallet.id}
            : _all
            ? null
            : _selected.toSet(),
        accountId: account?.id,
        excluded: _all ? _excluded : const {},
        query: _all ? query : null,
      );
      if (!mounted) return;
      final confirmed = await showWalletPanel<bool>(
        context: context,
        width: 640,
        builder: (_) => _WalletRemovalPanel(
          theme: shell.theme,
          vault: shell.vault,
          preview: preview!,
        ),
      );
      if (!mounted || confirmed != true) return;
      shell.balanceScan.invalidate();
      final result = await shell.vault.commitRemoval(preview.token);
      if (!mounted || !shell.mounted) return;
      shell._applyPortfolio(result);
      if (result.accountCount == 0) return;
      unawaited(shell._refreshBalance());
      _selected.clear();
      _excluded.clear();
      _all = false;
      _detail = account == null
          ? null
          : await shell.vault.managementGroup(account.groupId);
      _detailRevision++;
      if (mounted) {
        setState(() {});
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = walletMessage(e));
    } finally {
      if (preview != null) {
        try {
          await shell.vault.cancelRemoval(preview.token);
        } catch (_) {}
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), layout = WalletLayout.of(context);
    final detail = _detail;
    return Material(
      color: shell.theme.background,
      child: Padding(
        key: const ValueKey('wallet-management-page'),
        padding: EdgeInsets.all(layout.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (layout.mobile)
                  IconButton(
                    onPressed: _busy ? null : shell._goToAssets,
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: Text(
                    s.manageWalletsTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                PopupMenuButton<WalletManagerAction>(
                  tooltip: s.manageAdd,
                  enabled: !_busy,
                  onSelected: (action) async {
                    await shell._runWalletAction(action);
                    if (mounted) {
                      await _load();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: WalletManagerAction.create,
                      child: Text(s.msgCreateWallet),
                    ),
                    PopupMenuItem(
                      value: WalletManagerAction.importOptions,
                      child: Text(s.msgImportWallet),
                    ),
                  ],
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (_error != null)
              Text(
                localized(context, _error),
                style: TextStyle(color: shell.theme.danger),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: detail != null && !layout.wide
                  ? _detailPane(detail)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _listPane(s)),
                        if (layout.wide && detail != null) ...[
                          const SizedBox(width: 20),
                          Expanded(child: _detailPane(detail)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> change,
  ) => SizedBox(
    width: 150,
    child: DropdownButtonFormField<T>(
      key: ValueKey('manage-filter-$label-$value-${items.length}'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items,
      onChanged: _busy ? null : change,
    ),
  );

  Widget _listPane(AppLocalizations s) {
    final wallets = _page?.wallets ?? const <ManagedWallet>[];
    final scan = shell.balanceScan, theme = shell.theme;
    final selectedCount = _all
        ? (_page?.total ?? 0) - _excluded.length
        : _selected.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('manage-search'),
          controller: _search,
          onChanged: (_) => _filterChanged(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: s.omniSearchHint,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _search.clear();
                      _filterChanged();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            _choice<int>(
              s.msgNetwork,
              _chain ?? 0,
              [
                DropdownMenuItem(value: 0, child: Text(s.manageAllChains)),
                for (final n in shell.allNetworks)
                  DropdownMenuItem(value: n.id, child: Text(n.name)),
              ],
              (v) {
                _chain = v == 0 ? null : v;
                _filterChanged();
              },
            ),
            _choice<String>(
              s.managePlatform,
              _platform == null ? '__all' : 'platform:$_platform',
              [
                DropdownMenuItem(
                  value: '__all',
                  child: Text(s.manageAllPlatforms),
                ),
                DropdownMenuItem(
                  value: 'platform:',
                  child: Text(s.manageNoPlatform),
                ),
                for (final p in {
                  ..._platforms,
                  if (_platform?.isNotEmpty == true) _platform!,
                })
                  DropdownMenuItem(value: 'platform:$p', child: Text(p)),
                if (_morePlatforms)
                  DropdownMenuItem(
                    value: '__more',
                    child: Text(s.omniNextPage),
                  ),
              ],
              (v) {
                if (v == '__more') {
                  unawaited(_loadPlatforms());
                  return;
                }
                _platform = v == '__all'
                    ? null
                    : v?.substring('platform:'.length);
                _filterChanged();
              },
            ),
            _choice<String>(
              s.manageType,
              _kind?.name ?? '',
              [
                DropdownMenuItem(value: '', child: Text(s.manageAllTypes)),
                DropdownMenuItem(
                  value: 'mnemonic',
                  child: Text(s.msgRecoveryPhraseWallet),
                ),
                DropdownMenuItem(
                  value: 'privateKey',
                  child: Text(s.msgPrivateKeyWallet),
                ),
              ],
              (v) {
                _kind = v == null || v.isEmpty
                    ? null
                    : WalletKind.values.byName(v);
                _filterChanged();
              },
            ),
            _choice<WalletManagementSort>(
              s.manageSort,
              _sort,
              [
                DropdownMenuItem(
                  value: WalletManagementSort.value,
                  child: Text(s.manageValueSort),
                ),
                DropdownMenuItem(
                  value: WalletManagementSort.name,
                  child: Text(s.manageNameSort),
                ),
                DropdownMenuItem(
                  value: WalletManagementSort.newest,
                  child: Text(s.manageNewestSort),
                ),
              ],
              (v) {
                if (v != null) {
                  _sort = v;
                  _filterChanged();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s.manageMatches(_page?.total ?? 0)),
            TextButton.icon(
              key: const ValueKey('manage-query-balances'),
              onPressed: _busy
                  ? null
                  : scan.running
                  ? scan.togglePause
                  : shell.startWalletBalanceScan,
              icon: Icon(
                scan.running
                    ? scan.paused
                          ? Icons.play_arrow
                          : Icons.pause
                    : Icons.refresh,
                size: 18,
              ),
              label: Text(
                scan.running
                    ? scan.paused
                          ? s.walletBalancesResume
                          : s.walletBalancesPause
                    : s.manageQueryBalances,
              ),
            ),
            if (scan.running || scan.startedAt != null)
              Text(
                s.walletBalancesProgress(
                  scan.loadFailed
                      ? s.walletBalancesLoadFailed
                      : scan.running
                      ? scan.paused
                            ? s.walletBalancesPaused
                            : s.walletBalancesChecking
                      : s.walletBalancesFinished,
                  scan.checked,
                  scan.total,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        if (_chain != null)
          Text(s.manageChainValueScope, style: TextStyle(color: theme.muted)),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Checkbox(
              key: const ValueKey('manage-select-page'),
              tristate: true,
              value:
                  (wallets.isNotEmpty &&
                      wallets.every((w) => _isSelected(w.group.id)))
                  ? true
                  : wallets.any((w) => _isSelected(w.group.id))
                  ? null
                  : false,
              onChanged: _busy
                  ? null
                  : (_) => setState(() {
                      final allPage = wallets.every(
                        (w) => _isSelected(w.group.id),
                      );
                      for (final w in wallets) {
                        _setSelected(w.group.id, !allPage);
                      }
                    }),
            ),
            Text(s.manageSelectPage),
            TextButton(
              key: const ValueKey('manage-select-all'),
              onPressed: _busy || _page?.total == 0
                  ? null
                  : () => setState(() {
                      _all = true;
                      _selected.clear();
                      _excluded.clear();
                    }),
              child: Text(s.manageSelectAll),
            ),
            if (selectedCount > 0) ...[
              Text(s.manageSelected(selectedCount)),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _all = false;
                        _selected.clear();
                        _excluded.clear();
                      }),
                child: Text(s.manageClear),
              ),
              TextButton.icon(
                key: const ValueKey('manage-delete-selected'),
                onPressed: _busy ? null : _remove,
                icon: Icon(Icons.delete_outline, size: 18, color: theme.danger),
                label: Text(
                  s.manageDelete,
                  style: TextStyle(color: theme.danger),
                ),
              ),
            ],
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: wallets.isEmpty
              ? Center(
                  child: Text(
                    _loading ? s.msgSyncing : s.msgNoMatchingWalletsOrAccounts,
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('manage-wallet-list'),
                  itemCount: wallets.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: theme.border),
                  itemBuilder: (context, i) {
                    final wallet = wallets[i], group = wallet.group;
                    final chain = shell._networkForId(group.preferredNetworkId);
                    final status = _managementCoverageText(s, wallet.coverage);
                    return Material(
                      color: _detail?.id == group.id
                          ? theme.surfaceStrong
                          : theme.surface,
                      child: ListTile(
                        key: ValueKey('manage-wallet-${group.id}'),
                        dense: true,
                        onTap: _busy
                            ? null
                            : () => setState(() => _detail = group),
                        leading: Checkbox(
                          value: _isSelected(group.id),
                          onChanged: _busy
                              ? null
                              : (checked) => setState(() {
                                  _setSelected(group.id, checked == true);
                                }),
                        ),
                        title: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (shell.activeEntry?.groupId == group.id)
                              s.manageCurrent,
                            if (chain != null) chain.name,
                            if (wallet.platform != null) wallet.platform!,
                            group.kind == WalletKind.mnemonic
                                ? s.msgRecoveryPhraseWallet
                                : s.msgPrivateKeyWallet,
                            s.manageAccounts(
                              group.accounts.first.groupAccountCount,
                            ),
                            if (group.kind == WalletKind.privateKey)
                              shortAddress(
                                group.accounts.first.addressFor(chain),
                              ),
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_usd(context, wallet.amount)}${wallet.incomplete && wallet.amount != null ? ' *' : ''}',
                            ),
                            Text(
                              wallet.updatedAt == null
                                  ? wallet.attemptedAt == null
                                        ? s.manageNotQueried
                                        : status
                                  : '${DateFormat.Md().add_Hm().format(wallet.updatedAt!)}${status.isEmpty ? '' : ' · $status'}',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: s.omniPreviousPage,
              onPressed: _busy || _loading || _offset == 0
                  ? null
                  : () {
                      _offset -= 50;
                      unawaited(_load());
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${_offset ~/ 50 + 1}'),
            IconButton(
              tooltip: s.omniNextPage,
              onPressed: _busy || _loading || _page?.more != true
                  ? null
                  : () {
                      _offset += 50;
                      unawaited(_load());
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  Widget _detailPane(WalletGroup group) => _ManagedWalletDetail(
    key: ValueKey('${group.id}-$_detailRevision'),
    shell: shell,
    group: group,
    busy: _busy,
    refresh: shell.balanceScan.checked,
    close: () => setState(() => _detail = null),
    rename: (entry) => _rename(group, entry),
    remove: (entry) => _remove(wallet: group, account: entry),
    use: (entry) =>
        _change(() => shell.vault.selectAccount(entry.id), use: true),
    derive: () => _derive(group),
  );

  Future<void> _derive(WalletGroup group) async {
    final result = await showWalletPanel<WalletPortfolio>(
      context: context,
      width: 560,
      builder: (_) => DerivedAccountPanel(
        theme: shell.theme,
        vault: shell.vault,
        group: group,
        network: shell.selectedNetwork ?? bnbSmartChainNetwork,
      ),
    );
    if (!mounted || result == null) return;
    await _change(() async => result);
  }
}

ExactDecimal? _managementDisplayAmount(Object? amount) =>
    amount is String ? ExactDecimal(BigInt.parse(amount), 72) : null;

String _managementCoverageText(AppLocalizations s, int flags) => [
  if (flags & BalanceCoverage.failed != 0) s.manageUpdateFailed,
  if (flags & BalanceCoverage.missingPrices != 0) s.walletBalancesMissingPrices,
  if (flags != 0 &&
      flags & (BalanceCoverage.failed | BalanceCoverage.missingPrices) == 0)
    s.portfolioPartial,
].join(' · ');

class _WalletRemovalPanel extends StatefulWidget {
  const _WalletRemovalPanel({
    required this.theme,
    required this.vault,
    required this.preview,
  });
  final WalletTheme theme;
  final WalletVault vault;
  final WalletRemovalPreview preview;
  @override
  State<_WalletRemovalPanel> createState() => _WalletRemovalPanelState();
}

class _WalletRemovalPanelState extends State<_WalletRemovalPanel> {
  int _offset = 0;
  List<Map<Object?, Object?>> _rows = [];
  bool _loading = true;
  WalletMessage? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.vault.removalPage(
        widget.preview.token,
        offset: _offset,
      );
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = walletMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context), p = widget.preview;
    return WalletPanel(
      theme: widget.theme,
      title: s.manageConfirmDelete,
      footer: OverflowBar(
        spacing: 12,
        children: [
          TextButton(
            onPressed: () => closeWalletPanel(context, false),
            child: Text(s.manageCancel),
          ),
          FilledButton(
            key: const ValueKey('manage-confirm-delete'),
            style: FilledButton.styleFrom(backgroundColor: widget.theme.danger),
            onPressed: _loading || _error != null
                ? null
                : () => closeWalletPanel(context, true),
            child: Text(s.manageDelete),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.manageDeleteCounts(p.wallets, p.accounts),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(s.manageDeleteExplanation),
          if (p.active)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                s.manageDeleteActive,
                style: TextStyle(color: widget.theme.warning),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(localized(context, _error)),
          for (final r in _rows.take(50))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(r['name'] as String),
              trailing: Text(
                _usd(context, _managementDisplayAmount(r['amount'])),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _loading || _offset == 0
                    ? null
                    : () {
                        _offset -= 50;
                        unawaited(_load());
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_offset ~/ 50 + 1}'),
              IconButton(
                onPressed: _loading || _rows.length <= 50
                    ? null
                    : () {
                        _offset += 50;
                        unawaited(_load());
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ManagedWalletDetail extends StatefulWidget {
  const _ManagedWalletDetail({
    required this.shell,
    required this.group,
    required this.busy,
    required this.refresh,
    required this.close,
    required this.rename,
    required this.remove,
    required this.use,
    required this.derive,
    super.key,
  });
  final _WalletShellState shell;
  final WalletGroup group;
  final bool busy;
  final int refresh;
  final VoidCallback close, derive;
  final ValueChanged<WalletEntry?> rename, remove;
  final ValueChanged<WalletEntry> use;
  @override
  State<_ManagedWalletDetail> createState() => _ManagedWalletDetailState();
}

class _ManagedWalletDetailState extends State<_ManagedWalletDetail> {
  List<WalletEntry> _accounts = [];
  List<Map<Object?, Object?>> _balances = [];
  final _cursors = [-1];
  bool _loading = true;
  int _request = 0;
  WalletMessage? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _ManagedWalletDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) unawaited(_load());
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final results = await Future.wait<Object>([
        widget.shell.vault.managementAccounts(
          widget.group,
          after: _cursors.last,
        ),
        widget.shell.vault.managementBalanceDetails(
          widget.group.id,
          after: _cursors.last,
        ),
      ]);
      if (mounted && request == _request) {
        setState(() {
          _accounts = results[0] as List<WalletEntry>;
          _balances = results[1] as List<Map<Object?, Object?>>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() => _error = walletMessage(e));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context),
        group = widget.group,
        shell = widget.shell;
    final network =
        shell._networkForId(group.preferredNetworkId) ??
        shell.selectedNetwork ??
        ethereumMainnetNetwork;
    return Material(
      color: shell.theme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(
              group.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            trailing: IconButton(
              tooltip: s.msgClose,
              onPressed: widget.busy ? null : widget.close,
              icon: const Icon(Icons.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('rename-wallet-${group.id}'),
                  onPressed: widget.busy ? null : () => widget.rename(null),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(s.msgRenameWallet),
                ),
                if (group.hasAliases)
                  TextButton.icon(
                    onPressed: widget.busy
                        ? null
                        : () => showWalletPanel<void>(
                            context: context,
                            builder: (_) => _WalletAliasesPanel(
                              theme: shell.theme,
                              vault: shell.vault,
                              group: group,
                            ),
                          ),
                    icon: const Icon(Icons.badge_outlined, size: 16),
                    label: Text(s.omniWalletAliases),
                  ),
                if (group.kind == WalletKind.mnemonic)
                  TextButton.icon(
                    key: ValueKey('derive-account-${group.id}'),
                    onPressed: widget.busy ? null : widget.derive,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(s.msgAddAccount),
                  ),
                TextButton.icon(
                  key: const ValueKey('manage-delete-wallet'),
                  onPressed: widget.busy ? null : () => widget.remove(null),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: shell.theme.danger,
                  ),
                  label: Text(
                    s.manageDeleteWallet,
                    style: TextStyle(color: shell.theme.danger),
                  ),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(localized(context, _error)),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('manage-account-list'),
              padding: const EdgeInsets.all(16),
              itemCount: _accounts.take(50).length,
              itemBuilder: (context, i) {
                final a = _accounts[i];
                final chains = group.preferredNetworkId == null
                    ? shell.enabledNetworks
                    : [network];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              a.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (a.id == shell.activeEntry?.id)
                            Text(s.manageCurrent),
                          PopupMenuButton<String>(
                            key: ValueKey('manage-account-menu-${a.id}'),
                            enabled: !widget.busy,
                            onSelected: (v) => v == 'rename'
                                ? widget.rename(a)
                                : widget.remove(a),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(s.msgRenameAccount),
                              ),
                              if (group.kind == WalletKind.mnemonic &&
                                  a.index > 0)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(s.manageDeleteAccount),
                                ),
                            ],
                          ),
                        ],
                      ),
                      if (a.legacyAddressMode)
                        Text(
                          s.legacyAddressBadge,
                          style: TextStyle(color: shell.theme.danger),
                        ),
                      if (group.kind == WalletKind.mnemonic)
                        Text(
                          a.derivationPathFor(network)!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      for (final chain in chains) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text(chain.name)),
                            IconButton(
                              tooltip: s.msgCopyAccountAddress,
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: a.addressFor(chain)),
                              ),
                              icon: const Icon(Icons.copy_outlined, size: 16),
                            ),
                            IconButton(
                              tooltip: s.msgBlockExplorer,
                              onPressed:
                                  chain.explorerAddress(a.addressFor(chain)) ==
                                      null
                                  ? null
                                  : () => launchUrl(
                                      chain.explorerAddress(
                                        a.addressFor(chain),
                                      )!,
                                      mode: LaunchMode.externalApplication,
                                    ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                            ),
                          ],
                        ),
                        SelectableText(a.addressFor(chain)),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          key: ValueKey('manage-use-${a.id}'),
                          onPressed: widget.busy ? null : () => widget.use(a),
                          child: Text(s.manageUseAccount),
                        ),
                      ),
                      for (final b in _balances.where(
                        (b) => b['account_id'] == a.id,
                      )) ...[
                        const Divider(),
                        Text(
                          shell._networkForId(b['network_id'] as int)?.name ??
                              '',
                        ),
                        Text(
                          _usd(context, _managementDisplayAmount(b['amount'])),
                        ),
                        if (b['incomplete'] != 0 || b['failed'] == 1)
                          Text(
                            _managementCoverageText(
                              s,
                              (b['incomplete'] as int? ?? 0) |
                                  (b['failed'] == 1
                                      ? BalanceCoverage.failed
                                      : 0),
                            ),
                          ),
                        if (b['updated_at'] case final int time)
                          Text(
                            DateFormat.yMd().add_Hm().format(
                              DateTime.fromMillisecondsSinceEpoch(time),
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        for (final h
                            in (jsonDecode(b['payload'] as String) as List)
                                .cast<Map>())
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${h['quantity']} ${h['symbol']}'),
                            subtitle: h['contract'] == null
                                ? null
                                : Text(h['contract'] as String),
                            trailing: Text(
                              h['value'] == null ? '—' : '≈ \$${h['value']}',
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _loading || _cursors.length == 1
                    ? null
                    : () {
                        _cursors.removeLast();
                        unawaited(_load());
                      },
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_cursors.length}'),
              IconButton(
                onPressed: _loading || _accounts.length <= 50
                    ? null
                    : () {
                        _cursors.add(_accounts[49].index);
                        unawaited(_load());
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
