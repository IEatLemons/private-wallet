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

  final SecretStore _store;

  Future<bool> hasWallet() async => (await _store.read(mnemonicKey)) != null;

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

  Future<void> deleteWallet() => _store.delete(mnemonicKey);

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

  final EthPrivateKey credentials;

  EthereumAddress get address => credentials.address;

  String get addressHex => address.hex;

  String get checksumAddress => address.hexEip55;

  static Uint8List _copyBytes(Uint8List bytes) => Uint8List.fromList(bytes);
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

  Future<EtherAmount> getNativeBalance(WalletAccount account) {
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
