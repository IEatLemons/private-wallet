import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web3dart/web3dart.dart';

import 'wallet_core.dart';

String shortAddress(String address) {
  if (address.length <= 12) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StoneWalletApp());
}

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
    background: Color(0xFFF8FAFD),
    surface: Colors.white,
    surfaceStrong: Color(0xFFF0F4FF),
    border: Color(0xFFE4E9F2),
    text: Color(0xFF101B43),
    muted: Color(0xFF7A849D),
    primary: Color(0xFF2D63E8),
    success: Color(0xFF0EAC7A),
    warning: Color(0xFFD99422),
    danger: Color(0xFFE1585B),
    isDark: false,
  );

  static const dark = WalletTheme(
    background: Color(0xFF080D15),
    surface: Color(0xFF111923),
    surfaceStrong: Color(0xFF182331),
    border: Color(0xFF283543),
    text: Color(0xFFF2F5F9),
    muted: Color(0xFF8F9BAB),
    primary: Color(0xFFC8F637),
    success: Color(0xFFA9E8CF),
    warning: Color(0xFFEAC45D),
    danger: Color(0xFFF37C7C),
    isDark: true,
  );
}

class StoneWalletApp extends StatefulWidget {
  const StoneWalletApp({this.vault, super.key});

  final WalletVault? vault;

  @override
  State<StoneWalletApp> createState() => _StoneWalletAppState();
}

class _StoneWalletAppState extends State<StoneWalletApp> {
  WalletStyle style = WalletStyle.lightPortfolio;

  void toggleStyle() {
    setState(() {
      style = style == WalletStyle.lightPortfolio
          ? WalletStyle.darkCommand
          : WalletStyle.lightPortfolio;
    });
  }

