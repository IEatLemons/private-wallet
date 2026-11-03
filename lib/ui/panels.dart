part of '../main.dart';

class WalletOption {
  const WalletOption({
    required this.name,
    required this.account,
    this.network,
    this.selected = false,
  });
  final String name;
  final WalletAccount account;
  final EvmNetwork? network;
  final bool selected;
}

class WalletPicker extends StatelessWidget {
  const WalletPicker({
    required this.theme,
    required this.options,
    required this.onSelect,
    super.key,
  });
  final WalletTheme theme;
  final List<WalletOption> options;
  final ValueChanged<WalletOption> onSelect;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: '选择钱包',
    scrollBody: false,
    child: SizedBox(
      height: 360,
      child: ListView.separated(
        key: const ValueKey('wallet-list'),
        itemCount: options.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: theme.border),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            onTap: () => onSelect(option),
            leading: CircleAvatar(
              backgroundColor: theme.surfaceStrong,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.primary,
                size: 20,
              ),
            ),
            title: Text(
              option.name,
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${option.network?.name ?? '助记词钱包'}\n${shortAddress(option.account.checksumAddress)}',
              style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
            ),
            trailing: option.selected
                ? Icon(Icons.check_circle, color: theme.primary)
                : null,
          );
        },
      ),
    ),
  );
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
  final String action, walletName, networkLabel, address;
  final WalletTheme theme;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: action,
    subtitle: '请确认接收资产的网络与你选择的网络一致。',
    footer: FilledButton.icon(
      onPressed: onConfirm,
      icon: const Icon(Icons.copy_outlined, size: 18),
      label: const Text('复制收款地址'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletCard(
          theme: theme,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                walletName,
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(networkLabel, style: TextStyle(color: theme.muted)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: QrImageView(
            data: address,
            size: 176,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        SelectableText(
          address,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.text, fontSize: 14, height: 1.6),
        ),
      ],
    ),
  );
}

