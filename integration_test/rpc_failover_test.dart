import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Public synthetic account. Never load the user's wallet or sign a transaction.
  final account = WalletAccount.fromPrivateKey('1'.padLeft(64, '0'));
  for (final network in supportedEvmNetworks) {
    testWidgets(
      '${network.name} switches from unavailable local RPC to public pool',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: Text('RPC 检测：${network.name}'))),
        );
        final service = EvmNetworkService(
          network: network.copyWith(
            rpcUrls: ['http://127.0.0.1:1', ...network.rpcUrls],
          ),
        );
        try {
          final balance = await service.getNativeBalance(account);
          expect(balance.getInWei.isNegative, isFalse);
          expect(network.rpcUrls, contains(service.activeRpcUrl));
        } finally {
          await service.dispose();
        }
      },
    );
  }
}
