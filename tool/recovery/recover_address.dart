import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:crypto/crypto.dart' as hashes;
import 'package:web3dart/crypto.dart' as ec;

const defaultTarget = 'TWkvByXfB9QzaLHtMSi83GGaoBLBgE5KE7';
const maxChildIndex = 0x7fffffff;

class RecoveryError implements Exception {
  const RecoveryError(this.message);
  final String message;
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
String digest(String value) =>
    hashes.sha256.convert(utf8.encode(value)).toString();
String tronAddress(List<int> address) =>
    base58.encode(Uint8List.fromList([0x41, ...address]));

Uint8List targetBytes(String value) {
  final text = value.trim();
  final evm = text.replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
  if (RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(evm)) {
    return ec.hexToBytes(evm);
  }
  try {
    final decoded = base58.decode(text);
    if (decoded.length == 21 && decoded.first == 0x41) {
      return decoded.sublist(1);
    }
  } catch (_) {
    // Never echo an untrusted input or parser exception.
  }
  throw const RecoveryError('目标必须是有效的 TRON Base58Check 或 EVM 地址。');
}

class Options {
  final configs = <String>[];
  String stateDir = 'recovery-state';
  String target = defaultTarget;
  String stopOn = 'either';
  List<int> purposes = [44, 49, 84];
  List<int> coins = [0, 60, 195];
  List<int> changes = [0];
  int index = 925183485;
  int startAccount = 0;
  int endAccount = maxChildIndex;
  int cpuPercent = 25;
  int sliceMs = 40;
  int maxRssMb = 256;
  int runSeconds = 0;
  int limit = 0;
  int progressSeconds = 30;
  bool selfTest = false;
  bool help = false;

  static Options parse(List<String> args) {
    final result = Options();
    String take(int i) {
      if (i >= args.length) throw const RecoveryError('选项缺少参数。');
      return args[i];
    }

    List<int> numbers(String text) =>
        text.split(',').map(int.parse).toSet().toList()..sort();
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--config':
          result.configs.add(take(++i));
        case '--state-dir':
          result.stateDir = take(++i);
        case '--target':
          result.target = take(++i);
        case '--index':
          result.index = int.parse(take(++i));
        case '--account-start':
          result.startAccount = int.parse(take(++i));
        case '--account-max':
          result.endAccount = int.parse(take(++i));
        case '--cpu-percent':
          result.cpuPercent = int.parse(take(++i));
        case '--slice-ms':
          result.sliceMs = int.parse(take(++i));
        case '--max-rss-mb':
          result.maxRssMb = int.parse(take(++i));
        case '--run-seconds':
          result.runSeconds = int.parse(take(++i));
        case '--limit':
          result.limit = int.parse(take(++i));
        case '--progress-seconds':
          result.progressSeconds = int.parse(take(++i));
        case '--stop-on':
          result.stopOn = take(++i);
        case '--purposes':
          result.purposes = numbers(take(++i));
        case '--coins':
          result.coins = numbers(take(++i));
        case '--changes':
          result.changes = numbers(take(++i));
        case '--self-test':
          result.selfTest = true;
        case '--help':
        case '-h':
          result.help = true;
        default:
          throw const RecoveryError('存在不支持的选项，请运行 --help。');
      }
    }
    if (result.help || result.selfTest) return result;
    if (result.configs.isEmpty || result.configs.length > 16) {
      throw const RecoveryError('请用 --config 指定 1–16 个本地配置文件。');
    }
    if (result.startAccount < 0 ||
        result.endAccount > maxChildIndex ||
        result.startAccount > result.endAccount ||
        result.index < 0 ||
        result.index > maxChildIndex ||
        result.cpuPercent < 5 ||
        result.cpuPercent > 75 ||
        result.sliceMs < 5 ||
        result.sliceMs > 100 ||
        result.maxRssMb < 1 ||
        result.maxRssMb > 4096 ||
        result.runSeconds < 0 ||
        result.limit < 0 ||
        result.progressSeconds < 1 ||
        !['standard', 'either'].contains(result.stopOn)) {
      throw const RecoveryError('参数范围无效；CPU 为单核的 5–75%，账户和索引为 0–2147483647。');
    }
    for (final values in [result.purposes, result.coins, result.changes]) {
      if (values.isEmpty ||
          values.length > 16 ||
          values.any((v) => v < 0 || v > maxChildIndex)) {
        throw const RecoveryError('路径参数无效，每类最多 16 个非负索引。');
      }
    }
    targetBytes(result.target);
    return result;
  }
}

