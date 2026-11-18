part of '../main.dart';

enum WalletManagerAction {
  selected,
  create,
  importOptions,
  importMnemonic,
  importPrivateKey,
  batchImport,
}

class WalletManagerPanel extends StatefulWidget {
  const WalletManagerPanel({
    required this.theme,
    required this.initial,
    required this.vault,
    this.network = ethereumMainnetNetwork,
    super.key,
  });
  final WalletTheme theme;
  final WalletPortfolio initial;
  final WalletVault vault;
  final EvmNetwork network;
  @override
  State<WalletManagerPanel> createState() => _WalletManagerPanelState();
}

class _WalletManagerPanelState extends State<WalletManagerPanel> {
  late WalletPortfolio portfolio = widget.initial;
  bool busy = false;
  String query = '';
  WalletMessage? error;
  final _cursors = <WalletPageCursor?>[null];
  WalletGroupPage? _page;
  Timer? _searchTimer;
  int _pageRequest = 0;
  bool _loading = false;

  bool get _paged => widget.vault.supportsOmniVaultImport;

  @override
  void initState() {
    super.initState();
    if (_paged) unawaited(_loadPage());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPage() async {
    _searchTimer?.cancel();
    final request = ++_pageRequest;
    setState(() => _loading = true);
    try {
      final page = await widget.vault.loadWalletPage(
        query: query,
        after: _cursors.last,
      );
      if (!mounted || _pageRequest != request) return;
      setState(() => _page = page);
    } catch (e) {
      if (mounted && _pageRequest == request) {
        setState(() {
          _page = null;
          error = walletMessage(e);
        });
      }
    } finally {
      if (mounted && _pageRequest == request) setState(() => _loading = false);
    }
  }

  void _search(String value) {
    setState(() => query = value);
    if (!_paged) return;
    _searchTimer?.cancel();
    _cursors.removeRange(1, _cursors.length);
    _pageRequest++;
    setState(() {
      _loading = true;
      error = null;
    });
    _searchTimer = Timer(const Duration(milliseconds: 150), _loadPage);
  }

  Future<void> _showAliases(WalletGroup group) => showWalletPanel<void>(
    context: context,
    builder: (_) => _WalletAliasesPanel(
      theme: widget.theme,
      vault: widget.vault,
      group: group,
    ),
  );

  Future<void> _change(
    Future<WalletPortfolio> Function() operation, {
    bool close = false,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await operation();
      if (!mounted) return;
      setState(() {
        portfolio = result;
        busy = false;
      });
      if (close) {
        closeWalletPanel(context, WalletManagerAction.selected);
      } else if (_paged) {
        _cursors.removeRange(1, _cursors.length);
        await _loadPage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is WalletInputException
              ? e.message
              : WalletMessage(MessageCode.msgOperationFailedPleaseTryAgain);
        });
      }
    }
  }

  Future<void> _rename(String id, String name, {bool account = false}) async {
    final value = await showWalletPanel<String>(
      context: context,
      width: 440,
      builder: (_) => WalletNamePanel(
        theme: widget.theme,
        title: account
            ? tr(context, MessageCode.msgRenameAccount)
            : tr(context, MessageCode.msgRenameWallet),
        initialName: name,
      ),
    );
    if (!mounted || value == null) return;
    await _change(
      () => account
          ? widget.vault.renameAccount(id, value)
          : widget.vault.renameWallet(id, value),
    );
  }

  Future<void> _addAccount(WalletGroup group) async {
    final result = await showWalletPanel<WalletPortfolio>(
      context: context,
      width: 560,
      builder: (_) => DerivedAccountPanel(
        theme: widget.theme,
        vault: widget.vault,
        group: group,
        network: widget.network,
      ),
    );
    if (!mounted || result == null) return;
    await _change(() async => result);
  }

  Widget _group(WalletGroup group, List<WalletEntry> accounts) {
    final theme = widget.theme;
    final network = !_paged
        ? widget.network
        : group.preferredNetworkId == tronMainnetNetwork.id
        ? tronMainnetNetwork
        : group.preferredNetworkId == 56
        ? bnbSmartChainNetwork
        : widget.network;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: WalletCard(
        theme: theme,
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.surfaceStrong,
                    child: Icon(
                      group.kind == WalletKind.mnemonic
                          ? Icons.account_balance_wallet_outlined
                          : Icons.vpn_key_outlined,
                      color: theme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () => _change(
                              () => widget.vault.selectAccount(
                                _paged
                                    ? '${group.id}:0'
                                    : group.accounts.first.id,
                              ),
                              close: true,
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localized(context, group.name),
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(context, MessageCode.walletAccountCount, [
                              group.kind == WalletKind.mnemonic
                                  ? tr(
                                      context,
                                      MessageCode.msgRecoveryPhraseWallet,
                                    )
                                  : tr(
                                      context,
                                      MessageCode.msgPrivateKeyWallet,
                                    ),
                              group.accounts.first.groupAccountCount,
                            ]),
                            style: TextStyle(color: theme.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (group.hasAliases)
                    IconButton(
                      tooltip: AppLocalizations.of(context).omniWalletAliases,
                      onPressed: busy ? null : () => _showAliases(group),
                      icon: Icon(Icons.badge_outlined, color: theme.muted),
                    ),
                  IconButton(
                    key: ValueKey('rename-wallet-${group.id}'),
                    tooltip: tr(context, MessageCode.msgRenameWallet),
                    onPressed: busy
                        ? null
                        : () => _rename(group.id, group.name),
                    icon: Icon(
                      Icons.edit_outlined,
                      color: theme.muted,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final entry in accounts) ...[
                Divider(color: theme.border, height: 1),
                ListTile(
                  key: ValueKey('wallet-account-${entry.id}'),
                  contentPadding: EdgeInsets.zero,
                  onTap: busy
                      ? null
                      : () => _change(
                          () => widget.vault.selectAccount(entry.id),
                          close: true,
                        ),
                  leading: Icon(
                    entry.id == portfolio.selected?.id
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: entry.id == portfolio.selected?.id
                        ? theme.primary
                        : theme.muted,
                    size: 20,
                  ),
                  title: Text(
                    localized(context, entry.name),
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    localized(
                      context,
                      '${shortAddress(entry.addressFor(network))}${entry.derivationPathFor(network) == null ? '' : '\n${entry.derivationPathFor(network)}'}${entry.legacyAddressMode ? '\n${AppLocalizations.of(context).legacyAddressBadge}' : ''}',
                    ),
                    style: TextStyle(
                      color: theme.muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tr(context, MessageCode.msgCopyAccountAddress),
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: entry.addressFor(network)),
                        ),
                        icon: Icon(
                          Icons.copy_outlined,
                          color: theme.muted,
                          size: 16,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('rename-account-${entry.id}'),
                        tooltip: tr(context, MessageCode.msgRenameAccount),
                        onPressed: busy
                            ? null
                            : () =>
                                  _rename(entry.id, entry.name, account: true),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: theme.muted,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (group.kind == WalletKind.mnemonic)
                TextButton.icon(
                  key: ValueKey('derive-account-${group.id}'),
                  onPressed: busy ? null : () => _addAccount(group),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(tr(context, MessageCode.msgAddAccount)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final visible = <(WalletGroup, List<WalletEntry>)>[];
    for (final group
        in _paged ? _page?.groups ?? const <WalletGroup>[] : portfolio.groups) {
      final entries = group.accounts
          .where(
            (a) =>
                _paged ||
                '${group.name} ${a.name} ${a.addressFor(widget.network)}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      if (entries.isNotEmpty) visible.add((group, entries));
    }
    return PopScope(
      canPop: !busy,
      child: WalletPanel(
        theme: widget.theme,
        title: tr(context, MessageCode.msgWalletManagement),
        canClose: !busy,
        scrollBody: false,
        footer: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => closeWalletPanel(context, WalletManagerAction.create),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr(context, MessageCode.msgCreateWallet)),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => closeWalletPanel(
                      context,
                      WalletManagerAction.importOptions,
                    ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: Text(tr(context, MessageCode.msgImportWallet)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(context, MessageCode.walletAndAccountCount, [
                portfolio.groupCount,
                portfolio.accountCount,
              ]),
              style: TextStyle(color: widget.theme.muted, fontSize: 13),
            ),
            if (!keyboardVisible) ...[
              const SizedBox(height: 8),
              Text(
                tr(
                  context,
                  MessageCode.msgARecoveryPhraseWalletCanHaveMultipleAccounts,
                ),
                style: TextStyle(
                  color: widget.theme.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('wallet-search'),
              onChanged: _search,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: _paged
                    ? AppLocalizations.of(context).omniSearchHint
                    : tr(
                        context,
                        MessageCode.msgSearchWalletsAccountsOrAddresses,
                      ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  localized(context, error!),
                  style: TextStyle(color: widget.theme.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: SizedBox(
                height: 420,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          tr(
                            context,
                            MessageCode.msgNoMatchingWalletsOrAccounts,
                          ),
                          style: TextStyle(color: widget.theme.muted),
                        ),
                      )
                    : ListView.builder(
                        key: const ValueKey('wallet-management-list'),
                        itemCount: visible.length,
                        itemBuilder: (_, i) =>
                            _group(visible[i].$1, visible[i].$2),
                      ),
              ),
            ),
            if (_paged)
              _WalletPageButtons(
                previous: _cursors.length > 1 && !_loading && !busy
                    ? () {
                        _cursors.removeLast();
                        unawaited(_loadPage());
                      }
                    : null,
                next: _page?.next != null && !_loading && !busy
                    ? () {
                        _cursors.add(_page!.next);
                        unawaited(_loadPage());
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class WalletImportOptions extends StatelessWidget {
  const WalletImportOptions({
    required this.theme,
    this.supportsOmniVault = false,
    super.key,
  });
  final WalletTheme theme;
  final bool supportsOmniVault;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: tr(context, MessageCode.msgImportWallet),
    subtitle: tr(context, MessageCode.msgExistingWalletsAreKeptYouCanSwitchAt),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in [
          (
            WalletManagerAction.importMnemonic,
            Icons.key_outlined,
            tr(context, MessageCode.msgImportRecoveryPhrase),
            tr(context, MessageCode.msgRestoreAWalletAndAddDerivedAccounts),
          ),
          (
            WalletManagerAction.importPrivateKey,
            Icons.vpn_key_outlined,
            tr(context, MessageCode.msgImportPrivateKey),
            tr(context, MessageCode.msgImportOneEvmTronAccount),
          ),
          (
            WalletManagerAction.batchImport,
            Icons.upload_file_outlined,
            tr(context, MessageCode.msgImportPrivateKeyFile),
            supportsOmniVault
                ? AppLocalizations.of(context).omniFileHint
                : tr(context, MessageCode.msgImportMultipleAccountsFromCsvTsv),
          ),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => closeWalletPanel(context, option.$1),
            leading: Icon(option.$2, color: theme.primary),
            title: Text(
              localized(context, option.$3),
              style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              localized(context, option.$4),
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.muted),
          ),
      ],
    ),
  );
}

class WalletNamePanel extends StatefulWidget {
  const WalletNamePanel({
    required this.theme,
    required this.title,
    required this.initialName,
    super.key,
  });
  final WalletTheme theme;
  final String title, initialName;
  @override
  State<WalletNamePanel> createState() => _WalletNamePanelState();
}

class _WalletNamePanelState extends State<WalletNamePanel> {
  late final controller = TextEditingController(text: widget.initialName);
  WalletMessage? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = controller.text.trim();
    if (value.isEmpty || value.length > 64) {
      setState(
        () => error = WalletMessage(MessageCode.msgNamesMustContainCharacters),
      );
      return;
    }
    closeWalletPanel(context, value);
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: widget.title,
    footer: FilledButton(
      onPressed: _save,
      child: Text(tr(context, MessageCode.msgSaveName)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: 64,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: tr(context, MessageCode.msgName),
          ),
        ),
        if (error != null)
          Text(
            localized(context, error!),
            style: TextStyle(color: widget.theme.danger, fontSize: 13),
          ),
      ],
    ),
  );
}

class DerivedAccountPanel extends StatefulWidget {
  const DerivedAccountPanel({
    required this.theme,
    required this.vault,
    required this.group,
    this.network = ethereumMainnetNetwork,
    super.key,
  });
  final WalletTheme theme;
  final WalletVault vault;
  final WalletGroup group;
  final EvmNetwork network;

  @override
  State<DerivedAccountPanel> createState() => _DerivedAccountPanelState();
}

class _DerivedAccountPanelState extends State<DerivedAccountPanel> {
  final name = TextEditingController();
  final oldAddress = TextEditingController();
  bool legacyAddressMode = false;
  late bool checkTron = widget.network.isTron;
  LegacyMnemonicInspection? inspection;
  bool checking = false;
  late final evm = TextEditingController(text: widget.group.nextEvmPath);
  late final tron = TextEditingController(text: widget.group.nextTronPath);
  bool busy = false;
  WalletMessage? error;

  @override
  void dispose() {
    name.dispose();
    oldAddress.dispose();
    evm.dispose();
    tron.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.vault.addDerivedAccount(
        widget.group.id,
        name: name.text.trim().isEmpty
            ? tr(context, MessageCode.msgAccountMore, [
                widget.group.accounts.first.groupAccountCount + 1,
              ])
            : name.text,
        evmPath: evm.text,
        tronPath: tron.text,
        legacyAddressMode: legacyAddressMode,
      );
      if (mounted) closeWalletPanel(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = walletMessage(e);
        });
      }
    }
  }

  Future<void> _check() async {
    if (checking || busy) return;
    setState(() {
      checking = true;
      error = null;
      inspection = null;
    });
    try {
      final result = await widget.vault.inspectLegacyAccount(
        groupId: widget.group.id,
        path: checkTron ? tron.text : evm.text,
        expectedAddress: oldAddress.text,
        network: checkTron ? tronMainnetNetwork : ethereumMainnetNetwork,
      );
      if (mounted) setState(() => inspection = result);
    } catch (e) {
      if (mounted) setState(() => error = walletMessage(e));
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final fields = [
      (evm, strings.evmDerivationPath, 'derived-evm-path'),
      (tron, strings.tronDerivationPath, 'derived-tron-path'),
    ];
    return PopScope(
      canPop: !busy,
      child: WalletPanel(
        theme: widget.theme,
        title: tr(context, MessageCode.msgAddAccount),
        subtitle: widget.group.name,
        canClose: !busy && !checking,
        footer: FilledButton(
          key: const ValueKey('confirm-derived-account'),
          onPressed: busy || checking ? null : _add,
          child: Text(tr(context, MessageCode.msgAddAccount)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.derivedAccountHint,
              style: TextStyle(color: widget.theme.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('derived-account-name'),
              controller: name,
              enabled: !busy,
              maxLength: 64,
              decoration: InputDecoration(
                labelText: tr(context, MessageCode.msgName),
                hintText: tr(context, MessageCode.msgAccountMore, [
                  widget.group.accounts.first.groupAccountCount + 1,
                ]),
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('legacy-address-mode'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: legacyAddressMode,
              onChanged: busy || checking
                  ? null
                  : (value) =>
                        setState(() => legacyAddressMode = value ?? false),
              title: Text(strings.legacyAddressMode),
            ),
            if (legacyAddressMode)
              Text(
                strings.legacyAddressWarning,
                style: TextStyle(color: widget.theme.danger),
              ),
            for (final field
                in widget.network.isTron ? fields.reversed : fields) ...[
              const SizedBox(height: 16),
              TextField(
                key: ValueKey(field.$3),
                controller: field.$1,
                enabled: !busy && !checking,
                onChanged: (_) => setState(() => inspection = null),
                smartQuotesType: SmartQuotesType.disabled,
                smartDashesType: SmartDashesType.disabled,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.visiblePassword,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                decoration: InputDecoration(labelText: field.$2),
              ),
            ],
            if (legacyAddressMode || inspection != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                key: const ValueKey('legacy-check-chain'),
                initialValue: checkTron,
                items: const [
                  DropdownMenuItem(value: false, child: Text('EVM')),
                  DropdownMenuItem(value: true, child: Text('TRON')),
                ],
                onChanged: busy || checking
                    ? null
                    : (value) => setState(() {
                        checkTron = value ?? false;
                        inspection = null;
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('legacy-check-address'),
                controller: oldAddress,
                enabled: !busy && !checking,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() => inspection = null),
                decoration: InputDecoration(
                  labelText: strings.legacyCheckAddress,
                ),
              ),
              TextButton(
                key: const ValueKey('legacy-check'),
                onPressed: busy || checking ? null : _check,
                child: Text(strings.legacyCheck),
              ),
              if (inspection case final result?) ...[
                Text(
                  switch (result.match) {
                    LegacyMnemonicMatch.standard => strings.legacyMatchStandard,
                    LegacyMnemonicMatch.legacyHash => strings.legacyMatchHash,
                    LegacyMnemonicMatch.none => strings.legacyMatchNone,
                  },
                  style: TextStyle(
                    color: result.match == LegacyMnemonicMatch.standard
                        ? widget.theme.text
                        : widget.theme.danger,
                  ),
                ),
                if (result.matched case final matched?) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '${strings.legacyMatchedPath}\n${matched.path}',
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${strings.legacyStandardAddresses}\n${matched.standardAddress}',
                  ),
                  TextButton(
                    key: const ValueKey('legacy-use-path'),
                    onPressed: () => setState(() {
                      (checkTron ? tron : evm).text = matched.path;
                      legacyAddressMode =
                          result.match == LegacyMnemonicMatch.legacyHash;
                    }),
                    child: Text(strings.legacyUseMatchedPath),
                  ),
                ],
              ],
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                localized(context, error!),
                style: TextStyle(color: widget.theme.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
