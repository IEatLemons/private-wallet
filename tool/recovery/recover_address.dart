import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:stone_wallet/recovery_engine.dart';
import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart' as hashes;
import 'package:web3dart/crypto.dart' as ec;

int _temporaryCounter = 0;
Future<void> privateMode(String path, String mode) async {
  if (!Platform.isWindows) {
    final result = await Process.run('/bin/chmod', [mode, path]);
    if (result.exitCode != 0) throw const RecoveryError('无法设置本地文件访问权限。');
  }
}

Future<void> atomicJson(File destination, Map<String, Object?> value) async {
  final temporary = File(
    '${destination.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}-${_temporaryCounter++}',
  );
  try {
    await temporary.create(exclusive: true);
    await privateMode(temporary.path, '600');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    await temporary.rename(destination.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

class Store {
  Store(this.directory);
  final Directory directory;
  RandomAccessFile? _lock;
  File get checkpoint => File('${directory.path}/checkpoint.json');
  Future<void> open() async {
    if (FileSystemEntity.isLinkSync(directory.path)) {
      throw const RecoveryError('进度目录不能是符号链接。');
    }
    await directory.create(recursive: true);
    await privateMode(directory.path, '700');
    _lock = await File(
      '${directory.path}/run.lock',
    ).open(mode: FileMode.append);
    try {
      await _lock!.lock(FileLock.exclusive);
    } catch (_) {
      await _lock!.close();
      _lock = null;
      throw const RecoveryError('这个进度目录已有运行中的实例，请先停止它。');
    }
  }

  Future<void> close() async {
    await _lock?.close();
    _lock = null;
  }

  Map<String, Object?>? load() {
    if (!checkpoint.existsSync()) return null;
    try {
      if (checkpoint.lengthSync() > 1024 * 1024) {
        throw const RecoveryError('进度文件过大。');
      }
      return Map<String, Object?>.from(
        jsonDecode(checkpoint.readAsStringSync()) as Map,
      );
    } catch (_) {
      throw const RecoveryError('进度文件损坏，已停止，未覆盖原进度。');
    }
  }

  Future<void> save(Map<String, Object?> value) =>
      atomicJson(checkpoint, value);
  Future<Map<String, Object?>> saveMatch(
    Candidate candidate,
    int cursor,
  ) async {
    final kind = candidate.public['match'];
    final file = File('${directory.path}/match-$cursor-$kind.private.json');
    if (file.existsSync()) {
      if (FileSystemEntity.isLinkSync(file.path) ||
          file.lengthSync() > 64 * 1024) {
        throw const RecoveryError('结果文件类型或大小无效。');
      }
      final existing = jsonDecode(file.readAsStringSync()) as Map;
      if (existing['derived_private_key'] != candidate.privateKey ||
          existing['match'] != kind) {
        throw const RecoveryError('已有结果与本次核验不一致，未覆盖原文件。');
      }
    } else {
      await atomicJson(file, {
        ...candidate.public,
        'derived_private_key': candidate.privateKey,
      });
    }
    return {
      ...candidate.public,
      'cursor': cursor,
      'private_result_file': file.absolute.path,
    };
  }

  Future<void> log(String message) async {
    stdout.writeln(message);
    final log = File('${directory.path}/progress.log');
    if (log.existsSync() && log.lengthSync() >= 512 * 1024) {
      final previous = File('${log.path}.1');
      if (previous.existsSync()) previous.deleteSync();
      log.renameSync(previous.path);
    }
    if (!log.existsSync()) {
      await log.create(exclusive: true);
      await privateMode(log.path, '600');
    }
    await log.writeAsString(
      '${DateTime.now().toUtc().toIso8601String()} $message\n',
      mode: FileMode.append,
    );
  }
}

Future<int> run(Options options) async {
  final store = Store(Directory(options.stateDir).absolute);
  await store.open();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  var requestedStop = false;
  var stopReason = 'interrupted';
  try {
    for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
      subscriptions.add(
        signal.watch().listen((_) {
          requestedStop = true;
        }),
      );
    }
    if (ProcessInfo.currentRss > options.maxRssMb * 1024 * 1024) {
      await store.log('内存已超过上限，尚未加载助记词；请提高 --max-rss-mb 后重试。');
      return 5;
    }
    final engine = Engine(options, loadMaterials(options));
    final old = store.load();
    if (old != null &&
        (old['version'] != 1 || old['fingerprint'] != engine.fingerprint)) {
      throw const RecoveryError('配置、目标或路径范围已变化。请使用另一个 --state-dir，原进度未改动。');
    }
    var cursor = old?['next_cursor'] as int? ?? engine.initialCursor;
    var checked = old?['candidates_checked'] as int? ?? 0;
    var legacyMatches = old?['legacy_matches'] as int? ?? 0;
    var lastMatch = old?['last_match'] as Map?;
    if (cursor < 0 ||
        cursor > (maxChildIndex + 1) * engine.familyCount ||
        checked < 0) {
      throw const RecoveryError('进度游标无效，已停止，未覆盖原进度。');
    }
    final session = Stopwatch()..start();
    var activeMicros = 0;
    var sleepMicros = 0;
    var sessionChecked = 0;
    var nextSaveMs = 5000;
    var nextProgressMs = options.progressSeconds * 1000;
    var status = 'running';
    var reason = 'searching';
    Map<String, Object?> state() => {
      'version': 1,
      'fingerprint': engine.fingerprint,
      'status': status,
      'reason': reason,
      'next_cursor': cursor,
      'next_account': cursor ~/ engine.familyCount,
      'candidates_checked': checked,
      'legacy_matches': legacyMatches,
      'family_count': engine.familyCount,
      'account_max': options.endAccount,
      'stop_on': options.stopOn,
      'cpu_percent_of_one_core': options.cpuPercent,
      'session_active_microseconds': activeMicros,
      'session_sleep_microseconds': sleepMicros,
      'rss_bytes': ProcessInfo.currentRss,
      'last_match': lastMatch,
      'updated_at_utc': DateTime.now().toUtc().toIso8601String(),
    };
    await store.log(
      '离线搜索；单计算线程，约 ${options.cpuPercent}% 单核负载，内存上限 ${options.maxRssMb} MiB。',
    );
    await store.log(
      '目标 ${tronAddress(engine.target)}；固定末级索引 ${options.index}；从账户 ${cursor ~/ engine.familyCount} 续跑。',
    );
    await store.log(
      '停止条件：${options.stopOn == 'either' ? '派生私钥生成的标准或旧版地址匹配' : '仅标准地址匹配'}。旧版错误哈希匹配不代表恢复资金控制权。',
    );
    if (lastMatch != null) {
      final savedCursor = lastMatch['cursor'];
      if (savedCursor is! int || savedCursor < 0 || savedCursor >= cursor) {
        throw const RecoveryError('已有匹配记录的游标无效。');
      }
      final verified = engine.check(savedCursor);
      if (verified == null || verified.public['match'] != lastMatch['match']) {
        throw const RecoveryError('已有匹配记录未通过重新核验。');
      }
      lastMatch = await store.saveMatch(verified, savedCursor);
    }
    if (lastMatch != null &&
        (lastMatch['match'] == 'standard_address_match' ||
            options.stopOn == 'either')) {
      await store.log(
        '已有匹配结果：${lastMatch['match']}；本地结果：${lastMatch['private_result_file']}',
      );
      return lastMatch['match'] == 'standard_address_match' ? 0 : 3;
    }
    await store.save(state());
    while (cursor < engine.endCursor) {
      if (requestedStop) {
        reason = stopReason;
        break;
      }
      if (ProcessInfo.currentRss > options.maxRssMb * 1024 * 1024) {
        reason = 'memory_limit';
        break;
      }
      if (options.runSeconds > 0 &&
          session.elapsed.inSeconds >= options.runSeconds) {
        reason = 'session_time_limit';
        break;
      }
      if (options.limit > 0 && sessionChecked >= options.limit) {
        reason = 'session_candidate_limit';
        break;
      }
      final slice = Stopwatch()..start();
      while (slice.elapsedMilliseconds < options.sliceMs &&
          cursor < engine.endCursor &&
          !requestedStop) {
        final match = engine.check(cursor);
        final checkedCursor = cursor++;
        checked++;
        sessionChecked++;
        if (match != null) {
          lastMatch = await store.saveMatch(match, checkedCursor);
          if (match.public['match'] == 'legacy_hash_match_only') {
            legacyMatches++;
          }
          await store.log(
            '地址匹配：${match.public['match']}；路径 ${match.public['path']}；私钥只保存在本地受限文件。',
          );
          await store.log(
            '标准 TRON 地址：${match.public['standard_tron']}；结果：${lastMatch['private_result_file']}',
          );
          if (match.public['match'] == 'standard_address_match' ||
              options.stopOn == 'either') {
            activeMicros += slice.elapsedMicroseconds;
            status = match.public['match'] as String;
            reason = status;
            await store.save(state());
            await store.log(
              status == 'standard_address_match'
                  ? '标准地址与派生私钥匹配，搜索已停止。转账前仍需核对链上权限。'
                  : '仅旧版错误哈希匹配：已找到原派生密钥，未恢复目标地址的资金控制权。搜索已停止。',
            );
            return status == 'standard_address_match' ? 0 : 3;
          }
        }
        if (options.limit > 0 && sessionChecked >= options.limit) break;
      }
      slice.stop();
      final elapsed = slice.elapsedMicroseconds;
      activeMicros += elapsed;
      final rest = (elapsed * (100 - options.cpuPercent) / options.cpuPercent)
          .ceil();
      if (rest > 0) {
        await Future<void>.delayed(Duration(microseconds: rest));
        sleepMicros += rest;
      }
      if (session.elapsedMilliseconds >= nextSaveMs) {
        await store.save(state());
        nextSaveMs = session.elapsedMilliseconds + 5000;
      }
      if (session.elapsedMilliseconds >= nextProgressMs) {
        final seconds = max(1, session.elapsed.inSeconds);
        await store.log(
          '已核验 $checked 个候选；下一账户 ${cursor ~/ engine.familyCount}；本轮 ${sessionChecked ~/ seconds} 个/秒；内存 ${(ProcessInfo.currentRss / 1048576).toStringAsFixed(1)} MiB。Ctrl+C 可保存退出。',
        );
        nextProgressMs =
            session.elapsedMilliseconds + options.progressSeconds * 1000;
      }
    }
    status = cursor >= engine.endCursor ? 'range_exhausted' : 'paused';
    if (status == 'range_exhausted') reason = 'configured_range_exhausted';
    await store.save(state());
    await store.log(
      status == 'range_exhausted'
          ? '设定路径范围已遍历完，没有标准地址匹配。未承诺一定能够找到。'
          : '已保存并暂停（$reason）。再次运行相同配置会自动续跑。',
    );
    return status == 'range_exhausted' ? 4 : 0;
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await store.close();
  }
}

void selfTest() {
  const phrase =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  final root = BIP32.fromSeed(bip39.mnemonicToSeed(phrase));
  final source = Material(root, digest(root.neutered().toBase58()));
  final options = Options()
    ..target = '0x9858effd232b4033e47d90003d41ec34ecaeda94'
    ..index = 0
    ..endAccount = 0;
  final engine = Engine(options, [source]);
  final match = [
    for (var i = 0; i < engine.endCursor; i++) engine.check(i),
  ].whereType<Candidate>().single;
  if (match.public['match'] != 'standard_address_match') {
    throw StateError('Standard vector failed');
  }
  final standard = ec.hexToBytes(match.public['standard_evm'] as String);
  final key = ec.hexToBytes(match.privateKey);
  final message = Uint8List.fromList(
    hashes.sha256.convert(utf8.encode('public synthetic recovery test')).bytes,
  );
  if (hex(
        ec.keccak256(ec.ecRecover(message, ec.sign(message, key))).sublist(12),
      ) !=
      hex(standard)) {
    throw StateError('Signature vector failed');
  }
  final legacyOptions = Options()
    ..target = match.public['legacy_tron'] as String
    ..index = 0
    ..endAccount = 0;
  final legacyEngine = Engine(legacyOptions, [source]);
  final legacy = [
    for (var i = 0; i < legacyEngine.endCursor; i++) legacyEngine.check(i),
  ].whereType<Candidate>().single;
  if (legacy.public['match'] != 'legacy_hash_match_only' ||
      legacy.public['standard_address_matches_target'] != false) {
    throw StateError('Legacy classification failed');
  }
  stdout.writeln(
    jsonEncode({
      'self_test': 'passed',
      'synthetic_legacy_target': legacyOptions.target,
    }),
  );
}

const help = '''
离线助记词派生地址恢复搜索（不会连接网络，不会发送交易）
  recover-address --config /absolute/path/input.env --state-dir /absolute/path/state

默认：单计算线程，约 25% 单核负载，内存上限 256 MiB；Ctrl+C 保存，重启自动续跑。
  --cpu-percent 10        更低负载，允许 5–75（是一个核心，不是整机）
  --max-rss-mb 256        超过 RSS 上限时退出，不继续占用内存
  --stop-on either        标准或旧版地址匹配且存在派生私钥时停止（默认）
  --stop-on standard      旧版匹配只保存线索，继续查标准地址
  --target ADDRESS       默认是本次目标 TRON 地址
  --index 925183485       固定末级派生索引
  --account-max N         默认 2147483647；范围遍历完会停止
  --purposes 44,49,84 --coins 0,60,195 --changes 0
  --run-seconds N         本轮限时，0 表示不设时长上限
  --limit N               本轮限制候选数，0 表示不限制
  --progress-seconds 30   定时输出进度；日志轮换，不无限增大
  --self-test            仅使用公开测试助记词自检

输入支持 .env、JSON、普通 YAML 标量。读取 COLLECT_MNEMONIC/MNEMONIC/MNEMONICS，
可选 BIP39_PASSPHRASE。文件作为数据读取，绝不执行或 source。
结果私钥仅写入 state 目录的 *.private.json；不打印助记词或私钥。
旧版错误哈希匹配不等于恢复目标地址的控制权。持续搜索也不保证一定找到。
''';

Future<void> main(List<String> args) async {
  try {
    final options = Options.parse(args);
    if (options.help) {
      stdout.write(help);
      return;
    }
    if (options.selfTest) {
      selfTest();
      return;
    }
    exitCode = await run(options);
  } on RecoveryError catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } catch (_) {
    stderr.writeln('输入、进度文件或计算异常，已停止；不会输出秘密内容。');
    exitCode = 2;
  }
}
