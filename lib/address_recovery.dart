import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/foundation.dart';

import 'recovery_engine.dart' as engine;
import 'wallet_core.dart';

class RecoveryInputException implements Exception {
  const RecoveryInputException(this.code);
  final String code;
}

class AddressRecoveryInput {
  const AddressRecoveryInput({
    required this.mnemonic,
    required this.xpub,
    required this.target,
    this.passphrase = '',
    this.mode = 'account',
    this.basePath = "m/44'/60'/0'/0",
    this.index = 0,
    this.start = 0,
    this.end = 0x7fffffff,
    this.cpuPercent = 25,
    this.standardOnly = false,
  });
  final String mnemonic, xpub, target, passphrase, mode, basePath;
  final int index, start, end, cpuPercent;
  final bool standardOnly;

  void validate() {
    if (mnemonic.length > 4096 || passphrase.length > 1024) {
      throw const RecoveryInputException('mnemonic');
    }
    final phrase = mnemonic
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .join(' ');
    if (!bip39.validateMnemonic(phrase)) {
      throw const RecoveryInputException('mnemonic');
    }
    try {
      engine.targetBytes(target);
    } catch (_) {
      throw const RecoveryInputException('target');
    }
    if (xpub.trim().isNotEmpty) {
      try {
        if (!BIP32.fromBase58(xpub.trim()).isNeutered()) {
          throw const FormatException();
        }
      } catch (_) {
        throw const RecoveryInputException('xpub');
      }
    }
    if (!['account', 'index'].contains(mode) ||
        start < 0 ||
        end > 0x7fffffff ||
        start > end ||
        index < 0 ||
        index > 0x7fffffff ||
        cpuPercent < 5 ||
        cpuPercent > 50) {
      throw const RecoveryInputException('range');
    }
    if (mode == 'index') {
      try {
        engine.normalizeRecoveryBasePath(basePath);
      } catch (_) {
        throw const RecoveryInputException('path');
      }
    }
  }

  engine.Options options() => engine.Options()
    ..target = target
    ..mode = mode
    ..basePath = basePath
    ..index = index
    ..startAccount = start
    ..endAccount = end
    ..cpuPercent = cpuPercent
    ..stopOn = standardOnly ? 'standard' : 'either';
  Map<String, Object?> toJson() => {
    'mnemonic': mnemonic,
    'xpub': xpub,
    'target': target,
    'passphrase': passphrase,
    'mode': mode,
    'base_path': basePath,
    'index': index,
    'start': start,
    'end': end,
    'cpu_percent': cpuPercent,
    'standard_only': standardOnly,
  };
  factory AddressRecoveryInput.fromJson(Map value) => AddressRecoveryInput(
    mnemonic: value['mnemonic'] as String,
    xpub: value['xpub'] as String,
    target: value['target'] as String,
    passphrase: value['passphrase'] as String,
    mode: value['mode'] as String,
    basePath: value['base_path'] as String,
    index: value['index'] as int,
    start: value['start'] as int,
    end: value['end'] as int,
    cpuPercent: value['cpu_percent'] as int,
    standardOnly: value['standard_only'] as bool,
  );
  AddressRecoveryInput withCpu(int value) =>
      AddressRecoveryInput.fromJson({...toJson(), 'cpu_percent': value});
}

class AddressRecoveryTask {
  AddressRecoveryTask({
    required this.id,
    required this.input,
    required this.createdAt,
    this.cursor = 0,
    this.checked = 0,
    this.familyCount = 0,
    this.status = 'ready',
    this.reason = '',
    this.fingerprint,
    this.probe,
    this.verification,
    List<Map<String, Object?>>? matches,
    int? updatedAt,
  }) : matches = matches ?? [],
       updatedAt = updatedAt ?? createdAt;
  final String id;
  AddressRecoveryInput input;
  final int createdAt;
  int updatedAt, cursor, checked, familyCount;
  String status, reason;
  String? fingerprint;
  Map<String, Object?>? probe, verification;
  final List<Map<String, Object?>> matches;
  bool get canResume => ['paused', 'error'].contains(status);
  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'input': input.toJson(),
    'created_at': createdAt,
    'updated_at': updatedAt,
    'cursor': cursor,
    'checked': checked,
    'family_count': familyCount,
    'status': status,
    'reason': reason,
    'fingerprint': fingerprint,
    'probe': probe,
    'verification': verification,
    'matches': matches,
  };
  factory AddressRecoveryTask.fromJson(Map value) {
    if (value['version'] != 1 || (value['matches'] as List).length > 32) {
      throw const FormatException();
    }
    final task = AddressRecoveryTask(
      id: value['id'] as String,
      input: AddressRecoveryInput.fromJson(value['input'] as Map),
      createdAt: value['created_at'] as int,
      updatedAt: value['updated_at'] as int,
      cursor: value['cursor'] as int,
      checked: value['checked'] as int,
      familyCount: value['family_count'] as int,
      status: value['status'] as String,
      reason: value['reason'] as String,
      fingerprint: value['fingerprint'] as String?,
      probe: value['probe'] == null
          ? null
          : Map<String, Object?>.from(value['probe'] as Map),
      verification: value['verification'] == null
          ? null
          : Map<String, Object?>.from(value['verification'] as Map),
      matches: [
        for (final item in value['matches'] as List)
          Map<String, Object?>.from(item as Map),
      ],
    );
    if (task.cursor < 0 || task.checked < 0 || task.familyCount < 0) {
      throw const FormatException();
    }
    return task;
  }
}

