part of '../main.dart';

class AssetTable extends StatelessWidget {
  const AssetTable({
    required this.theme,
    required this.assets,
    this.compact = false,
    this.onViewAll,
    this.onAssetTap,
    super.key,
  });

  final WalletTheme theme;
  final List<AssetRow> assets;
  final bool compact;
  final VoidCallback? onViewAll;
  final ValueChanged<AssetRow>? onAssetTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 16 : 22, 18, compact ? 16 : 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onViewAll,
                  child: Text(
                    tr(context, MessageCode.msgOnchainAssets),
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(tr(context, MessageCode.msgViewAll)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!compact)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _HeaderText(
                      tr(context, MessageCode.msgAssets),
                      theme,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _HeaderText(
                      tr(context, MessageCode.msgNetwork),
                      theme,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _HeaderText(
                      tr(context, MessageCode.msgBalance),
                      theme,
                    ),
                  ),
                  Expanded(
                    child: _HeaderText(
                      tr(context, MessageCode.msgStatus),
                      theme,
                      align: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ...assets.map(
            (asset) => AssetListRow(
              asset: asset,
              theme: theme,
              compact: compact,
              onTap: onAssetTap == null ? null : () => onAssetTap!(asset),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.value, this.theme, {this.align = TextAlign.left});

  final Object value;
  final WalletTheme theme;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    localized(context, value),
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
    this.onTap,
    super.key,
  });

  final AssetRow asset;
  final WalletTheme theme;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
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
                            localized(context, asset.symbol),
                            style: TextStyle(
                              color: theme.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            localized(context, asset.name),
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
                    localized(context, asset.network),
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
                      displayQuantity(context, asset.amount),
                      textAlign: compact ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (compact)
                      Text(
                        localized(context, asset.change),
                        style: TextStyle(
                          color:
                              asset.change is WalletMessage &&
                                  (asset.change as WalletMessage).code ==
                                      MessageCode.msgSynced
                              ? theme.success
                              : theme.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (!compact)
                Expanded(
                  child: Text(
                    localized(context, asset.change),
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
        ),
      ),
    );
  }
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
    this.networkId,
    this.error,
  });

  final String symbol;
  final Object name;
  final Object network;
  final String amount;
  final Object value;
  final Object change;
  final IconData icon;
  final Color color;
  final int? networkId;
  final WalletMessage? error;
}