  @override
  Widget build(BuildContext context) {
    final walletTheme = style == WalletStyle.lightPortfolio
        ? WalletTheme.light
        : WalletTheme.dark;

    return MaterialApp(
      title: 'Stone Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: walletTheme.isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: walletTheme.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: walletTheme.primary,
          brightness: walletTheme.isDark ? Brightness.dark : Brightness.light,
          surface: walletTheme.surface,
        ),
        fontFamily: 'Inter',
      ),
      home: WalletShell(
        walletTheme: walletTheme,
        style: style,
        onToggleStyle: toggleStyle,
        vault: widget.vault,
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
    super.key,
  });

  final WalletTheme walletTheme;
  final WalletStyle style;
  final VoidCallback onToggleStyle;
  final WalletVault? vault;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int selectedNav = 0;
  String walletName = '主钱包';
  bool isLoadingWallet = true;
  bool isRefreshing = false;
  WalletAccount? account;
  EvmNetwork? selectedNetwork;
  List<EvmNetwork> enabledNetworks = const [];
  BigInt? balanceWei;
  final Map<int, BigInt?> balancesByNetwork = {};
  final Set<int> responsiveNetworkIds = <int>{};
  String? walletError;
  String? lastTxHash;
  DateTime? lastSyncedAt;

  late final WalletVault vault;
  final Map<int, EvmNetworkService> networkServices = {};
  EvmNetworkService? networkService;

  List<AssetRow> get assets {
    if (enabledNetworks.isEmpty) {
      return [
        const AssetRow(
          symbol: '—',
          name: '未选择网络',
          network: '请先选择要查看的链',
          amount: '0',
          value: '未连接 RPC',
          change: '—',
          icon: Icons.public,
          color: Color(0xFF627EEA),
        ),
      ];
    }

    return enabledNetworks.map((network) {
      final balance = balancesByNetwork[network.id];
      return AssetRow(
        symbol: network.nativeSymbol,
        name: network.name,
        network: _networkLabel(network),
        amount: balance == null
            ? '0 ${network.nativeSymbol}'
            : '${formatWeiAsEther(balance)} ${network.nativeSymbol}',
        value: '原生资产',
        change: balance == null ? '未同步' : '已同步',
        icon: Icons.diamond_outlined,
        color: network.isTestnet
            ? const Color(0xFF9B7BFF)
            : const Color(0xFF627EEA),
      );
    }).toList();
  }

  List<ActivityRow> get activities => [
    if (lastTxHash != null)
      ActivityRow(
        type: '已发送',
        detail: selectedNetwork?.name ?? '当前网络',
        amount: '已广播',
        time: '刚刚',
        status: '等待确认',
        icon: Icons.north_east_rounded,
      ),
  ];

  String get _syncLabel {
    if (selectedNetwork == null) return '未选择网络';
    if (walletError != null) return 'RPC 不可用';
    if (isRefreshing) return '同步中…';
    return selectedNetwork!.isTestnet ? 'RPC 已连接 · 测试网' : 'RPC 已连接 · 主网';
  }

  String get _currentBalanceLabel {
    final symbol = selectedNetwork?.nativeSymbol ?? '—';
    final amount = balanceWei == null ? '0' : formatWeiAsEther(balanceWei!);
    return '$amount $symbol';
  }

  WalletTheme get theme => widget.walletTheme;

  bool get isDark => widget.style == WalletStyle.darkCommand;

  @override
  void initState() {
    super.initState();
    vault = widget.vault ?? WalletVault();
    unawaited(_loadWallet());
  }

  @override
  void dispose() {
    for (final service in networkServices.values) {
      unawaited(service.dispose());
    }
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final loaded = await vault.loadWallet();
      final selectedIds = await vault.loadSelectedNetworkIds();
      final currentId = await vault.loadSelectedNetworkId();
      final loadedNetworks = selectedIds
          .map(_networkForId)
          .whereType<EvmNetwork>()
          .toList();
      final loadedNetwork =
          _networkForId(currentId) ??
          (loadedNetworks.isEmpty ? null : loadedNetworks.first);
      if (!mounted) return;
      setState(() {
        account = loaded;
        enabledNetworks = loadedNetworks;
        selectedNetwork = loadedNetwork;
        isLoadingWallet = false;
      });
      if (loaded != null && loadedNetworks.isNotEmpty) {
        _configureNetworks(loadedNetworks, current: loadedNetwork);
        await _refreshBalance();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        walletError = error.toString();
        isLoadingWallet = false;
      });
    }
  }

  Future<void> _refreshBalance() async {
    final currentAccount = account;
    if (currentAccount == null || networkServices.isEmpty) return;
    setState(() => isRefreshing = true);
    try {
      final entries = await Future.wait(
        networkServices.entries.map((entry) async {
          try {
            final balance = await entry.value
                .getNativeBalance(currentAccount)
                .timeout(const Duration(seconds: 12));
            return MapEntry(entry.key, balance.getInWei);
          } catch (_) {
            return MapEntry<int, BigInt?>(entry.key, null);
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        balancesByNetwork
          ..clear()
          ..addEntries(entries);
        responsiveNetworkIds
          ..clear()
          ..addAll(
            entries
                .where((entry) => entry.value != null)
                .map((entry) => entry.key),
          );
        balanceWei = selectedNetwork == null
            ? null
            : balancesByNetwork[selectedNetwork!.id];
        lastSyncedAt = DateTime.now();
        walletError = entries.any((entry) => entry.value == null)
            ? '部分网络 RPC 暂时不可用，请在设置中检查连接。'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => walletError = '网络同步失败：$error');
    } finally {
      if (mounted) setState(() => isRefreshing = false);
    }
  }

  EvmNetwork? _networkForId(int? id) {
    if (id == null) return null;
    for (final network in supportedEvmNetworks) {
      if (network.id == id) return network;
    }
    return null;
  }

  String _networkLabel(EvmNetwork network) {
    return network.isTestnet ? '${network.name} · 测试网' : '${network.name} · 主网';
  }

  void _configureNetworks(List<EvmNetwork> networks, {EvmNetwork? current}) {
    final enabledIds = networks.map((network) => network.id).toSet();
    for (final entry in networkServices.entries.toList()) {
      if (!enabledIds.contains(entry.key)) {
        unawaited(entry.value.dispose());
        networkServices.remove(entry.key);
      }
    }
    for (final network in networks) {
      networkServices.putIfAbsent(
        network.id,
        () => EvmNetworkService(network: network),
      );
    }
    responsiveNetworkIds.removeWhere((id) => !enabledIds.contains(id));
    final nextCurrent = current ?? (networks.isEmpty ? null : networks.first);
    networkService = nextCurrent == null
        ? null
        : networkServices[nextCurrent.id];
    if (!mounted) return;
    setState(() {
      enabledNetworks = List.unmodifiable(networks);
      selectedNetwork = nextCurrent;
      balanceWei = nextCurrent == null
          ? null
          : balancesByNetwork[nextCurrent.id];
      lastTxHash = null;
      walletError = null;
    });
  }

  Future<void> _selectNetworks(
    List<EvmNetwork> networks, {
    EvmNetwork? current,
  }) async {
    _configureNetworks(networks, current: current);
    await vault.saveSelectedNetworks(networks, current: current);
    await _refreshBalance();
  }

  Future<void> _clearNetwork() async {
    final oldService = networkService;
    networkService = null;
    if (oldService != null) await oldService.dispose();
    for (final entry in networkServices.entries.toList()) {
      if (entry.value != oldService) await entry.value.dispose();
      networkServices.remove(entry.key);
    }
    await vault.clearSelectedNetworks();
    if (!mounted) return;
    setState(() {
      enabledNetworks = const [];
      selectedNetwork = null;
      balanceWei = null;
      balancesByNetwork.clear();
      responsiveNetworkIds.clear();
      lastTxHash = null;
      walletError = null;
    });
  }

  Widget _networkErrorBanner() {
    final error = walletError;
    if (error == null || account == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_outlined, color: theme.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: theme.danger, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createWallet() async {
    try {
      final creation = await vault.prepareNewWallet();
      if (!mounted) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            RecoveryPhraseSheet(theme: theme, mnemonic: creation.mnemonic),
      );
      if (confirmed != true) return;
      final saved = await vault.saveRecoveryPhrase(creation.mnemonic);
      if (!mounted) return;
      setState(() {
        account = saved;
        isLoadingWallet = false;
        walletError = null;
      });
      await _refreshBalance();
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  Future<void> _importWallet() async {
    final mnemonic = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImportWalletDialog(theme: theme),
    );
    if (mnemonic == null || mnemonic.trim().isEmpty) return;
    try {
      final imported = await vault.importWallet(mnemonic);
      if (!mounted) return;
      setState(() {
        account = imported;
        isLoadingWallet = false;
        balanceWei = null;
        walletError = null;
      });
      await _refreshBalance();
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showNetworkSelector() async {
    final result = await showModalBottomSheet<NetworkSelectionResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NetworkSelectorSheet(
        theme: theme,
        networks: supportedEvmNetworks,
        selectedNetworks: enabledNetworks,
        currentNetwork: selectedNetwork,
      ),
    );
    if (result == null) return;
    if (result.clear || result.networks.isEmpty) {
      await _clearNetwork();
    } else {
      await _selectNetworks(result.networks, current: result.current);
    }
  }

  void showAction(String action) {
    if (action == '发送') {
      _showSendSheet();
      return;
    }
    if (action == '兑换') {
      _showMessage('兑换功能尚未接入，没有创建订单或签名。');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActionSheet(
        action: action,
        theme: theme,
        walletName: walletName,
        networkLabel: selectedNetwork == null
            ? '未选择网络'
            : _networkLabel(selectedNetwork!),
        address: account?.checksumAddress ?? '暂不可用',
        onConfirm: () {
          Navigator.of(context).pop();
          if (action == '接收' && account != null) {
            Clipboard.setData(ClipboardData(text: account!.checksumAddress));
            _showMessage('地址已复制');
          }
        },
      ),
    );
  }

  Future<void> _showSendSheet() async {
    final currentAccount = account;
    if (currentAccount == null) return;
    final network = selectedNetwork;
    final service = networkService;
    if (network == null || service == null) {
      _showMessage('发送前请先选择网络。');
      return;
    }
    final txHash = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SendSheet(
        theme: theme,
        network: network,
        balanceWei: balanceWei,
        onSend: (recipient, amount) => service.sendNative(
          account: currentAccount,
          recipient: recipient,
          amountWei: parseEtherToWei(amount),
        ),
      ),
    );
    if (!mounted || txHash == null) return;
    setState(() => lastTxHash = txHash);
    await _refreshBalance();
    if (mounted) _showMessage('交易已广播：$txHash');
  }

  void selectWallet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('选择钱包', style: textStyle(20, FontWeight.w700)),
            const SizedBox(height: 14),
            WalletChoice(
              name: '主钱包',
              address: account?.checksumAddress ?? '暂不可用',
              selected: walletName == '主钱包',
              theme: theme,
              onTap: () {
                setState(() => walletName = '主钱包');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
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
        backgroundColor: theme.background,
        body: Center(child: CircularProgressIndicator(color: theme.primary)),
      );
    }

    if (account == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: SafeArea(
          child: OnboardingPage(
            theme: theme,
            error: walletError,
            onCreate: _createWallet,
            onImport: _importWallet,
            onToggleStyle: widget.onToggleStyle,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            final medium = constraints.maxWidth < 1180;
            return Row(
              children: [
                if (!compact)
                  WalletRail(
                    theme: theme,
                    selected: selectedNav,
                    onSelect: (index) => setState(() => selectedNav = index),
                    onToggleStyle: widget.onToggleStyle,
                  ),
                Expanded(
                  child: _buildContent(compact: compact, medium: medium),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 860
          ? WalletBottomBar(
              theme: theme,
              selected: selectedNav,
              onSelect: (index) => setState(() => selectedNav = index),
            )
          : null,
    );
  }

  Widget _buildContent({required bool compact, required bool medium}) {
    if (selectedNav == 1) {
      return SettingsPage(
        theme: theme,
        address: account!.checksumAddress,
        networks: enabledNetworks,
        currentNetwork: selectedNetwork,
        networkServices: networkServices,
        responsiveNetworkIds: responsiveNetworkIds,
        onManageNetworks: _showNetworkSelector,
        onRefresh: _refreshBalance,
        onToggleStyle: widget.onToggleStyle,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        compact ? 20 : 40,
        26,
        compact ? 20 : 40,
        34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WalletHeader(
            theme: theme,
            walletName: walletName,
            address: account!.checksumAddress,
            onWalletTap: selectWallet,
            onToggleStyle: widget.onToggleStyle,
          ),
          const SizedBox(height: 32),
          if (compact)
            _buildCompactDashboard()
          else
            _buildDesktopDashboard(medium: medium),
        ],
      ),
    );
  }

  Widget _buildCompactDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortfolioHero(
          theme: theme,
          compact: true,
          balance: _currentBalanceLabel,
          network: selectedNetwork?.name ?? '选择网络',
          syncLabel: _syncLabel,
          onNetworkTap: _showNetworkSelector,
        ),
        _networkErrorBanner(),
        const SizedBox(height: 22),
        ActionRow(theme: theme, onAction: showAction, compact: true),
        const SizedBox(height: 28),
        AssetTable(theme: theme, assets: assets, compact: true),
        const SizedBox(height: 26),
        ActivityPanel(theme: theme, activities: activities),
      ],
    );
  }

  Widget _buildDesktopDashboard({required bool medium}) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PortfolioHero(
                    theme: theme,
                    balance: _currentBalanceLabel,
                    network: selectedNetwork?.name ?? '选择网络',
                    syncLabel: _syncLabel,
                    onNetworkTap: _showNetworkSelector,
                  ),
                  _networkErrorBanner(),
                  const SizedBox(height: 22),
                  ActionRow(theme: theme, onAction: showAction),
                  const SizedBox(height: 28),
                  AssetTable(theme: theme, assets: assets),
                ],
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 320,
              child: ActivityPanel(theme: theme, activities: activities),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SecurityBanner(theme: theme),
      ],
    );
  }
}