class AddressRecoveryController extends ChangeNotifier {
  AddressRecoveryController(this.vault);
  final WalletVault vault;
  List<AddressRecoveryTask> tasks = [];
  AddressRecoveryTask? selected;
  bool loaded = false,
      loading = false,
      running = false,
      pausing = false,
      disposed = false;
  String? error;
  double rate = 0;
  int activeMicros = 0, sleepMicros = 0;
  Isolate? _worker;
  ReceivePort? _messages, _errors, _exit;
  SendPort? _commands;
  bool _finalReceived = false;
  Completer<void>? _pause;
  Future<void> _tail = Future.value();
  int _lastSavedMs = 0;

  void _notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> load() async {
    if (loaded || loading) return;
    loading = true;
    error = null;
    _notify();
    try {
      tasks = (await vault.loadRecoveryTasks())
          .map(AddressRecoveryTask.fromJson)
          .toList();
      for (final task in tasks) {
        if (['running', 'starting', 'pausing'].contains(task.status)) {
          task.status = 'paused';
          task.reason = 'restart';
          await vault.saveRecoveryTask(task.toJson());
        }
      }
      selected = tasks.firstOrNull;
      loaded = true;
    } catch (_) {
      error = 'storage';
    }
    loading = false;
    _notify();
  }

  void select(String id) {
    if (running) return;
    selected = tasks.where((task) => task.id == id).firstOrNull;
    error = null;
    _notify();
  }

  Future<void> start(AddressRecoveryInput input) async {
    if (running || disposed) return;
    input.validate();
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final task = AddressRecoveryTask(
      id: id,
      input: input,
      createdAt: now,
      status: 'starting',
    );
    selected = task;
    tasks.insert(0, task);
    await _launch(task);
  }

  Future<void> resume({int? cpuPercent}) async {
    final task = selected;
    if (running || task == null || !task.canResume) return;
    if (cpuPercent != null) task.input = task.input.withCpu(cpuPercent);
    task.input.validate();
    await _launch(task);
  }

