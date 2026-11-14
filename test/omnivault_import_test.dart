import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'widget_test.dart' show MapSecretStore;

const _header = 'platform,uid,chain,address,private_key,key_status,reason';
const _channel = MethodChannel('asterkeel/wallet_database');
const _address = '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf';
const _tron = 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC';
final _key = '1'.padLeft(64, '0');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WalletVault vault;
  late List<Map<Object?, Object?>> staged;
  late List<String> calls;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('omni-test-');
    staged = [];
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call.method);
      switch (call.method) {
        case 'needsMigration':
          return false;
        case 'beginPreview':
          staged.clear();
          return null;
        case 'stage':
          staged.addAll(
            (call.arguments['rows'] as List).cast<Map<Object?, Object?>>(),
          );
          return null;
        case 'finishPreview':
          final counts = <String, int>{};
          for (final row in staged) {
            final status = row['status'] == 'valid'
                ? 'new'
                : row['status'] as String;
            counts.update(status, (count) => count + 1, ifAbsent: () => 1);
          }
          return [
            for (final entry in counts.entries)
              {'status': entry.key, 'count': entry.value},
          ];
        case 'cancelPreview':
          staged.clear();
          return null;
        default:
          throw StateError('Unexpected database call');
      }
    });
    vault = WalletVault(store: MapSecretStore({}), useMacWalletDatabase: true);
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    await directory.delete(recursive: true);
  });

  Future<OmniVaultPreview> open(String content) async {
    final file = File('${directory.path}/synthetic.csv');
    await file.writeAsString(content);
    return vault.beginOmniVaultPreview(file.path, accountName: 'Account 1');
  }

  test(
    'validates reordered columns, both chains and physical CSV row numbers',
    () async {
      final preview = await open(
        '\uFEFFuid,platform,private_key,chain,key_status,reason,address\r\n'
        '001,"Site ""A""",$_key,bsc,exported,"multi\r\nline",${_address.toUpperCase()}\r\n'
        '002,Site B,$_key,tron,exported,,$_tron\r\n'
        '003,Site C,$_key,tron,exported,,41${_address.substring(2)}\r\n'
        '004,Site D,,tron,unavailable,"missing key",\r\n'
        '005,Site E,$_key,bsc,unexpected,,$_address\r\n'
        '006,Site F,123,bsc,exported,,$_address\r\n'
        '007,Site G,${'2'.padLeft(64, '0')},bsc,exported,,$_address\r\n'
        '008,Site H,$_key,bsc,exported,\r\n',
      );
      try {
        expect(await preview.ready, {
          OmniImportStatus.newWallet: 3,
          OmniImportStatus.skipped: 1,
          OmniImportStatus.failed: 4,
        });
        expect(staged.map((row) => row['line']), [2, 4, 5, 6, 7, 8, 9, 10]);
        expect(staged.first['uid'], '001');
        expect(staged.first['platform'], 'Site "A"');
        expect(staged.first['secret'], _key);
        expect(staged[1]['address'], _tron);
        expect(staged[1]['identity'], staged[2]['identity']);
        expect(staged[6]['error'], MessageCode.omniAddressMismatch.name);
        expect(staged[7]['error'], MessageCode.omniColumnCount.name);
        expect(
          staged.skip(3).every((row) => !row.containsKey('secret')),
          isTrue,
        );
        expect(staged.every((row) => !row.containsKey('reason')), isTrue);
        expect(calls, isNot(contains('commitPreview')));
      } finally {
        await preview.close();
      }
      expect(staged, isEmpty);
    },
  );

  test('rejects incomplete OmniVault headers and unclosed quotes', () async {
    for (final (csv, code) in [
      (
        'platform,uid,chain,private_key\nA,001,bsc,$_key',
        MessageCode.omniHeader,
      ),
      (
        '$_header\nA,001,bsc,$_address,$_key,exported,"unterminated',
        MessageCode.omniMalformedCsv,
      ),
    ]) {
      final preview = await open(csv);
      try {
        await expectLater(
          preview.ready,
          throwsA(
            isA<WalletInputException>().having((e) => e.code, 'code', code),
          ),
        );
      } finally {
        await preview.close();
      }
      expect(staged, isEmpty);
    }
  });

  test(
    'reports invalid UTF-8 and cancels an active validation batch',
    () async {
      final invalid = File('${directory.path}/invalid.csv');
      await invalid.writeAsBytes([..._header.codeUnits, 10, 0xFF]);
      final unreadable = await vault.beginOmniVaultPreview(
        invalid.path,
        accountName: 'Account 1',
      );
      try {
        await expectLater(
          unreadable.ready,
          throwsA(
            isA<WalletInputException>().having(
              (error) => error.code,
              'code',
              MessageCode.omniInvalidEncoding,
            ),
          ),
        );
      } finally {
        await unreadable.close();
      }
      final file = File('${directory.path}/cancel.csv');
      final row = 'Site,001,bsc,$_address,$_key,exported,\n';
      await file.writeAsString('$_header\n${row * 1024}');
      final firstBatch = Completer<void>();
      final preview = await vault.beginOmniVaultPreview(
        file.path,
        accountName: 'Account 1',
        onProgress: (_) {
          if (!firstBatch.isCompleted) firstBatch.complete();
        },
      );
      await firstBatch.future;
      await preview.close();
      expect(await preview.ready, isNull);
      expect(staged, isEmpty);
    },
  );

  test(
    'recognizes the legacy table and can immediately cancel a new preview',
    () async {
      final legacy = await open('chain\tprivate_key\nbsc\t$_key');
      expect(await legacy.ready, isNull);
      await legacy.close();

      final preview = await open(
        '$_header\nA,001,bsc,$_address,$_key,exported,',
      );
      await preview.close();
      expect(await preview.ready, isNull);
      expect(staged, isEmpty);
    },
  );
}
