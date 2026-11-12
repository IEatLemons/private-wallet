part of '../main.dart';

/// Stable navigation identities shared by the directory, shortcuts and search.
enum SettingsDestination {
  directory,
  search,
  wallets,
  importWallet,
  assets,
  display,
  data,
  networks,
  network,
  indexers,
  indexer,
  securityBackup,
  security,
  backup,
  general,
  language,
  appearance,
}

enum SettingsAction {
  manageWallets,
  createWallet,
  importMnemonic,
  importPrivateKey,
  importFile,
  watchedTokens,
  enableNetworks,
  addNetwork,
}

typedef SettingsLabel = String Function(AppLocalizations);

class SettingsEntry {
  const SettingsEntry(
    this.id,
    this.destination,
    this.title,
    this.icon, {
    this.category,
    this.description,
    this.aliases = '',
    this.anchor,
    this.action,
    this.unavailable = false,
    this.provider,
  });
  final String id;
  final SettingsDestination destination;
  final SettingsDestination? category;
  final SettingsLabel title;
  final SettingsLabel? description;
  final IconData icon;
  final String aliases;
  final String? anchor;
  final SettingsAction? action;
  final bool unavailable;
  final IndexerProvider? provider;
}

final settingsEntries = <SettingsEntry>[
  SettingsEntry(
    'wallets',
    SettingsDestination.wallets,
    (s) => s.settingsWallets,
    Icons.account_balance_wallet_outlined,
    description: (s) => s.settingsWalletsHint,
  ),
  SettingsEntry(
    'assets',
    SettingsDestination.assets,
    (s) => s.msgAssets,
    Icons.toll_outlined,
    description: (s) => s.settingsAssetsHint,
  ),
  SettingsEntry(
    'data',
    SettingsDestination.data,
    (s) => s.settingsData,
    Icons.public,
    description: (s) => s.settingsDataHint,
  ),
  SettingsEntry(
    'security-backup',
    SettingsDestination.securityBackup,
    (s) => s.settingsSecurity,
    Icons.shield_outlined,
    description: (s) => s.settingsSecurityHint,
  ),
  SettingsEntry(
    'general',
    SettingsDestination.general,
    (s) => s.settingsGeneral,
    Icons.tune,
    description: (s) => s.settingsGeneralHint,
  ),
  SettingsEntry(
    'manage-wallets',
    SettingsDestination.wallets,
    (s) => s.msgManageWalletsAndAccounts,
    Icons.account_balance_wallet_outlined,
    category: SettingsDestination.wallets,
    action: SettingsAction.manageWallets,
    aliases: 'account 帳戶 账户 钱包 錢包',
  ),
  SettingsEntry(
    'create-wallet',
    SettingsDestination.wallets,
    (s) => s.msgCreateWallet,
    Icons.add,
    category: SettingsDestination.wallets,
    action: SettingsAction.createWallet,
  ),
  SettingsEntry(
    'import-wallet',
    SettingsDestination.importWallet,
    (s) => s.msgImportWallet,
    Icons.download_outlined,
    category: SettingsDestination.wallets,
  ),
  SettingsEntry(
    'import-mnemonic',
    SettingsDestination.importWallet,
    (s) => s.msgImportRecoveryPhrase,
    Icons.key_outlined,
    category: SettingsDestination.wallets,
    action: SettingsAction.importMnemonic,
    aliases: 'seed mnemonic 助记词 助記詞',
  ),
  SettingsEntry(
    'import-key',
    SettingsDestination.importWallet,
    (s) => s.msgImportPrivateKey,
    Icons.vpn_key_outlined,
    category: SettingsDestination.wallets,
    action: SettingsAction.importPrivateKey,
    aliases: 'private key 私钥 私鑰',
  ),
  SettingsEntry(
    'import-file',
    SettingsDestination.importWallet,
    (s) => s.msgImportPrivateKeyFile,
    Icons.upload_file_outlined,
    category: SettingsDestination.wallets,
    action: SettingsAction.importFile,
    aliases: 'CSV TSV 批量 檔案 文件',
  ),
  SettingsEntry(
    'display',
    SettingsDestination.display,
    (s) => s.portfolioDisplaySettings,
    Icons.view_agenda_outlined,
    category: SettingsDestination.assets,
    description: (s) => s.settingsAssetsHint,
  ),
  SettingsEntry(
    'watched-tokens',
    SettingsDestination.assets,
    (s) => s.settingsWatchedTokens,
    Icons.playlist_add,
    category: SettingsDestination.assets,
    action: SettingsAction.watchedTokens,
    aliases: 'token 代币 代幣 添加币种 添加幣種',
  ),
  SettingsEntry(
    'display-mode',
    SettingsDestination.display,
    (s) => s.portfolioDisplayMode,
    Icons.view_list_outlined,
    category: SettingsDestination.assets,
    anchor: 'display-mode',
    aliases: 'simple detailed 简洁 详细 簡潔 詳細',
  ),
  SettingsEntry(
    'initial-count',
    SettingsDestination.display,
    (s) => s.portfolioInitialCount,
    Icons.format_list_numbered,
    category: SettingsDestination.assets,
    anchor: 'initial-count',
    aliases: '3 5 10',
  ),
  SettingsEntry(
    'sort',
    SettingsDestination.display,
    (s) => s.portfolioSort,
    Icons.sort,
    category: SettingsDestination.assets,
    anchor: 'sort',
  ),
  SettingsEntry(
    'hide-zero',
    SettingsDestination.display,
    (s) => s.portfolioHideZero,
    Icons.visibility_off_outlined,
    category: SettingsDestination.assets,
    anchor: 'hide-zero',
    aliases: 'zero 零余额 零餘額',
  ),
  SettingsEntry(
    'show-spam',
    SettingsDestination.display,
    (s) => s.portfolioShowSpam,
    Icons.filter_alt_outlined,
    category: SettingsDestination.assets,
    anchor: 'show-spam',
    aliases: 'spam 垃圾',
  ),
  SettingsEntry(
    'networks',
    SettingsDestination.networks,
    (s) => s.msgNetworksAndRpc,
    Icons.public,
    category: SettingsDestination.data,
    aliases: 'RPC 节点 節點 node endpoint',
  ),
  SettingsEntry(
    'enable-networks',
    SettingsDestination.networks,
    (s) => s.msgManageNetworks,
    Icons.toggle_on_outlined,
    category: SettingsDestination.data,
    action: SettingsAction.enableNetworks,
  ),
  SettingsEntry(
    'add-network',
    SettingsDestination.networks,
    (s) => s.msgAddCustomNetwork,
    Icons.add,
    category: SettingsDestination.data,
    action: SettingsAction.addNetwork,
  ),
  SettingsEntry(
    'indexers',
    SettingsDestination.indexers,
    (s) => s.discoveryServices,
    Icons.radar,
    category: SettingsDestination.data,
    aliases: 'API Key Moralis Alchemy TronGrid 索引 自动发现 自動發現',
  ),
  for (final descriptor in indexerDescriptors)
    SettingsEntry(
      'provider-${descriptor.provider.name}',
      SettingsDestination.indexer,
      (_) => descriptor.name,
      Icons.radar,
      category: SettingsDestination.data,
      provider: descriptor.provider,
      aliases: 'API Key',
    ),
  SettingsEntry(
    'security',
    SettingsDestination.security,
    (s) => s.msgWalletSecurity,
    Icons.shield_outlined,
    category: SettingsDestination.securityBackup,
    aliases: 'address derivation storage 地址 派生 本地存储 本機儲存',
  ),
  SettingsEntry(
    'backup',
    SettingsDestination.backup,
    (s) => s.msgBackup,
    Icons.backup_outlined,
    category: SettingsDestination.securityBackup,
    aliases: 'offline 离线 離線',
  ),
  SettingsEntry(
    'cloud-backup',
    SettingsDestination.backup,
    (s) => s.msgIcloudGoogleDriveBackupNotConnected,
    Icons.cloud_outlined,
    category: SettingsDestination.securityBackup,
    anchor: 'cloud-backup',
    unavailable: true,
    aliases: 'iCloud Google Drive 云备份 雲端備份',
  ),
  SettingsEntry(
    'language',
    SettingsDestination.language,
    (s) => s.msgLanguage,
    Icons.language,
    category: SettingsDestination.general,
    aliases: 'English 中文 简体 繁體 简体中文 繁體中文 语言 語言',
    anchor: 'language',
  ),
  SettingsEntry(
    'appearance',
    SettingsDestination.appearance,
    (s) => s.settingsAppearance,
    Icons.contrast,
    category: SettingsDestination.general,
    aliases: 'theme dark light system 主题 主題 深色 浅色 淺色 跟随系统 跟隨系統',
    anchor: 'appearance',
  ),
];