class NetworkSelectorSheet extends StatefulWidget {
  const NetworkSelectorSheet({
    required this.theme,
    required this.networks,
    required this.selectedNetworks,
    required this.currentNetwork,
    this.onEdit,
    super.key,
  });
  final WalletTheme theme;
  final List<EvmNetwork> networks, selectedNetworks;
  final EvmNetwork? currentNetwork;
  final Future<EvmNetwork?> Function(EvmNetwork?)? onEdit;
  @override
  State<NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<NetworkSelectorSheet> {
  late final List<EvmNetwork> networks = List.of(widget.networks);
  late final Set<int> selectedIds = widget.selectedNetworks
      .map((n) => n.id)
      .toSet();
  late int? currentId = widget.currentNetwork?.id ?? selectedIds.firstOrNull;

  void _toggle(EvmNetwork network) => setState(() {
    if (!selectedIds.add(network.id)) {
      selectedIds.remove(network.id);
      if (currentId == network.id) currentId = selectedIds.firstOrNull;
    } else {
      currentId ??= network.id;
    }
  });

  void _save() {
    final selected = networks.where((n) => selectedIds.contains(n.id)).toList();
    Navigator.pop(
      context,
      NetworkSelectionResult(
        networks: selected,
        current: selected.where((n) => n.id == currentId).firstOrNull,
      ),
    );
  }

  void _setCurrent(EvmNetwork network) => setState(() {
    selectedIds.add(network.id);
    currentId = network.id;
  });

  Future<void> _edit(EvmNetwork? network) async {
    final result = await widget.onEdit?.call(network);
    if (!mounted || result == null) return;
    setState(() {
      final index = networks.indexWhere((n) => n.id == result.id);
      if (index < 0) {
        networks.add(result);
        selectedIds.add(result.id);
        currentId = result.id;
      } else {
        networks[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: '管理网络',
    subtitle: '可同时启用多条链查看余额。只有点击保存后，选中的网络才会访问 RPC。',
    footer: FilledButton(
      onPressed: _save,
      child: Text(selectedIds.isEmpty ? '断开所有网络' : '保存网络选择'),
    ),
    child: Column(
      children: [
        Text(
          '点击网络名称可切换当前链；勾选框用于同时启用多条链。',
          style: TextStyle(color: widget.theme.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (widget.onEdit != null)
          OutlinedButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('添加自定义链'),
          ),
        const SizedBox(height: 12),
        for (final network in networks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selectedIds.contains(network.id),
                  onChanged: (_) => _toggle(network),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _setCurrent(network),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            network.name,
                            style: TextStyle(
                              color: widget.theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (currentId == network.id)
                            Text(
                              '当前操作链',
                              style: TextStyle(
                                color: widget.theme.primary,
                                fontSize: 12,
                              ),
                            ),
                          if (widget.onEdit != null)
                            TextButton(
                              onPressed: () => _edit(network),
                              child: const Text('编辑 RPC'),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'Chain ID ${network.id} · ${network.nativeSymbol} · ${network.isTestnet ? '测试网' : '主网'}',
                            style: TextStyle(
                              color: widget.theme.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '设为当前操作链',
                  onPressed: () => _setCurrent(network),
                  icon: Icon(
                    currentId == network.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selectedIds.contains(network.id)
                        ? widget.theme.primary
                        : widget.theme.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
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

class RecoveryPhraseSheet extends StatefulWidget {
  const RecoveryPhraseSheet({
    required this.theme,
    required this.mnemonic,
    this.allowCancel = false,
    super.key,
  });
  final WalletTheme theme;
  final String mnemonic;
  final bool allowCancel;
  @override
  State<RecoveryPhraseSheet> createState() => _RecoveryPhraseSheetState();
}

class _RecoveryPhraseSheetState extends State<RecoveryPhraseSheet> {
  static const indexes = [1, 5, 9];
  late final words = widget.mnemonic.split(' ');
  final controllers = List.generate(3, (_) => TextEditingController());
  bool verifying = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _continue() {
    if (!verifying) {
      setState(() => verifying = true);
      return;
    }
    final valid = indexes.asMap().entries.every(
      (e) =>
          controllers[e.key].text.trim().toLowerCase() ==
          words[e.value].toLowerCase(),
    );
    if (!valid) {
      setState(() => error = '助记词校验不正确，请重新核对第 2、6、10 个单词。');
      return;
    }
    closeWalletPanel(context, true);
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: verifying ? '验证恢复助记词' : '记录恢复助记词',
    canClose: widget.allowCancel,
    expandBody: WalletLayout.of(context).mobile,
    footer: FilledButton(
      onPressed: _continue,
      child: Text(verifying ? '验证并进入钱包' : '我已记录，继续验证'),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          verifying ? '记录  ✓     →     ② 验证' : '① 记录     →     ② 验证',
          style: TextStyle(
            color: widget.theme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          verifying ? '请输入指定位置的单词，验证后完成创建。' : '请按顺序记录以下单词，保存在离线安全位置。',
          style: TextStyle(
            color: widget.theme.muted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        if (!verifying)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = WalletLayout.of(context).mobile ? 2 : 3;
              final cellWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in words.asMap().entries)
                    Container(
                      width: cellWidth,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.theme.surfaceStrong,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.key + 1}. ${entry.value}',
                        style: TextStyle(
                          color: widget.theme.text,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (final entry in indexes.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[entry.key],
                autofocus: entry.key == 0,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: entry.key == 2
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) => entry.key == 2
                    ? _continue()
                    : FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: '第 ${entry.value + 1} 个单词',
                ),
              ),
            ),
        const SizedBox(height: 20),
        Text(
          '不要截图、复制或发送助记词。校验在本机完成。',
          style: TextStyle(
            color: widget.theme.danger,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: widget.theme.danger, fontSize: 13),
          ),
        ],
      ],
    ),
  );
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
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: '导入钱包',
    subtitle: '输入已有钱包的助记词，单词之间用空格分隔。',
    footer: FilledButton(
      onPressed: () => closeWalletPanel(context, controller.text),
      child: const Text('导入'),
    ),
    child: TextField(
      controller: controller,
      // Let the mobile route settle before connecting the native keyboard.
      // The user taps the field to enter or paste; desktop keeps autofocus.
      autofocus: !WalletLayout.of(context).mobile,
      minLines: 4,
      maxLines: 6,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      style: TextStyle(color: widget.theme.text, fontSize: 14, height: 1.6),
      decoration: const InputDecoration(hintText: '请输入 12 或 24 个助记词单词'),
    ),
  );
}

class ImportPrivateKeyPanel extends StatefulWidget {
  const ImportPrivateKeyPanel({
    required this.theme,
    required this.networks,
    required this.onImport,
    this.currentNetwork,
    super.key,
  });

  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final EvmNetwork? currentNetwork;
  final Future<ImportedWallet> Function(String, EvmNetwork) onImport;

  @override
  State<ImportPrivateKeyPanel> createState() => _ImportPrivateKeyPanelState();
}

class _ImportPrivateKeyPanelState extends State<ImportPrivateKeyPanel> {
  final controller = TextEditingController();
  late EvmNetwork? network = widget.currentNetwork;
  bool obscure = true;
  bool importing = false;
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (importing) return;
    final selected = network;
    if (selected == null) {
      setState(() => error = '请选择导入后要查看的网络。');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      importing = true;
      error = null;
    });
    try {
      final imported = await widget.onImport(controller.text, selected);
      controller.clear();
      if (mounted) closeWalletPanel(context, imported);
    } catch (e) {
      if (mounted) {
        setState(() {
          importing = false;
          error = e is WalletInputException ? e.message : '私钥导入失败，请重试。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !importing,
    child: WalletPanel(
      theme: widget.theme,
      title: '导入私钥',
      subtitle: '使用已有的 EVM 私钥恢复账户，无需助记词。',
      canClose: !importing,
      footer: FilledButton(
        onPressed: importing ? null : _submit,
        child: Text(importing ? '导入中…' : '导入并进入钱包'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: network?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '网络'),
            hint: const Text('请选择网络'),
            items: [
              for (final n in widget.networks)
                DropdownMenuItem(
                  value: n.id,
                  child: Text(
                    '${n.name} · ${n.isTestnet ? '测试网' : '主网'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: importing
                ? null
                : (id) => setState(() {
                    network = widget.networks.firstWhere((n) => n.id == id);
                    error = null;
                  }),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('private-key-input'),
            controller: controller,
            enabled: !importing,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: '私钥',
              hintText: '64 位十六进制，可带 0x 前缀',
              suffixIcon: IconButton(
                tooltip: obscure ? '显示私钥' : '隐藏私钥',
                onPressed: importing
                    ? null
                    : () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '私钥仅保存在本机系统安全存储中。导入成功后，将连接所选网络查询余额；私钥不会发送给 RPC。',
            style: TextStyle(
              color: widget.theme.muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: TextStyle(color: widget.theme.danger, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}

class ImportResultDialog extends StatelessWidget {
  const ImportResultDialog({
    required this.theme,
    required this.errors,
    this.importedCount = 0,
    super.key,
  });
  final WalletTheme theme;
  final List<WalletImportError> errors;
  final int importedCount;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: '导入结果',
    scrollBody: false,
    footer: FilledButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('知道了'),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          child: Text(
            '成功 $importedCount 条 · 跳过或失败 ${errors.length} 条',
            style: TextStyle(color: theme.text, fontSize: 15),
          ),
        ),
        if (errors.isNotEmpty)
          Flexible(
            child: SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: errors.length,
                separatorBuilder: (_, _) => Divider(color: theme.border),
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '第 ${errors[index].row} 条：${errors[index].message}',
                    style: TextStyle(
                      color: theme.danger,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
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
  final recipientController = TextEditingController(),
      amountController = TextEditingController();
  bool sending = false;
  String? error;
  String? uncertainHash;
  @override
  void dispose() {
    recipientController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (sending || uncertainHash != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final recipient = recipientController.text.trim(),
          amount = amountController.text.trim();
      EthereumAddress.fromHex(recipient, enforceEip55: false);
      final wei = parseEtherToWei(amount);
      if (wei <= BigInt.zero) throw const WalletInputException('金额必须大于 0。');
      if (widget.balanceWei != null && wei > widget.balanceWei!) {
        throw const WalletInputException('金额超过当前余额。');
      }
      setState(() {
        sending = true;
        error = null;
      });
      final tx = await widget.onSend(recipient, amount);
      if (mounted) Navigator.pop(context, tx);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = e.toString();
          if (e is RpcBroadcastException) uncertainHash = e.transactionHash;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: WalletPanel(
      theme: widget.theme,
      title: '发送 ${widget.network.nativeSymbol}',
      canClose: !sending,
      subtitle:
          '${widget.network.name} · ${widget.network.isTestnet ? '测试网' : '主网'} · 在本机完成签名',
      footer: FilledButton(
        onPressed: sending || uncertainHash != null ? null : _submit,
        child: sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(uncertainHash != null ? '请先确认交易状态' : '签名并广播'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: recipientController,
            enabled: !sending,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '收款地址',
              hintText: '0x…',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountController,
            enabled: !sending,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '金额（${widget.network.nativeSymbol}）',
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 16),
          if (widget.balanceWei != null)
            Text(
              '可用余额：${formatWeiAsEther(widget.balanceWei!)} ${widget.network.nativeSymbol} · Gas 费另行扣除',
              style: TextStyle(
                color: widget.theme.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              error!,
              style: TextStyle(color: widget.theme.danger, fontSize: 13),
            ),
          ],
          if (uncertainHash != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              '交易哈希：$uncertainHash',
              style: TextStyle(color: widget.theme.text, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}
