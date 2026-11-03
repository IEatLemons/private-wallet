part of '../main.dart';

class NetworkEditorPanel extends StatefulWidget {
  const NetworkEditorPanel({
    required this.theme,
    required this.networks,
    required this.onSave,
    required this.onCheck,
    this.network,
    super.key,
  });
  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final EvmNetwork? network;
  final Future<void> Function(EvmNetwork) onSave;
  final Future<void> Function(EvmNetwork) onCheck;
  @override
  State<NetworkEditorPanel> createState() => _NetworkEditorPanelState();
}

class _NetworkEditorPanelState extends State<NetworkEditorPanel> {
  late final name = TextEditingController(text: widget.network?.name);
  late final chainId = TextEditingController(
    text: widget.network?.id.toString(),
  );
  late final symbol = TextEditingController(text: widget.network?.nativeSymbol);
  late final rpc = TextEditingController(
    text: widget.network?.rpcUrls.join('\n'),
  );
  late final explorer = TextEditingController(
    text: widget.network?.explorerUrl,
  );
  late bool testnet = widget.network?.isTestnet ?? false;
  bool saving = false, checking = false;
  String? error, checkStatus;
  @override
  void dispose() {
    for (final c in [name, chainId, symbol, rpc, explorer]) {
      c.dispose();
    }
    super.dispose();
  }

  EvmNetwork _value() {
    final id = int.tryParse(chainId.text.trim());
    if (id == null) throw const WalletInputException('Chain ID 必须是有效的正整数。');
    if (widget.network == null && widget.networks.any((n) => n.id == id)) {
      throw const WalletInputException('该 Chain ID 已存在，请编辑现有网络的 RPC。');
    }
    final network = EvmNetwork(
      id: id,
      name: name.text.trim(),
      nativeSymbol: symbol.text.trim(),
      rpcUrl: _rpcUrls.first,
      fallbackRpcUrls: _rpcUrls.skip(1).toList(),
      explorerUrl: explorer.text.trim(),
      isTestnet: testnet,
    );
    network.validate();
    return network;
  }

  List<String> get _rpcUrls {
    final urls = rpc.text
        .split(RegExp(r'\s+'))
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (urls.isEmpty) throw const WalletInputException('请至少配置一个 RPC 地址。');
    return urls;
  }

  Future<void> _check() async {
    try {
      final network = _value();
      setState(() {
        checking = true;
        error = null;
        checkStatus = null;
      });
      await widget.onCheck(network);
      if (mounted) setState(() => checkStatus = 'RPC 可用，Chain ID 与网络配置一致。');
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is WalletInputException
              ? e.message
              : '检测失败，请检查 RPC 地址、网络或访问凭证。',
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _save() async {
    try {
      final network = _value();
      setState(() {
        saving = true;
        error = null;
      });
      await widget.onSave(network);
      if (mounted) Navigator.pop(context, network);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is WalletInputException ? e.message : '网络配置保存失败，请重试。';
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool enabled = true,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: controller,
      enabled: enabled && !saving && !checking,
      autocorrect: false,
      keyboardType: type,
      onChanged: (_) {
        if (checkStatus != null) setState(() => checkStatus = null);
      },
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: WalletPanel(
      theme: widget.theme,
      title: widget.network == null ? '添加自定义 EVM 链' : '编辑网络与 RPC',
      subtitle: '每行填写一个 RPC 地址，按顺序尝试；失败后自动切换，后续优先使用可用节点。',
      canClose: !saving,
      footer: FilledButton(
        onPressed: saving || checking ? null : _save,
        child: Text(saving ? '保存中…' : '保存网络配置'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('网络名称', name, hint: '例如：Base'),
          _field(
            'Chain ID',
            chainId,
            hint: '例如：8453',
            enabled: widget.network == null,
            type: TextInputType.number,
          ),
          _field('原生代币符号', symbol, hint: '例如：ETH'),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              controller: rpc,
              enabled: !saving && !checking,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() => checkStatus = null),
              decoration: const InputDecoration(
                labelText: 'RPC 地址',
                hintText: 'https://第一个节点\nhttps://备用节点',
                helperText: '每行一个；顺序即优先级，自动去重。',
              ),
            ),
          ),
          if (widget.network != null &&
              supportedEvmNetworks.any((n) => n.id == widget.network!.id))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: saving || checking
                    ? null
                    : () => setState(() {
                        rpc.text = supportedEvmNetworks
                            .firstWhere((n) => n.id == widget.network!.id)
                            .rpcUrls
                            .join('\n');
                        checkStatus = null;
                        error = null;
                      }),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('恢复内置免费节点'),
              ),
            ),
          _field(
            '区块浏览器地址（可选）',
            explorer,
            hint: 'https://…',
            type: TextInputType.url,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('测试网'),
            value: testnet,
            onChanged: saving || checking
                ? null
                : (v) => setState(() => testnet = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving || checking ? null : _check,
            icon: const Icon(Icons.network_check, size: 18),
            label: Text(checking ? '检测中…' : '检测 RPC 连接'),
          ),
          if (checkStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                checkStatus!,
                style: TextStyle(color: widget.theme.success, fontSize: 13),
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
        ],
      ),
    ),
  );
}
