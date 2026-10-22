part of '../main.dart';

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
    final layout = WalletLayout.of(context);
    return Container(
      width: layout.navigationWidth,
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(right: BorderSide(color: theme.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: layout.wide ? 16 : 12,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandMark(theme: theme),
              if (layout.wide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Stone Wallet',
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 40),
          for (final item in [
            (Icons.grid_view_rounded, '首页'),
            (Icons.settings_outlined, '设置'),
          ].asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: item.value.$2,
                child: Material(
                  color: selected == item.key
                      ? theme.surfaceStrong
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(item.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: layout.wide
                            ? MainAxisAlignment.start
                            : MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.value.$1,
                            size: 20,
                            color: selected == item.key
                                ? theme.primary
                                : theme.muted,
                          ),
                          if (layout.wide) ...[
                            const SizedBox(width: 12),
                            Text(
                              item.value.$2,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: selected == item.key
                                    ? theme.primary
                                    : theme.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          if (layout.wide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '密钥由你掌握\n签名在本机完成',
                style: TextStyle(color: theme.muted, fontSize: 12, height: 1.7),
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
  Widget build(BuildContext context) => NavigationBar(
    height: 68,
    backgroundColor: theme.surface,
    selectedIndex: selected,
    indicatorColor: theme.surfaceStrong,
    onDestinationSelected: onSelect,
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view_rounded),
        label: '首页',
      ),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
    ],
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({required this.theme, super.key});
  final WalletTheme theme;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: theme.primary,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(
      Icons.account_balance_wallet_rounded,
      color: Colors.white,
      size: 22,
    ),
  );
}

class WalletHeader extends StatelessWidget {
  const WalletHeader({
    required this.theme,
    required this.walletName,
    required this.address,
    required this.onWalletTap,
    required this.onToggleStyle,
    this.pageTitle = '首页',
    this.networkLabel = '选择网络',
    this.onNetworkTap,
    super.key,
  });
  final WalletTheme theme;
  final String walletName, address, pageTitle, networkLabel;
  final VoidCallback onWalletTap, onToggleStyle;
  final VoidCallback? onNetworkTap;

  @override
  Widget build(BuildContext context) {
    final layout = WalletLayout.of(context);
    final wallet = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: InkWell(
        onTap: onWalletTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.surfaceStrong,
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: theme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      walletName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      shortAddress(address),
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.expand_more, size: 18, color: theme.muted),
            ],
          ),
        ),
      ),
    );
    if (layout.mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: wallet),
              ),
              ThemeToggle(theme: theme, onTap: onToggleStyle),
            ],
          ),
          if (pageTitle != '首页') ...[
            const SizedBox(height: 20),
            Text(
              pageTitle,
              style: TextStyle(
                color: theme.text,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            wallet,
            if (onNetworkTap != null)
              NetworkButton(
                theme: theme,
                label: networkLabel,
                onTap: onNetworkTap!,
              ),
            ThemeToggle(theme: theme, onTap: onToggleStyle),
          ],
        );
        final title = Text(
          pageTitle,
          style: TextStyle(
            color: theme.text,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        );
        if (constraints.maxWidth < 700 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), actions],
          );
        }
        return Row(
          children: [
            title,
            const SizedBox(width: 24),
            Expanded(
              child: Align(alignment: Alignment.centerRight, child: actions),
            ),
          ],
        );
      },
    );
  }
}

class NetworkButton extends StatelessWidget {
  const NetworkButton({
    required this.theme,
    required this.label,
    required this.onTap,
    super.key,
  });
  final WalletTheme theme;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.public, size: 16),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}