String appearanceLabel(AppLocalizations s, AppAppearance appearance) =>
    switch (appearance) {
      AppAppearance.system => s.msgSystemDefault,
      AppAppearance.light => s.settingsLight,
      AppAppearance.dark => s.settingsDark,
    };

SettingsEntry settingsEntry(String id) =>
    settingsEntries.firstWhere((e) => e.id == id);
final _settingsSearchLanguages = [
  lookupAppLocalizations(const Locale('en')),
  lookupAppLocalizations(const Locale('zh')),
  lookupAppLocalizations(
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ),
];

/// Only static labels are indexed. No wallet, network URL or credential values.
List<SettingsEntry> searchSettings(String query) {
  final words = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty);
  if (words.isEmpty) return const [];
  return settingsEntries.where((entry) {
    final text = [
      entry.aliases,
      for (final s in _settingsSearchLanguages) ...[
        entry.title(s),
        if (entry.description != null) entry.description!(s),
      ],
    ].join(' ').toLowerCase();
    return words.every(text.contains);
  }).toList();
}

class _SettingsLocation {
  const _SettingsLocation(
    this.destination, {
    this.anchor,
    this.networkId,
    this.provider,
  });
  final SettingsDestination destination;
  final String? anchor;
  final int? networkId;
  final IndexerProvider? provider;
}

