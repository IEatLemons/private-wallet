part of 'wallet_core.dart';

enum OmniImportStatus { newWallet, alias, duplicate, skipped, failed }

class OmniImportRow {
  const OmniImportRow({
    required this.line,
    required this.status,
    this.error,
    this.platform,
    this.uid,
    this.address,
    this.networkId,
  });
  final int line;
  final OmniImportStatus status;
  final MessageCode? error;
  final String? platform, uid, address;
  final int? networkId;
}

class OmniImportCommit {
  const OmniImportCommit(this.portfolio, this.initialNetworkId);
  final WalletPortfolio portfolio;
  final int? initialNetworkId;
}

extension OmniVaultImport on WalletVault {
  Future<OmniVaultPreview> beginOmniVaultPreview(
    String path, {
    required String accountName,
    void Function(int processed)? onProgress,
  }) async {
    final session = _newWalletId();
    await _macCall<void>('beginPreview', {
      'session': session,
      'accountName': accountName,
    });
    return OmniVaultPreview._(this, path, session, onProgress);
  }
}

class OmniVaultPreview {
  OmniVaultPreview._(
    this._vault,
    String path,
    this._session,
    this._onProgress,
  ) {
    _messages.listen(_receive);
    unawaited(_start(path));
  }

  final WalletVault _vault;
  final String _session;
  final void Function(int)? _onProgress;
  final _messages = ReceivePort();
  final _scannerDone = Completer<void>();
  final _ready = Completer<Map<OmniImportStatus, int>?>();
  SendPort? _cancelScanner;
  Future<void>? _closing;
  Future<void>? _batch;
  bool _closed = false;

  /// A null result identifies a legacy table. The caller can use its existing importer.
  Future<Map<OmniImportStatus, int>?> get ready => _ready.future;

  Future<void> _start(String path) async {
    try {
      final workerCount = (Platform.numberOfProcessors - 1).clamp(1, 8);
      await Isolate.spawn(
        _scanOmniVault,
        (path, _messages.sendPort, workerCount),
        onExit: _messages.sendPort,
        errorsAreFatal: true,
      );
    } catch (_) {
      _fail(MessageCode.msgCannotReadThisFile);
      _scannerDone.complete();
      _messages.close();
    }
  }

  void _receive(dynamic message) {
    if (message == null) {
      _fail(MessageCode.msgCannotReadThisFile);
      _scannerDone.complete();
      _messages.close();
      return;
    }
    if (message is SendPort) {
      _cancelScanner = message;
      if (_closed || _ready.isCompleted) message.send(null);
      return;
    }
    if (_closed || _ready.isCompleted) return;
    if (message case (List<_DatabaseRow> rows, SendPort reply)) {
      _batch = _stage(rows, reply);
      return;
    }
    if (message case (String outcome, SendPort reply)) {
      _batch = _finish(outcome, reply);
    } else if (message case (
      MessageCode code,
      List<Object> arguments,
      SendPort reply,
    )) {
      _fail(code, arguments);
      reply.send(true);
    }
  }

  Future<void> _stage(List<_DatabaseRow> rows, SendPort reply) async {
    try {
      await _vault._macCall<void>('stage', {'session': _session, 'rows': rows});
      if (_closed) return;
      _processed += rows.length;
      _onProgress?.call(_processed);
      reply.send(true);
    } on WalletInputException catch (error) {
      _fail(error.code);
    } catch (_) {
      _fail(MessageCode.omniStorageError);
    }
  }

  int _processed = 0;

  Future<void> _finish(String outcome, SendPort reply) async {
    try {
      if (outcome == 'legacy') {
        _ready.complete(null);
      } else if (outcome == 'ready') {
        final counts = await _vault._macRows('finishPreview', {
          'session': _session,
        });
        if (!_closed) {
          _ready.complete({
            for (final row in counts)
              _omniStatus(row['status'] as String): row['count'] as int,
          });
        }
      } else {
        _fail(MessageCode.values.byName(outcome));
      }
    } on WalletInputException catch (error) {
      _fail(error.code);
    } catch (_) {
      _fail(MessageCode.omniStorageError);
    } finally {
      reply.send(true);
    }
  }

  void _fail(MessageCode code, [List<Object> arguments = const []]) {
    if (_closed || _ready.isCompleted) return;
    _ready.completeError(WalletInputException(code, arguments: arguments));
    _cancelScanner?.send(null);
  }

