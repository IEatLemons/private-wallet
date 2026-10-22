import 'dart:convert';
import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

const evmDerivationPath = "m/44'/60'/0'/0/0";

const ethereumMainnetNetwork = EvmNetwork(
  id: 1,
  name: 'Ethereum',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://cloudflare-eth.com',
  explorerUrl: 'https://etherscan.io',
  isTestnet: false,
);

const ethereumSepoliaNetwork = EvmNetwork(
  id: 11155111,
  name: 'Ethereum Sepolia',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://rpc.sepolia.org',
  explorerUrl: 'https://sepolia.etherscan.io',
  isTestnet: true,
);

const polygonMainnetNetwork = EvmNetwork(
  id: 137,
  name: 'Polygon',
  nativeSymbol: 'POL',
  rpcUrl: 'https://polygon-rpc.com',
  explorerUrl: 'https://polygonscan.com',
  isTestnet: false,
);

const polygonAmoyNetwork = EvmNetwork(
  id: 80002,
  name: 'Polygon Amoy',
  nativeSymbol: 'POL',
  rpcUrl: 'https://rpc-amoy.polygon.technology',
  explorerUrl: 'https://amoy.polygonscan.com',
  isTestnet: true,
);

const supportedEvmNetworks = <EvmNetwork>[
  ethereumMainnetNetwork,
  ethereumSepoliaNetwork,
  polygonMainnetNetwork,
  polygonAmoyNetwork,
];

class EvmNetwork {
  const EvmNetwork({
    required this.id,
    required this.name,
    required this.nativeSymbol,
    required this.rpcUrl,
    required this.explorerUrl,
    required this.isTestnet,
  });

  final int id;
  final String name;
  final String nativeSymbol;
  final String rpcUrl;
  final String explorerUrl;
  final bool isTestnet;

  EvmNetwork copyWith({
    String? name,
    String? nativeSymbol,
    String? rpcUrl,
    String? explorerUrl,
    bool? isTestnet,
  }) => EvmNetwork(
    id: id,
    name: name ?? this.name,
    nativeSymbol: nativeSymbol ?? this.nativeSymbol,
    rpcUrl: rpcUrl ?? this.rpcUrl,
    explorerUrl: explorerUrl ?? this.explorerUrl,
    isTestnet: isTestnet ?? this.isTestnet,
  );

  void validate() {
    if (id <= 0 || id > 9007199254740991) {
      throw const WalletInputException('Chain ID 必须是有效的正整数。');
    }
    if (name.trim().isEmpty || nativeSymbol.trim().isEmpty) {
      throw const WalletInputException('请填写网络名称和原生代币符号。');
    }
    for (final url in [rpcUrl, if (explorerUrl.isNotEmpty) explorerUrl]) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          !['https', 'http'].contains(uri.scheme)) {
        throw const WalletInputException('请输入有效的 HTTP / HTTPS 地址。');
      }
    }
  }

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'nativeSymbol': nativeSymbol,
    'rpcUrl': rpcUrl,
    'explorerUrl': explorerUrl,
    'isTestnet': isTestnet,
  };

  factory EvmNetwork.fromJson(Map<String, dynamic> json) {
    final network = EvmNetwork(
      id: json['id'] as int,
      name: json['name'] as String,
      nativeSymbol: json['nativeSymbol'] as String,
      rpcUrl: json['rpcUrl'] as String,
      explorerUrl: json['explorerUrl'] as String? ?? '',
      isTestnet: json['isTestnet'] as bool,
    );
    network.validate();
    return network;
  }
}