  Future<void> _persist(AddressRecoveryTask task) {
    task.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final snapshot = jsonDecode(jsonEncode(task.toJson())) as Map;
    final operation = _tail.then(
      (_) => vault.saveRecoveryTask(Map<String, Object?>.from(snapshot)),
    );
    _tail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _launch(AddressRecoveryTask task) async {
    error = null;
    running = true;
    pausing = false;
    _finalReceived = false;
    activeMicros = 0;
    sleepMicros = 0;
    rate = 0;
    task.status = 'starting';
    task.reason = '';
    _notify();
    try {
      await _persist(task);
      if (disposed) {
        running = false;
        return;
      }
      _messages = ReceivePort();
      _errors = ReceivePort();
      _exit = ReceivePort();
      _messages!.listen(
        (message) =>
            _onMessage(task, Map<String, Object?>.from(message as Map)),
      );
      _errors!.listen((_) => _failed(task));
      _exit!.listen((_) {
        if (!_finalReceived && running) _failed(task);
      });
      final worker = await Isolate.spawn(
        _recoveryWorker,
        <Object?>[
          _messages!.sendPort,
          task.input.toJson(),
          task.cursor,
          task.checked,
          task.fingerprint,
          task.matches,
        ],
        onError: _errors!.sendPort,
        onExit: _exit!.sendPort,
        debugName: 'address-recovery',
      );
      if (disposed) {
        worker.kill(priority: Isolate.immediate);
        _cleanup();
        running = false;
        return;
      }
      _worker = worker;
    } catch (_) {
      running = false;
      pausing = false;
      task.status = 'error';
      task.reason = 'storage';
      error = 'storage';
      _cleanup();
      if (!(_pause?.isCompleted ?? true)) _pause!.complete();
      _notify();
    }
  }

  void _onMessage(AddressRecoveryTask task, Map<String, Object?> message) {
    if (disposed) return;
    final type = message['type'];
    if (type == 'port') {
      _commands = message['port'] as SendPort;
      if (pausing) _commands!.send('pause');
      return;
    }
    if (type == 'error') {
      _failed(task);
      return;
    }
    if (message['cursor'] case final int cursor) task.cursor = cursor;
    if (message['checked'] case final int checked) task.checked = checked;
    if (message['family_count'] case final int count) task.familyCount = count;
    if (message['fingerprint'] case final String fingerprint) {
      task.fingerprint = fingerprint;
    }
    if (message['probe'] case final Map probe) {
      task.probe = Map<String, Object?>.from(probe);
    }
    if (message['verification'] case final Map verification) {
      task.verification = Map<String, Object?>.from(verification);
    }
    if (message['matches'] case final List matches) {
      task.matches
        ..clear()
        ..addAll([
          for (final match in matches) Map<String, Object?>.from(match as Map),
        ]);
    }
    rate = (message['rate'] as num?)?.toDouble() ?? rate;
    activeMicros = message['active_us'] as int? ?? activeMicros;
    sleepMicros = message['sleep_us'] as int? ?? sleepMicros;
    if (type == 'done') {
      _finalReceived = true;
      task.status = message['status'] as String;
      task.reason = message['reason'] as String;
      unawaited(_finish(task));
    } else {
      task.status = pausing ? 'pausing' : 'running';
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSavedMs >= 5000) {
        _lastSavedMs = now;
        unawaited(
          _persist(task).catchError((Object _) {
            error = 'storage';
            unawaited(pause());
            _notify();
          }),
        );
      }
    }
    _notify();
  }

  Future<void> _finish(AddressRecoveryTask task) async {
    _cleanup();
    try {
      await _persist(task);
    } catch (_) {
      error = 'storage';
      task.status = 'error';
      task.reason = 'storage';
    }
    running = false;
    pausing = false;
    if (!(_pause?.isCompleted ?? true)) _pause!.complete();
    _notify();
  }

  void _failed(AddressRecoveryTask task) {
    if (_finalReceived) return;
    _finalReceived = true;
    task.status = 'error';
    task.reason = 'worker';
    error = 'worker';
    unawaited(_finish(task));
  }

  Future<void> pause() async {
    if (!running) {
      await _tail;
      return;
    }
    pausing = true;
    selected?.status = 'pausing';
    _pause ??= Completer<void>();
    if (_pause!.isCompleted) _pause = Completer<void>();
    _commands?.send('pause');
    _notify();
    await _pause!.future;
  }

  void _cleanup() {
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _messages?.close();
    _messages = null;
    _errors?.close();
    _errors = null;
    _exit?.close();
    _exit = null;
    _commands = null;
  }

  @override
  void dispose() {
    disposed = true;
    running = false;
    pausing = false;
    _cleanup();
    if (!(_pause?.isCompleted ?? true)) _pause!.complete();
    super.dispose();
  }
}

Map<String, Object?> _verifyXpub(
  AddressRecoveryInput input,
  List<engine.Material> materials, {
  int? overrideIndex,
}) {
  if (input.xpub.trim().isEmpty) return {'match': 'not_provided'};
  final xpub = BIP32.fromBase58(input.xpub.trim());
  final index = input.mode == 'index'
      ? overrideIndex ?? input.start
      : input.index;
  final child = xpub.derive(index);
  // Public xPub verification is informational and never a private-key match.
  final coordinates = child.publicKey;
  final raw = engine.addressesForPublicKey(coordinates);
  final target = engine.hex(engine.targetBytes(input.target));
  final defaultPath = input.mode == 'index'
      ? engine.normalizeRecoveryBasePath(input.basePath)
      : "m/44'/60'/0'/0";
  final origin = materials.any((material) {
    final parent = defaultPath == 'm'
        ? material.root
        : material.root.derivePath(defaultPath);
    return engine.hex(parent.publicKey) == engine.hex(xpub.publicKey) &&
        engine.hex(parent.chainCode) == engine.hex(xpub.chainCode);
  });
  return {
    'match': raw['standard_evm'] == '0x$target'
        ? 'standard'
        : raw['legacy_evm'] == '0x$target'
        ? 'legacy'
        : 'none',
    'origin_matches_base': origin,
    'index': index,
    ...raw,
  };
}

