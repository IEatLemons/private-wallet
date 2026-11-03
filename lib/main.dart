import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web3dart/web3dart.dart';

import 'wallet_core.dart';

part 'ui/layout.dart';
part 'ui/dashboard.dart';
part 'ui/navigation.dart';
part 'ui/pages.dart';
part 'ui/panels.dart';
part 'ui/network_editor.dart';
part 'ui/assets.dart';
part 'ui/wallet_manager.dart';

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
    primary: Color(0xFF76A2FF),
    success: Color(0xFFA9E8CF),
    warning: Color(0xFFEAC45D),
    danger: Color(0xFFF37C7C),
    isDark: true,
  );
}

class StoneWalletApp extends StatefulWidget {
  const StoneWalletApp({this.vault, this.networkServiceBuilder, super.key});

  final WalletVault? vault;
  final EvmNetworkService Function(EvmNetwork)? networkServiceBuilder;

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
          primary: walletTheme.primary,
          onPrimary: walletTheme.isDark
              ? const Color(0xFF10234A)
              : Colors.white,
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
      ),
      builder: (context, child) {
        final data = Theme.of(context);
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
      home: WalletShell(
        walletTheme: walletTheme,
        style: style,
        onToggleStyle: toggleStyle,
        vault: widget.vault,
        networkServiceBuilder: widget.networkServiceBuilder,
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
    super.key,
  });

  final WalletTheme walletTheme;
  final WalletStyle style;
  final VoidCallback onToggleStyle;
  final WalletVault? vault;
  final EvmNetworkService Function(EvmNetwork)? networkServiceBuilder;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int selectedNav = 0;
  final pageScroll = ScrollController();
  String walletName = '主钱包';
  bool isLoadingWallet = true;
  bool isRefreshing = false;
  WalletAccount? account;
  WalletPortfolio portfolio = const WalletPortfolio(groups: []);
  WalletEntry? get activeEntry => portfolio.selected;
  EvmNetwork? selectedNetwork;
  List<EvmNetwork> enabledNetworks = const [];
  List<EvmNetwork> allNetworks = List.of(supportedEvmNetworks);
  BigInt? balanceWei;
  final Map<int, BigInt?> balancesByNetwork = {};
  final Set<int> responsiveNetworkIds = <int>{};
  final Set<int> pendingNetworkIds = {};
  final Map<int, String> networkErrors = {};
  int balanceRequest = 0;
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
          amount: '—',
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
        networkId: network.id,
        error: networkErrors[network.id],
        symbol: network.nativeSymbol,
        name: network.name,
        network: _networkLabel(network),
        amount: balance == null
            ? '— ${network.nativeSymbol}'
            : '${formatWeiAsEther(balance)} ${network.nativeSymbol}',
        value: '原生资产',
        change: pendingNetworkIds.contains(network.id)
            ? '同步中…'
            : networkErrors.containsKey(network.id)
            ? '连接失败'
            : balance == null
            ? '待同步'
            : '已同步',
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
    if (pendingNetworkIds.contains(selectedNetwork!.id)) return '同步中…';
    if (networkErrors.containsKey(selectedNetwork!.id)) return 'RPC 连接失败';
    if (!responsiveNetworkIds.contains(selectedNetwork!.id)) return '待同步';
    return selectedNetwork!.isTestnet ? 'RPC 已连接 · 测试网' : 'RPC 已连接 · 主网';
  }

  String get _currentBalanceLabel {
    if (selectedNetwork == null) return '—';
    final symbol = selectedNetwork?.nativeSymbol ?? '—';
    final amount = balanceWei == null ? '—' : formatWeiAsEther(balanceWei!);
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
    pageScroll.dispose();
    for (final service in networkServices.values) {
      unawaited(service.dispose());
    }
    super.dispose();
  }

  Future<void> _loadWallet() async {
    try {
      final loaded = await vault.loadPortfolio();
      allNetworks = await vault.loadNetworks();
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
        portfolio = loaded;
        account = loaded.selected?.account;
        walletName = loaded.selected?.displayName ?? '钱包';
        enabledNetworks = loadedNetworks;
        selectedNetwork = loadedNetwork;
        isLoadingWallet = false;
      });
      if (account != null && loadedNetworks.isNotEmpty) {
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

  EvmNetworkService _makeService(EvmNetwork network) =>
      widget.networkServiceBuilder?.call(network) ??
      EvmNetworkService(network: network);

  String _connectionError(Object error) {
    if (error is WalletInputException) return error.message;
    if (error is TimeoutException) return 'RPC 请求超时，请检查地址或更换节点。';
    return 'RPC 请求失败，请检查网络、节点地址或访问凭证。';
  }

  Future<void> _refreshBalance() async {
    final currentAccount = account;
    if (!mounted || currentAccount == null || networkServices.isEmpty) return;
    final request = ++balanceRequest;
    final services = networkServices.entries.toList();
    setState(() {
      isRefreshing = true;
      walletError = null;
      pendingNetworkIds
        ..clear()
        ..addAll(services.map((e) => e.key));
      networkErrors.clear();
    });
    await Future.wait(
      services.map((entry) async {
        BigInt? balance;
        String? failure;
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
          return;
        }
        setState(() {
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
      }),
    );
    if (!mounted || request != balanceRequest || account != currentAccount) {
      return;
    }
    setState(() {
      isRefreshing = false;
      lastSyncedAt = DateTime.now();
      final failed = enabledNetworks
          .where((n) => networkErrors.containsKey(n.id))
          .map((n) => n.name);
      walletError = failed.isEmpty
          ? null
          : '${failed.join('、')} 连接失败，可在设置中修改 RPC 或重试。';
    });
  }

  EvmNetwork? _networkForId(int? id) =>
      allNetworks.where((network) => network.id == id).firstOrNull;

  String _networkLabel(EvmNetwork network) =>
      '${network.name} · ${network.isTestnet ? '测试网' : '主网'}';

  void _configureNetworks(List<EvmNetwork> networks, {EvmNetwork? current}) {
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
    networkService = networkServices[nextCurrent?.id];
    if (!mounted) return;
    setState(() {
      enabledNetworks = List.unmodifiable(byId.values);
      selectedNetwork = nextCurrent;
      balancesByNetwork.removeWhere((id, _) => !byId.containsKey(id));
      responsiveNetworkIds.removeWhere((id) => !byId.containsKey(id));
      pendingNetworkIds.clear();
      networkErrors.clear();
      isRefreshing = false;
      balanceWei = balancesByNetwork[nextCurrent?.id];
      lastTxHash = null;
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
      if (mounted) _showMessage('网络选择保存失败，请重试。');
    }
  }

  Future<void> _clearNetwork() => _selectNetworks(const []);

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
      final allowCancel = portfolio.groups.isNotEmpty;
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
      await vault.saveRecoveryPhrase(creation.mnemonic);
      await _reloadPortfolio(goHome: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    }
  }

  Future<void> _importWallet() async {
    final mnemonic = await showWalletPanel<String>(
      context: context,
      builder: (context) => ImportWalletDialog(theme: theme),
    );
    if (mnemonic == null || mnemonic.trim().isEmpty) return;
    try {
      await vault.importWallet(mnemonic);
      await _reloadPortfolio(goHome: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
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
        ),
      ),
    );
    if (!mounted || imported == null) return;
    try {
      await _reloadPortfolio(goHome: true, useAccountNetwork: true);
      if (mounted) _showMessage('私钥账户已导入');
    } catch (_) {
      if (mounted) _showMessage('账户已保存，加载失败，请重新打开钱包。');
    }
  }

  Future<void> _importBatchWallets() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'txt'],
        withData: true,
      );
      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final content = file.bytes == null
          ? (file.path == null ? null : await File(file.path!).readAsString())
          : utf8.decode(file.bytes!);
      if (!mounted) return;
      if (content == null) {
        _showMessage('无法读取表格文件。');
        return;
      }
      final rows = _parseWalletImportTable(content);
      if (rows.isEmpty) {
        _showMessage('表格没有可导入的数据。首行为：链,私钥');
        return;
      }
      final result = await vault.importPrivateKeyWallets(rows);
      final loaded = await vault.loadPortfolio();
      if (!mounted) return;
      _applyPortfolio(loaded);
      final failures = result.errors.length;
      _showMessage(
        '成功导入 ${result.imported.length} 条${failures == 0 ? '' : '，$failures 条失败'}。',
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
      if (mounted) _showMessage(error.toString());
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
    final keyIndex = findColumn(['私钥', 'privatekey', 'private key', 'key']);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
      _showMessage('已选择 ${current.name}，正在连接 RPC…');
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
    setState(() => allNetworks = catalog);
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
    _showMessage('${saved.name} 网络配置已保存');
    return saved;
  }

  Future<void> _addNetwork() async {
    final network = await _editNetwork(null);
    if (!mounted || network == null) return;
    await _selectNetworks([...enabledNetworks, network], current: network);
  }

  void _selectPage(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => selectedNav = index);
    if (pageScroll.hasClients) pageScroll.jumpTo(0);
  }

  void _showAllAssets() => _selectPage(2);

  Future<void> _showAssetDetails(AssetRow asset) async {
    final network = _networkForId(asset.networkId);
    if (network == null) {
      await _showNetworkSelector();
      return;
    }
    await showWalletPanel<void>(
      context: context,
      width: 560,
      builder: (panelContext) => AssetDetailsPanel(
        theme: theme,
        asset: asset,
        network: network,
        address: account!.checksumAddress,
        onRefresh: () async {
          await _refreshBalance();
          return assets.firstWhere((a) => a.networkId == network.id);
        },
        onActivate: () async {
          Navigator.pop(panelContext);
          await _selectNetworks(enabledNetworks, current: network);
        },
        onAction: (action) async {
          final originalAccount = account;
          Navigator.pop(panelContext);
          await _selectNetworks(
            enabledNetworks,
            current: network,
            waitForBalance: false,
          );
          if (mounted &&
              account == originalAccount &&
              selectedNetwork?.id == network.id) {
            showAction(action);
          }
        },
      ),
    );
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
    showWalletPanel<void>(
      context: context,
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
    final txHash = await showWalletPanel<String>(
      context: context,
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

  void _applyPortfolio(WalletPortfolio loaded, {bool goHome = false}) {
    ++balanceRequest;
    setState(() {
      portfolio = loaded;
      account = loaded.selected?.account;
      walletName = loaded.selected?.displayName ?? '钱包';
      if (goHome) selectedNav = 0;
      isLoadingWallet = false;
      balanceWei = null;
      balancesByNetwork.clear();
      responsiveNetworkIds.clear();
      pendingNetworkIds.clear();
      networkErrors.clear();
      isRefreshing = false;
      lastTxHash = null;
      walletError = null;
    });
  }

  Future<void> _reloadPortfolio({
    bool goHome = false,
    bool useAccountNetwork = false,
  }) async {
    final loaded = await vault.loadPortfolio();
    if (!mounted) return;
    _applyPortfolio(loaded, goHome: goHome);
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
          builder: (_) => WalletImportOptions(theme: theme),
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
      builder: (_) =>
          WalletManagerPanel(theme: theme, initial: portfolio, vault: vault),
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
          error is WalletInputException ? error.message : '钱包操作失败，请重试。',
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
            onToggleStyle: widget.onToggleStyle,
          ),
        ),
      );
    }
    final layout = WalletLayout.of(context);
    return PopScope(
      canPop: selectedNav != 2,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedNav == 2) _selectPage(0);
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!layout.mobile)
                WalletRail(
                  theme: theme,
                  selected: selectedNav == 2 ? 0 : selectedNav,
                  onSelect: _selectPage,
                  onToggleStyle: widget.onToggleStyle,
                ),
              Expanded(child: _buildContent(layout)),
            ],
          ),
        ),
        bottomNavigationBar: layout.mobile
            ? WalletBottomBar(
                theme: theme,
                selected: selectedNav == 2 ? 0 : selectedNav,
                onSelect: _selectPage,
              )
            : null,
      ),
    );
  }

  Widget _buildContent(WalletLayout layout) {
    return SingleChildScrollView(
      controller: pageScroll,
      key: const ValueKey('page-scroll'),
      padding: EdgeInsets.all(layout.gutter),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WalletHeader(
                theme: theme,
                walletName: walletName,
                address: account!.checksumAddress,
                pageTitle: selectedNav == 0
                    ? '首页'
                    : selectedNav == 1
                    ? '设置'
                    : '链上资产',
                networkLabel: selectedNetwork?.name ?? '选择网络',
                onNetworkTap: selectedNav != 1 ? _showNetworkSelector : null,
                onWalletTap: selectWallet,
                onToggleStyle: widget.onToggleStyle,
              ),
              const SizedBox(height: 24),
              if (selectedNav == 1)
                SettingsPage(
                  theme: theme,
                  address: account!.checksumAddress,
                  networks: enabledNetworks,
                  currentNetwork: selectedNetwork,
                  networkServices: networkServices,
                  responsiveNetworkIds: responsiveNetworkIds,
                  onManageNetworks: _showNetworkSelector,
                  onBatchImport: _importBatchWallets,
                  onImportPrivateKey: _importPrivateKey,
                  onRefresh: _refreshBalance,
                  onToggleStyle: widget.onToggleStyle,
                  isPrivateKey: activeEntry?.kind == WalletKind.privateKey,
                  derivationPath: activeEntry?.derivationPath,
                  onManageWallets: selectWallet,
                  walletCount: portfolio.groups.length,
                  accountCount: portfolio.accounts.length,
                  onCreateWallet: _createWallet,
                  onImportMnemonic: _importWallet,
                  onEditNetwork: _editNetwork,
                  onAddNetwork: _addNetwork,
                  networkErrors: networkErrors,
                  pendingNetworkIds: pendingNetworkIds,
                )
              else if (selectedNav == 2)
                AssetsPage(
                  theme: theme,
                  assets: assets,
                  refreshing: isRefreshing,
                  onBack: () => _selectPage(0),
                  onRefresh: _refreshBalance,
                  onAssetTap: _showAssetDetails,
                  onManageNetworks: _showNetworkSelector,
                )
              else
                _dashboard(layout),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboard(WalletLayout layout) {
    final portfolio = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortfolioHero(
          theme: theme,
          compact: layout.mobile,
          balance: _currentBalanceLabel,
          network: selectedNetwork?.name ?? '选择网络',
          syncLabel: _syncLabel,
          onNetworkTap: _showNetworkSelector,
        ),
        _networkErrorBanner(),
        const SizedBox(height: 16),
        ActionRow(theme: theme, onAction: showAction, compact: layout.mobile),
        const SizedBox(height: 24),
        AssetTable(
          theme: theme,
          assets: assets.take(4).toList(),
          compact: layout.mobile,
          onViewAll: _showAllAssets,
          onAssetTap: _showAssetDetails,
        ),
      ],
    );
    if (!layout.wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          portfolio,
          const SizedBox(height: 24),
          ActivityPanel(theme: theme, activities: activities),
        ],
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: portfolio),
            const SizedBox(width: 24),
            SizedBox(
              width: 300,
              child: ActivityPanel(theme: theme, activities: activities),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SecurityBanner(theme: theme),
      ],
    );
  }
}
