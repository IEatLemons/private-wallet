import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'wallet_core.dart';
import 'preferences.dart';
import 'quotes.dart';
import 'portfolio_assets.dart';
import 'wallet_balances.dart';
import 'asset_discovery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'l10n/generated/app_localizations.dart';

part 'ui/layout.dart';
part 'ui/dashboard.dart';
part 'ui/navigation.dart';
part 'ui/pages.dart';
part 'ui/panels.dart';
part 'ui/network_editor.dart';
part 'ui/assets.dart';
part 'ui/portfolio_settings.dart';
part 'ui/asset_data.dart';
part 'ui/wallet_balances.dart';
part 'ui/wallet_manager.dart';
part 'ui/omnivault_import.dart';
part 'ui/platform_address_pool.dart';
part 'ui/transfers.dart';
part 'ui/stablecoins.dart';
part 'ui/app_settings.dart';
part 'ui/settings.dart';
part 'ui/localization.dart';

String shortAddress(String address) {
  if (address.length <= 12) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoneWalletApp());
}

enum WalletAction { send, receive, swap }

enum WalletStyle { lightPortfolio, darkCommand }

class WalletTheme {
  const WalletTheme({
    required this.background,
    required this.surface,
    required this.surfaceStrong,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceStrong;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color success;
  final Color warning;
  final Color danger;
  final bool isDark;

  static const light = WalletTheme(
    background: Color(0xFFF5F7FC),
    surface: Colors.white,
    surfaceStrong: Color(0xFFF0F4FF),
    border: Color(0xFFE4E9F2),
    text: Color(0xFF101B43),
    muted: Color(0xFF7A849D),
    primary: Color(0xFF426CF5),
    success: Color(0xFF0EAC7A),
    warning: Color(0xFFD99422),
    danger: Color(0xFFE1585B),
    isDark: false,
  );

  static const dark = WalletTheme(
    background: Color(0xFF0B1020),
    surface: Color(0xFF121A2B),
    surfaceStrong: Color(0xFF19233A),
    border: Color(0xFF283543),
    text: Color(0xFFF2F5F9),
    muted: Color(0xFF8F9BAB),
    primary: Color(0xFF7297FF),
    success: Color(0xFFA9E8CF),
    warning: Color(0xFFEAC45D),
    danger: Color(0xFFF37C7C),
    isDark: true,
  );
}

class StoneWalletApp extends StatefulWidget {
  const StoneWalletApp({
    this.vault,
    this.networkServiceBuilder,
    this.quoteService,
    this.discoveryServiceBuilder,
    super.key,
  });

  final WalletVault? vault;
  final EvmNetworkService Function(EvmNetwork)? networkServiceBuilder;
  final QuoteService? quoteService;
  final AssetDiscoveryService Function(IndexerConfig)? discoveryServiceBuilder;

  @override
  State<StoneWalletApp> createState() => _StoneWalletAppState();
}

class _StoneWalletAppState extends State<StoneWalletApp> {
  late final WalletVault vault;
  late final PreferencesController preferences;
  @override
  void initState() {
    super.initState();
    vault = widget.vault ?? WalletVault();
    preferences = PreferencesController(
      read: vault.readAppPreferences,
      write: vault.writeAppPreferences,
    );
    unawaited(preferences.load());
  }

  @override
  void dispose() {
    preferences.dispose();
    super.dispose();
  }

  void toggleStyle() {
    final dark = switch (preferences.value.appearance) {
      AppAppearance.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
      AppAppearance.light => false,
      AppAppearance.dark => true,
    };
    preferences.update(
      appearance: dark ? AppAppearance.light : AppAppearance.dark,
    );
  }

  ThemeData _themeData(WalletTheme walletTheme) => ThemeData(
    useMaterial3: true,
    brightness: walletTheme.isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: walletTheme.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: walletTheme.primary,
      primary: walletTheme.primary,
      onPrimary: walletTheme.isDark ? const Color(0xFF10234A) : Colors.white,
      brightness: walletTheme.isDark ? Brightness.dark : Brightness.light,
      surface: walletTheme.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: walletTheme.surfaceStrong,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: walletTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: walletTheme.border),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: preferences,
      builder: (context, _) => AppSettingsScope(
        controller: preferences,
        child: MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          locale: selectedLocale(preferences.value.language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          localeListResolutionCallback: resolveWalletLocale,
          debugShowCheckedModeBanner: false,
          theme: _themeData(WalletTheme.light),
          darkTheme: _themeData(WalletTheme.dark),
          themeMode: switch (preferences.value.appearance) {
            AppAppearance.system => ThemeMode.system,
            AppAppearance.light => ThemeMode.light,
            AppAppearance.dark => ThemeMode.dark,
          },
          builder: (context, child) {
            final data = Theme.of(context);
            final walletTheme = data.brightness == Brightness.dark
                ? WalletTheme.dark
                : WalletTheme.light;
            final height = WalletLayout.of(context).controlHeight;
            final style = ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, height)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              textStyle: WidgetStatePropertyAll(
                data.textTheme.labelLarge!.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
            return Theme(
              data: data.copyWith(
                filledButtonTheme: FilledButtonThemeData(style: style),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: style.copyWith(
                    side: WidgetStatePropertyAll(
                      BorderSide(color: walletTheme.border),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(style: style),
              ),
              child: child!,
            );
          },
          home: Builder(
            builder: (context) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return !preferences.loaded
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : WalletShell(
                      walletTheme: dark ? WalletTheme.dark : WalletTheme.light,
                      style: dark
                          ? WalletStyle.darkCommand
                          : WalletStyle.lightPortfolio,
                      onToggleStyle: toggleStyle,
                      vault: vault,
                      networkServiceBuilder: widget.networkServiceBuilder,
                      quoteService: widget.quoteService,
                      discoveryServiceBuilder: widget.discoveryServiceBuilder,
                    );
            },
          ),
        ),
      ),
    );
  }
}

class WalletShell extends StatefulWidget {
  const WalletShell({
    required this.walletTheme,
    required this.style,
    required this.onToggleStyle,
    this.vault,
    this.networkServiceBuilder,
    this.quoteService,
    this.discoveryServiceBuilder,
    super.key,
  });