Future<void> _recoveryWorker(List<Object?> arguments) async {
  final output = arguments[0] as SendPort;
  final commands = ReceivePort();
  var paused = false;
  commands.listen((message) {
    if (message == 'pause') paused = true;
  });
  output.send({'type': 'port', 'port': commands.sendPort});
  try {
    await Future<void>.delayed(Duration.zero);
    final input = AddressRecoveryInput.fromJson(arguments[1] as Map)
      ..validate();
    final options = input.options();
    final sources = engine.materialsFromMnemonic(
      input.mnemonic,
      passphrase: input.passphrase,
    );
    final search = engine.Engine(options, sources);
    final restored = arguments[4] as String?;
    if (restored != null && restored != search.fingerprint) {
      throw const FormatException();
    }
    var cursor = restored == null ? search.initialCursor : arguments[2] as int;
    var checked = arguments[3] as int;
    if (cursor < 0 ||
        cursor > (engine.maxChildIndex + 1) * search.familyCount) {
      throw const FormatException();
    }
    final matches = [
      for (final match in arguments[5] as List)
        Map<String, Object?>.from(match as Map),
    ];
    for (final saved in matches) {
      final match = search.check(saved['cursor'] as int);
      if (match == null ||
          match.privateKey != saved['derived_private_key'] ||
          match.public['match'] != saved['match']) {
        throw const FormatException();
      }
    }
    var verification = _verifyXpub(input, sources);
    final baselineRss = ProcessInfo.currentRss;
    final timer = Stopwatch()..start();
    var lastProgress = 0, activeUs = 0, sleepUs = 0, sessionChecked = 0;
    Map<String, Object?>? probe;
    Map<String, Object?> message(
      String type, {
      String status = 'running',
      String reason = '',
    }) => {
      'type': type,
      'status': status,
      'reason': reason,
      'cursor': cursor,
      'checked': checked,
      'family_count': search.familyCount,
      'fingerprint': search.fingerprint,
      'probe': probe,
      'verification': verification,
      'matches': matches,
      'rate': sessionChecked * 1000 / max(1, timer.elapsedMilliseconds),
      'active_us': activeUs,
      'sleep_us': sleepUs,
    };
    output.send(message('ready'));
    if (matches.length >= 32 && input.standardOnly) {
      output.send(message('done', status: 'paused', reason: 'match_limit'));
      return;
    }
    if (matches.isNotEmpty &&
        (matches.last['match'] == 'standard_address_match' ||
            !input.standardOnly)) {
      output.send(
        message(
          'done',
          status: matches.last['match'] as String,
          reason: 'match',
        ),
      );
      return;
    }
    var reason = 'user';
    while (cursor < search.endCursor && !paused) {
      if (ProcessInfo.currentRss > baselineRss + 128 * 1024 * 1024) {
        reason = 'memory_limit';
        break;
      }
      final slice = Stopwatch()..start();
      while (slice.elapsedMilliseconds < 40 &&
          cursor < search.endCursor &&
          !paused) {
        final result = search.probe(cursor);
        final position = cursor++;
        checked++;
        sessionChecked++;
        probe = result.public;
        if (result.match case final engine.Candidate match) {
          if (input.mode == 'index') {
            verification = _verifyXpub(
              input,
              sources,
              overrideIndex: result.public['counter'] as int,
            );
          }
          matches.add({
            ...match.public,
            'cursor': position,
            'derived_private_key': match.privateKey,
          });
          if (match.public['match'] == 'standard_address_match' ||
              !input.standardOnly ||
              matches.length >= 32) {
            activeUs += slice.elapsedMicroseconds;
            final status = matches.length >= 32 && input.standardOnly
                ? 'paused'
                : match.public['match'] as String;
            output.send(
              message(
                'done',
                status: status,
                reason: matches.length >= 32 ? 'match_limit' : 'match',
              ),
            );
            return;
          }
        }
      }
      slice.stop();
      activeUs += slice.elapsedMicroseconds;
      final rest =
          (slice.elapsedMicroseconds *
                  (100 - input.cpuPercent) /
                  input.cpuPercent)
              .ceil();
      await Future<void>.delayed(Duration(microseconds: rest));
      sleepUs += rest;
      if (timer.elapsedMilliseconds - lastProgress >= 1000) {
        lastProgress = timer.elapsedMilliseconds;
        output.send(message('progress'));
      }
    }
    final exhausted = cursor >= search.endCursor;
    output.send(
      message(
        'done',
        status: exhausted ? 'range_exhausted' : 'paused',
        reason: exhausted ? 'exhausted' : reason,
      ),
    );
  } catch (_) {
    output.send({'type': 'error'});
  } finally {
    commands.close();
  }
}
