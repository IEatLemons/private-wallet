part of '../main.dart';

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
  final String balance, network, syncLabel;
  final VoidCallback onNetworkTap;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final active = syncLabel.startsWith('RPC 已连接');
    return WalletCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '资产总览',
            style: TextStyle(
              color: theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (compact) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: NetworkButton(
                  theme: theme,
                  label: network,
                  onTap: onNetworkTap,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('当前链余额', style: TextStyle(color: theme.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            balance,
            style: TextStyle(
              color: theme.text,
              fontSize: compact ? 32 : 40,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                active ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                size: 16,
                color: active ? theme.success : theme.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  syncLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: active ? theme.success : theme.muted,
                  ),
                ),
              ),
            ],
          ),
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
    final send = FilledButton.icon(
      onPressed: () => onAction('发送'),
      icon: const Icon(Icons.north_east, size: 18),
      label: const Text('发送'),
    );
    final receive = OutlinedButton.icon(
      onPressed: () => onAction('接收'),
      icon: const Icon(Icons.south_west, size: 18),
      label: const Text('接收'),
    );
    final swap = Tooltip(
      message: '兑换功能暂未接入',
      child: OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.swap_horiz, size: 18),
        label: const Text('兑换'),
      ),
    );
    if (compact) {
      return Row(
        children: [
          Expanded(child: send),
          const SizedBox(width: 8),
          Expanded(child: receive),
          const SizedBox(width: 8),
          Expanded(child: swap),
        ],
      );
    }
    return Wrap(spacing: 12, runSpacing: 12, children: [send, receive, swap]);
  }
}

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
                    '链上资产',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('查看全部')),
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
                      textAlign: compact ? TextAlign.right : TextAlign.left,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (compact)
                      Text(
                        asset.change,
                        style: TextStyle(
                          color: asset.change == '已同步'
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
                    asset.change,
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
        borderRadius: BorderRadius.circular(16),
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
                  '恢复凭证保存在本机安全存储中，签名在本机完成。',
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
    this.networkId,
    this.error,
  });

  final String symbol;
  final String name;
  final String network;
  final String amount;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final int? networkId;
  final String? error;
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