  final WalletTheme walletTheme;
  final WalletStyle style;
  final VoidCallback onToggleStyle;
  final WalletVault? vault;
  final EvmNetworkService Function(EvmNetwork)? networkServiceBuilder;
  final QuoteService? quoteService;
  final AssetDiscoveryService Function(IndexerConfig)? discoveryServiceBuilder;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  late final QuoteService quoteService;
  late final IndexerSettings indexerSettings;
  WalletBalanceScan? _walletBalanceScan;
  final Map<QuoteAsset, PriceQuote> quotes = {};
  final Map<int, DiscoverySnapshot> discoverySnapshots = {};
  final Map<int, AssetDiscoveryService> discoveryClients = {};
  final Map<int, Set<String>> discoveryCursors = {};
  int quoteRequest = 0, discoveryRequest = 0;
  bool quoteLoading = false;
  String indexerSignature = '[]';
  final viewRevision = ValueNotifier<int>(0);
  final assetScroll = ScrollController();
  final _settingsHub = GlobalKey<_SettingsHubState>();
  SettingsDestination? _settingsDestination;
  bool _addressPoolOpen = false;
  void _updateView(VoidCallback fn) {
    setState(fn);
    viewRevision.value++;
  }

  String walletName = '';
  bool isLoadingWallet = true;
  bool isRefreshing = false;
  WalletAccount? account;
  WalletPortfolio portfolio = const WalletPortfolio(groups: []);
  WalletEntry? get activeEntry => portfolio.selected;
  EvmNetwork? selectedNetwork;
  List<EvmNetwork> enabledNetworks = const [];
  List<EvmNetwork> allNetworks = List.of(supportedNetworks);
  BigInt? balanceWei;
  List<TokenDefinition> watchedTokens = builtinTokens
      .where((t) => t.defaultVisible)
      .toList();
  final Map<String, BigInt> tokenUnits = {};
  final Map<String, WalletMessage> tokenErrors = {};
  final Set<String> pendingTokens = {};
  WalletMessage? tokenCatalogError;

  List<TokenHolding> get tokenHoldings => [
    for (final token in watchedTokens)
      if (_networkForId(token.networkId) case final EvmNetwork network)
        TokenHolding(
          token: token,
          network: network,
          units: tokenUnits[token.key],
          error: tokenErrors[token.key],
          state: !enabledNetworks.any((n) => n.id == token.networkId)
              ? TokenState.disabled
              : pendingTokens.contains(token.key)
              ? TokenState.pending
              : tokenErrors.containsKey(token.key)
              ? TokenState.failed
              : tokenUnits.containsKey(token.key)
              ? TokenState.ready
              : TokenState.pending,
        ),
  ];

  final Map<int, BigInt?> balancesByNetwork = {};
  final Set<int> responsiveNetworkIds = <int>{};
  final Set<int> pendingNetworkIds = {};
  final Map<int, WalletMessage> networkErrors = {};
  int balanceRequest = 0;
  WalletMessage? walletError;
  String? lastTxHash;
  EvmNetwork? lastTxNetwork;
  bool lastTxUncertain = false;
  DateTime? lastSyncedAt;

  late final WalletVault vault;
  final Map<int, EvmNetworkService> networkServices = {};

  List<AssetRow> get assets {
    if (enabledNetworks.isEmpty) {
      return [
        AssetRow(
          symbol: '—',
          name: WalletMessage(MessageCode.msgNoNetworkSelected),
          network: WalletMessage(MessageCode.msgChooseANetworkToView),
          amount: '—',
          value: WalletMessage(MessageCode.msgRpcNotConnected),
          change: '—',
          icon: Icons.public,
          color: Color(0xFF627EEA),
        ),
      ];
    }

    return enabledNetworks.map((network) {
      final balance = balancesByNetwork[network.id];
      return AssetRow(
        networkId: network.id,
        error: networkErrors[network.id],
        symbol: network.nativeSymbol,
        name: network.name,
        network: _networkLabel(network),
        amount: balance == null
            ? '— ${network.nativeSymbol}'
            : '${network.formatAmount(balance)} ${network.nativeSymbol}',
        value: WalletMessage(MessageCode.msgNativeAsset),
        change: pendingNetworkIds.contains(network.id)
            ? WalletMessage(MessageCode.msgSyncing)
            : networkErrors.containsKey(network.id)
            ? WalletMessage(MessageCode.msgConnectionFailed)
            : balance == null
            ? WalletMessage(MessageCode.msgAwaitingSync)
            : WalletMessage(MessageCode.msgSynced),
        icon: Icons.diamond_outlined,
        color: network.isTestnet
            ? const Color(0xFF9B7BFF)
            : const Color(0xFF627EEA),
      );
    }).toList();
  }