Map<String, List<String>> readConfig(String path) {
  final file = File(path);
  if (!file.existsSync() || file.lengthSync() > 1024 * 1024) {
    throw const RecoveryError('配置文件不存在或超过 1 MiB。');
  }
  final raw = file.readAsStringSync();
  final values = <String, List<String>>{};
  const wanted = {
    'COLLECT_MNEMONIC',
    'MNEMONIC',
    'MNEMONICS',
    'BIP39_PASSPHRASE',
  };
  void add(String key, dynamic value) {
    final name = key.toUpperCase();
    if (!wanted.contains(name)) return;
    if (value is String) values.putIfAbsent(name, () => []).add(value);
    if (value is List) {
      for (final item in value.whereType<String>()) {
        values.putIfAbsent(name, () => []).add(item);
      }
    }
  }

  if (raw.trimLeft().startsWith('{')) {
    void visit(Map value) {
      for (final entry in value.entries) {
        if (entry.value is Map) {
          visit(entry.value as Map);
        } else {
          add(entry.key.toString(), entry.value);
        }
      }
    }

    visit(jsonDecode(raw) as Map);
  } else {
    for (final line in const LineSplitter().convert(raw)) {
      final match = RegExp(
        r'^\s*(?:export\s+)?([A-Za-z_][A-Za-z_0-9]*)\s*[=:]\s*(.*?)\s*$',
      ).firstMatch(line);
      if (match == null || !wanted.contains(match.group(1)!.toUpperCase())) {
        continue;
      }
      var value = match.group(2)!;
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1);
      } else {
        value = value.split(RegExp(r'\s+#')).first.trim();
      }
      add(match.group(1)!, value);
    }
  }
  return values;
}

class Material {
  Material(this.root, this.id);
  final BIP32 root;
  final String id;
}

List<Material> loadMaterials(Options options) {
  final unique = <String, Material>{};
  for (final path in options.configs) {
    final values = readConfig(path);
    final passphrases = values['BIP39_PASSPHRASE'] ?? [''];
    if (passphrases.length != 1) {
      throw const RecoveryError('每份配置只能指定一个 BIP39_PASSPHRASE。');
    }
    final phrases = [
      for (final name in ['COLLECT_MNEMONIC', 'MNEMONIC', 'MNEMONICS'])
        ...?values[name],
    ];
    for (final raw in phrases) {
      if (raw.trim().isEmpty) continue;
      final canonical = raw
          .trim()
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .join(' ');
      if (!bip39.validateMnemonic(canonical)) {
        throw const RecoveryError('存在无效助记词，未输出其内容。');
      }
      // Preserve the original spelling as well, to cover Go NewSeed's exact input.
      for (final phrase in {canonical, raw.trim()}) {
        final root = BIP32.fromSeed(
          bip39.mnemonicToSeed(phrase, passphrase: passphrases.single),
        );
        final id = digest(root.neutered().toBase58());
        unique[id] = Material(root, id);
        if (unique.length > 32) {
          throw const RecoveryError('助记词来源超过 32 份，请拆分到不同进度目录。');
        }
      }
    }
  }
  if (unique.isEmpty || unique.length > 32) {
    throw const RecoveryError('需要 1–32 份有效助记词；只有 xPub 无法导出私钥。');
  }
  final ids = unique.keys.toList()..sort();
  return [for (final id in ids) unique[id]!];
}