class WalletRail extends StatelessWidget {
  const WalletRail({
    required this.theme,
    required this.selected,
    required this.onSelect,
    required this.onToggleStyle,
    super.key,
  });

  final WalletTheme theme;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleStyle;

  @override
  Widget build(BuildContext context) {
    final items = [(Icons.home_rounded, '首页'), (Icons.settings_outlined, '设置')];

    return Container(
      width: 92,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: theme.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(
        children: [
          BrandMark(theme: theme),
          const SizedBox(height: 46),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final active = selected == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Tooltip(
                message: item.$2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.primary.withValues(
                              alpha: theme.isDark ? 0.14 : 0.1,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: active
                          ? Border.all(
                              color: theme.primary.withValues(alpha: 0.42),
                            )
                          : null,
                    ),
                    child: Icon(
                      item.$1,
                      color: active ? theme.primary : theme.muted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          IconButton(
            tooltip: '切换主题',
            onPressed: onToggleStyle,
            icon: Icon(
              theme.isDark
                  ? Icons.wb_sunny_outlined
                  : Icons.nightlight_outlined,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class WalletBottomBar extends StatelessWidget {
  const WalletBottomBar({
    required this.theme,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final WalletTheme theme;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: onSelect,
      backgroundColor: theme.surface,
      indicatorColor: theme.primary.withValues(
        alpha: theme.isDark ? 0.18 : 0.12,
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
      ],
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({required this.theme, super.key});

  final WalletTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        color: theme.isDark ? const Color(0xFF10150B) : Colors.white,
        size: 24,
      ),
    );
  }
}

class WalletHeader extends StatelessWidget {
  const WalletHeader({
    required this.theme,
    required this.walletName,
    required this.address,
    required this.onWalletTap,
    required this.onToggleStyle,
    super.key,
  });

  final WalletTheme theme;
  final String walletName;
  final String address;
  final VoidCallback onWalletTap;
  final VoidCallback onToggleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onWalletTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: theme.isDark
                            ? const [Color(0xFFB9E836), Color(0xFF5E6DFF)]
                            : const [Color(0xFF3475ED), Color(0xFF7F86FF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                walletName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: theme.muted,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${shortAddress(address)}  ·  账户 1',
                          style: TextStyle(color: theme.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '切换主题',
          onPressed: onToggleStyle,
          icon: Icon(
            theme.isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
            color: theme.muted,
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.theme,
    required this.address,
    required this.networks,
    required this.currentNetwork,
    required this.networkServices,
    required this.responsiveNetworkIds,
    required this.onManageNetworks,
    required this.onRefresh,
    required this.onToggleStyle,
    super.key,
  });

  final WalletTheme theme;
  final String address;
  final List<EvmNetwork> networks;
  final EvmNetwork? currentNetwork;
  final Map<int, EvmNetworkService> networkServices;
  final Set<int> responsiveNetworkIds;
  final VoidCallback onManageNetworks;
  final Future<void> Function() onRefresh;
  final VoidCallback onToggleStyle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '设置',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '切换主题',
                onPressed: onToggleStyle,
                icon: Icon(
                  theme.isDark
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_outlined,
                  color: theme.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SettingsCard(
            theme: theme,
            title: '网络与 RPC',
            icon: Icons.public,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (networks.isEmpty)
                  Text(
                    '尚未选择网络。首页不会请求任何 RPC。',
                    style: TextStyle(color: theme.muted, fontSize: 13),
                  )
                else
                  ...networks.map(
                    (network) => _NetworkSettingsRow(
                      theme: theme,
                      network: network,
                      current: currentNetwork?.id == network.id,
                      connected: networkServices.containsKey(network.id),
                      responsive: responsiveNetworkIds.contains(network.id),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onManageNetworks,
                        icon: const Icon(Icons.tune, size: 17),
                        label: const Text('管理网络'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: '刷新余额',
                      onPressed: () => onRefresh(),
                      icon: Icon(Icons.refresh, color: theme.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            theme: theme,
            title: '钱包安全',
            icon: Icons.shield_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsInfoLine(
                  theme: theme,
                  label: '钱包地址',
                  value: shortAddress(address),
                ),
                _SettingsInfoLine(
                  theme: theme,
                  label: '派生路径',
                  value: evmDerivationPath,
                ),
                const SizedBox(height: 10),
                Text(
                  '助记词只保存在本机安全存储中。没有独立密码或云端托管服务可以替你找回它。',
                  style: TextStyle(
                    color: theme.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            theme: theme,
            title: '备份',
            icon: Icons.backup_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('iCloud / Google Drive 云备份（暂未接入）'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '云备份功能尚未接入，按钮已置灰。请先完成助记词验证并保存在离线安全位置。',
                  style: TextStyle(
                    color: theme.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.theme,
    required this.title,
    required this.icon,
    required this.child,
  });

  final WalletTheme theme;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primary, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _NetworkSettingsRow extends StatelessWidget {
  const _NetworkSettingsRow({
    required this.theme,
    required this.network,
    required this.current,
    required this.connected,
    required this.responsive,
  });

  final WalletTheme theme;
  final EvmNetwork network;
  final bool current;
  final bool connected;
  final bool responsive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${network.name}${current ? ' · 当前操作链' : ''}',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                responsive
                    ? 'RPC 已响应'
                    : connected
                    ? '已配置，未检测'
                    : '未配置',
                style: TextStyle(
                  color: responsive
                      ? theme.success
                      : connected
                      ? theme.primary
                      : theme.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chain ID ${network.id} · ${network.nativeSymbol} · ${network.isTestnet ? '测试网' : '主网'}',
            style: TextStyle(color: theme.muted, fontSize: 11),
          ),
          const SizedBox(height: 3),
          SelectableText(
            'RPC：${network.rpcUrl}',
            style: TextStyle(color: theme.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoLine extends StatelessWidget {
  const _SettingsInfoLine({
    required this.theme,
    required this.label,
    required this.value,
  });

  final WalletTheme theme;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ),
          SelectableText(
            value,
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PortfolioHero extends StatelessWidget {
  const PortfolioHero({
    required this.theme,
    required this.balance,
    required this.network,
    required this.syncLabel,
    required this.onNetworkTap,
    this.compact = false,
    super.key,
  });

  final WalletTheme theme;
  final String balance;
  final String network;
  final String syncLabel;
  final VoidCallback onNetworkTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '资产总览',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: onNetworkTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surfaceStrong,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.public, size: 15, color: theme.primary),
                      const SizedBox(width: 6),
                      Text(
                        network,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: theme.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('当前链余额', style: TextStyle(color: theme.muted, fontSize: 13)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              balance,
              style: TextStyle(
                color: theme.text,
                fontSize: compact ? 38 : 46,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.cloud_done_outlined, size: 16, color: theme.success),
              const SizedBox(width: 4),
              Text(
                syncLabel,
                style: TextStyle(
                  color: theme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 22),
            Text(
              '接入行情服务后才会显示价格历史。',
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    required this.theme,
    required this.onAction,
    this.compact = false,
    super.key,
  });

  final WalletTheme theme;
  final ValueChanged<String> onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('发送', Icons.north_east_rounded),
      ('接收', Icons.south_west_rounded),
      ('兑换', Icons.swap_horiz_rounded),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: _ActionButton(
              label: actions[i].$1,
              icon: actions[i].$2,
              theme: theme,
              prominent: actions[i].$1 == '兑换',
              onTap: () => onAction(actions[i].$1),
              compact: compact,
            ),
          ),
          if (i < actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.theme,
    required this.prominent,
    required this.onTap,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final WalletTheme theme;
  final bool prominent;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = prominent
        ? (theme.isDark ? const Color(0xFF11170B) : Colors.white)
        : theme.text;
    return Material(
      color: prominent ? theme.primary : theme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: compact ? 54 : 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: prominent ? null : Border.all(color: theme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: prominent ? foreground : theme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssetTable extends StatelessWidget {
  const AssetTable({
    required this.theme,
    required this.assets,
    this.compact = false,
    super.key,
  });

  final WalletTheme theme;
  final List<AssetRow> assets;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 16 : 22, 18, compact ? 16 : 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '链上资产',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '查看全部',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(Icons.arrow_forward, size: 15, color: theme.primary),
            ],
          ),
          const SizedBox(height: 12),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _HeaderText('资产', theme)),
                  Expanded(flex: 2, child: _HeaderText('网络', theme)),
                  Expanded(flex: 2, child: _HeaderText('余额', theme)),
                  Expanded(
                    child: _HeaderText('状态', theme, align: TextAlign.right),
                  ),
                ],
              ),
            ),
          ...assets.map(
            (asset) =>
                AssetListRow(asset: asset, theme: theme, compact: compact),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.value, this.theme, {this.align = TextAlign.left});

  final String value;
  final WalletTheme theme;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    value,
    textAlign: align,
    style: TextStyle(
      color: theme.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    ),
  );
}

class AssetListRow extends StatelessWidget {
  const AssetListRow({
    required this.asset,
    required this.theme,
    required this.compact,
    super.key,
  });

  final AssetRow asset;
  final WalletTheme theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: compact ? 4 : 3,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: asset.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(asset.icon, color: asset.color, size: 18),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.symbol,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        asset.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: theme.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            Expanded(
              flex: 2,
              child: Text(
                asset.network,
                style: TextStyle(color: theme.muted, fontSize: 12),
              ),
            ),
          Expanded(
            flex: compact ? 3 : 2,
            child: Column(
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  asset.amount,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  asset.change,
                  style: TextStyle(color: theme.success, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!compact)
            Expanded(
              child: Text(
                asset.value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ActivityPanel extends StatelessWidget {
  const ActivityPanel({
    required this.theme,
    required this.activities,
    super.key,
  });

  final WalletTheme theme;
  final List<ActivityRow> activities;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '最近活动',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '查看全部',
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                '暂时没有交易记录。',
                style: TextStyle(color: theme.muted, fontSize: 12),
              ),
            )
          else
            ...activities.map(
              (activity) => ActivityListRow(activity: activity, theme: theme),
            ),
        ],
      ),
    );
  }
}

class ActivityListRow extends StatelessWidget {
  const ActivityListRow({
    required this.activity,
    required this.theme,
    super.key,
  });

  final ActivityRow activity;
  final WalletTheme theme;

  @override
  Widget build(BuildContext context) {
    final received = activity.type == '已接收';
    final color = received ? theme.success : theme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(activity.icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.type,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.detail,
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity.amount,
                style: TextStyle(
                  color: received ? theme.success : theme.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                activity.time,
                style: TextStyle(color: theme.muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final WalletTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SecurityBanner extends StatelessWidget {
  const SecurityBanner({required this.theme, super.key});

  final WalletTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.success.withValues(alpha: theme.isDark ? 0.09 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: theme.success, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '安全状态',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '助记词保存在本机安全存储中，签名在本机完成。主网发布前仍需要独立安全审计。',
                  style: TextStyle(color: theme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward, color: theme.success, size: 17),
        ],
      ),
    );
  }
}

class ActionSheet extends StatelessWidget {
  const ActionSheet({
    required this.action,
    required this.theme,
    required this.walletName,
    required this.networkLabel,
    required this.address,
    required this.onConfirm,
    super.key,
  });

  final String action;
  final WalletTheme theme;
  final String walletName;
  final String networkLabel;
  final String address;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isReceive = action == '接收';
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    action,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: theme.surfaceStrong,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _InfoLine(label: '钱包', value: walletName, theme: theme),
                  _InfoLine(label: '网络', value: networkLabel, theme: theme),
                ],
              ),
            ),
            if (isReceive) ...[
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: address,
                      size: 128,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      shortAddress(address),
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击下方按钮复制地址',
                      style: TextStyle(color: theme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: theme.isDark
                      ? const Color(0xFF10150B)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('复制收款地址'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WalletChoice extends StatelessWidget {
  const WalletChoice({
    required this.name,
    required this.address,
    required this.selected,
    required this.theme,
    required this.onTap,
    this.readOnly = false,
    super.key,
  });

  final String name;
  final String address;
  final bool selected;
  final WalletTheme theme;
  final VoidCallback onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: theme.primary.withValues(alpha: 0.15),
        child: Icon(
          readOnly
              ? Icons.visibility_outlined
              : Icons.account_balance_wallet_outlined,
          color: theme.primary,
          size: 18,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: theme.text,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        address,
        style: TextStyle(color: theme.muted, fontSize: 11),
      ),
      trailing: selected
          ? Icon(Icons.check_circle, color: theme.primary)
          : Icon(Icons.chevron_right, color: theme.muted),
    );
  }
}

class NetworkSelectorSheet extends StatefulWidget {
  const NetworkSelectorSheet({
    required this.theme,
    required this.networks,
    required this.selectedNetworks,
    required this.currentNetwork,
    super.key,
  });

  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final List<EvmNetwork> selectedNetworks;
  final EvmNetwork? currentNetwork;

  @override
  State<NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<NetworkSelectorSheet> {
  late final Set<int> selectedIds = widget.selectedNetworks
      .map((network) => network.id)
      .toSet();
  int? currentId;

  @override
  void initState() {
    super.initState();
    currentId =
        widget.currentNetwork?.id ??
        (selectedIds.isEmpty ? null : selectedIds.first);
  }

  void _toggleNetwork(EvmNetwork network) {
    setState(() {
      if (selectedIds.contains(network.id)) {
        selectedIds.remove(network.id);
        if (currentId == network.id) {
          currentId = selectedIds.isEmpty ? null : selectedIds.first;
        }
      } else {
        selectedIds.add(network.id);
        currentId ??= network.id;
      }
    });
  }

  void _setCurrent(EvmNetwork network) {
    if (!selectedIds.contains(network.id)) return;
    setState(() => currentId = network.id);
  }

  void _save() {
    final selected = widget.networks
        .where((network) => selectedIds.contains(network.id))
        .toList();
    final matching = selected.where((network) => network.id == currentId);
    final current = matching.isEmpty ? null : matching.first;
    Navigator.pop(
      context,
      NetworkSelectionResult(networks: selected, current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                '管理网络',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '可同时启用多条链查看余额。只有点击保存后，选中的网络才会访问 RPC。',
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              ...widget.networks.map(
                (network) => ListTile(
                  onTap: () => _toggleNetwork(network),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Checkbox(
                    value: selectedIds.contains(network.id),
                    onChanged: (_) => _toggleNetwork(network),
                    activeColor: theme.primary,
                  ),
                  title: Text(
                    network.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Chain ID ${network.id} · ${network.nativeSymbol} · ${network.isTestnet ? '测试网' : '主网'}',
                    style: TextStyle(color: theme.muted, fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: '设为当前操作链',
                    onPressed: selectedIds.contains(network.id)
                        ? () => _setCurrent(network)
                        : null,
                    icon: Icon(
                      currentId == network.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: currentId == network.id
                          ? theme.primary
                          : theme.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.isDark
                        ? const Color(0xFF10150B)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(selectedIds.isEmpty ? '断开所有网络' : '保存网络选择'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkSelectionResult {
  const NetworkSelectionResult({
    required this.networks,
    this.current,
    this.clear = false,
  });

  final List<EvmNetwork> networks;
  final EvmNetwork? current;
  final bool clear;
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.theme,
    required this.error,
    required this.onCreate,
    required this.onImport,
    required this.onToggleStyle,
    super.key,
  });

  final WalletTheme theme;
  final String? error;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onToggleStyle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600 ? 24.0 : 48.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 28, horizontal, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BrandMark(theme: theme),
                    const Spacer(),
                    IconButton(
                      tooltip: '切换主题',
                      onPressed: onToggleStyle,
                      icon: Icon(
                        theme.isDark
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_outlined,
                        color: theme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 70),
                Text(
                  '你的密钥，\n你的钱包。',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 44,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '创建或导入自托管 EVM 钱包。网络由你自己选择；在选择网络前，不会连接任何 RPC。',
                  style: TextStyle(
                    color: theme.muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                _OnboardingNotice(theme: theme),
                if (error != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    error!,
                    style: TextStyle(color: theme.danger, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.isDark
                          ? const Color(0xFF10150B)
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('创建新钱包'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onImport,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.text,
                      side: BorderSide(color: theme.border),
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text('导入助记词'),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '不要向任何人透露助记词。Stone Wallet 无法替你找回助记词。',
                  style: TextStyle(color: theme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingNotice extends StatelessWidget {
  const _OnboardingNotice({required this.theme});

  final WalletTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          _NoticeLine(
            theme: theme,
            icon: Icons.key_outlined,
            title: '自托管钱包',
            detail: '交易签名在本机完成，私钥由助记词派生。',
          ),
          const SizedBox(height: 14),
          _NoticeLine(
            theme: theme,
            icon: Icons.lock_outline,
            title: '系统安全存储',
            detail: '助记词保存在 Keychain、Keystore 或 Windows 凭据管理器中。',
          ),
          const SizedBox(height: 14),
          _NoticeLine(
            theme: theme,
            icon: Icons.science_outlined,
            title: '网络由你选择',
            detail: '主网和测试网分别选择；只有启用网络后才会连接对应 RPC。',
          ),
        ],
      ),
    );
  }
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({
    required this.theme,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final WalletTheme theme;
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: TextStyle(
                  color: theme.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RecoveryPhraseSheet extends StatefulWidget {
  const RecoveryPhraseSheet({
    required this.theme,
    required this.mnemonic,
    super.key,
  });

  final WalletTheme theme;
  final String mnemonic;

  @override
  State<RecoveryPhraseSheet> createState() => _RecoveryPhraseSheetState();
}

class _RecoveryPhraseSheetState extends State<RecoveryPhraseSheet> {
  static const verificationIndexes = [1, 5, 9];

  late final List<String> words = widget.mnemonic.split(' ');
  late final List<TextEditingController> verificationControllers =
      List.generate(verificationIndexes.length, (_) => TextEditingController());
  bool verifying = false;
  String? error;

  @override
  void dispose() {
    for (final controller in verificationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _beginVerification() {
    setState(() {
      verifying = true;
      error = null;
    });
  }

  void _verify() {
    final valid = verificationIndexes.asMap().entries.every((entry) {
      final expected = words[entry.value].trim().toLowerCase();
      final actual = verificationControllers[entry.key].text
          .trim()
          .toLowerCase();
      return expected == actual;
    });
    if (!valid) {
      setState(() => error = '助记词校验不正确，请重新核对第 2、6、10 个单词。');
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.border,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                verifying ? '验证恢复助记词' : '记录恢复助记词',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verifying
                    ? '请输入指定位置的单词，验证完成后钱包才会创建并进入首页。'
                    : '请按顺序抄写 12 个单词。助记词是恢复钱包的唯一凭证。',
                style: TextStyle(color: theme.muted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 18),
              if (!verifying)
                _RecoveryWordsGrid(theme: theme, words: words)
              else
                ...verificationIndexes.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: verificationControllers[entry.key],
                      autofocus: entry.key == 0,
                      textInputAction:
                          entry.key == verificationIndexes.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      onSubmitted: (_) {
                        if (entry.key < verificationControllers.length - 1) {
                          FocusScope.of(context).nextFocus();
                        } else {
                          _verify();
                        }
                      },
                      style: TextStyle(color: theme.text),
                      decoration: InputDecoration(
                        labelText: '第 ${entry.value + 1} 个单词',
                        labelStyle: TextStyle(color: theme.muted),
                        hintText: '请输入第 ${entry.value + 1} 个单词',
                        hintStyle: TextStyle(
                          color: theme.muted.withValues(alpha: 0.85),
                        ),
                        filled: true,
                        fillColor: theme.surfaceStrong,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(13),
                          borderSide: BorderSide(
                            color: theme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                verifying ? '校验不会把助记词上传到网络。' : '不要截图、复制或发送助记词。云备份尚未接入。',
                style: TextStyle(color: theme.danger, fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error!,
                  style: TextStyle(color: theme.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: verifying ? _verify : _beginVerification,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.isDark
                        ? const Color(0xFF10150B)
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(verifying ? '验证并进入钱包' : '我已记录，继续验证'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryWordsGrid extends StatelessWidget {
  const _RecoveryWordsGrid({required this.theme, required this.words});

  final WalletTheme theme;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: words.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 3.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => Text(
          '${index + 1}. ${words[index]}',
          style: TextStyle(
            color: theme.text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ImportWalletDialog extends StatefulWidget {
  const ImportWalletDialog({required this.theme, super.key});

  final WalletTheme theme;

  @override
  State<ImportWalletDialog> createState() => _ImportWalletDialogState();
}

class _ImportWalletDialogState extends State<ImportWalletDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AlertDialog(
      backgroundColor: theme.surface,
      title: Text('导入钱包', style: TextStyle(color: theme.text)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 4,
        style: TextStyle(color: theme.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: '请输入 12 或 24 个助记词单词',
          hintStyle: TextStyle(color: theme.muted),
          filled: true,
          fillColor: theme.surfaceStrong,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: theme.muted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('导入'),
        ),
      ],
    );
  }
}

class SendSheet extends StatefulWidget {
  const SendSheet({
    required this.theme,
    required this.network,
    required this.balanceWei,
    required this.onSend,
    super.key,
  });

  final WalletTheme theme;
  final EvmNetwork network;
  final BigInt? balanceWei;
  final Future<String> Function(String recipient, String amount) onSend;

  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  final recipientController = TextEditingController();
  final amountController = TextEditingController();
  bool sending = false;
  String? error;

  @override
  void dispose() {
    recipientController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final recipient = recipientController.text.trim();
      final amount = amountController.text.trim();
      EthereumAddress.fromHex(recipient, enforceEip55: false);
      final amountWei = parseEtherToWei(amount);
      if (widget.balanceWei != null && amountWei > widget.balanceWei!) {
        throw const WalletInputException('金额超过当前余额。');
      }
      setState(() {
        sending = true;
        error = null;
      });
      final txHash = await widget.onSend(recipient, amount);
      if (mounted) Navigator.pop(context, txHash);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        sending = false;
        error = exception.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.border,
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '发送 ${widget.network.nativeSymbol}',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: sending ? null : () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.network.name} · ${widget.network.isTestnet ? '测试网' : '主网'} · 在本机完成签名',
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            _SendField(
              theme: theme,
              controller: recipientController,
              label: '收款地址',
              hint: '0x…',
            ),
            const SizedBox(height: 12),
            _SendField(
              theme: theme,
              controller: amountController,
              label: '金额（${widget.network.nativeSymbol}）',
              hint: '0.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (widget.balanceWei != null) ...[
              const SizedBox(height: 8),
              Text(
                '可用余额：${formatWeiAsEther(widget.balanceWei!)} ${widget.network.nativeSymbol} · Gas 费另行扣除',
                style: TextStyle(color: theme.muted, fontSize: 11),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(error!, style: TextStyle(color: theme.danger, fontSize: 12)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: theme.isDark
                      ? const Color(0xFF10150B)
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: sending
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('签名并广播'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendField extends StatelessWidget {
  const _SendField({
    required this.theme,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final WalletTheme theme;
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.muted, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: theme.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: theme.surfaceStrong,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.theme,
    required this.onBackToPortfolio,
    super.key,
  });

  final String title;
  final WalletTheme theme;
  final VoidCallback onBackToPortfolio;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_outlined, color: theme.primary, size: 42),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: theme.text,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '此页面尚未接入功能模块。',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onBackToPortfolio,
              icon: const Icon(Icons.arrow_back),
              label: const Text('返回资产首页'),
            ),
          ],
        ),
      ),
    );
  }
}

class PortfolioSparklinePainter extends CustomPainter {
  const PortfolioSparklinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(0, size.height * 0.72);
    final points = [
      Offset(size.width * 0.1, size.height * 0.58),
      Offset(size.width * 0.2, size.height * 0.68),
      Offset(size.width * 0.32, size.height * 0.28),
      Offset(size.width * 0.44, size.height * 0.48),
      Offset(size.width * 0.57, size.height * 0.17),
      Offset(size.width * 0.68, size.height * 0.36),
      Offset(size.width * 0.8, size.height * 0.18),
      Offset(size.width * 0.9, size.height * 0.25),
      Offset(size.width, size.height * 0.05),
    ];
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant PortfolioSparklinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class AssetRow {
  const AssetRow({
    required this.symbol,
    required this.name,
    required this.network,
    required this.amount,
    required this.value,
    required this.change,
    required this.icon,
    required this.color,
  });

  final String symbol;
  final String name;
  final String network;
  final String amount;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
}

class ActivityRow {
  const ActivityRow({
    required this.type,
    required this.detail,
    required this.amount,
    required this.time,
    required this.status,
    required this.icon,
  });

  final String type;
  final String detail;
  final String amount;
  final String time;
  final String status;
  final IconData icon;
}