class _SettingsHub extends StatefulWidget {
  const _SettingsHub({required this.shell, required this.initial});
  final _WalletShellState shell;
  final SettingsDestination initial;
  @override
  State<_SettingsHub> createState() => _SettingsHubState();
}

class _SettingsHubState extends State<_SettingsHub> {
  final navigator = GlobalKey<NavigatorState>();
  final observer = _SettingsObserver();
  _WalletShellState get shell => widget.shell;
  final location = ValueNotifier<_SettingsLocation>(
    const _SettingsLocation(SettingsDestination.directory),
  );
  @override
  void dispose() {
    location.dispose();
    super.dispose();
  }

  MaterialPageRoute<void> route(_SettingsLocation target) =>
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: '/settings/${target.destination.name}',
          arguments: target,
        ),
        builder: (_) => _SettingsScreen(hub: this, location: target),
      );
  void open(_SettingsLocation target) {
    FocusManager.instance.primaryFocus?.unfocus();
    navigator.currentState!.push<void>(route(target));
  }

  void back() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (navigator.currentState!.canPop()) {
      navigator.currentState!.pop();
    } else {
      exit();
    }
  }

  void exit() => Navigator.of(context).pop();
  void selectCategory(SettingsEntry entry) {
    navigator.currentState!.popUntil((r) => r.isFirst);
    open(_SettingsLocation(entry.destination));
  }

  Future<void> openEntry(SettingsEntry entry) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (entry.action == null) {
      open(
        _SettingsLocation(
          entry.destination,
          anchor: entry.anchor,
          provider: entry.provider,
        ),
      );
      return;
    }
    switch (entry.action!) {
      case SettingsAction.manageWallets:
        await shell.selectWallet();
      case SettingsAction.createWallet:
        await shell._createWallet();
      case SettingsAction.importMnemonic:
        await shell._importWallet();
      case SettingsAction.importPrivateKey:
        await shell._importPrivateKey();
      case SettingsAction.importFile:
        await shell._importBatchWallets();
      case SettingsAction.watchedTokens:
        await shell._manageTokens();
      case SettingsAction.enableNetworks:
        await shell._showNetworkSelector();
      case SettingsAction.addNetwork:
        await shell._addNetwork();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      shell.viewRevision,
      shell.indexerSettings,
      location,
    ]),
    builder: (context, _) {
      final theme = Theme.of(context).brightness == Brightness.dark
          ? WalletTheme.dark
          : WalletTheme.light;
      final layout = WalletLayout.of(context);
      return Scaffold(
        key: const ValueKey('settings-hub'),
        body: SafeArea(
          child: Row(
            children: [
              if (!layout.mobile)
                WalletRail(
                  theme: theme,
                  selected: WalletPage.settings,
                  onSelect: (page) {
                    if (page == WalletPage.assets) exit();
                  },
                ),
              if (layout.wide)
                SizedBox(
                  width: 224,
                  child: Material(
                    color: theme.surface,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        const SizedBox(height: 12),
                        _SettingsRow(
                          title: tr(context, MessageCode.msgSettings),
                          icon: Icons.settings_outlined,
                          selected:
                              location.value.destination ==
                              SettingsDestination.directory,
                          onTap: () {
                            navigator.currentState!.popUntil((r) => r.isFirst);
                            open(
                              const _SettingsLocation(
                                SettingsDestination.directory,
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        for (final e in settingsEntries.where(
                          (e) => e.category == null,
                        ))
                          _SettingsRow(
                            key: ValueKey('settings-nav-${e.id}'),
                            title: e.title(AppLocalizations.of(context)),
                            icon: e.icon,
                            selected:
                                _category(location.value.destination) ==
                                e.destination,
                            onTap: () => selectCategory(e),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: NavigatorPopHandler<void>(
                  onPopWithResult: (_) => navigator.currentState!.pop(),
                  child: Navigator(
                    key: navigator,
                    observers: [
                      observer
                        ..onChanged = (value) {
                          // Notifications arrive while Navigator is building.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) location.value = value;
                          });
                        },
                    ],
                    onGenerateInitialRoutes: (_, _) => [
                      route(_SettingsLocation(widget.initial)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SettingsObserver extends NavigatorObserver {
  void Function(_SettingsLocation)? onChanged;
  void changed(Route<dynamic>? route) {
    final target = route?.settings.arguments;
    if (target is _SettingsLocation) onChanged?.call(target);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      changed(previousRoute);
}

SettingsDestination? _category(SettingsDestination destination) =>
    switch (destination) {
      SettingsDestination.wallets ||
      SettingsDestination.importWallet => SettingsDestination.wallets,
      SettingsDestination.assets ||
      SettingsDestination.display => SettingsDestination.assets,
      SettingsDestination.data ||
      SettingsDestination.networks ||
      SettingsDestination.network ||
      SettingsDestination.indexers ||
      SettingsDestination.indexer => SettingsDestination.data,
      SettingsDestination.securityBackup ||
      SettingsDestination.security ||
      SettingsDestination.backup => SettingsDestination.securityBackup,
      SettingsDestination.general ||
      SettingsDestination.language ||
      SettingsDestination.appearance => SettingsDestination.general,
      _ => null,
    };

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.value,
    this.icon,
    this.selected = false,
    this.selection = false,
    super.key,
  });
  final String title;
  final String? subtitle, value;
  final IconData? icon;
  final bool selected, selection;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .09)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: MergeSemantics(
        child: Semantics(
          checked: selection ? selected : null,
          inMutuallyExclusiveGroup: selection ? true : null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 21,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null && value!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: Text(
                        value!,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Icon(
                    selection
                        ? (selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked)
                        : Icons.chevron_right,
                    size: selection ? 22 : 18,
                    color: selection
                        ? (selected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _SettingsScreen extends StatefulWidget {
  const _SettingsScreen({required this.hub, required this.location});
  final _SettingsHubState hub;
  final _SettingsLocation location;
  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  final query = TextEditingController();
  final scroll = ScrollController();
  final anchors = <String, GlobalKey>{};
  Timer? highlightTimer;
  bool highlight = true;
  bool changingNetwork = false;
  _WalletShellState get shell => widget.hub.shell;
  SettingsDestination get destination => widget.location.destination;
  @override
  void initState() {
    super.initState();
    if (widget.location.anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final target = anchors[widget.location.anchor]?.currentContext;
        if (target != null) {
          Scrollable.ensureVisible(
            target,
            alignment: .2,
            duration: const Duration(milliseconds: 250),
          );
        }
        highlightTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => highlight = false);
        });
      });
    }
  }

  @override
  void dispose() {
    query.dispose();
    scroll.dispose();
    highlightTimer?.cancel();
    super.dispose();
  }

  Widget target(String id, Widget child) => Container(
    key: anchors.putIfAbsent(id, () => GlobalKey()),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: highlight && widget.location.anchor == id
            ? Theme.of(context).colorScheme.primary
            : Colors.transparent,
        width: 2,
      ),
    ),
    child: Semantics(
      label: highlight && widget.location.anchor == id
          ? AppLocalizations.of(context).settingsMatchedOption
          : null,
      child: KeyedSubtree(key: ValueKey('settings-target-$id'), child: child),
    ),
  );
  Widget heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  String title(AppLocalizations s) {
    if (destination == SettingsDestination.directory) return s.msgSettings;
    if (destination == SettingsDestination.search) return s.settingsSearch;
    if (destination == SettingsDestination.network) {
      return shell.allNetworks
          .firstWhere((n) => n.id == widget.location.networkId)
          .name;
    }
    if (destination == SettingsDestination.indexer) {
      return indexerDescriptors
          .firstWhere((d) => d.provider == widget.location.provider)
          .name;
    }
    return settingsEntries
        .firstWhere((e) => e.destination == destination && e.action == null)
        .title(s);
  }

  String path(SettingsEntry entry, AppLocalizations s) {
    final parent = entry.category;
    final label = parent == null
        ? s.msgSettings
        : settingsEntries
              .firstWhere((e) => e.destination == parent && e.category == null)
              .title(s);
    final page = entry.provider != null
        ? entry.title(s)
        : settingsEntries
              .firstWhere(
                (e) => e.destination == entry.destination && e.action == null,
              )
              .title(s);
    return label == page ? '${s.msgSettings} › $label' : '$label › $page';
  }

  String? currentValue(SettingsEntry e, AppLocalizations s) {
    final p = AppSettingsScope.of(context).value;
    return switch (e.id) {
      'language' => languageLabel(context, p.language),
      'appearance' => appearanceLabel(s, p.appearance),
      'display-mode' || 'display' =>
        p.display == AssetDisplay.simple
            ? s.portfolioSimple
            : s.portfolioDetailed,
      'initial-count' =>
        p.limit == 0 ? s.portfolioAll : localized(context, p.limit),
      'sort' => switch (p.sort) {
        AssetSort.value => s.portfolioSortValue,
        AssetSort.stableFirst => s.portfolioStableFirst,
        AssetSort.name => s.portfolioSortName,
      },
      'hide-zero' =>
        p.hideZero ? s.settingsNetworkEnabled : s.settingsNetworkDisabled,
      'show-spam' =>
        p.showSpam ? s.settingsNetworkEnabled : s.settingsNetworkDisabled,
      _ => e.unavailable ? s.settingsUnavailable : null,
    };
  }

  Widget entry(String id, {bool search = false}) {
    final e = settingsEntry(id), s = AppLocalizations.of(context);
    return _SettingsRow(
      key: ValueKey('${search ? 'settings-result' : 'settings-entry'}-$id'),
      title: e.title(s),
      subtitle: search ? path(e, s) : e.description?.call(s),
      value: currentValue(e, s),
      icon: e.icon,
      onTap: () => widget.hub.openEntry(e),
    );
  }

  Widget searchEntry(AppLocalizations s) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      button: true,
      label: s.settingsSearch,
      child: InkWell(
        key: const ValueKey('settings-search-entry'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.hub.open(
          const _SettingsLocation(SettingsDestination.search),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: 12),
              Expanded(child: Text(s.settingsSearchHint)),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> contents(WalletTheme theme, AppLocalizations s) {
    switch (destination) {
      case SettingsDestination.directory:
        return [
          heading(s.settingsQuickLinks),
          for (final id in ['language', 'display', 'networks']) entry(id),
          heading(s.settingsCategories),
          for (final e in settingsEntries.where((e) => e.category == null))
            entry(e.id),
        ];
      case SettingsDestination.search:
        final results = searchSettings(query.text);
        return [
          TextField(
            key: const ValueKey('settings-search-field'),
            controller: query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.settingsSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: s.settingsClearSearch,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(query.clear),
                    ),
            ),
          ),
          if (query.text.trim().isEmpty) ...[
            heading(s.settingsQuickLinks),
            for (final id in ['language', 'display', 'networks'])
              entry(id, search: true),
          ] else if (results.isEmpty) ...[
            const SizedBox(height: 32),
            Text(s.settingsNoResults),
            TextButton(
              onPressed: () => setState(query.clear),
              child: Text(s.settingsClearSearch),
            ),
          ] else ...[
            const SizedBox(height: 12),
            for (final e in results) entry(e.id, search: true),
          ],
        ];
      case SettingsDestination.wallets:
        return [
          Text(
            s.walletAndAccountSummary(
              shell.portfolio.groups.length,
              shell.portfolio.accounts.length,
            ),
          ),
          const SizedBox(height: 12),
          for (final id in ['manage-wallets', 'create-wallet', 'import-wallet'])
            entry(id),
        ];
      case SettingsDestination.importWallet:
        return [
          for (final id in ['import-mnemonic', 'import-key', 'import-file'])
            entry(id),
        ];
      case SettingsDestination.assets:
        return [entry('display'), entry('watched-tokens')];
      case SettingsDestination.display:
        return [AssetDisplayControls(theme: theme, wrap: target)];
      case SettingsDestination.data:
        return [entry('networks'), entry('indexers')];
      case SettingsDestination.networks:
        return [
          entry('enable-networks'),
          entry('add-network'),
          const Divider(),
          for (final n in shell.allNetworks)
            _SettingsRow(
              key: ValueKey('settings-network-${n.id}'),
              title: localized(context, n.name),
              subtitle: networkState(n, s),
              icon: Icons.public,
              onTap: () => widget.hub.open(
                _SettingsLocation(SettingsDestination.network, networkId: n.id),
              ),
            ),
        ];
      case SettingsDestination.network:
        final network = shell.allNetworks.firstWhere(
          (n) => n.id == widget.location.networkId,
        );
        return [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.settingsNetworkState),
            value: shell.enabledNetworks.any((n) => n.id == network.id),
            onChanged: changingNetwork
                ? null
                : (value) async {
                    setState(() => changingNetwork = true);
                    try {
                      final networks = value
                          ? [...shell.enabledNetworks, network]
                          : shell.enabledNetworks
                                .where((n) => n.id != network.id)
                                .toList();
                      await shell._selectNetworks(
                        networks,
                        current:
                            networks.any(
                              (n) => n.id == shell.selectedNetwork?.id,
                            )
                            ? shell.selectedNetwork
                            : null,
                      );
                    } finally {
                      if (mounted) setState(() => changingNetwork = false);
                    }
                  },
          ),
          Text(networkState(network, s)),
          const SizedBox(height: 20),
          Text(
            '${network.identifierLabel} · ${network.nativeSymbol} · ${network.isTestnet ? s.msgTestnet : s.msgMainnet}',
          ),
          heading(s.msgRpcUrl),
          SelectableText(
            network.rpcUrls.join('\n'),
            style: const TextStyle(height: 1.7),
          ),
          const SizedBox(height: 12),
          Text(s.endpointCount(network.rpcUrls.length)),
          if (shell.responsiveNetworkIds.contains(network.id) &&
              shell.networkServices[network.id] != null) ...[
            heading(s.msgActiveEndpoint),
            SelectableText(shell.networkServices[network.id]!.activeRpcUrl),
          ],
          if (shell.networkErrors[network.id] != null) ...[
            const SizedBox(height: 12),
            Text(localized(context, shell.networkErrors[network.id])),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: ValueKey('edit-rpc-${network.id}'),
            onPressed: () => shell._editNetwork(network),
            icon: const Icon(Icons.edit_outlined),
            label: Text(s.msgEditRpc),
          ),
          TextButton.icon(
            onPressed: () => shell._refreshBalance(),
            icon: const Icon(Icons.refresh),
            label: Text(s.msgRefreshBalance),
          ),
        ];
      case SettingsDestination.indexers:
        return [
          Text(
            s.discoveryPrivacy,
            style: TextStyle(color: theme.muted, fontSize: 13, height: 1.5),
          ),
          if (shell.indexerSettings.error != null)
            Text(
              localized(context, shell.indexerSettings.error),
              style: TextStyle(color: theme.danger),
            ),
          const SizedBox(height: 12),
          for (final d in indexerDescriptors)
            _SettingsRow(
              key: ValueKey('settings-provider-${d.provider.name}'),
              title: d.name,
              subtitle: providerNetworks(d),
              value: providerState(d, s),
              icon: Icons.radar,
              onTap: () => widget.hub.open(
                _SettingsLocation(
                  SettingsDestination.indexer,
                  provider: d.provider,
                ),
              ),
            ),
        ];
      case SettingsDestination.indexer:
        final d = indexerDescriptors.firstWhere(
          (d) => d.provider == widget.location.provider,
        );
        final config = shell.indexerSettings.forProvider(d.provider);
        final eligible = shell.enabledNetworks.any(
          (n) => d.networkIds.contains(n.id),
        );
        return [
          Text(providerNetworks(d), style: TextStyle(color: theme.primary)),
          const SizedBox(height: 8),
          Text(providerState(d, s)),
          const SizedBox(height: 20),
          Text(tr(context, d.guide), style: const TextStyle(height: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => openServiceLink(context, d.signup),
                child: Text(s.discoveryGetKey),
              ),
              TextButton(
                onPressed: () => openServiceLink(context, d.docs),
                child: Text(s.discoveryDocs),
              ),
              TextButton(
                onPressed: () => openServiceLink(context, d.plans),
                child: Text(s.discoveryPlans),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!eligible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.discoveryNoEnabledNetworks),
            ),
          FilledButton(
            key: ValueKey('configure-${d.provider.name}'),
            onPressed: shell.indexerSettings.busy || !eligible
                ? null
                : () => showWalletPanel<void>(
                    context: context,
                    width: 600,
                    builder: (_) => IndexerConfigPanel(
                      theme: theme,
                      descriptor: d,
                      initial: shell.indexerSettings.forProvider(d.provider),
                      networks: shell.enabledNetworks
                          .where((n) => d.networkIds.contains(n.id))
                          .toList(),
                      onSave: shell.indexerSettings.save,
                      onTest: shell.testIndexerConnection,
                    ),
                  ),
            child: Text(s.discoveryEdit),
          ),
          if (config != null) ...[
            if (config.enabled && config.networkIds.isNotEmpty)
              OutlinedButton(
                onPressed: shell.indexerSettings.busy
                    ? null
                    : () => changeIndexer(
                        () => shell.indexerSettings.save(
                          config.copyWith(enabled: false),
                        ),
                      ),
                child: Text(s.discoveryDisable),
              ),
            TextButton(
              onPressed: shell.indexerSettings.busy
                  ? null
                  : () => changeIndexer(
                      () => shell.indexerSettings.remove(d.provider),
                    ),
              child: Text(s.discoveryDelete),
            ),
          ],
        ];
      case SettingsDestination.securityBackup:
        return [entry('security'), entry('backup')];
      case SettingsDestination.security:
        return [
          heading(s.msgWalletAddress),
          SelectableText(
            shell.account?.addressFor(shell.selectedNetwork) ?? '',
          ),
          heading(
            shell.activeEntry?.kind == WalletKind.privateKey
                ? s.msgAccountSource
                : s.msgDerivationPath,
          ),
          SelectableText(
            shell.activeEntry?.kind == WalletKind.privateKey
                ? s.msgPrivateKeyImport
                : shell.activeEntry?.derivationPathFor(shell.selectedNetwork) ??
                      evmDerivationPath,
          ),
          const SizedBox(height: 20),
          Text(
            s.msgRecoveryPhrasesAndPrivateKeysRemainInSecure,
            style: const TextStyle(height: 1.6),
          ),
        ];
      case SettingsDestination.backup:
        return [
          Text(s.settingsBackupHint, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 16),
          target(
            'cloud-backup',
            FilledButton(
              onPressed: null,
              child: Text(
                s.msgIcloudGoogleDriveBackupNotConnected,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ];
      case SettingsDestination.general:
        return [entry('language'), entry('appearance')];
      case SettingsDestination.language:
        final preferences = AppSettingsScope.of(context);
        return [
          target(
            'language',
            Column(
              children: [
                for (final language in AppLanguage.values)
                  _SettingsRow(
                    key: ValueKey('settings-language-${language.name}'),
                    title: languageLabel(context, language),
                    icon: Icons.language,
                    selection: true,
                    selected: preferences.value.language == language,
                    onTap: () => preferences.update(language: language),
                  ),
              ],
            ),
          ),
          if (preferences.saveFailed)
            Text(s.msgPreferencesCouldNotBeSavedPreviousSettingsMay),
        ];
      case SettingsDestination.appearance:
        final preferences = AppSettingsScope.of(context);
        return [
          target(
            'appearance',
            Column(
              children: [
                for (final appearance in AppAppearance.values)
                  _SettingsRow(
                    key: ValueKey('settings-theme-${appearance.name}'),
                    title: appearanceLabel(s, appearance),
                    icon: switch (appearance) {
                      AppAppearance.system => Icons.brightness_auto_outlined,
                      AppAppearance.light => Icons.light_mode_outlined,
                      AppAppearance.dark => Icons.dark_mode_outlined,
                    },
                    selection: true,
                    selected: preferences.value.appearance == appearance,
                    onTap: () => preferences.update(appearance: appearance),
                  ),
              ],
            ),
          ),
          if (preferences.saveFailed)
            Text(s.msgPreferencesCouldNotBeSavedPreviousSettingsMay),
        ];
    }
  }

  String networkState(EvmNetwork n, AppLocalizations s) {
    if (!shell.enabledNetworks.any((v) => v.id == n.id)) {
      return s.settingsNetworkDisabled;
    }
    final status = shell.pendingNetworkIds.contains(n.id)
        ? s.msgSyncingMore
        : shell.networkErrors.containsKey(n.id)
        ? s.msgConnectionFailed
        : shell.responsiveNetworkIds.contains(n.id)
        ? s.msgRpcConnected
        : s.msgNotSynced;
    return '${s.settingsNetworkEnabled} · $status';
  }

  String providerNetworks(IndexerDescriptor d) => d.networkIds
      .map((id) => supportedNetworks.firstWhere((n) => n.id == id).name)
      .join(' / ');
  String providerState(IndexerDescriptor d, AppLocalizations s) {
    final config = shell.indexerSettings.forProvider(d.provider);
    return config == null
        ? s.discoveryNotConfiguredShort
        : config.enabled && config.networkIds.isNotEmpty
        ? s.discoveryEnabled
        : s.discoveryDisabled;
  }

  Future<void> changeIndexer(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized(context, walletMessage(e)))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([shell.viewRevision, shell.indexerSettings]),
    builder: (context, _) {
      final layout = WalletLayout.of(context), s = AppLocalizations.of(context);
      final theme = Theme.of(context).brightness == Brightness.dark
          ? WalletTheme.dark
          : WalletTheme.light;
      final parent = _category(destination);
      return Material(
        color: theme.background,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(layout.gutter, 12, layout.gutter, 8),
              child: Row(
                children: [
                  BackButton(onPressed: widget.hub.back),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title(s),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (destination != SettingsDestination.search &&
                      destination != SettingsDestination.directory)
                    IconButton(
                      key: const ValueKey('settings-search-button'),
                      tooltip: s.settingsSearch,
                      onPressed: () => widget.hub.open(
                        const _SettingsLocation(SettingsDestination.search),
                      ),
                      icon: const Icon(Icons.search),
                    ),
                ],
              ),
            ),
            if (layout.wide && parent != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.gutter),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${s.msgSettings} › ${settingsEntries.firstWhere((e) => e.destination == parent && e.category == null).title(s)}${parent != destination ? ' › ${title(s)}' : ''}',
                    style: TextStyle(fontSize: 12, color: theme.muted),
                  ),
                ),
              ),
            if (destination == SettingsDestination.directory)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: layout.gutter),
                child: searchEntry(s),
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  layout.gutter,
                  12,
                  layout.gutter,
                  28,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: contents(theme, s),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
