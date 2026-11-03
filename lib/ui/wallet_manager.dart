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
    super.key,
  });
  final WalletTheme theme;
  final WalletPortfolio initial;
  final WalletVault vault;
  @override
  State<WalletManagerPanel> createState() => _WalletManagerPanelState();
}

class _WalletManagerPanelState extends State<WalletManagerPanel> {
  late WalletPortfolio portfolio = widget.initial;
  bool busy = false;
  String query = '';
  String? error;

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
      if (close) closeWalletPanel(context, WalletManagerAction.selected);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is WalletInputException ? e.message : '操作失败，请重试。';
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
        title: account ? '重命名账户' : '重命名钱包',
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

  Widget _group(WalletGroup group, List<WalletEntry> accounts) {
    final theme = widget.theme;
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
                                group.accounts.first.id,
                              ),
                              close: true,
                            ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${group.kind == WalletKind.mnemonic ? '助记词钱包' : '私钥钱包'} · ${group.accounts.length} 个账户',
                            style: TextStyle(color: theme.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('rename-wallet-${group.id}'),
                    tooltip: '重命名钱包',
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
                    entry.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${shortAddress(entry.account.checksumAddress)}${entry.derivationPath == null ? '' : '\n${entry.derivationPath}'}',
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
                        tooltip: '复制账户地址',
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: entry.account.checksumAddress),
                        ),
                        icon: Icon(
                          Icons.copy_outlined,
                          color: theme.muted,
                          size: 16,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('rename-account-${entry.id}'),
                        tooltip: '重命名账户',
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
                  onPressed: busy
                      ? null
                      : () => _change(
                          () => widget.vault.addDerivedAccount(group.id),
                        ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加账户'),
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
    for (final group in portfolio.groups) {
      final entries = group.accounts
          .where(
            (a) => '${group.name} ${a.name} ${a.account.checksumAddress}'
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
        title: '钱包管理',
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
              label: const Text('创建新钱包'),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => closeWalletPanel(
                      context,
                      WalletManagerAction.importOptions,
                    ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('导入钱包'),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${portfolio.groups.length} 个钱包 · ${portfolio.accounts.length} 个账户',
              style: TextStyle(color: widget.theme.muted, fontSize: 13),
            ),
            if (!keyboardVisible) ...[
              const SizedBox(height: 8),
              Text(
                '一个助记词钱包可添加多个账户；新的助记词或私钥会保存为独立钱包。',
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
              onChanged: (s) => setState(() => query = s),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索钱包、账户或地址',
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: widget.theme.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: SizedBox(
                height: 420,
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          '没有匹配的钱包或账户',
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
          ],
        ),
      ),
    );
  }
}

class WalletImportOptions extends StatelessWidget {
  const WalletImportOptions({required this.theme, super.key});
  final WalletTheme theme;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: '导入钱包',
    subtitle: '已有的钱包会保留，可随时切换。',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in [
          (
            WalletManagerAction.importMnemonic,
            Icons.key_outlined,
            '导入助记词',
            '恢复钱包，并继续添加派生账户',
          ),
          (
            WalletManagerAction.importPrivateKey,
            Icons.vpn_key_outlined,
            '导入私钥',
            '导入已有的单个 EVM 账户',
          ),
          (
            WalletManagerAction.batchImport,
            Icons.upload_file_outlined,
            '批量导入私钥表格',
            '从 CSV / TSV 导入多个账户',
          ),
        ])
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => closeWalletPanel(context, option.$1),
            leading: Icon(option.$2, color: theme.primary),
            title: Text(
              option.$3,
              style: TextStyle(color: theme.text, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              option.$4,
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
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = controller.text.trim();
    if (value.isEmpty || value.length > 64) {
      setState(() => error = '名称需要包含 1 至 64 个字符。');
      return;
    }
    closeWalletPanel(context, value);
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: widget.title,
    footer: FilledButton(onPressed: _save, child: const Text('保存名称')),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: 64,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: '名称'),
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: widget.theme.danger, fontSize: 13),
          ),
      ],
    ),
  );
}