  WalletTheme get theme => widget.walletTheme;

  bool get isDark => widget.style == WalletStyle.darkCommand;

  @override
  void initState() {
    super.initState();
    vault = widget.vault ?? WalletVault();
    quoteService = widget.quoteService ?? BinanceQuoteService();
    indexerSettings = IndexerSettings(
      read: vault.readAssetIndexerConfigs,
      write: vault.writeAssetIndexerConfigs,
    )..addListener(onIndexerSettingsChanged);
    unawaited(_loadWallet());
  }

  @override
  void dispose() {
    _walletBalanceScan?.dispose();
    clearDiscovery();
    indexerSettings.removeListener(onIndexerSettingsChanged);
    indexerSettings.dispose();
    if (widget.quoteService == null) quoteService.dispose();
    assetScroll.dispose();
    viewRevision.dispose();
    for (final service in networkServices.values) {
      unawaited(service.dispose());
    }
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      await indexerSettings.load();
      final loaded = await vault.loadWalletSummary();
      allNetworks = await vault.loadNetworks();
      try {
        watchedTokens = await vault.loadTokens();
      } catch (error) {
        tokenCatalogError = walletMessage(error);
        watchedTokens = [];
      }
      final selectedIds = await vault.loadSelectedNetworkIds();
      final pendingImportId = await vault.loadPendingImportNetwork();
      final currentId = pendingImportId ?? await vault.loadSelectedNetworkId();
      final loadedNetworks = {
        ...selectedIds,
        ?pendingImportId,
      }.map(_networkForId).whereType<EvmNetwork>().toList();
      final loadedNetwork =
          _networkForId(currentId) ??
          (loadedNetworks.isEmpty ? null : loadedNetworks.first);
      if (!mounted) return;
      _updateView(() {
        portfolio = loaded;
        account = loaded.selected?.account;
        walletName =
            loaded.selected?.displayName ?? tr(context, MessageCode.msgWallet);
        enabledNetworks = loadedNetworks;
        selectedNetwork = loadedNetwork;
        isLoadingWallet = false;
      });
      if (account != null && loadedNetworks.isNotEmpty) {
        if (pendingImportId != null && loadedNetwork != null) {
          try {
            await vault.saveSelectedNetworks(
              loadedNetworks,
              current: loadedNetwork,
            );
            await vault.acknowledgeImportNetwork(pendingImportId);
          } catch (error) {
            if (mounted) _showMessage(walletMessage(error));
          }
          if (!mounted) return;
        }
        _configureNetworks(loadedNetworks, current: loadedNetwork);
        await _refreshBalance();
      }
    } catch (error) {
      if (!mounted) return;
      _updateView(() {
        walletError = walletMessage(error);
        isLoadingWallet = false;
      });
    }
  }

  EvmNetworkService _makeService(EvmNetwork network) =>
      widget.networkServiceBuilder?.call(network) ??
      EvmNetworkService(network: network);

  WalletMessage _connectionError(Object error) {
    if (error is WalletInputException) return error.message;
    if (error is TimeoutException) {
      return WalletMessage(MessageCode.msgRpcRequestTimedOutCheckTheUrlOr);
    }
    return WalletMessage(
      MessageCode.msgRpcRequestFailedCheckTheNetworkEndpointOr,
    );
  }

  Future<void> _refreshBalance() async {
    final currentAccount = account;
    if (!mounted || currentAccount == null || networkServices.isEmpty) return;
    final request = ++balanceRequest;
    unawaited(refreshDiscovery());
    final services = networkServices.entries.toList();
    _updateView(() {
      isRefreshing = true;
      walletError = null;
      tokenUnits.clear();
      tokenErrors.clear();
      pendingTokens
        ..clear()
        ..addAll(
          watchedTokens
              .where((t) => networkServices.containsKey(t.networkId))
              .map((t) => t.key),
        );
      pendingNetworkIds
        ..clear()
        ..addAll(services.map((e) => e.key));
      networkErrors.clear();
    });
    await Future.wait(
      services.map((entry) async {
        final tokensFuture = _readTokenBalances(
          entry.value,
          currentAccount,
          request,
        );
        BigInt? balance;
        WalletMessage? failure;
        try {
          balance = (await entry.value.getNativeBalance(
            currentAccount,
          )).getInWei;
        } catch (error) {
          failure = _connectionError(error);
        }
        if (!mounted ||
            request != balanceRequest ||
            account != currentAccount) {
          await tokensFuture;
          return;
        }
        _updateView(() {
          balancesByNetwork[entry.key] = balance;
          pendingNetworkIds.remove(entry.key);
          if (failure == null) {
            responsiveNetworkIds.add(entry.key);
            networkErrors.remove(entry.key);
          } else {
            responsiveNetworkIds.remove(entry.key);
            networkErrors[entry.key] = failure;
          }
          balanceWei = balancesByNetwork[selectedNetwork?.id];
        });
        await tokensFuture;
      }),
    );
    if (!mounted || request != balanceRequest || account != currentAccount) {
      return;
    }
    _updateView(() {
      isRefreshing = false;
      lastSyncedAt = DateTime.now();
      final failed = enabledNetworks
          .where((n) => networkErrors.containsKey(n.id))
          .map((n) => n.name);
      walletError = failed.isEmpty
          ? null
          : WalletMessage(MessageCode.msgCouldNotConnectToEditRpcSettingsOr, [
              failed.join('、'),
            ]);
    });
    unawaited(refreshQuotes());
  }