class Family {
  Family(
    this.source,
    this.purpose,
    this.coin,
    this.hardened,
    this.change,
    this.coinNode,
  );
  final Material source;
  final int purpose, coin, change;
  final bool hardened;
  final BIP32 coinNode;
  String path(int account, int index) =>
      "m/$purpose'/$coin'/$account${hardened ? "'" : ''}/$change/$index";
}

class Candidate {
  Candidate(this.public, this.privateKey);
  final Map<String, Object?> public;
  final String privateKey;
}

class Engine {
  Engine(this.options, this.materials) : target = targetBytes(options.target) {
    for (final source in materials) {
      for (final purpose in options.purposes) {
        final purposeNode = source.root.deriveHardened(purpose);
        for (final coin in options.coins) {
          final coinNode = purposeNode.deriveHardened(coin);
          for (final hardened in [true, false]) {
            for (final change in options.changes) {
              families.add(
                Family(source, purpose, coin, hardened, change, coinNode),
              );
            }
          }
        }
      }
    }
  }
  final Options options;
  final List<Material> materials;
  final Uint8List target;
  final families = <Family>[];
  int get initialCursor => options.startAccount * families.length;
  int get endCursor => (options.endAccount + 1) * families.length;
  String get fingerprint => digest(
    jsonEncode({
      'schema': 1,
      'root_ids': materials.map((m) => m.id).toList(),
      'target': hex(target),
      'index': options.index,
      'purposes': options.purposes,
      'coins': options.coins,
      'changes': options.changes,
      'account_hardening': [true, false],
    }),
  );

  Candidate? check(int cursor) {
    final family = families[cursor % families.length];
    final accountIndex = cursor ~/ families.length;
    final account = family.hardened
        ? family.coinNode.deriveHardened(accountIndex)
        : family.coinNode.derive(accountIndex);
    final child = account.derive(family.change).derive(options.index);
    final coordinates = ec.decompressPublicKey(child.publicKey).sublist(1);
    final standard = ec.keccak256(coordinates).sublist(12);
    final legacy = ec
        .keccak256(Uint8List.fromList([4, ...coordinates]))
        .sublist(12);
    final targetHex = hex(target);
    final standardMatch = hex(standard) == targetHex;
    if (!standardMatch && hex(legacy) != targetHex) return null;
    return Candidate({
      'match': standardMatch
          ? 'standard_address_match'
          : 'legacy_hash_match_only',
      'standard_address_matches_target': standardMatch,
      'source_id': family.source.id.substring(0, 12),
      'path': family.path(accountIndex, options.index),
      'target_evm': '0x$targetHex',
      'target_tron': tronAddress(target),
      'standard_evm': '0x${hex(standard)}',
      'standard_tron': tronAddress(standard),
      'legacy_evm': '0x${hex(legacy)}',
      'legacy_tron': tronAddress(legacy),
      'warning': standardMatch
          ? 'Standard address matches the private key. On-chain permissions must still be checked before spending.'
          : 'This is the original derived key for the old hash, NOT a controlling key for the target standard address. Funds have not been recovered.',
    }, hex(child.privateKey!));
  }
}

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
        cursor > (maxChildIndex + 1) * engine.families.length ||
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
      'next_account': cursor ~/ engine.families.length,
      'candidates_checked': checked,
      'legacy_matches': legacyMatches,
      'family_count': engine.families.length,
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
      '目标 ${tronAddress(engine.target)}；固定末级索引 ${options.index}；从账户 ${cursor ~/ engine.families.length} 续跑。',
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
          '已核验 $checked 个候选；下一账户 ${cursor ~/ engine.families.length}；本轮 ${sessionChecked ~/ seconds} 个/秒；内存 ${(ProcessInfo.currentRss / 1048576).toStringAsFixed(1)} MiB。Ctrl+C 可保存退出。',
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
