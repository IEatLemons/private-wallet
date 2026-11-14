import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'message_codes.dart';
export 'message_codes.dart';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bs58check/bs58check.dart' as base58;
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart'
    show
        AEADParameters,
        AESEngine,
        Argon2BytesGenerator,
        Argon2Parameters,
        GCMBlockCipher,
        KeyParameter;
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart' show bytesToHex, keccak256;
import 'package:web3dart/crypto.dart' as ec;
import 'package:web3dart/json_rpc.dart' show RPCError;

part 'wallet_book.dart';
part 'mac_wallet_book.dart';
part 'omnivault_import.dart';
part 'platform_address_pool.dart';
part 'tron.dart';
part 'tokens.dart';
part 'transfers.dart';

const evmDerivationPath = "m/44'/60'/0'/0/0";

enum NetworkProtocol { evm, tron }

const bnbSmartChainNetwork = EvmNetwork(
  id: 56,
  name: 'BNB Smart Chain',
  nativeSymbol: 'BNB',
  rpcUrl: 'https://bsc-dataseed.bnbchain.org',
  fallbackRpcUrls: ['https://bsc-rpc.publicnode.com'],
  explorerUrl: 'https://bscscan.com',
  isTestnet: false,
);

const tronMainnetNetwork = EvmNetwork(
  id: 728126428,
  name: 'TRON',
  nativeSymbol: 'TRX',
  rpcUrl: 'https://api.trongrid.io',
  fallbackRpcUrls: ['https://tron-rpc.publicnode.com'],
  explorerUrl: 'https://tronscan.org',
  isTestnet: false,
  protocol: NetworkProtocol.tron,
);

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

const supportedNetworks = <EvmNetwork>[
  ethereumMainnetNetwork,
  ethereumSepoliaNetwork,
  polygonMainnetNetwork,
  polygonAmoyNetwork,
  bnbSmartChainNetwork,
  tronMainnetNetwork,
];

// Kept for callers of the original EVM-only API. New code uses supportedNetworks.
const supportedEvmNetworks = [
  ethereumMainnetNetwork,
  ethereumSepoliaNetwork,
  polygonMainnetNetwork,
  polygonAmoyNetwork,
  bnbSmartChainNetwork,
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
    this.protocol = NetworkProtocol.evm,
  });

  final int id;
  final NetworkProtocol protocol;
  bool get isTron => protocol == NetworkProtocol.tron;
  int get nativeDecimals => isTron ? 6 : 18;
  String get identifierLabel => isTron ? 'TRON · HTTP API' : 'Chain ID $id';
  String get addressHint => isTron ? 'T…' : '0x…';
  BigInt parseAmount(String value) => parseNativeAmount(value, nativeDecimals);
  String formatAmount(BigInt value) =>
      formatNativeAmount(value, nativeDecimals);
  void validateAddress(String value) {
    if (isTron) {
      decodeTronAddress(value);
    } else {
      EthereumAddress.fromHex(value, enforceEip55: false);
    }
  }

  final String name;
  final String nativeSymbol;
  final String rpcUrl;
  final List<String> fallbackRpcUrls;
  List<String> get rpcUrls => List.unmodifiable({rpcUrl, ...fallbackRpcUrls});
  final String explorerUrl;
  final bool isTestnet;

  Uri? explorerAddress(String address) => _explorerLink('address', address);

  Uri? explorerTransaction(String hash) =>
      _explorerLink(isTron ? 'transaction' : 'tx', hash);

  Uri? _explorerLink(String section, String value) {
    final base = Uri.tryParse(explorerUrl);
    if (base == null ||
        !{'https', 'http'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        value.isEmpty) {
      return null;
    }
    final path = base.pathSegments.toList();
    while (path.isNotEmpty && path.last.isEmpty) {
      path.removeLast();
    }
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: isTron ? ['', ...path, ''] : [...path, section, value],
      fragment: isTron ? '/$section/${Uri.encodeComponent(value)}' : null,
    );
  }

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
    protocol: protocol,
  );

  void validate() {
    if ((isTron && (id != tronMainnetNetwork.id || isTestnet)) ||
        (!isTron && id == tronMainnetNetwork.id)) {
      throw const WalletInputException(
        MessageCode.msgTronMainnetIdentifierDoesNotMatchTheProtocol,
      );
    }
    if (id <= 0 || id > 9007199254740991) {
      throw const WalletInputException(
        MessageCode.msgChainIdMustBeAValidPositiveInteger,
      );
    }
    if (name.trim().isEmpty || nativeSymbol.trim().isEmpty) {
      throw const WalletInputException(
        MessageCode.msgEnterTheNetworkNameAndNativeCurrencySymbol,
      );
    }
    for (final url in [...rpcUrls, if (explorerUrl.isNotEmpty) explorerUrl]) {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !uri.hasAuthority ||
          uri.host.isEmpty ||
          !['https', 'http'].contains(uri.scheme)) {
        throw const WalletInputException(
          MessageCode.msgEnterAValidHttpHttpsUrl,
        );
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
    'protocol': protocol.name,
  };

  factory EvmNetwork.fromJson(Map<String, dynamic> json) {
    final urls = json['rpcUrls'] == null
        ? [json['rpcUrl'] as String]
        : List<String>.from(json['rpcUrls'] as List);
    if (urls.isEmpty) {
      throw const WalletInputException(
        MessageCode.msgConfigureAtLeastOneRpcUrl,
      );
    }
    final network = EvmNetwork(
      id: json['id'] as int,
      name: json['name'] as String,
      nativeSymbol: json['nativeSymbol'] as String,
      rpcUrl: urls.first,
      fallbackRpcUrls: List.unmodifiable(urls.skip(1)),
      explorerUrl: json['explorerUrl'] as String? ?? '',
      isTestnet: json['isTestnet'] as bool,
      protocol: NetworkProtocol.values.byName(
        json['protocol'] as String? ?? 'evm',
      ),
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
          MessageCode.msgCannotAccessKeychainQuitRebuildAndRunThe,
        );
      }
      throw const WalletInputException(
        MessageCode.msgCannotAccessSecureDeviceStorageCheckThatKeychain,
      );
    }
  }
}