/// Narrow storage interface keeps key handling testable without touching a
/// platform keychain in unit tests.
abstract interface class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecretStore implements SecretStore {
  FlutterSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class WalletVault {
  WalletVault({SecretStore? store}) : _store = store ?? FlutterSecretStore();

  static const mnemonicKey = 'stone_wallet.v1.mnemonic';
  static const selectedNetworkKey = 'stone_wallet.v1.selected_network';
  static const selectedNetworksKey = 'stone_wallet.v1.selected_networks';
  static const privateKeyWalletsKey = 'stone_wallet.v1.private_key_wallets';
  static const networkConfigsKey = 'stone_wallet.v1.network_configs';

  final SecretStore _store;

  Future<bool> hasWallet() async =>
      (await _store.read(mnemonicKey)) != null ||
      (await _store.read(privateKeyWalletsKey)) != null;

  Future<WalletAccount> createWallet() async {
    final creation = await prepareNewWallet();
    return saveRecoveryPhrase(creation.mnemonic);
  }

  Future<WalletCreation> prepareNewWallet() async {
    final mnemonic = bip39.generateMnemonic(strength: 128);
    return WalletCreation(
      mnemonic: mnemonic,
      account: WalletAccount.fromMnemonic(mnemonic),
    );
  }

  Future<WalletAccount> saveRecoveryPhrase(String mnemonic) async {
    final normalized = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const WalletInputException('助记词无效，请检查单词和顺序。');
    }
    await _store.write(mnemonicKey, normalized);
    return WalletAccount.fromMnemonic(normalized);
  }

  Future<WalletAccount> importWallet(String mnemonic) async {
    final normalized = _normalizeMnemonic(mnemonic);
    if (!bip39.validateMnemonic(normalized)) {
      throw const WalletInputException('助记词无效，请检查单词和顺序。');
    }

    return saveRecoveryPhrase(normalized);
  }

  Future<WalletAccount?> loadWallet() async {
    final mnemonic = await _store.read(mnemonicKey);
    if (mnemonic == null || mnemonic.trim().isEmpty) return null;
    if (!bip39.validateMnemonic(mnemonic)) {
      throw const WalletInputException('本机保存的助记词校验失败。');
    }
    return WalletAccount.fromMnemonic(mnemonic);
  }

  Future<List<ImportedWallet>> loadImportedWallets() async {
    final raw = await _store.read(privateKeyWalletsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final values = jsonDecode(raw);
      if (values is! List) throw const FormatException();
      return values.map((item) {
        if (item is! Map) throw const FormatException();
        final chainId = item['chainId'];
        final privateKey = item['privateKey'];
        if (chainId is! int || privateKey is! String) {
          throw const FormatException();
        }
        return ImportedWallet(
          networkId: chainId,
          account: WalletAccount.fromPrivateKey(privateKey),
        );
      }).toList();
    } catch (_) {
      throw const WalletInputException('本机保存的批量私钥数据已损坏。');
    }
  }