  Future<List<OmniImportRow>> page({
    int after = 0,
    OmniImportStatus? status,
  }) async =>
      (await _vault._macRows('previewPage', {
            'session': _session,
            'after': after,
            'status': status == null ? null : _omniStatusNames[status],
          }))
          .map(
            (row) => OmniImportRow(
              line: row['source_line'] as int,
              status: _omniStatus(row['status'] as String),
              error: (row['error'] as String?) == null
                  ? null
                  : MessageCode.values.byName(row['error'] as String),
              platform: row['platform'] as String?,
              uid: row['uid'] as String?,
              address: row['address'] as String?,
              networkId: row['network_id'] as int?,
            ),
          )
          .toList();

  Future<OmniImportCommit> commit() async {
    final row = await _vault._serialize(
      () => _vault._macRow('commitPreview', {'session': _session}),
    );
    return OmniImportCommit(
      _summaryFromMac(row),
      row['initial_network'] as int?,
    );
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _cancelScanner?.send(null);
    if (!_ready.isCompleted) _ready.complete(null);
    await _scannerDone.future;
    await _batch;
    await _vault._macCall<void>('cancelPreview', {'session': _session});
  }
}

const _omniStatusNames = {
  OmniImportStatus.newWallet: 'new',
  OmniImportStatus.alias: 'alias',
  OmniImportStatus.duplicate: 'duplicate',
  OmniImportStatus.skipped: 'skipped',
  OmniImportStatus.failed: 'failed',
};

OmniImportStatus _omniStatus(String name) =>
    _omniStatusNames.entries.firstWhere((entry) => entry.value == name).key;

const _omniColumns = [
  'platform',
  'uid',
  'chain',
  'address',
  'private_key',
  'key_status',
  'reason',
];

Future<void> _scanOmniVault((String, SendPort, int) args) async {
  final (path, owner, workerCount) = args;
  final cancellation = ReceivePort();
  owner.send(cancellation.sendPort);
  final acknowledgements = ReceivePort();
  final acknowledgementsIterator = StreamIterator<Object?>(acknowledgements);
  final allWorkers = <_OmniWorker>[];
  final workers = <_OmniWorker>[];
  var cancelled = false;
  cancellation.listen((_) {
    cancelled = true;
    acknowledgements.sendPort.send(null);
    for (final worker in allWorkers) {
      worker.isolate.kill(priority: Isolate.immediate);
    }
  });
  final pending = <(_OmniWorker, Future<List<_DatabaseRow>?>)>[];
  final records = StreamIterator(
    _csvRecords(File(path).openRead().transform(utf8.decoder)),
  );
  Object outcome = 'ready';
  Future<void> stageOldest() async {
    final (worker, result) = pending.removeAt(0);
    final rows = await result;
    if (cancelled) return;
    if (rows == null) {
      throw const WalletInputException(MessageCode.msgCannotReadThisFile);
    }
    owner.send((rows, acknowledgements.sendPort));
    await acknowledgementsIterator.moveNext();
    workers.add(worker);
  }

  try {
    if (!await records.moveNext()) {
      throw const WalletInputException(MessageCode.omniHeader);
    }
    final header = records.current.cells
        .map((cell) => cell.trim().toLowerCase())
        .toList();
    final isOmni = [
      'platform',
      'uid',
      'address',
      'key_status',
      'reason',
    ].any(header.contains);
    if (!isOmni) {
      outcome = 'legacy';
    } else {
      if (header.length != header.toSet().length ||
          !_omniColumns.every(header.contains)) {
        throw const WalletInputException(MessageCode.omniHeader);
      }
      final columns = _omniColumns.map(header.indexOf).toList();
      await Future.wait(
        List.generate(workerCount, (_) async {
          final worker = await _OmniWorker.start(columns, header.length);
          allWorkers.add(worker);
          workers.add(worker);
          if (cancelled) worker.isolate.kill(priority: Isolate.immediate);
        }),
      );
      if (cancelled) return;
      var batch = <_CsvRecord>[];
      while (!cancelled && await records.moveNext()) {
        batch.add(records.current);
        if (batch.length < 256) continue;
        if (workers.isEmpty) await stageOldest();
        if (cancelled) return;
        final worker = workers.removeLast();
        pending.add((worker, worker.validate(batch)));
        batch = [];
      }
      if (!cancelled && batch.isNotEmpty) {
        if (workers.isEmpty) await stageOldest();
        if (cancelled) return;
        final worker = workers.removeLast();
        pending.add((worker, worker.validate(batch)));
      }
      while (!cancelled && pending.isNotEmpty) {
        await stageOldest();
      }
    }
  } on WalletInputException catch (error) {
    outcome = (error.code, error.arguments);
  } on FormatException {
    outcome = (MessageCode.omniInvalidEncoding, <Object>[]);
  } catch (_) {
    outcome = (MessageCode.msgCannotReadThisFile, <Object>[]);
  } finally {
    await records.cancel();
    for (final worker in allWorkers) {
      await worker.close();
    }
    if (!cancelled) {
      if (outcome case (MessageCode code, List<Object> arguments)) {
        owner.send((code, arguments, acknowledgements.sendPort));
      } else {
        owner.send((outcome, acknowledgements.sendPort));
      }
      await acknowledgementsIterator.moveNext();
    }
    await acknowledgementsIterator.cancel();
    acknowledgements.close();
    cancellation.close();
  }
}

