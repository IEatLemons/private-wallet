part of '../main.dart';

class WalletRail extends StatelessWidget {
  const WalletRail({
    required this.theme,
    required this.selected,
    required this.onSelect,
    this.supportsAddressPool = false,
    super.key,
  });
  final WalletTheme theme;
  final WalletPage selected;
  final bool supportsAddressPool;
  final ValueChanged<WalletPage> onSelect;

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
              const BrandMark(),
              if (layout.wide) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).appName,
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
            (
              Icons.account_balance_wallet_outlined,
              tr(context, MessageCode.msgAssets),
              WalletPage.assets,
            ),
            if (supportsAddressPool)
              (
                Icons.inventory_2_outlined,
                AppLocalizations.of(context).omniPoolTitle,
                WalletPage.addressPool,
              ),
            (
              Icons.settings_outlined,
              tr(context, MessageCode.msgSettings),
              WalletPage.settings,
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: item.$2,
                child: Material(
                  color: selected == item.$3
                      ? theme.surfaceStrong
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: ValueKey('wallet-nav-${item.$3.name}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(item.$3),
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
                            item.$1,
                            size: 20,
                            color: selected == item.$3
                                ? theme.primary
                                : theme.muted,
                          ),
                          if (layout.wide) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.$2,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: selected == item.$3
                                      ? theme.primary
                                      : theme.muted,
                                ),
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
                tr(
                  context,
                  MessageCode.msgYourKeysStayWithYouTransactionsAreSigned,
                ),
                style: TextStyle(color: theme.muted, fontSize: 12, height: 1.7),
              ),
            ),
        ],
      ),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/brand/asterkeel.png',
    width: 40,
    height: 40,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5F4F0)
        : const Color(0xFF1A1C20),
    excludeFromSemantics: true,
  );
}

class WalletHeader extends StatelessWidget {
  const WalletHeader({
    required this.theme,
    required this.walletName,
    required this.address,
    required this.onWalletTap,
    required this.onSettings,
    required this.pageTitle,
    required this.networkLabel,
    this.linkedAddresses,
    this.onNetworkTap,
    this.onAddressPool,
    super.key,
  });
  final WalletTheme theme;
  final String walletName, address, pageTitle, networkLabel;
  final VoidCallback onWalletTap, onSettings;
  final VoidCallback? onNetworkTap, onAddressPool;
  final List<String>? linkedAddresses;

  @override
  Widget build(BuildContext context) {
    final layout = WalletLayout.of(context);
    final wallet = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Semantics(
        button: true,
        label: tr(context, MessageCode.msgSelectWallet),
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
                        localized(context, walletName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        linkedAddresses?.map(shortAddress).join(' · ') ??
                            shortAddress(address),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
              if (onAddressPool != null)
                IconButton(
                  key: const ValueKey('open-address-pool'),
                  tooltip: AppLocalizations.of(context).omniPoolTitle,
                  onPressed: onAddressPool,
                  icon: Icon(Icons.inventory_2_outlined, color: theme.muted),
                ),
              IconButton(
                key: const ValueKey('open-settings'),
                tooltip: tr(context, MessageCode.msgSettings),
                onPressed: onSettings,
                icon: Icon(Icons.settings_outlined, color: theme.muted),
              ),
            ],
          ),
          if (onNetworkTap != null) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: NetworkButton(
                theme: theme,
                label: networkLabel,
                onTap: onNetworkTap!,
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
            IconButton(
              key: const ValueKey('open-settings'),
              tooltip: tr(context, MessageCode.msgSettings),
              onPressed: onSettings,
              icon: Icon(Icons.settings_outlined, color: theme.muted),
            ),
          ],
        );
        final title = Text(
          localized(context, pageTitle),
          style: TextStyle(
            color: theme.text,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        );
        if (constraints.maxWidth < 700) {
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
    label: Text(
      localized(context, label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
