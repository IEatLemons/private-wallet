import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stone_wallet/wallet_core.dart';

class _EmptyLegacyStore implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

/// Build a dedicated macOS release with WALLET_TEST_DATABASE set for Swift.
/// The native runner requires a UUID in ASTERKEEL_TEST_DATABASE for isolation.
Future<void> main() async {
  final total = Stopwatch()..start();
  final environment = Platform.environment;
  if (environment['ASTERKEEL_TEST_DATABASE'] == null) {
    stderr.writeln('The synthetic wallet database ID is required.');
    exit(1);
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(body: Center(child: Text('OmniVault benchmark'))),
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  final vault = WalletVault(
    store: _EmptyLegacyStore(),
    useMacWalletDatabase: true,
  );
  try {
    final book = await vault.loadWalletSummary();
    stdout.writeln(
      'summary-ready=${total.elapsedMilliseconds}ms wallets=${book.groupCount}',
    );
    stdout.writeln('workers=${(Platform.numberOfProcessors - 1).clamp(1, 8)}');
    final fixture = environment['ASTERKEEL_TEST_CSV'];
    if (fixture != null) {
      if (book.groupCount != 0) {
        throw StateError('Use a fresh synthetic database.');
      }
      final watch = Stopwatch()..start();
      var reported = 0;
      final preview = await vault.beginOmniVaultPreview(
        fixture,
        accountName: 'Account 1',
        onProgress: (count) {
          if (count - reported >= 25000) {
            stdout.writeln(
              'scanned=$count elapsed=${watch.elapsedMilliseconds}ms rss=${ProcessInfo.currentRss}',
            );
            reported = count;
          }
        },
      );
      try {
        final counts = (await preview.ready)!;
        final expected = int.parse(
          environment['ASTERKEEL_TEST_ROWS'] ?? '300000',
        );
        stdout.writeln(
          'preview=${watch.elapsedMilliseconds}ms counts=${jsonEncode(counts.map((key, value) => MapEntry(key.name, value)))} rss=${ProcessInfo.currentRss}',
        );
        if (counts[OmniImportStatus.newWallet] != expected ||
            counts.length != 1) {
          throw StateError('Unexpected fixture validation result.');
        }
        final first = (await preview.page()).first;
        watch.reset();
        final committed = await preview.commit();
        stdout.writeln(
          'commit=${watch.elapsedMilliseconds}ms wallets=${committed.portfolio.groupCount} peakRss=${ProcessInfo.maxRss}',
        );
        if (committed.portfolio.groupCount != expected ||
            committed.initialNetworkId != 56) {
          throw StateError('Unexpected committed wallet summary.');
        }
        if (committed.portfolio.selected!.account.addressFor(
              ethereumMainnetNetwork,
            ) !=
            first.address) {
          throw StateError('Unexpected selected address.');
        }
      } finally {
        await preview.close();
      }
    }
    final latencies = <int>[];
    for (var index = 0; index < 100; index++) {
      final watch = Stopwatch()..start();
      final query = index.isEven ? 'fixture' : '00000';
      final page = await vault.loadWalletPage(query: query);
      latencies.add(watch.elapsedMicroseconds);
      if (page.groups.isEmpty) {
        throw StateError('Missing fixture search results.');
      }
    }
    latencies.sort();
    stdout.writeln(
      'search-p95=${latencies[94] / 1000}ms peakRss=${ProcessInfo.maxRss}',
    );
    await stdout.flush();
    exit(0);
  } catch (error) {
    final code = error is WalletInputException
        ? error.code.name
        : error.runtimeType;
    stderr.writeln('Synthetic benchmark failed ($code).');
    await stdout.flush();
    await stderr.flush();
    exit(1);
  }
}