  Future<BatchImportResult> importPrivateKeyWallets(
    List<WalletImportRow> rows,
  ) async {
    final existing = await loadImportedWallets();
    final networks = await loadNetworks();
    final seen = existing
        .map((wallet) => '${wallet.networkId}:${wallet.account.privateKeyHex}')
        .toSet();
    final imported = <ImportedWallet>[];
    final errors = <WalletImportError>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      try {
        final network = networkForValue(row.chain, networks: networks);
        if (network == null) throw const WalletInputException('不支持的链。');
        final account = WalletAccount.fromPrivateKey(row.privateKey);
        final key = '${network.id}:${account.privateKeyHex}';
        if (!seen.add(key)) {
          errors.add(WalletImportError(index + 1, '重复记录，已跳过。'));
          continue;
        }
        imported.add(ImportedWallet(networkId: network.id, account: account));
      } catch (error) {
        errors.add(WalletImportError(index + 1, error.toString()));
      }
    }
    if (imported.isNotEmpty) {
      final all = [...existing, ...imported];
      await _store.write(
        privateKeyWalletsKey,
        jsonEncode(
          all
              .map(
                (wallet) => {
                  'chainId': wallet.networkId,
                  'privateKey': wallet.account.privateKeyHex,
                },
              )
              .toList(),
        ),
      );
    }
    return BatchImportResult(imported: imported, errors: errors);
  }

  Future<void> deleteWallet() => _store.delete(mnemonicKey);

  Future<List<EvmNetwork>> loadNetworks() async {
    final raw = await _store.read(networkConfigsKey);
    final networks = {for (final n in supportedEvmNetworks) n.id: n};
    if (raw == null) return networks.values.toList();
    try {
      for (final value in jsonDecode(raw) as List) {
        final network = EvmNetwork.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        networks[network.id] = network;
      }
    } catch (_) {
      throw const WalletInputException('本机网络配置无法读取，请检查保存的数据。');
    }
    return networks.values.toList();
  }

  Future<void> saveNetwork(EvmNetwork network) async {
    network.validate();
    final networks = {
      for (final n in await loadNetworks()) n.id: n,
      network.id: network,
    };
    await _store.write(
      networkConfigsKey,
      jsonEncode(networks.values.map((n) => n.toJson()).toList()),
    );
  }

  Future<int?> loadSelectedNetworkId() async {
    final raw = await _store.read(selectedNetworkKey);
    return raw == null ? null : int.tryParse(raw);
  }

  Future<void> saveSelectedNetwork(EvmNetwork network) {
    return saveSelectedNetworks([network], current: network);
  }

  Future<List<int>> loadSelectedNetworkIds() async {
    final raw = await _store.read(selectedNetworksKey);
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.split(',').map(int.tryParse).whereType<int>().toSet().toList();
    }

    final legacyId = await loadSelectedNetworkId();
    return legacyId == null ? <int>[] : [legacyId];
  }

  Future<void> saveSelectedNetworks(
    List<EvmNetwork> networks, {
    EvmNetwork? current,
  }) async {
    final ids = networks.map((network) => network.id).toSet().toList();
    if (ids.isEmpty) {
      await clearSelectedNetworks();
      return;
    }
    await _store.write(selectedNetworksKey, ids.join(','));
    final selectedCurrent = current ?? networks.first;
    await _store.write(selectedNetworkKey, selectedCurrent.id.toString());
  }

  Future<void> clearSelectedNetworks() async {
    await _store.delete(selectedNetworksKey);
    await _store.delete(selectedNetworkKey);
  }

  Future<void> clearSelectedNetwork() => clearSelectedNetworks();

  static String _normalizeMnemonic(String mnemonic) =>
      mnemonic.trim().split(RegExp(r'\s+')).join(' ');
}

class WalletCreation {
  const WalletCreation({required this.mnemonic, required this.account});

  final String mnemonic;
  final WalletAccount account;
}

class WalletImportRow {
  const WalletImportRow({required this.chain, required this.privateKey});

  final String chain;
  final String privateKey;
}

class WalletImportError {
  const WalletImportError(this.row, this.message);

  final int row;
  final String message;
}

class BatchImportResult {
  const BatchImportResult({required this.imported, required this.errors});

  final List<ImportedWallet> imported;
  final List<WalletImportError> errors;
}

class ImportedWallet {
  const ImportedWallet({required this.networkId, required this.account});

  final int networkId;
  final WalletAccount account;
}

class WalletAccount {
  WalletAccount._({required this.credentials});

  factory WalletAccount.fromMnemonic(String mnemonic) {
    final seed = bip39.mnemonicToSeed(mnemonic);
    final node = BIP32.fromSeed(seed).derivePath(evmDerivationPath);
    final privateKey = node.privateKey;
    if (privateKey == null) {
      throw const WalletInputException('无法派生 EVM 私钥。');
    }

    return WalletAccount._(credentials: EthPrivateKey(_copyBytes(privateKey)));
  }