class WalletVault {
  WalletVault({SecretStore? store, bool? useMacWalletDatabase})
    : _store = store ?? FlutterSecretStore(),
      _database = (useMacWalletDatabase ?? (store == null && Platform.isMacOS))
          ? const MethodChannel('asterkeel/wallet_database')
          : null;

  static const walletBookKey = 'stone_wallet.v2.wallet_book';
  static const assetIndexerConfigsKey = 'stone_wallet.v1.asset_indexer_configs';
  Future<String?> readAssetIndexerConfigs() =>
      _store.read(assetIndexerConfigsKey);
  Future<void> writeAssetIndexerConfigs(String value) =>
      _store.write(assetIndexerConfigsKey, value);
  static const appPreferencesKey = 'stone_wallet.v1.app_preferences';
  Future<String?> readAppPreferences() => _store.read(appPreferencesKey);
  Future<void> writeAppPreferences(String value) =>
      _store.write(appPreferencesKey, value);
  static const mnemonicKey = 'stone_wallet.v1.mnemonic';
  static const selectedNetworkKey = 'stone_wallet.v1.selected_network';
  static const selectedNetworksKey = 'stone_wallet.v1.selected_networks';
  static const privateKeyWalletsKey = 'stone_wallet.v1.private_key_wallets';
  static const networkConfigsKey = 'stone_wallet.v1.network_configs';

  final SecretStore _store;
  final MethodChannel? _database;
  Future<void>? _databaseReady;
  bool get supportsOmniVaultImport => _database != null;

  Future<void> _mutationTail = Future.value();

  Future<bool> hasWallet() async => (await loadWalletSummary()).groupCount > 0;

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

  Future<WalletAccount> saveRecoveryPhrase(
    String mnemonic, {
    String? name,
    String? accountName,
    String Function(int)? nameForWallet,
  }) async => (await addMnemonicWallet(
    mnemonic,
    name: name,
    accountName: accountName,
    nameForWallet: nameForWallet,
  )).selected!.account;

  Future<WalletAccount> importWallet(
    String mnemonic, {
    String? name,
    String? accountName,
    String Function(int)? nameForWallet,
  }) => saveRecoveryPhrase(
    mnemonic,
    name: name,
    accountName: accountName,
    nameForWallet: nameForWallet,
  );