class _OmniWorker {
  _OmniWorker(this.isolate, this.port, this.results, this.replies);
  final Isolate isolate;
  final SendPort port;
  final ReceivePort results;
  final StreamIterator<dynamic> replies;

  static Future<_OmniWorker> start(List<int> columns, int columnCount) async {
    final results = ReceivePort();
    final replies = StreamIterator<dynamic>(results);
    final isolate = await Isolate.spawn(_validateOmniVaultRows, (
      columns,
      columnCount,
      results.sendPort,
    ), onExit: results.sendPort);
    if (!await replies.moveNext() || replies.current is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      results.close();
      await replies.cancel();
      throw const WalletInputException(MessageCode.msgCannotReadThisFile);
    }
    return _OmniWorker(isolate, replies.current as SendPort, results, replies);
  }

  Future<List<_DatabaseRow>?> validate(List<_CsvRecord> rows) async {
    port.send(rows);
    if (!await replies.moveNext()) return null;
    return replies.current as List<_DatabaseRow>?;
  }

  Future<void> close() async {
    isolate.kill(priority: Isolate.immediate);
    results.close();
    await replies.cancel();
  }
}

void _validateOmniVaultRows((List<int>, int, SendPort) args) {
  final (columns, columnCount, owner) = args;
  final inbox = ReceivePort();
  owner.send(inbox.sendPort);
  inbox.listen((message) {
    final rows = message as List<_CsvRecord>;
    owner.send(<_DatabaseRow>[
      for (final row in rows) _validateOmniVaultRow(row, columns, columnCount),
    ]);
  });
}

final _keyPattern = RegExp(r'^[0-9a-fA-F]{64}$');
final _evmPattern = RegExp(r'^(?:0x)?[0-9a-f]{40}$', caseSensitive: false);
final _tronHexPattern = RegExp(
  r'^(?:0x)?(41[0-9a-f]{40})$',
  caseSensitive: false,
);
final _invalidName = RegExp(r'[\x00-\x1F\x7F]');
const _maximumIdentityLength = 256;

