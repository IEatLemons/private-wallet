import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'package:web3dart/crypto.dart' as crypto;
import 'package:web3dart/web3dart.dart' show EthereumAddress;

import 'network_management_test.dart' show RpcFixture, start, tap;
import 'widget_test.dart' show MapSecretStore;

const _database = MethodChannel('asterkeel/wallet_database');
const _address = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';

class _SyntheticPicker extends FilePicker {
  _SyntheticPicker(this.file);
  final PlatformFile file;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    expect(withData, isFalse);
    return FilePickerResult([file]);
  }
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final watch = Stopwatch()..start();
  while (finder.evaluate().isEmpty && watch.elapsed.inSeconds < 10) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsOneWidget);
}

void main() {
  for (final width in [1200.0, 640.0]) {
    testWidgets('macOS address pools open directly at width $width', (
      tester,
    ) async {
      const key =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final messenger = tester.binding.defaultBinaryMessenger;
      var deviceCalls = 0;
      messenger.setMockMethodCallHandler(_database, (call) async {
        switch (call.method) {
          case 'needsMigration':
            return false;
          case 'initialNetwork':
            return null;
          case 'summary':
            return {
              'groups_count': 1,
              'accounts_count': 1,
              'active_id': 'test:0',
              'selected': {
                'id': 'test:0',
                'group_id': 'test',
                'group_name': 'Fixture',
                'group_count': 1,
                'kind': 'privateKey',
                'network_id': 56,
                'name': 'Account 1',
                'account_index': 0,
                'evm': _address,
                'tron': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
                'secret': key,
              },
            };
          case 'pool.device':
            deviceCalls++;
            return Uint8List.fromList([1, 2, 3]);
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(_database, null));
      final vault = WalletVault(
        store: MapSecretStore({}),
        useMacWalletDatabase: true,
      );
      await start(tester, vault, RpcFixture(), size: Size(width, 800));
      final navigationKey = width >= 760
          ? 'wallet-nav-addressPool'
          : 'open-address-pool';
      expect(deviceCalls, 0);
      await tester.tap(find.byKey(ValueKey(navigationKey)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey('omni-pool-page')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('HTTPS URL'), findsOneWidget);
      expect(deviceCalls, 1);
      if (width >= 760) {
        await tester.tap(find.byKey(const ValueKey('wallet-nav-assets')));
      } else {
        await tester.tap(find.byType(BackButton));
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const PageStorageKey('omni-pool-page')), findsNothing);
      await tester.tap(find.byKey(ValueKey(navigationKey)));
      await tester.pumpAndSettle();
      expect(deviceCalls, 1);
    });
  }

  testWidgets(
    'OmniVault file import previews before confirmation and displays aliases',
    (tester) async {
      final key = '1'.padLeft(64, '0');
      final directory = Directory.systemTemp.createTempSync('omni-ui-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final csv = File('${directory.path}/fixture.csv');
      csv.writeAsStringSync(
        'platform,uid,chain,address,private_key,key_status,reason\n'
        'Site,001,bsc,$_address,$key,exported,\n',
      );
      FilePicker.platform = _SyntheticPicker(
        PlatformFile(
          name: 'fixture.csv',
          path: csv.path,
          size: csv.lengthSync(),
        ),
      );

      final entry = {
        'id': 'test:0',
        'group_id': 'test',
        'group_name': 'Site · 001',
        'kind': 'privateKey',
        'network_id': 56,
        'group_count': 1,
        'name': '账户 1',
        'account_index': 0,
        'evm': _address,
        'tron': 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC',
      };
      var committed = false;
      var staged = false;
      Map<String, Object?> summary() => {
        'groups_count': committed ? 1 : 0,
        'accounts_count': committed ? 1 : 0,
        if (committed) ...{
          'active_id': 'test:0',
          'selected': {...entry, 'secret': key},
        },
      };
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _database,
        (call) async => switch (call.method) {
          'needsMigration' => false,
          'summary' => summary(),
          'initialNetwork' ||
          'beginPreview' ||
          'cancelPreview' ||
          'ackInitialNetwork' => null,
          'stage' => () {
            staged = true;
            return null;
          }(),
          'finishPreview' => [
            {'status': 'new', 'count': 1},
          ],
          'previewPage' => [
            {
              'source_line': 2,
              'status': 'new',
              'platform': 'Site',
              'uid': '001',
              'address': _address,
              'network_id': 56,
            },
          ],
          'commitPreview' => () {
            committed = true;
            return {...summary(), 'initial_network': 56};
          }(),
          'walletPage' => [
            {
              'id': 'test',
              'name': 'Site · 001',
              'kind': 'privateKey',
              'network_id': 56,
              'sequence': 1,
              'has_aliases': 1,
              'accounts': [entry],
            },
          ],
          'aliasPage' => [
            {'id': 1, 'platform': 'Site', 'uid': '001'},
          ],
          _ => throw StateError('Unexpected database method'),
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(_database, null));

      final rpc = RpcFixture();
      final vault = WalletVault(
        store: MapSecretStore({}),
        useMacWalletDatabase: true,
      );
      await start(tester, vault, rpc);
      final importButton = find.text('批量导入私钥表格');
      await tester.ensureVisible(importButton);
      await tester.tap(importButton);
      await tester.pump();
      final confirm = find.byKey(const ValueKey('omni-confirm-import'));
      await _pumpUntil(tester, confirm);
      await tester.pumpAndSettle();
      expect(staged, isTrue);
      expect(committed, isFalse);
      expect(find.textContaining(key), findsNothing);
      expect(find.textContaining('第 2 行'), findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(committed, isTrue);
      final stored = (await vault.loadWalletSummary()).selected!.account;
      final digest = crypto.keccak256(Uint8List.fromList([1, 2, 3]));
      final signature = crypto.sign(digest, stored.credentials.privateKey);
      final signer = EthereumAddress.fromPublicKey(
        crypto.ecRecover(digest, signature),
      );
      expect(signer.hexEip55, _address);
      expect(find.text('OmniVault 导入结果'), findsOneWidget);
      expect(rpc.calls, isEmpty);
      await tester.tap(find.text('知道了'));
      final watch = Stopwatch()..start();
      while (find.text('OmniVault 导入结果').evaluate().isNotEmpty &&
          watch.elapsed.inSeconds < 10) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.text('OmniVault 导入结果'), findsNothing);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Site · 001'));
      await tap(tester, find.byTooltip('钱包别名'));
      expect(find.text('钱包别名'), findsOneWidget);
      expect(find.text('Site · 001'), findsWidgets);
    },
  );
}
