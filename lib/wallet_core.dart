import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart' show bytesToHex, keccak256;
import 'package:web3dart/json_rpc.dart' show RPCError;

part 'wallet_book.dart';

const evmDerivationPath = "m/44'/60'/0'/0/0";

const ethereumMainnetNetwork = EvmNetwork(
  id: 1,
  name: 'Ethereum',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://eth.drpc.org',
  fallbackRpcUrls: ['https://ethereum-rpc.publicnode.com'],
  explorerUrl: 'https://etherscan.io',
  isTestnet: false,
);

const ethereumSepoliaNetwork = EvmNetwork(
  id: 11155111,
  name: 'Ethereum Sepolia',
  nativeSymbol: 'ETH',
  rpcUrl: 'https://ethereum-sepolia-rpc.publicnode.com',
  fallbackRpcUrls: ['https://rpc.sepolia.ethpandaops.io'],
  explorerUrl: 'https://sepolia.etherscan.io',
  isTestnet: true,
);

const polygonMainnetNetwork = EvmNetwork(
  id: 137,
  name: 'Polygon',
  nativeSymbol: 'POL',
  rpcUrl: 'https://polygon.drpc.org',
  fallbackRpcUrls: ['https://polygon-bor-rpc.publicnode.com'],
  explorerUrl: 'https://polygonscan.com',
  isTestnet: false,
);

const polygonAmoyNetwork = EvmNetwork(
  id: 80002,
  name: 'Polygon Amoy',
  nativeSymbol: 'POL',
  rpcUrl: 'https://polygon-amoy.drpc.org',
  fallbackRpcUrls: ['https://polygon-amoy-bor-rpc.publicnode.com'],
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
    this.fallbackRpcUrls = const [],
  });

  final int id;
  final String name;
  final String nativeSymbol;
  final String rpcUrl;
  final List<String> fallbackRpcUrls;
  List<String> get rpcUrls => List.unmodifiable({rpcUrl, ...fallbackRpcUrls});
  final String explorerUrl;
  final bool isTestnet;

  EvmNetwork copyWith({
    String? name,
    String? nativeSymbol,
    String? rpcUrl,
    List<String>? rpcUrls,
    String? explorerUrl,
    bool? isTestnet,
  }) => EvmNetwork(
    id: id,
    name: name ?? this.name,
    nativeSymbol: nativeSymbol ?? this.nativeSymbol,
    rpcUrl: rpcUrls != null ? rpcUrls.first : rpcUrl ?? this.rpcUrl,
    fallbackRpcUrls: rpcUrls != null
        ? List.unmodifiable(rpcUrls.skip(1))
        : rpcUrl != null
        ? const []
        : fallbackRpcUrls,
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
    for (final url in [...rpcUrls, if (explorerUrl.isNotEmpty) explorerUrl]) {
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
    'rpcUrls': rpcUrls,
    'explorerUrl': explorerUrl,
    'isTestnet': isTestnet,
  };

  factory EvmNetwork.fromJson(Map<String, dynamic> json) {
    final urls = json['rpcUrls'] == null
        ? [json['rpcUrl'] as String]
        : List<String>.from(json['rpcUrls'] as List);
    if (urls.isEmpty) throw const WalletInputException('请至少配置一个 RPC 地址。');
    final network = EvmNetwork(
      id: json['id'] as int,
      name: json['name'] as String,
      nativeSymbol: json['nativeSymbol'] as String,
      rpcUrl: urls.first,
      fallbackRpcUrls: List.unmodifiable(urls.skip(1)),
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
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Standalone macOS builds use ad-hoc signing without a provisioning
            // profile. Use the local login Keychain, which supports this signing
            // mode, rather than the entitlement-gated Data Protection Keychain.
            // Other platforms continue to use their default secure storage.
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _access(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String value) =>
      _access(() => _storage.write(key: key, value: value));

  @override
  Future<void> delete(String key) => _access(() async {
    // The Darwin plugin also probes synchronizable items when deleting. With
    // ad-hoc signing that probe can return -34018 for an absent key; skip the
    // unnecessary delete rather than hiding a real permission failure.
    if (await _storage.read(key: key) == null) return;
    await _storage.delete(key: key);
  });

  Future<T> _access<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      if (error.code == '-34018' || error.details?.toString() == '-34018') {
        throw const WalletInputException(
          '无法访问系统钥匙串（-34018）。请退出应用并重新编译运行；热重载无法更新原生签名权限。',
        );
      }
      throw const WalletInputException('无法访问本机安全存储，请检查系统钥匙串是否已解锁及访问是否被允许。');
    }
  }
}