_DatabaseRow _validateOmniVaultRow(
  _CsvRecord row,
  List<int> columns,
  int columnCount,
) {
  final result = <Object?, Object?>{'line': row.line};
  _DatabaseRow fail(MessageCode code) => result
    ..['status'] = 'failed'
    ..['error'] = code.name;
  if (row.cells.length != columnCount) return fail(MessageCode.omniColumnCount);
  final cells = row.cells;
  final status = cells[columns[5]].trim();
  if (status == 'unavailable') return result..['status'] = 'skipped';
  if (status != 'exported') return fail(MessageCode.omniInvalidStatus);

  final platform = cells[columns[0]].trim();
  final uid = cells[columns[1]].trim();
  if (platform.isEmpty ||
      uid.isEmpty ||
      platform.length > _maximumIdentityLength ||
      uid.length > _maximumIdentityLength ||
      _invalidName.hasMatch(platform) ||
      _invalidName.hasMatch(uid)) {
    return fail(MessageCode.omniInvalidIdentity);
  }
  result['platform'] = platform;
  result['uid'] = uid;
  final network = switch (cells[columns[2]].trim().toLowerCase()) {
    'bsc' => 56,
    'tron' => tronMainnetNetwork.id,
    _ => null,
  };
  if (network == null) return fail(MessageCode.msgUnsupportedNetwork);
  result['network'] = network;
  final key = cells[columns[4]];
  if (!_keyPattern.hasMatch(key)) {
    return fail(MessageCode.msgInvalidPrivateKeyEnterHexadecimalCharacters);
  }
  final address = cells[columns[3]].trim();
  final isTron = network == tronMainnetNetwork.id;
  try {
    final String expected;
    if (isTron) {
      expected =
          _tronHexPattern.firstMatch(address)?.group(1)?.toLowerCase() ??
          bytesToHex(decodeTronAddress(address));
    } else {
      if (!_evmPattern.hasMatch(address)) {
        return fail(MessageCode.omniInvalidAddress);
      }
      final normalized = address.toLowerCase();
      expected = normalized.startsWith('0x') ? normalized : '0x$normalized';
    }
    final account = WalletAccount.fromPrivateKey(key);
    final evmIdentity = account.addressHex.toLowerCase();
    final derived = isTron ? '41${evmIdentity.substring(2)}' : evmIdentity;
    if (expected != derived) return fail(MessageCode.omniAddressMismatch);
    final evm = account.checksumAddress;
    final tron = account.tronAddress;
    return result
      ..['status'] = 'valid'
      ..['address'] = isTron ? tron : evm
      ..['identity'] = isTron ? tron : evmIdentity
      ..['secret'] = account.privateKeyHex
      ..['evm'] = evm
      ..['tron'] = tron;
  } on WalletInputException catch (error) {
    return fail(error.code);
  }
}

class _CsvRecord {
  const _CsvRecord(this.line, this.cells);
  final int line;
  final List<String> cells;
}

enum _CsvState { start, unquoted, quoted, quoteEnd }

Stream<_CsvRecord> _csvRecords(Stream<String> content) async* {
  var state = _CsvState.start;
  var cells = <String>[];
  var field = StringBuffer();
  var line = 1;
  var recordLine = 1;
  var length = 0;
  var delimiter = 0;
  var pendingCr = false;
  var first = true;

  void endField() {
    cells.add(field.toString());
    field = StringBuffer();
    state = _CsvState.start;
  }

  await for (final chunk in content) {
    for (var i = 0; i < chunk.length; i++) {
      var char = chunk.codeUnitAt(i);
      if (first) {
        first = false;
        if (char == 0xFEFF) continue;
      }
      if (pendingCr) {
        pendingCr = false;
        if (char == 10) continue;
      }
      if (char == 13) {
        pendingCr = true;
        char = 10;
      }
      if (++length > 1024 * 1024) {
        throw const WalletInputException(MessageCode.omniRecordTooLarge);
      }
      if (state == _CsvState.quoted) {
        if (char == 34) {
          state = _CsvState.quoteEnd;
        } else {
          if (char == 10) line++;
          field.writeCharCode(char);
        }
        continue;
      }
      if (state == _CsvState.quoteEnd && char == 34) {
        field.writeCharCode(char);
        state = _CsvState.quoted;
        continue;
      }
      if (delimiter == 0 && (char == 44 || char == 9)) delimiter = char;
      if (char == delimiter && delimiter != 0) {
        endField();
      } else if (char == 10) {
        endField();
        if (cells.length != 1 || cells.single.trim().isNotEmpty) {
          yield _CsvRecord(recordLine, cells);
        }
        cells = [];
        recordLine = ++line;
        length = 0;
      } else if (char == 34 && state == _CsvState.start) {
        state = _CsvState.quoted;
      } else if (char == 34 || state == _CsvState.quoteEnd) {
        throw WalletInputException(
          MessageCode.omniMalformedCsv,
          arguments: [line],
        );
      } else {
        field.writeCharCode(char);
        state = _CsvState.unquoted;
      }
    }
  }
  if (state == _CsvState.quoted) {
    throw WalletInputException(
      MessageCode.omniMalformedCsv,
      arguments: [recordLine],
    );
  }
  if (length != 0) {
    endField();
    if (cells.length != 1 || cells.single.trim().isNotEmpty) {
      yield _CsvRecord(recordLine, cells);
    }
  }
}