  /// Compatibility view of the selected mnemonic account (or first mnemonic
  /// wallet when a private-key account is selected). It never replaces a root.
  Future<WalletAccount?> loadWallet() async {
    if (_database != null) {
      final selected = (await loadWalletSummary()).selected;
      if (selected?.kind == WalletKind.mnemonic) return selected!.account;
      final row = await _macCall<Map<Object?, Object?>>('firstMnemonic');
      return row == null ? null : _macGroup(row).accounts.first.account;
    }
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
    String Function(int)? nameForWallet,
    String? accountName,
  }) async {
    final result = await importPrivateKeyRows(
      [WalletImportRow(chain: networkId.toString(), privateKey: privateKey)],
      selectImported: true,
      nameForWallet: nameForWallet,
      accountName: accountName,
    );
    if (result.errors.isNotEmpty) {
      throw WalletInputException.fromMessage(result.errors.first.message);
    }
    return result.imported.single;
  }

  Future<BatchImportResult> importPrivateKeyWallets(
    List<WalletImportRow> rows, {
    String Function(int)? nameForWallet,
    String? accountName,
  }) => importPrivateKeyRows(
    rows,
    nameForWallet: nameForWallet,
    accountName: accountName,
  );

  Future<List<EvmNetwork>> loadNetworks() async {
    final raw = await _store.read(networkConfigsKey);
    final networks = {for (final n in supportedNetworks) n.id: n};
    if (raw == null) return networks.values.toList();
    try {
      for (final value in jsonDecode(raw) as List) {
        final json = Map<String, dynamic>.from(value as Map);
        var network = EvmNetwork.fromJson(json);
        // Upgrade old single-URL profiles while preserving a custom first URL.
        // An explicitly saved new list is always respected, including one URL.
        if (!json.containsKey('rpcUrls')) {
          final defaults = supportedNetworks
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
      throw const WalletInputException(
        MessageCode.msgCannotReadSavedNetworkSettingsCheckTheStored,
      );
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
  final WalletMessage message;
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
  WalletAccount._({required this.credentials, EthPrivateKey? tronCredentials})
    : _tronCredentials = tronCredentials ?? credentials;

  factory WalletAccount.fromMnemonic(String mnemonic, {int accountIndex = 0}) {
    if (accountIndex < 0 || accountIndex >= 0x80000000) {
      throw const WalletInputException(MessageCode.msgAccountIndexIsOutOfRange);
    }
    if (!bip39.validateMnemonic(mnemonic)) {
      throw const WalletInputException(
        MessageCode.msgInvalidRecoveryPhraseCheckTheWordsAndTheir,
      );
    }
    final seed = bip39.mnemonicToSeed(mnemonic);
    final node = BIP32
        .fromSeed(seed)
        .derivePath(evmAccountDerivationPath(accountIndex));
    final privateKey = node.privateKey;
    if (privateKey == null) {
      throw const WalletInputException(
        MessageCode.msgCannotDeriveTheEvmPrivateKey,
      );
    }

    final tronKey = BIP32
        .fromSeed(seed)
        .derivePath(tronAccountDerivationPath(accountIndex))
        .privateKey!;
    return WalletAccount._(
      credentials: EthPrivateKey(_copyBytes(privateKey)),
      tronCredentials: EthPrivateKey(_copyBytes(tronKey)),
    );
  }

  factory WalletAccount.fromPrivateKey(String privateKey) {
    final normalized = privateKey.trim().replaceFirst(
      RegExp(r'^0x', caseSensitive: false),
      '',
    );
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(normalized)) {
      throw const WalletInputException(
        MessageCode.msgInvalidPrivateKeyEnterHexadecimalCharacters,
      );
    }
    final value = BigInt.parse(normalized, radix: 16);
    final order = BigInt.parse(
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
      radix: 16,
    );
    if (value <= BigInt.zero || value >= order) {
      throw const WalletInputException(
        MessageCode.msgPrivateKeyValueIsOutOfRange,
      );
    }
    try {
      return WalletAccount._(credentials: EthPrivateKey.fromHex(normalized));
    } catch (_) {
      throw const WalletInputException(
        MessageCode.msgInvalidPrivateKeyCannotCreateAnAccount,
      );
    }
  }

  final EthPrivateKey credentials;
  final EthPrivateKey _tronCredentials;

  String get tronAddress => base58.encode(
    Uint8List.fromList([0x41, ..._tronCredentials.address.addressBytes]),
  );
  String addressFor(EvmNetwork? network) =>
      network?.isTron == true ? tronAddress : checksumAddress;

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
  List<EvmNetwork> networks = supportedNetworks,
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
    'bsc': 56,
    'binance': 56,
    '币安': 56,
    'bnb': 56,
    'tron': 728126428,
    'trx': 728126428,
    '波场': 728126428,
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
    if (network.isTron) {
      return TronNetworkService._(
        network: network,
        httpClient: effectiveHttpClient,
        ownsHttpClient: httpClient == null,
        endpointTimeout: endpointTimeout,
      );
    }
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
      throw WalletInputException(
        MessageCode.msgRpcNetworkMismatchExpectedReceived,
        arguments: [network.id, actual],
      );
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
        if (_disposed || error is _TransferRejected) rethrow;
        lastError = error;
      }
    }
    if (lastError is WalletInputException) throw lastError;
    throw WalletInputException(
      MessageCode.msgAllRpcEndpointsAreUnavailableTryAgainLater,
      arguments: [_clients.length],
    );
  }

  Future<void> checkConnection() => _withFailover((_) async {});

  Future<EtherAmount> getNativeBalance(WalletAccount account) =>
      getNativeBalanceForAddress(account.addressFor(network));

  Future<EtherAmount> getNativeBalanceForAddress(String address) {
    final owner = EthereumAddress.fromHex(address, enforceEip55: false);
    return _withFailover((client) => client.getBalance(owner));
  }

  Future<String> readTokenContract(
    String contract,
    String signature,
    String parameter,
  ) => _withFailover((client) async {
    final result = await client.callRaw(
      contract: EthereumAddress.fromHex(contract, enforceEip55: false),
      data: Uint8List.fromList([
        ...keccak256(Uint8List.fromList(utf8.encode(signature))).take(4),
        ...ec.hexToBytes(parameter),
      ]),
    );
    validateTokenResponse(signature, result);
    return result;
  });

  Future<BigInt> getTokenBalance(
    WalletAccount account,
    TokenDefinition token,
  ) => getTokenBalanceForAddress(account.addressFor(network), token);

  Future<BigInt> getTokenBalanceForAddress(
    String address,
    TokenDefinition token,
  ) async {
    if (token.networkId != network.id) {
      throw const WalletInputException(
        MessageCode.msgTheTokenAndNetworkDoNotMatch,
      );
    }
    token.validate(network);
    final owner = network.isTron
        ? bytesToHex(decodeTronAddress(address).sublist(1))
        : EthereumAddress.fromHex(address, enforceEip55: false).hexNo0x;
    final result = await readTokenContract(
      token.contract,
      'balanceOf(address)',
      owner.padLeft(64, '0'),
    );
    return decodeTokenUint(result);
  }

  Future<TokenDefinition> inspectToken(String contract) async {
    network.validateAddress(contract);
    final decimals = decodeTokenUint(
      await readTokenContract(contract, 'decimals()', ''),
    ).toInt();
    if (decimals < 0 || decimals > 36) {
      throw const WalletInputException(
        MessageCode.msgOnlyTokensWithDecimalsAreSupported,
      );
    }
    final symbol = decodeTokenSymbol(
      await readTokenContract(contract, 'symbol()', ''),
    );
    final token = TokenDefinition(
      networkId: network.id,
      contract: contract,
      symbol: symbol,
      decimals: decimals,
      name: symbol,
    );
    token.validate(network);
    return canonicalToken(token);
  }

  Future<String> sendNative({
    required WalletAccount account,
    required String recipient,
    required BigInt amountWei,
  }) async {
    final to = EthereumAddress.fromHex(recipient, enforceEip55: false);
    if (amountWei <= BigInt.zero) {
      throw const WalletInputException(
        MessageCode.msgAmountMustBeGreaterThanZero,
      );
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
    return _broadcastEvm(signed);
  }

  Future<PreparedWalletTransfer> prepareTransfer({
    required WalletAccount account,
    required String recipient,
    required BigInt amount,
    TokenDefinition? token,
  }) async {
    final to = _evmRecipient(recipient);
    _validateTransfer(network, token, amount);
    final owner = account.address;
    final contract = token == null
        ? null
        : EthereumAddress.fromHex(token.contract);
    final data = token == null ? null : _transferData(to.addressBytes, amount);
    final value = EtherAmount.inWei(token == null ? amount : BigInt.zero);
    final target = contract ?? to;

    final fee = await _withFailover((client) async {
      if (token != null) {
        final decimals = await client.callRaw(
          contract: contract!,
          data: _tokenCall('decimals()'),
        );
        _requireTokenDecimals(token, decimals);
        final balance = await client.callRaw(
          contract: contract,
          data: _tokenCall(
            'balanceOf(address)',
            _addressWord(owner.addressBytes),
          ),
        );
        _requireBalance(decodeTokenUint(balance), amount);
        final result = await _simulateEvm(
          () => client.callRaw(sender: owner, contract: contract, data: data!),
        );
        _requireTransferSuccess(result);
      }

      final available = await client.getBalance(
        owner,
        atBlock: const BlockNum.pending(),
      );
      _requireBalance(available.getInWei, value.getInWei);
      final gasPrice = await client.getGasPrice();
      final gas = await _simulateEvm(
        () => client.estimateGas(
          sender: owner,
          to: target,
          value: value,
          data: data,
          gasPrice: gasPrice,
        ),
      );
      if (gas <= BigInt.zero ||
          gas > BigInt.from(9007199254740991) ||
          gasPrice.getInWei <= BigInt.zero) {
        throw const WalletInputException(MessageCode.transferFeeUnavailable);
      }
      final fee = gas * gasPrice.getInWei;
      _requireFeeBalance(available.getInWei, value.getInWei, fee);
      return (gas.toInt(), gasPrice, fee);
    });

    return PreparedWalletTransfer._(
      fee: fee.$3,
      send: () async {
        final signed = await _withFailover((client) async {
          final available = await client.getBalance(
            owner,
            atBlock: const BlockNum.pending(),
          );
          _requireFeeBalance(available.getInWei, value.getInWei, fee.$3);
          final nonce = await client.getTransactionCount(
            owner,
            atBlock: const BlockNum.pending(),
          );
          return client.signTransaction(
            account.credentials,
            Transaction(
              from: owner,
              to: target,
              value: value,
              data: data,
              maxGas: fee.$1,
              gasPrice: fee.$2,
              nonce: nonce,
            ),
            chainId: network.id,
          );
        });
        return _broadcastEvm(signed);
      },
    );
  }

  Future<String> _broadcastEvm(Uint8List signed) async {
    final hash = bytesToHex(keccak256(signed), include0x: true);
    var attempted = false;
    try {
      return await _withFailover((client) async {
        attempted = true;
        try {
          final result = await client.sendRawTransaction(signed);
          if (result.toLowerCase() != hash.toLowerCase()) {
            throw const WalletInputException(
              MessageCode.msgTheRpcReturnedADifferentTransactionHash,
            );
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
    : super(MessageCode.msgBroadcastStatusIsUncertainCheckTheTransactionHash);
  final String transactionHash;
}

class WalletInputException implements Exception {
  const WalletInputException(this.code, {this.arguments = const []});
  factory WalletInputException.fromMessage(WalletMessage message) =>
      WalletInputException(message.code, arguments: message.arguments);
  final MessageCode code;
  final List<Object> arguments;
  WalletMessage get message => WalletMessage(code, arguments);
  @override
  String toString() => code.name;
}

BigInt parseEtherToWei(String input) => parseNativeAmount(input, 18);

BigInt parseNativeAmount(String input, int decimals) {
  final normalized = input.trim();
  final fractionPattern = decimals == 0 ? '' : '(?:\\.(\\d{1,$decimals}))?';
  final match = RegExp('^(\\d+)$fractionPattern\$').firstMatch(normalized);
  if (match == null) {
    throw WalletInputException(
      MessageCode.msgEnterAValidAmountWithAtMostDecimal,
      arguments: [decimals],
    );
  }

  final whole = BigInt.parse(match.group(1)!);
  final fraction = (decimals == 0 ? '' : match.group(2) ?? '').padRight(
    decimals,
    '0',
  );
  final fractionalWei = fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction);
  return whole * BigInt.from(10).pow(decimals) + fractionalWei;
}

String formatWeiAsEther(BigInt wei, {int decimals = 6}) {
  return formatNativeAmount(wei, 18, displayDecimals: decimals);
}

String formatNativeAmount(
  BigInt wei,
  int nativeDecimals, {
  int displayDecimals = 6,
}) {
  final safeDecimals = displayDecimals.clamp(0, nativeDecimals).toInt();
  final base = BigInt.from(10).pow(nativeDecimals);
  final whole = wei ~/ base;
  final remainder = wei.remainder(base).toString().padLeft(nativeDecimals, '0');
  final fraction = remainder
      .substring(0, safeDecimals)
      .replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? whole.toString() : '$whole.$fraction';
}