class WalletVault {
  WalletVault({SecretStore? store}) : _store = store ?? FlutterSecretStore();

  static const walletBookKey = 'stone_wallet.v2.wallet_book';
  static const mnemonicKey = 'stone_wallet.v1.mnemonic';
  static const selectedNetworkKey = 'stone_wallet.v1.selected_network';
  static const selectedNetworksKey = 'stone_wallet.v1.selected_networks';
  static const privateKeyWalletsKey = 'stone_wallet.v1.private_key_wallets';
  static const networkConfigsKey = 'stone_wallet.v1.network_configs';

  final SecretStore _store;
  Future<void> _mutationTail = Future.value();

  Future<bool> hasWallet() async => (await loadPortfolio()).groups.isNotEmpty;

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

  Future<WalletAccount> saveRecoveryPhrase(String mnemonic) async =>
      (await addMnemonicWallet(mnemonic)).selected!.account;

  Future<WalletAccount> importWallet(String mnemonic) =>
      saveRecoveryPhrase(mnemonic);

  /// Compatibility view of the selected mnemonic account (or first mnemonic
  /// wallet when a private-key account is selected). It never replaces a root.
  Future<WalletAccount?> loadWallet() async {
    final portfolio = await loadPortfolio();
    final group = portfolio.groups
        .where((g) => g.kind == WalletKind.mnemonic)
        .firstOrNull;
    if (group == null) return null;
    return portfolio.selected?.kind == WalletKind.mnemonic
        ? portfolio.selected!.account
        : group.accounts.first.account;
  }

  Future<List<ImportedWallet>> loadImportedWallets() async => [
    for (final group in (await loadPortfolio()).groups)
      if (group.kind == WalletKind.privateKey)
        ImportedWallet(
          networkId: group.preferredNetworkId!,
          account: group.accounts.first.account,
        ),
  ];

  Future<ImportedWallet> importPrivateKeyWallet({
    required String privateKey,
    required int networkId,
  }) async {
    final result = await importPrivateKeyRows([
      WalletImportRow(chain: networkId.toString(), privateKey: privateKey),
    ], selectImported: true);
    if (result.errors.isNotEmpty) {
      throw WalletInputException(result.errors.first.message);
    }
    return result.imported.single;
  }

  Future<BatchImportResult> importPrivateKeyWallets(
    List<WalletImportRow> rows,
  ) => importPrivateKeyRows(rows);