  Future<void> _readTokenBalances(
    EvmNetworkService service,
    WalletAccount owner,
    int request,
  ) async {
    final tokens = watchedTokens
        .where((t) => t.networkId == service.network.id)
        .toList();
    for (final token in tokens) {
      if (!mounted || request != balanceRequest || owner != account) return;
      BigInt? units;
      WalletMessage? error;
      try {
        units = await service.getTokenBalance(owner, token);
      } catch (e) {
        error = _connectionError(e);
      }
      if (!mounted || request != balanceRequest || owner != account) return;
      _updateView(() {
        pendingTokens.remove(token.key);
        if (units != null) tokenUnits[token.key] = units;
        if (error != null) tokenErrors[token.key] = error;
      });
    }
  }

  Future<void> _manageTokens() async {
    if (tokenCatalogError != null) {
      _showMessage(tokenCatalogError!);
      return;
    }
    await showWalletPanel<void>(
      context: context,
      width: 640,
      builder: (_) => TokenManagerPanel(
        theme: theme,
        networks: allNetworks,
        initial: watchedTokens,
        onInspect: (network, contract) async {
          final service = _makeService(network);
          try {
            return await service.inspectToken(contract);
          } finally {
            await service.dispose();
          }
        },
        onSave: (tokens) async {
          await vault.saveTokens(tokens);
          if (!mounted) return;
          _updateView(() => watchedTokens = List.of(tokens));
          unawaited(_refreshBalance());
        },
      ),
    );
  }

  EvmNetwork? _networkForId(int? id) =>
      allNetworks.where((network) => network.id == id).firstOrNull;

  String _networkLabel(EvmNetwork network) =>
      '${network.name} · ${network.isTestnet ? tr(context, MessageCode.msgTestnet) : tr(context, MessageCode.msgMainnet)}';

  void _configureNetworks(List<EvmNetwork> networks, {EvmNetwork? current}) {
    clearDiscovery();
    ++balanceRequest;
    final byId = {for (final n in networks) n.id: n};
    for (final entry in networkServices.entries.toList()) {
      final next = byId[entry.key];
      if (next == null ||
          jsonEncode(next.toJson()) !=
              jsonEncode(entry.value.network.toJson())) {
        unawaited(entry.value.dispose());
        networkServices.remove(entry.key);
        balancesByNetwork.remove(entry.key);
        responsiveNetworkIds.remove(entry.key);
      }
    }
    for (final network in byId.values) {
      networkServices.putIfAbsent(network.id, () => _makeService(network));
    }
    final nextCurrent = byId[current?.id] ?? byId.values.firstOrNull;
    if (!mounted) return;
    _updateView(() {
      enabledNetworks = List.unmodifiable(byId.values);
      selectedNetwork = nextCurrent;
      balancesByNetwork.removeWhere((id, _) => !byId.containsKey(id));
      responsiveNetworkIds.removeWhere((id) => !byId.containsKey(id));
      pendingNetworkIds.clear();
      networkErrors.clear();
      tokenUnits.clear();
      tokenErrors.clear();
      pendingTokens.clear();
      isRefreshing = false;
      balanceWei = balancesByNetwork[nextCurrent?.id];
      lastTxHash = null;
      lastTxNetwork = null;
      lastTxUncertain = false;
      walletError = null;
    });
  }

