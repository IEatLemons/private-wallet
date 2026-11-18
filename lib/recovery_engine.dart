// Deterministic derivation search shared by the wallet and offline CLI.
import 'dart:convert';
import 'dart:io';
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
  String mode = 'account';
  String basePath = "m/44'/60'/0'/0";
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
        case '--mode':
          result.mode = take(++i);
        case '--base-path':
          result.basePath = take(++i);
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
    if (!['account', 'index'].contains(result.mode)) {
      throw const RecoveryError('Search mode is invalid.');
    }
    if (result.mode == 'index') {
      result.basePath = normalizeRecoveryBasePath(result.basePath);
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

String normalizeRecoveryBasePath(String value) {
  final path = value.trim();
  if (path == 'm') return path;
  if (path.length > 4096 || !RegExp(r"^m(?:/[0-9]+['hH]?)+$").hasMatch(path)) {
    throw const RecoveryError('Invalid base path.');
  }
  final parts = path.split('/').skip(1).toList();
  if (parts.length > 254) throw const RecoveryError('Base path is too deep.');
  return 'm/${parts.map((part) {
    final hard = RegExp(r"['hH]$").hasMatch(part);
    final n = int.tryParse(hard ? part.substring(0, part.length - 1) : part);
    if (n == null || n < 0 || n > maxChildIndex) throw const RecoveryError('Invalid path index.');
    return "$n${hard ? "'" : ''}";
  }).join('/')}';
}

List<Material> materialsFromMnemonic(String phrase, {String passphrase = ''}) {
  final canonical = phrase.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');
  if (!bip39.validateMnemonic(canonical)) {
    throw const RecoveryError('Invalid recovery phrase.');
  }
  final sources = <String, Material>{};
  for (final text in {canonical, phrase.trim()}) {
    final root = BIP32.fromSeed(
      bip39.mnemonicToSeed(text, passphrase: passphrase),
    );
    final id = digest(root.neutered().toBase58());
    sources[id] = Material(root, id);
  }
  final ids = sources.keys.toList()..sort();
  return [for (final id in ids) sources[id]!];
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
    if (options.mode == 'index') {
      options.basePath = normalizeRecoveryBasePath(options.basePath);
      for (final source in materials) {
        indexNodes.add(
          options.basePath == 'm'
              ? source.root
              : source.root.derivePath(options.basePath),
        );
      }
      return;
    }
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
  final indexNodes = <BIP32>[];
  int get familyCount =>
      options.mode == 'index' ? materials.length : families.length;
  int get initialCursor => options.startAccount * familyCount;
  int get endCursor => (options.endAccount + 1) * familyCount;
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
      if (options.mode == 'index') 'mode': 'index',
      if (options.mode == 'index') 'base_path': options.basePath,
    }),
  );

  Candidate? check(int cursor) => probe(cursor).match;

  Probe probe(int cursor) {
    final counter = cursor ~/ familyCount;
    final slot = cursor % familyCount;
    final BIP32 child;
    final String path;
    final String sourceId;
    if (options.mode == 'index') {
      child = indexNodes[slot].derive(counter);
      path = '${options.basePath}/$counter';
      sourceId = materials[slot].id;
    } else {
      final family = families[slot];
      final account = family.hardened
          ? family.coinNode.deriveHardened(counter)
          : family.coinNode.derive(counter);
      child = account.derive(family.change).derive(options.index);
      path = family.path(counter, options.index);
      sourceId = family.source.id;
    }
    final coordinates = ec.decompressPublicKey(child.publicKey).sublist(1);
    final standard = ec.keccak256(coordinates).sublist(12);
    final legacy = ec
        .keccak256(Uint8List.fromList([4, ...coordinates]))
        .sublist(12);
    final targetHex = hex(target);
    final standardMatch = hex(standard) == targetHex;
    final publicProbe = <String, Object?>{
      'path': path,
      'counter': counter,
      'standard_evm': '0x${hex(standard)}',
      'standard_tron': tronAddress(standard),
      'legacy_evm': '0x${hex(legacy)}',
      'legacy_tron': tronAddress(legacy),
    };
    if (!standardMatch && hex(legacy) != targetHex) {
      return Probe(publicProbe, null);
    }
    return Probe(
      publicProbe,
      Candidate({
        'match': standardMatch
            ? 'standard_address_match'
            : 'legacy_hash_match_only',
        'standard_address_matches_target': standardMatch,
        'source_id': sourceId.substring(0, 12),
        'path': path,
        'target_evm': '0x$targetHex',
        'target_tron': tronAddress(target),
        'standard_evm': '0x${hex(standard)}',
        'standard_tron': tronAddress(standard),
        'legacy_evm': '0x${hex(legacy)}',
        'legacy_tron': tronAddress(legacy),
        'warning': standardMatch
            ? 'Standard address matches the private key. On-chain permissions must still be checked before spending.'
            : 'This is the original derived key for the old hash, NOT a controlling key for the target standard address. Funds have not been recovered.',
      }, hex(child.privateKey!)),
    );
  }
}

class Probe {
  const Probe(this.public, this.match);
  final Map<String, Object?> public;
  final Candidate? match;
}

Map<String, String> addressesForPublicKey(Uint8List compressed) {
  final coordinates = ec.decompressPublicKey(compressed).sublist(1);
  final standard = ec.keccak256(coordinates).sublist(12);
  final legacy = ec
      .keccak256(Uint8List.fromList([4, ...coordinates]))
      .sublist(12);
  return {
    'standard_evm': '0x${hex(standard)}',
    'standard_tron': tronAddress(standard),
    'legacy_evm': '0x${hex(legacy)}',
    'legacy_tron': tronAddress(legacy),
  };
}