  Future<List<EvmNetwork>> loadNetworks() async {
    final raw = await _store.read(networkConfigsKey);
    final networks = {for (final n in supportedEvmNetworks) n.id: n};
    if (raw == null) return networks.values.toList();
    try {
      for (final value in jsonDecode(raw) as List) {
        final json = Map<String, dynamic>.from(value as Map);
        var network = EvmNetwork.fromJson(json);
        // Upgrade old single-URL profiles while preserving a custom first URL.
        // An explicitly saved new list is always respected, including one URL.
        if (!json.containsKey('rpcUrls')) {
          final defaults = supportedEvmNetworks
              .where((n) => n.id == network.id)
              .firstOrNull;
          if (defaults != null) {
            const retired = {
              'https://cloudflare-eth.com',
              'https://polygon-rpc.com',
              'https://rpc-amoy.polygon.technology',
            };
            network = network.copyWith(
              rpcUrls: {
                if (!retired.contains(network.rpcUrl)) network.rpcUrl,
                ...defaults.rpcUrls,
              }.toList(),
            );
          }
        }
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

  factory WalletAccount.fromMnemonic(String mnemonic, {int accountIndex = 0}) {
    if (accountIndex < 0 || accountIndex >= 0x80000000) {
      throw const WalletInputException('账户序号超出有效范围。');
    }
    if (!bip39.validateMnemonic(mnemonic)) {
      throw const WalletInputException('助记词无效，请检查单词和顺序。');
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    final node = BIP32
        .fromSeed(seed)
        .derivePath(evmAccountDerivationPath(accountIndex));
    final privateKey = node.privateKey;
    if (privateKey == null) {
      throw const WalletInputException('无法派生 EVM 私钥。');
    }

    return WalletAccount._(credentials: EthPrivateKey(_copyBytes(privateKey)));
  }

  factory WalletAccount.fromPrivateKey(String privateKey) {
    final normalized = privateKey.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalized)) {
      throw const WalletInputException('私钥无效，应为 64 位十六进制字符串。');
    }
    final value = BigInt.parse(normalized, radix: 16);
    final order = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );
    if (value <= BigInt.zero || value >= order) {
      throw const WalletInputException('私钥无效，数值超出有效范围。');
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
    Duration endpointTimeout = const Duration(seconds: 5),
  }) {
    network.validate();
    final effectiveHttpClient = httpClient ?? http.Client();
    final checkedHttp = _RpcHttpClient(effectiveHttpClient);
    return EvmNetworkService._(
      network: network,
      clients: client != null
          ? [client]
          : [for (final url in network.rpcUrls) Web3Client(url, checkedHttp)],
      httpClient: effectiveHttpClient,
      ownsHttpClient: httpClient == null,
      endpointTimeout: endpointTimeout,
    );
  }

  EvmNetworkService._({
    required this.network,
    required List<Web3Client> clients,
    required http.Client httpClient,
    required bool ownsHttpClient,
    required this.endpointTimeout,
  }) : _clients = clients,
       _httpClient = httpClient,
       _ownsHttpClient = ownsHttpClient;

  final EvmNetwork network;
  final List<Web3Client> _clients;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration endpointTimeout;
  int _activeIndex = 0;
  bool _disposed = false;

  String get activeRpcUrl => network.rpcUrls[_activeIndex];

  Future<void> _checkChain(Web3Client client) async {
    final actual = await client.getChainId().timeout(endpointTimeout);
    if (actual != BigInt.from(network.id)) {
      throw WalletInputException('RPC 链不匹配：预期 ${network.id}，实际 $actual。');
    }
  }

  Future<T> _withFailover<T>(Future<T> Function(Web3Client) operation) async {
    if (_disposed) throw StateError('RPC service disposed');
    final first = _activeIndex;
    Object? lastError;
    for (var offset = 0; offset < _clients.length; offset++) {
      final index = (first + offset) % _clients.length;
      try {
        final client = _clients[index];
        // Each stage has its own timeout. A late chain-check result must never
        // start an operation (especially a broadcast) after we have moved on.
        await _checkChain(client);
        if (_disposed) throw StateError('RPC service disposed');
        final result = await operation(client).timeout(endpointTimeout);
        if (_disposed) throw StateError('RPC service disposed');
        _activeIndex = index;
        return result;
      } catch (error) {
        if (_disposed) rethrow;
        lastError = error;
      }
    }
    if (lastError is WalletInputException) throw lastError;
    throw WalletInputException(
      '全部 ${_clients.length} 个 RPC 节点均不可用，请稍后重试或编辑节点列表。',
    );
  }

  Future<void> checkConnection() => _withFailover((_) async {});

  Future<EtherAmount> getNativeBalance(WalletAccount account) =>
      _withFailover((client) => client.getBalance(account.address));

  Future<String> sendNative({
    required WalletAccount account,
    required String recipient,
    required BigInt amountWei,
  }) async {
    final to = EthereumAddress.fromHex(recipient, enforceEip55: false);
    if (amountWei <= BigInt.zero) {
      throw const WalletInputException('金额必须大于 0。');
    }
    // Failover during preparation never broadcasts. Once signed, every retry
    // reuses these exact bytes (same nonce and hash), never a new transaction.
    final signed = await _withFailover(
      (client) => client.signTransaction(
        account.credentials,
        Transaction(to: to, value: EtherAmount.inWei(amountWei)),
        chainId: network.id,
      ),
    );
    final hash = bytesToHex(keccak256(signed), include0x: true);
    var attempted = false;
    try {
      return await _withFailover((client) async {
        attempted = true;
        try {
          final result = await client.sendRawTransaction(signed);
          if (result.toLowerCase() != hash.toLowerCase()) {
            throw const WalletInputException('RPC 返回的交易哈希不匹配。');
          }
          return hash;
        } on RPCError catch (error) {
          final message = error.message.toLowerCase();
          if (RegExp(
            r'^(already known|known transaction|already imported)(?:$|[\s:])',
          ).hasMatch(message)) {
            return hash;
          }
          rethrow;
        }
      });
    } catch (_) {
      if (attempted) throw RpcBroadcastException(hash);
      rethrow;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait(_clients.map((client) => client.dispose()));
    if (_ownsHttpClient) _httpClient.close();
  }
}

class _RpcHttpClient extends http.BaseClient {
  _RpcHttpClient(this.inner);
  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await inner.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.drain<void>();
      throw http.ClientException('RPC HTTP ${response.statusCode}');
    }
    return response;
  }
}

class RpcBroadcastException extends WalletInputException {
  RpcBroadcastException(this.transactionHash)
    : super('无法确认交易是否已广播。请先按交易哈希查询确认状态，避免再次发起转账。');
  final String transactionHash;
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