  Future<void> _selectNetworks(
    List<EvmNetwork> networks, {
    EvmNetwork? current,
    bool waitForBalance = true,
  }) async {
    try {
      await vault.saveSelectedNetworks(networks, current: current);
      if (!mounted) return;
      _configureNetworks(networks, current: current);
      final refresh = _refreshBalance();
      if (waitForBalance) {
        await refresh;
      } else {
        unawaited(refresh);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          WalletMessage(
            MessageCode.msgCouldNotSaveNetworkSelectionPleaseTryAgain,
          ),
        );
      }
    }
  }

  Future<void> _clearNetwork() => _selectNetworks(const []);

  String _newMnemonicName(int number) => number == 1
      ? tr(context, MessageCode.msgMainWallet)
      : tr(context, MessageCode.msgWalletMore, [number]);

  String _newPrivateKeyName(int number) =>
      tr(context, MessageCode.msgPrivateKeyAccount, [number]);
  String get _firstAccountName => tr(context, MessageCode.msgAccountMore, [1]);

  Future<void> _createWallet() async {
    try {
      final creation = await vault.prepareNewWallet();
      if (!mounted) return;
      final allowCancel = portfolio.groupCount > 0;
      final confirmed = await showWalletPanel<bool>(
        context: context,
        width: 640,
        dismissible: allowCancel,
        mobileFullscreen: true,
        builder: (context) => RecoveryPhraseSheet(
          theme: theme,
          mnemonic: creation.mnemonic,
          allowCancel: allowCancel,
        ),
      );
      if (confirmed != true) return;
      await vault.saveRecoveryPhrase(
        creation.mnemonic,
        nameForWallet: _newMnemonicName,
        accountName: _firstAccountName,
      );
      await _reloadPortfolio(showAssets: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(walletMessage(error));
    }
  }

  Future<void> _importWallet() async {
    final mnemonic = await showWalletPanel<String>(
      context: context,
      builder: (context) => ImportWalletDialog(theme: theme),
    );
    if (mnemonic == null || mnemonic.trim().isEmpty) return;
    try {
      await vault.importWallet(
        mnemonic,
        nameForWallet: _newMnemonicName,
        accountName: _firstAccountName,
      );
      await _reloadPortfolio(showAssets: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(walletMessage(error));
    }
  }

  Future<void> _importPrivateKey() async {
    final imported = await showWalletPanel<ImportedWallet>(
      context: context,
      builder: (context) => ImportPrivateKeyPanel(
        theme: theme,
        networks: allNetworks,
        currentNetwork: selectedNetwork,
        onImport: (privateKey, network) => vault.importPrivateKeyWallet(
          privateKey: privateKey,
          networkId: network.id,
          nameForWallet: _newPrivateKeyName,
          accountName: _firstAccountName,
        ),
      ),
    );
    if (!mounted || imported == null) return;
    try {
      await _reloadPortfolio(showAssets: true, useAccountNetwork: true);
      if (mounted) {
        _showMessage(WalletMessage(MessageCode.msgPrivateKeyAccountImported));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
          WalletMessage(MessageCode.msgTheAccountWasSavedButCouldNotBe),
        );
      }
    }
  }

  bool _batchImportOpen = false;

  Future<void> _importBatchWallets() async {
    if (_batchImportOpen) return;
    _batchImportOpen = true;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt'],
        withData: !vault.supportsOmniVaultImport,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (vault.supportsOmniVaultImport && file.path != null) {
        final result = await showWalletPanel<_OmniPanelResult>(
          context: context,
          width: 760,
          dismissible: false,
          builder: (_) => _OmniVaultImportPanel(
            theme: theme,
            vault: vault,
            path: file.path!,
            accountName: _firstAccountName,
            onCommitted: _applyOmniImport,
          ),
        );
        if (!mounted || result != _OmniPanelResult.legacy) return;
      }
      final content = file.bytes == null
          ? (file.path == null ? null : await File(file.path!).readAsString())
          : utf8.decode(file.bytes!);
      if (!mounted) return;
      if (content == null) {
        _showMessage(WalletMessage(MessageCode.msgCannotReadThisFile));
        return;
      }
      final rows = _parseWalletImportTable(content);
      if (rows.isEmpty) {
        _showMessage(
          WalletMessage(
            MessageCode.msgNoImportableRowsTheHeaderMustContainChain,
          ),
        );
        return;
      }
      final result = await vault.importPrivateKeyWallets(
        rows,
        nameForWallet: _newPrivateKeyName,
        accountName: _firstAccountName,
      );
      final loaded = await vault.loadWalletSummary();
      if (!mounted) return;
      _applyPortfolio(loaded);
      final failures = result.errors.length;
      _showMessage(
        WalletMessage(MessageCode.importedRowSummary, [
          result.imported.length,
          failures == 0 ? '' : WalletMessage(MessageCode.msgFailed, [failures]),
        ]),
      );
      final importedNetworks = result.imported
          .map((wallet) => _networkForId(wallet.networkId))
          .whereType<EvmNetwork>()
          .toList();
      if (importedNetworks.isNotEmpty) {
        final networks = {
          for (final n in [...enabledNetworks, ...importedNetworks]) n.id: n,
        }.values.toList();
        _configureNetworks(networks, current: importedNetworks.first);
        await vault.saveSelectedNetworks(
          networks,
          current: importedNetworks.first,
        );
        if (mounted) unawaited(_refreshBalance());
      }
      if (mounted) {
        await showWalletPanel<void>(
          context: context,
          width: 640,
          builder: (context) => ImportResultDialog(
            theme: theme,
            errors: result.errors,
            importedCount: result.imported.length,
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(walletMessage(error));
    } finally {
      _batchImportOpen = false;
    }
  }

  Future<void> _applyOmniImport(OmniImportCommit result) async {
    if (result.initialNetworkId case final id?) {
      _applyPortfolio(result.portfolio);
      final network = _networkForId(id);
      if (network == null) return;
      // Select the chain without an RPC request. Normal asset refresh remains available.
      final networks = {
        for (final enabled in [...enabledNetworks, network])
          enabled.id: enabled,
      }.values.toList();
      _configureNetworks(networks, current: network);
      await vault.saveSelectedNetworks(networks, current: network);
      await vault.acknowledgeImportNetwork(id);
    } else {
      _updateView(() => portfolio = result.portfolio);
    }
  }

  List<WalletImportRow> _parseWalletImportTable(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final separator = lines.first.contains('\t') ? '\t' : ',';
    final header = _splitTableLine(
      lines.first,
      separator,
    ).map((cell) => cell.trim().toLowerCase()).toList();
    int findColumn(List<String> names) => header.indexWhere(names.contains);
    final chainIndex = findColumn([
      '链',
      'chain',
      'network',
      'chainid',
      'chain id',
    ]);
    final keyIndex = findColumn([
      '私钥',
      'privatekey',
      'private key',
      if (vault.supportsOmniVaultImport) 'private_key',
      'key',
    ]);
    final start = chainIndex >= 0 && keyIndex >= 0 ? 1 : 0;
    if (chainIndex < 0 || keyIndex < 0) return const [];
    final rows = <WalletImportRow>[];
    for (final line in lines.skip(start)) {
      final cells = _splitTableLine(line, separator);
      if (cells.length <= chainIndex || cells.length <= keyIndex) continue;
      rows.add(
        WalletImportRow(chain: cells[chainIndex], privateKey: cells[keyIndex]),
      );
    }
    return rows;
  }

  List<String> _splitTableLine(String line, String separator) {
    final cells = <String>[];
    var buffer = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == separator && !quoted) {
        cells.add(buffer.toString().trim());
        buffer = StringBuffer();
      } else {
        buffer.write(char);
      }
    }
    cells.add(buffer.toString().trim());
    return cells;
  }

  void _showMessage(Object message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) => Text(localized(context, message)),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNetworkSelector() async {
    final result = await showWalletPanel<NetworkSelectionResult>(
      context: context,
      width: 560,
      builder: (context) => NetworkSelectorSheet(
        theme: theme,
        networks: allNetworks,
        onEdit: _editNetwork,
        selectedNetworks: enabledNetworks,
        currentNetwork: selectedNetwork,
      ),
    );
    if (result == null) return;
    if (result.clear || result.networks.isEmpty) {
      await _clearNetwork();
    } else {
      final current = result.current ?? result.networks.first;
      _showMessage(
        WalletMessage(MessageCode.msgSelectedConnectingToRpc, [current.name]),
      );
      await _selectNetworks(result.networks, current: result.current);
    }
  }

  Future<EvmNetwork?> _editNetwork(EvmNetwork? network) async {
    final saved = await showWalletPanel<EvmNetwork>(
      context: context,
      width: 560,
      builder: (_) => NetworkEditorPanel(
        theme: theme,
        networks: allNetworks,
        network: network,
        onSave: vault.saveNetwork,
        onCheck: (value) async {
          final service = _makeService(value);
          try {
            await service.checkConnection();
          } finally {
            await service.dispose();
          }
        },
      ),
    );
    if (!mounted || saved == null) return null;
    final catalog = await vault.loadNetworks();
    if (!mounted) return null;
    _updateView(() => allNetworks = catalog);
    if (enabledNetworks.any((n) => n.id == saved.id)) {
      final active = enabledNetworks
          .map((n) => n.id == saved.id ? saved : n)
          .toList();
      _configureNetworks(
        active,
        current: selectedNetwork?.id == saved.id ? saved : selectedNetwork,
      );
      unawaited(_refreshBalance());
    }
    _showMessage(
      WalletMessage(MessageCode.msgNetworkSettingsSaved, [saved.name]),
    );
    return saved;
  }

  Future<void> _addNetwork() async {
    final network = await _editNetwork(null);
    if (!mounted || network == null) return;
    await _selectNetworks([...enabledNetworks, network], current: network);
  }

  void _goToAssets() {
    if (_settingsDestination == null && !_addressPoolOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _settingsDestination = null;
      _addressPoolOpen = false;
    });
    unawaited(refreshQuotes());
  }

  void _openOmniPools() {
    if (!vault.supportsOmniVaultImport || _addressPoolOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _settingsDestination = null;
      _addressPoolOpen = true;
    });
  }

  void _openSettings({
    SettingsDestination initial = SettingsDestination.directory,
  }) {
    if (_settingsDestination != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _addressPoolOpen = false;
      _settingsDestination = initial;
    });
  }

  Future<void> _showAssetDetails(AssetRow asset) async {
    final network = _networkForId(asset.networkId);
    if (network == null) {
      await _showNetworkSelector();
      return;
    }
    final originalAccount = account!;
    final action = await showWalletPanel<WalletAction>(
      context: context,
      width: 560,
      builder: (panelContext) => AssetDetailsPanel(
        theme: theme,
        asset: asset,
        network: network,
        address: originalAccount.addressFor(network),
        onRefresh: () async {
          await _refreshBalance();
          return assets.firstWhere((a) => a.networkId == network.id);
        },
        onActivate: () async {
          Navigator.pop(panelContext);
          await _selectNetworks(enabledNetworks, current: network);
        },
        onAction: (action) async => closeWalletPanel(panelContext, action),
      ),
    );
    if (!mounted || action == null || account != originalAccount) return;
    if (action == WalletAction.send) {
      await _showSendSheet(network: network);
    } else {
      await _selectNetworks(
        enabledNetworks,
        current: network,
        waitForBalance: false,
      );
      if (!mounted ||
          account != originalAccount ||
          selectedNetwork?.id != network.id) {
        return;
      }
      showAction(action, network: network);
    }
  }

  void showAction(WalletAction action, {EvmNetwork? network}) {
    final chain = network ?? selectedNetwork;
    if (action == WalletAction.send) {
      unawaited(_showSendSheet(network: chain));
      return;
    }
    if (action == WalletAction.swap) {
      _showMessage(
        WalletMessage(MessageCode.msgSwapsAreNotConnectedNoOrderOrSignature),
      );
      return;
    }
    showWalletPanel<void>(
      context: context,
      builder: (context) => ActionSheet(
        action: action,
        theme: theme,
        walletName: walletName,
        network: chain,
        address:
            account?.addressFor(chain) ??
            tr(context, MessageCode.msgUnavailable),
        onConfirm: () {
          Navigator.of(context).pop();
          if (action == WalletAction.receive && account != null) {
            Clipboard.setData(ClipboardData(text: account!.addressFor(chain)));
            _showMessage(WalletMessage(MessageCode.msgAddressCopied));
          }
        },
      ),
    );
  }

  Future<void> _chooseSendAsset() async {
    if (enabledNetworks.isEmpty) {
      await _showNetworkSelector();
      if (!mounted || enabledNetworks.isEmpty) return;
    }
    final holdings =
        portfolioPositions.where((holding) => !holding.spam).toList()
          ..sort((a, b) {
            final aFunded = a.known && a.units! > BigInt.zero;
            final bFunded = b.known && b.units! > BigInt.zero;
            if (aFunded != bFunded) return aFunded ? -1 : 1;
            final chain = a.network.name.compareTo(b.network.name);
            if (chain != 0) return chain;
            return a.symbol.compareTo(b.symbol);
          });
    final holding = await showWalletPanel<PortfolioHolding>(
      context: context,
      width: 520,
      builder: (_) => _SendAssetPanel(theme: theme, holdings: holdings),
    );
    if (!mounted ||
        holding == null ||
        account?.addressFor(holding.network) != holding.address) {
      return;
    }
    await _showSendSheet(network: holding.network, token: holding.token);
  }

  Future<void> _showSendSheet({
    required EvmNetwork? network,
    TokenDefinition? token,
  }) async {
    final currentAccount = account;
    if (currentAccount == null) return;
    final service = networkServices[network?.id];
    if (network == null || service == null) {
      _showMessage(WalletMessage(MessageCode.msgSelectANetworkBeforeSending));
      return;
    }
    void checkAccountAndNetwork() {
      if (account != currentAccount || networkServices[network.id] != service) {
        throw const WalletInputException(
          MessageCode.msgTheAccountHasChangedReopenThisAsset,
        );
      }
    }

    final txHash = await showWalletPanel<String>(
      context: context,
      dismissible: false,
      builder: (context) => SendSheet(
        theme: theme,
        network: network,
        token: token,
        fromAddress: currentAccount.addressFor(network),
        balanceWei: token == null
            ? balancesByNetwork[network.id]
            : tokenUnits[token.key],
        onPrepare: (recipient, amount) {
          checkAccountAndNetwork();
          return service.prepareTransfer(
            account: currentAccount,
            recipient: recipient,
            amount: amount,
            token: token,
          );
        },
        onConfirmTransfer: (transfer) async {
          checkAccountAndNetwork();
          try {
            return await transfer.broadcast();
          } on RpcBroadcastException catch (error) {
            if (mounted && account == currentAccount) {
              _updateView(() {
                lastTxHash = error.transactionHash;
                lastTxNetwork = network;
                lastTxUncertain = true;
              });
            }
            rethrow;
          }
        },
      ),
    );
    if (!mounted || txHash == null || account != currentAccount) return;
    _updateView(() {
      lastTxHash = txHash;
      lastTxNetwork = network;
      lastTxUncertain = false;
    });
    _showMessage(WalletMessage(MessageCode.msgTransactionBroadcast, [txHash]));
    unawaited(_refreshBalance());
  }

  void _applyPortfolio(WalletPortfolio loaded, {bool showAssets = false}) {
    ++balanceRequest;
    ++quoteRequest;
    quoteLoading = false;
    clearDiscovery();
    _updateView(() {
      portfolio = loaded;
      account = loaded.selected?.account;
      walletName =
          loaded.selected?.displayName ?? tr(context, MessageCode.msgWallet);

      isLoadingWallet = false;
      balanceWei = null;
      balancesByNetwork.clear();
      responsiveNetworkIds.clear();
      pendingNetworkIds.clear();
      networkErrors.clear();
      tokenUnits.clear();
      tokenErrors.clear();
      pendingTokens.clear();
      isRefreshing = false;
      lastTxHash = null;
      lastTxNetwork = null;
      lastTxUncertain = false;
      walletError = null;
    });
    if (showAssets) _goToAssets();
  }

  Future<void> _reloadPortfolio({
    bool showAssets = false,
    bool useAccountNetwork = false,
  }) async {
    final loaded = await vault.loadWalletSummary();
    if (!mounted) return;
    _applyPortfolio(loaded, showAssets: showAssets);
    final network = useAccountNetwork
        ? _networkForId(loaded.selected?.preferredNetworkId)
        : null;
    if (network != null) {
      await _selectNetworks(
        {
          for (final n in [...enabledNetworks, network]) n.id: n,
        }.values.toList(),
        current: network,
        waitForBalance: false,
      );
    } else {
      unawaited(_refreshBalance());
    }
  }

  Future<void> _runWalletAction(WalletManagerAction action) async {
    switch (action) {
      case WalletManagerAction.create:
        await _createWallet();
      case WalletManagerAction.importMnemonic:
        await _importWallet();
      case WalletManagerAction.importPrivateKey:
        await _importPrivateKey();
      case WalletManagerAction.batchImport:
        await _importBatchWallets();
      case WalletManagerAction.importOptions:
        final choice = await showWalletPanel<WalletManagerAction>(
          context: context,
          builder: (_) => WalletImportOptions(
            theme: theme,
            supportsOmniVault: vault.supportsOmniVaultImport,
          ),
        );
        if (mounted && choice != null) await _runWalletAction(choice);
      case WalletManagerAction.selected:
        break;
    }
  }

  Future<void> selectWallet() async {
    final result = await showWalletPanel<WalletManagerAction>(
      context: context,
      width: 640,
      builder: (_) => WalletManagerPanel(
        theme: theme,
        initial: portfolio,
        vault: vault,
        network: selectedNetwork ?? ethereumMainnetNetwork,
      ),
    );
    if (!mounted) return;
    try {
      await _reloadPortfolio(
        useAccountNetwork: result == WalletManagerAction.selected,
      );
      if (mounted && result != null) await _runWalletAction(result);
    } catch (error) {
      if (mounted) {
        _showMessage(
          error is WalletInputException
              ? error.message
              : WalletMessage(
                  MessageCode.msgWalletOperationFailedPleaseTryAgain,
                ),
        );
      }
    }
  }

  TextStyle textStyle(double size, FontWeight weight, {Color? color}) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? theme.text,
      letterSpacing: size <= 13 ? 0.1 : -0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingWallet) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }
    if (account == null && _addressPoolOpen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goToAssets();
        },
        child: Scaffold(
          body: SafeArea(
            child: _OmniPoolPage(vault: vault, onBack: _goToAssets),
          ),
        ),
      );
    }
    if (account == null) {
      return Scaffold(
        body: SafeArea(
          child: OnboardingPage(
            theme: theme,
            error: walletError,
            onCreate: _createWallet,
            onImport: _importWallet,
            onImportPrivateKey: _importPrivateKey,
            onBatchImport: _importBatchWallets,
            supportsOmniVault: vault.supportsOmniVaultImport,
            onAddressPool: vault.supportsOmniVaultImport
                ? _openOmniPools
                : null,
            onToggleStyle: widget.onToggleStyle,
          ),
        ),
      );
    }
    final layout = WalletLayout.of(context);
    final settings = _settingsDestination;
    final page = _addressPoolOpen
        ? WalletPage.addressPool
        : settings == null
        ? WalletPage.assets
        : WalletPage.settings;
    return PopScope(
      canPop: page == WalletPage.assets,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_addressPoolOpen) {
          _goToAssets();
        } else {
          _settingsHub.currentState?.back();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!layout.mobile)
                WalletRail(
                  theme: theme,
                  selected: page,
                  supportsAddressPool: vault.supportsOmniVaultImport,
                  onSelect: (page) {
                    switch (page) {
                      case WalletPage.assets:
                        _goToAssets();
                      case WalletPage.addressPool:
                        _openOmniPools();
                      case WalletPage.settings:
                        _openSettings();
                    }
                  },
                )
              else
                const SizedBox.shrink(),
              Expanded(
                child: IndexedStack(
                  index: page.index,
                  sizing: StackFit.expand,
                  children: [
                    ExcludeFocus(
                      excluding: page != WalletPage.assets,
                      child: _buildAssets(layout),
                    ),
                    if (vault.supportsOmniVaultImport)
                      _OmniPoolPage(
                        vault: vault,
                        active: _addressPoolOpen,
                        onBack: layout.mobile ? _goToAssets : null,
                      )
                    else
                      const SizedBox.shrink(),
                    if (settings != null)
                      _SettingsHub(
                        key: _settingsHub,
                        shell: this,
                        initial: settings,
                        onExit: _goToAssets,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssets(WalletLayout layout) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(
          layout.gutter,
          layout.gutter,
          layout.gutter,
          0,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: SizedBox(
              width: double.infinity,
              child: WalletHeader(
                theme: theme,
                walletName: walletName,
                address: account!.addressFor(selectedNetwork),
                onAddressPool: layout.mobile && vault.supportsOmniVaultImport
                    ? _openOmniPools
                    : null,
                linkedAddresses: [
                  account!.checksumAddress,
                  account!.tronAddress,
                ],
                pageTitle: tr(context, MessageCode.msgAssets),
                networkLabel:
                    selectedNetwork?.name ??
                    tr(context, MessageCode.msgChooseNetwork),
                onWalletTap: selectWallet,
                onSettings: _openSettings,
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          controller: assetScroll,
          padding: EdgeInsets.all(layout.gutter),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (AppSettingsScope.of(context).saveFailed)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        tr(
                          context,
                          MessageCode
                              .msgPreferencesCouldNotBeSavedPreviousSettingsMay,
                        ),
                      ),
                    ),
                  if (lastTxHash != null)
                    WalletCard(
                      theme: theme,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(
                              context,
                              lastTxUncertain
                                  ? MessageCode
                                        .msgBroadcastStatusIsUncertainCheckTheTransactionHash
                                  : MessageCode
                                        .msgMostRecentlyBroadcastTransaction,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(lastTxHash!),
                          if (lastTxNetwork case final chain?)
                            _TransactionLink(network: chain, hash: lastTxHash!),
                        ],
                      ),
                    ),
                  AssetsPage(
                    theme: theme,
                    positions: portfolioPositions,
                    quotes: effectiveQuotes,
                    networks: enabledNetworks,
                    addresses: {
                      AddressScope.evm: account!.checksumAddress,
                      AddressScope.tron: account!.tronAddress,
                    },
                    refreshing: isRefreshing || quoteLoading,
                    onRefresh: refreshAllAssets,
                    onHoldingTap: showPortfolioHolding,
                    onSend: _chooseSendAsset,
                    onWalletBalances: _showWalletBalances,
                    onManageNetworks: _showNetworkSelector,
                    onManageTokens: _manageTokens,
                    onDiscovery: openIndexerServices,
                    onDisplaySettings: () =>
                        _openSettings(initial: SettingsDestination.display),
                    discovery: discoverySnapshots,
                    discoveryConfigured: enabledNetworks.any(
                      (n) => indexerSettings.forNetwork(n.id) != null,
                    ),
                    onContinueDiscovery: continueDiscovery,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