  factory WalletAccount.fromPrivateKey(String privateKey) {
    final normalized = privateKey.trim().replaceFirst(RegExp(r'^0x'), '');
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalized)) {
      throw const WalletInputException('私钥无效，应为 64 位十六进制字符串。');
    }
    try {
      return WalletAccount._(credentials: EthPrivateKey.fromHex(normalized));
    } catch (_) {
      throw const WalletInputException('私钥无效，无法创建账户。');
    }
  }

  final EthPrivateKey credentials;

  EthereumAddress get address => credentials.address;

  String get addressHex => address.hex;

  String get checksumAddress => address.hexEip55;

  String get privateKeyHex => credentials.privateKey
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  static Uint8List _copyBytes(Uint8List bytes) => Uint8List.fromList(bytes);
}

EvmNetwork? networkForValue(
  String value, {
  List<EvmNetwork> networks = supportedEvmNetworks,
}) {
  final normalized = value.trim().toLowerCase();
  final id = int.tryParse(normalized);
  for (final network in networks) {
    if (network.id == id ||
        network.name.toLowerCase() == normalized ||
        network.nativeSymbol.toLowerCase() == normalized) {
      return network;
    }
  }
  const aliases = <String, int>{
    'eth': 1,
    'ethereum': 1,
    'mainnet': 1,
    'sepolia': 11155111,
    'polygon': 137,
    'matic': 137,
    'amoy': 80002,
  };
  final aliasId = aliases[normalized];
  return networks.where((network) => network.id == aliasId).firstOrNull;
}

class EvmNetworkService {
  factory EvmNetworkService({
    required EvmNetwork network,
    Web3Client? client,
    http.Client? httpClient,
  }) {
    final effectiveHttpClient = httpClient ?? http.Client();
    return EvmNetworkService._(
      network: network,
      client: client ?? Web3Client(network.rpcUrl, effectiveHttpClient),
      httpClient: effectiveHttpClient,
      ownsHttpClient: httpClient == null,
    );
  }

  EvmNetworkService._({
    required this.network,
    required Web3Client client,
    required http.Client httpClient,
    required bool ownsHttpClient,
  }) : _client = client,
       _httpClient = httpClient,
       _ownsHttpClient = ownsHttpClient;

  final EvmNetwork network;
  final Web3Client _client;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  Future<void> checkConnection() async {
    final actual = await _client.getChainId();
    if (actual != BigInt.from(network.id)) {
      throw WalletInputException('RPC 链不匹配：预期 ${network.id}，实际 $actual。');
    }
  }

  Future<EtherAmount> getNativeBalance(WalletAccount account) async {
    await checkConnection();
    return _client.getBalance(account.address);
  }

  Future<String> sendNative({
    required WalletAccount account,
    required String recipient,
    required BigInt amountWei,
  }) async {
    final to = EthereumAddress.fromHex(recipient, enforceEip55: false);
    if (amountWei <= BigInt.zero) {
      throw const WalletInputException('金额必须大于 0。');
    }

    await checkConnection();
    return _client.sendTransaction(
      account.credentials,
      Transaction(to: to, value: EtherAmount.inWei(amountWei)),
      chainId: network.id,
    );
  }

  Future<void> dispose() async {
    await _client.dispose();
    if (_ownsHttpClient) _httpClient.close();
  }
}

class WalletInputException implements Exception {
  const WalletInputException(this.message);

  final String message;

  @override
  String toString() => message;
}

BigInt parseEtherToWei(String input) {
  final normalized = input.trim();
  final match = RegExp(r'^(\d+)(?:\.(\d{1,18}))?$').firstMatch(normalized);
  if (match == null) {
    throw const WalletInputException('请输入有效金额，最多支持 18 位小数。');
  }

  final whole = BigInt.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(18, '0');
  final fractionalWei = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);
  return whole * BigInt.from(10).pow(18) + fractionalWei;
}

String formatWeiAsEther(BigInt wei, {int decimals = 6}) {
  final safeDecimals = decimals.clamp(0, 18).toInt();
  final base = BigInt.from(10).pow(18);
  final whole = wei ~/ base;
  final remainder = wei.remainder(base).toString().padLeft(18, '0');
  final fraction = remainder
      .substring(0, safeDecimals)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}
