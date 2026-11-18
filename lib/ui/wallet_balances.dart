part of '../main.dart';

extension _WalletBalanceActions on _WalletShellState {
  WalletBalanceScan get balanceScan => _walletBalanceScan ??= WalletBalanceScan(
    vault: vault,
    quoteService: quoteService,
    makeRpc: _makeService,
    makeIndexer: makeDiscoveryService,
    persistResults: true,
  );

  void startWalletBalanceScan() {
    unawaited(
      balanceScan.start(
        accountCount: portfolio.accountCount,
        networks: allNetworks,
        enabled: enabledNetworks,
        watchedTokens: watchedTokens,
        configs: indexerSettings.configs,
        tokenCatalogIncomplete: tokenCatalogError != null,
      ),
    );
  }

  Future<void> _showWalletBalances() async {
    _openWalletManagement();
    startWalletBalanceScan();
  }
}
