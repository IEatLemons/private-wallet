part of '../main.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.theme,
    required this.error,
    required this.onCreate,
    required this.onImport,
    required this.onBatchImport,
    required this.onToggleStyle,
    super.key,
  });
  final WalletTheme theme;
  final String? error;
  final VoidCallback onCreate, onImport, onBatchImport, onToggleStyle;

  Widget _intro(bool mobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'SELF-CUSTODY · EVM',
        style: TextStyle(
          color: theme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '你的密钥，\n你的钱包。',
        style: TextStyle(
          color: theme.text,
          fontSize: mobile ? 30 : 40,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        '轻松管理你的链上资产。\n创建钱包，或导入已有账户，即可开始。',
        style: TextStyle(color: theme.muted, fontSize: 15, height: 1.7),
      ),
    ],
  );

  Widget _features() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _NoticeLine(
        theme: theme,
        icon: Icons.key_outlined,
        title: '自托管钱包',
        detail: '交易在本机签名，密钥由你掌握。',
      ),
      const SizedBox(height: 20),
      _NoticeLine(
        theme: theme,
        icon: Icons.lock_outline,
        title: '系统安全存储',
        detail: '恢复凭证保存在本机系统安全存储中。',
      ),
      const SizedBox(height: 20),
      _NoticeLine(
        theme: theme,
        icon: Icons.public,
        title: '网络由你选择',
        detail: '启用网络后，才会连接对应的 RPC。',
      ),
    ],
  );

  Widget _actions(bool mobile) => WalletCard(
    theme: theme,
    padding: EdgeInsets.all(mobile ? 20 : 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '开始使用 Stone Wallet',
          style: TextStyle(
            color: theme.text,
            fontSize: mobile ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text('选择适合你的方式', style: TextStyle(color: theme.muted, fontSize: 14)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('创建新钱包'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.key_outlined, size: 18),
          label: const Text('导入助记词'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onBatchImport,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: const Text('批量导入私钥表格'),
        ),
        const SizedBox(height: 12),
        Text(
          'CSV / TSV · 包含「链」「私钥」两列',
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.5),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: theme.danger, fontSize: 13)),
        ],
        const SizedBox(height: 24),
        Divider(color: theme.border, height: 1),
        const SizedBox(height: 16),
        Text(
          '请妥善保管助记词与私钥，它们是恢复钱包的凭证。',
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );

  Widget _mobileFeatures() => Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      for (final feature in [
        (Icons.key_outlined, '自托管钱包'),
        (Icons.lock_outline, '系统安全存储'),
        (Icons.public, '网络由你选择'),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(feature.$1, color: theme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              feature.$2,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = WalletLayout(constraints.maxWidth);
      final horizontal = layout.mobile ? 20.0 : 40.0;
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout.splitWelcome ? 1120 : 640,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BrandMark(theme: theme),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Stone Wallet',
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        ThemeToggle(theme: theme, onTap: onToggleStyle),
                      ],
                    ),
                    SizedBox(height: layout.mobile ? 32 : 24),
                    if (layout.splitWelcome)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 144).clamp(
                            0,
                            800,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _intro(false),
                                  const SizedBox(height: 32),
                                  _features(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 64),
                            SizedBox(width: 400, child: _actions(false)),
                          ],
                        ),
                      )
                    else ...[
                      _intro(layout.mobile),
                      const SizedBox(height: 24),
                      _actions(layout.mobile),
                      const SizedBox(height: 28),
                      layout.mobile ? _mobileFeatures() : _features(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
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
  final String title, detail;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surfaceStrong,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: TextStyle(color: theme.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
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
    required this.onBatchImport,
    required this.onRefresh,
    required this.onToggleStyle,
    this.isPrivateKey = false,
    this.onEditNetwork,
    this.onAddNetwork,
    this.networkErrors = const {},
    this.pendingNetworkIds = const {},
    super.key,
  });
  final WalletTheme theme;
  final String address;
  final List<EvmNetwork> networks;
  final EvmNetwork? currentNetwork;
  final Map<int, EvmNetworkService> networkServices;
  final Set<int> responsiveNetworkIds;
  final VoidCallback onManageNetworks, onBatchImport, onToggleStyle;
  final Future<void> Function() onRefresh;
  final bool isPrivateKey;
  final Future<EvmNetwork?> Function(EvmNetwork?)? onEditNetwork;
  final VoidCallback? onAddNetwork;
  final Map<int, String> networkErrors;
  final Set<int> pendingNetworkIds;

  Widget _section(String title, IconData icon, Widget child) => WalletCard(
    theme: theme,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.muted, fontSize: 12)),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: TextStyle(color: theme.text, fontSize: 14, height: 1.5),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final networkCard = _section(
      '网络与 RPC',
      Icons.public,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (networks.isEmpty)
            Text(
              '尚未选择网络。首页不会请求任何 RPC。',
              style: TextStyle(color: theme.muted, fontSize: 14, height: 1.5),
            ),
          for (final network in networks)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        network.name,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (currentNetwork?.id == network.id)
                        Text(
                          '当前操作链',
                          style: TextStyle(color: theme.primary, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chain ID ${network.id} · ${network.nativeSymbol} · ${network.isTestnet ? '测试网' : '主网'}',
                    style: TextStyle(color: theme.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    network.rpcUrl,
                    style: TextStyle(
                      color: theme.muted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pendingNetworkIds.contains(network.id)
                        ? '○ 同步中…'
                        : networkErrors[network.id] ??
                              (responsiveNetworkIds.contains(network.id)
                                  ? '● RPC 已连接'
                                  : '○ 尚未同步'),
                    style: TextStyle(
                      fontSize: 12,
                      color: responsiveNetworkIds.contains(network.id)
                          ? theme.success
                          : theme.muted,
                    ),
                  ),
                  if (onEditNetwork != null)
                    TextButton.icon(
                      key: ValueKey('edit-rpc-${network.id}'),
                      onPressed: () => onEditNetwork!(network),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('编辑 RPC'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onManageNetworks,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('管理网络'),
              ),
              IconButton(
                tooltip: '刷新余额',
                onPressed: () => onRefresh(),
                icon: Icon(Icons.refresh, color: theme.primary),
              ),
              if (onAddNetwork != null)
                OutlinedButton.icon(
                  onPressed: onAddNetwork,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加自定义链'),
                ),
            ],
          ),
        ],
      ),
    );
    final security = _section(
      '钱包安全',
      Icons.shield_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('钱包地址', address),
          _info(
            isPrivateKey ? '账户来源' : '派生路径',
            isPrivateKey ? '私钥导入' : evmDerivationPath,
          ),
          Text(
            '助记词与私钥仅保存在本机安全存储中，请自行保管恢复凭证。',
            style: TextStyle(color: theme.muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
    final batch = _section(
      '批量导入',
      Icons.upload_file_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '从 CSV / TSV 表格导入多个账户。\n表头需要包含「链」「私钥」两列。',
            style: TextStyle(color: theme.muted, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onBatchImport,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('选择表格导入'),
            ),
          ),
        ],
      ),
    );
    final backup = _section(
      '备份',
      Icons.backup_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FilledButton(
            onPressed: null,
            child: Text(
              'iCloud / Google Drive 云备份（暂未接入）',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '请将恢复凭证妥善保存在离线安全位置。',
            style: TextStyle(color: theme.muted, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
    final side = Column(
      children: [
        security,
        const SizedBox(height: 24),
        batch,
        const SizedBox(height: 24),
        backup,
      ],
    );
    if (WalletLayout.of(context).wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: networkCard),
          const SizedBox(width: 24),
          Expanded(child: side),
        ],
      );
    }
    return Column(children: [networkCard, const SizedBox(height: 24), side]);
  }
}
