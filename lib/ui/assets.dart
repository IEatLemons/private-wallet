part of '../main.dart';

class AssetsPage extends StatefulWidget {
  const AssetsPage({
    required this.theme,
    required this.assets,
    required this.refreshing,
    required this.onBack,
    required this.onRefresh,
    required this.onAssetTap,
    required this.onManageNetworks,
    super.key,
  });
  final WalletTheme theme;
  final List<AssetRow> assets;
  final bool refreshing;
  final VoidCallback onBack, onManageNetworks;
  final Future<void> Function() onRefresh;
  final ValueChanged<AssetRow> onAssetTap;
  @override
  State<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<AssetsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final rows = widget.assets
        .where(
          (a) => '${a.name} ${a.symbol} ${a.network}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('返回首页'),
            ),
            OutlinedButton.icon(
              onPressed: widget.refreshing ? null : () => widget.onRefresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(widget.refreshing ? '同步中…' : '刷新资产'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onManageNetworks,
              icon: const Icon(Icons.public, size: 18),
              label: const Text('管理网络'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: '搜索资产或网络',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '显示已启用网络的原生资产；未同步的余额显示为 —。',
          style: TextStyle(
            color: widget.theme.muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        if (rows.isEmpty)
          WalletCard(
            theme: widget.theme,
            child: Text(
              '没有匹配的资产。',
              style: TextStyle(color: widget.theme.muted),
            ),
          )
        else
          AssetTable(
            theme: widget.theme,
            assets: rows,
            compact: WalletLayout.of(context).mobile,
            onAssetTap: widget.onAssetTap,
          ),
      ],
    );
  }
}

class AssetDetailsPanel extends StatefulWidget {
  const AssetDetailsPanel({
    required this.theme,
    required this.asset,
    required this.network,
    required this.address,
    required this.onRefresh,
    required this.onActivate,
    required this.onAction,
    super.key,
  });
  final WalletTheme theme;
  final AssetRow asset;
  final EvmNetwork network;
  final String address;
  final Future<AssetRow> Function() onRefresh;
  final Future<void> Function() onActivate;
  final Future<void> Function(String) onAction;
  @override
  State<AssetDetailsPanel> createState() => _AssetDetailsPanelState();
}

class _AssetDetailsPanelState extends State<AssetDetailsPanel> {
  late AssetRow asset = widget.asset;
  bool refreshing = false;
  Future<void> _refresh() async {
    setState(() => refreshing = true);
    try {
      final next = await widget.onRefresh();
      if (mounted) setState(() => asset = next);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: widget.theme.muted, fontSize: 12)),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: TextStyle(color: widget.theme.text, fontSize: 14, height: 1.6),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: '${asset.symbol} 资产详情',
    footer: Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => widget.onAction('发送'),
          icon: const Icon(Icons.north_east, size: 18),
          label: const Text('发送'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onAction('接收'),
          icon: const Icon(Icons.south_west, size: 18),
          label: const Text('接收'),
        ),
        TextButton(onPressed: widget.onActivate, child: const Text('设为当前链')),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          asset.amount,
          style: TextStyle(
            color: widget.theme.text,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          refreshing ? '同步中…' : asset.error ?? asset.change,
          style: TextStyle(
            color: asset.error == null
                ? widget.theme.muted
                : widget.theme.danger,
            fontSize: 13,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: refreshing ? null : _refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新余额'),
          ),
        ),
        _info('网络', '${widget.network.name} · Chain ID ${widget.network.id}'),
        _info('钱包地址', widget.address),
        _info('RPC 地址', widget.network.rpcUrls.join('\n')),
        if (widget.network.explorerUrl.isNotEmpty) ...[
          _info('区块浏览器', widget.network.explorerUrl),
          TextButton.icon(
            onPressed: () async {
              final url =
                  '${widget.network.explorerUrl.replaceFirst(RegExp(r'/$'), '')}/address/${widget.address}';
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('浏览器链接已复制')));
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('复制浏览器链接'),
          ),
        ],
      ],
    ),
  );
}
