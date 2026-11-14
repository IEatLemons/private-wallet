part of '../main.dart';

class _SendAssetPanel extends StatelessWidget {
  const _SendAssetPanel({required this.theme, required this.holdings});
  final WalletTheme theme;
  final List<PortfolioHolding> holdings;

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: AppLocalizations.of(context).transferChooseAsset,
    scrollBody: false,
    child: SizedBox(
      height: 380,
      child: ListView.builder(
        itemCount: holdings.length,
        itemBuilder: (context, index) {
          final holding = holdings[index];
          return ListTile(
            key: ValueKey('send-asset-${holding.key}'),
            title: Text('${holding.symbol} · ${holding.network.name}'),
            subtitle: Text(displayQuantity(context, holding.amount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => closeWalletPanel(context, holding),
          );
        },
      ),
    ),
  );
}

class _TransactionLink extends StatelessWidget {
  const _TransactionLink({required this.network, required this.hash});
  final EvmNetwork network;
  final String hash;

  @override
  Widget build(BuildContext context) {
    final url = network.explorerTransaction(hash);
    if (url == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _openExplorer(context, url),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(AppLocalizations.of(context).transferViewTransaction),
      ),
    );
  }
}

Future<void> _openExplorer(BuildContext context, Uri url) => openServiceLink(
  context,
  url.toString(),
  copiedMessage: MessageCode.msgExplorerLinkCopied,
);

class _AddressExplorerButton extends StatelessWidget {
  const _AddressExplorerButton({required this.url, this.compact = false});

  final Uri url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = tr(context, MessageCode.msgBlockExplorer);
    const icon = Icon(Icons.open_in_new, size: 18);
    void open() => _openExplorer(context, url);
    return compact
        ? IconButton(tooltip: label, onPressed: open, icon: icon)
        : TextButton.icon(onPressed: open, icon: icon, label: Text(label));
  }
}
