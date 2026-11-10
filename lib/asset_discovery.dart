import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'wallet_core.dart';

enum IndexerProvider { moralis, alchemy, trongrid }

class IndexerDescriptor {
  const IndexerDescriptor(
    this.provider,
    this.name,
    this.networkIds,
    this.signup,
    this.docs,
    this.plans,
    this.guide,
  );
  final IndexerProvider provider;
  final String name, signup, docs, plans;
  final List<int> networkIds;
  final MessageCode guide;
}

const indexerDescriptors = [
  IndexerDescriptor(
    IndexerProvider.moralis,
    'Moralis',
    [1, 137, 56],
    'https://admin.moralis.com/',
    'https://docs.moralis.com/data-api/evm/wallet/token-balances',
    'https://moralis.com/pricing/',
    MessageCode.discoveryMoralisGuide,
  ),
  IndexerDescriptor(
    IndexerProvider.alchemy,
    'Alchemy',
    [1, 137],
    'https://dashboard.alchemy.com/',
    'https://www.alchemy.com/docs/reference/token-api-quickstart',
    'https://www.alchemy.com/pricing',
    MessageCode.discoveryAlchemyGuide,
  ),
  IndexerDescriptor(
    IndexerProvider.trongrid,
    'TronGrid',
    [728126428],
    'https://www.trongrid.io/',
    'https://developers.tron.network/reference/get-trc20-token-balances-by-address',
    'https://www.trongrid.io/',
    MessageCode.discoveryTronGridGuide,
  ),
];
IndexerDescriptor descriptorFor(IndexerProvider provider) =>
    indexerDescriptors.firstWhere((d) => d.provider == provider);

class IndexerConfig {
  IndexerConfig({
    required this.provider,
    required this.apiKey,
    required Set<int> networkIds,
    this.enabled = true,
  }) : networkIds = Set.unmodifiable(networkIds);
  final IndexerProvider provider;
  final String apiKey;
  final Set<int> networkIds;
  final bool enabled;
  IndexerConfig copyWith({Set<int>? networkIds, bool? enabled}) =>
      IndexerConfig(
        provider: provider,
        apiKey: apiKey,
        networkIds: networkIds ?? this.networkIds,
        enabled: enabled ?? this.enabled,
      );
  Map<String, Object> toJson() => {
    'provider': provider.name,
    'apiKey': apiKey,
    'networks': networkIds.toList(),
    'enabled': enabled,
  };
  factory IndexerConfig.fromJson(Map json) {
    final provider = IndexerProvider.values.firstWhere(
      (p) => p.name == json['provider'],
    );
    final key = json['apiKey'] as String;
    if (key.trim().isEmpty ||
        key.length > 1024 ||
        RegExp(r'[\s\x00-\x1f]').hasMatch(key)) {
      throw const FormatException();
    }
    final ids = (json['networks'] as List).cast<int>().toSet();
    if (!ids.every(descriptorFor(provider).networkIds.contains)) {
      throw const FormatException();
    }
    return IndexerConfig(
      provider: provider,
      apiKey: key,
      networkIds: ids,
      enabled: json['enabled'] as bool,
    );
  }
}

class IndexerSettings extends ChangeNotifier {
  IndexerSettings({required this.read, required this.write});
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  List<IndexerConfig> configs = [];
  WalletMessage? error;
  bool loaded = false, busy = false, _disposed = false;
  Future<void> _tail = Future.value();
  Future<void> load() async {
    try {
      final raw = await read();
      if (raw != null) {
        final json = jsonDecode(raw) as Map;
        if (json['version'] != 1) throw const FormatException();
        final next = (json['services'] as List)
            .map((c) => IndexerConfig.fromJson(c as Map))
            .toList();
        final assigned = <int>{}, providers = <IndexerProvider>{};
        for (final c in next) {
          if (!providers.add(c.provider)) throw const FormatException();
          if (c.enabled) {
            for (final id in c.networkIds) {
              if (!assigned.add(id)) throw const FormatException();
            }
          }
        }
        configs = next;
      }
    } catch (_) {
      error = const WalletMessage(MessageCode.discoverySettingsUnreadable);
    }
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  IndexerConfig? forNetwork(int id) =>
      configs.where((c) => c.enabled && c.networkIds.contains(id)).firstOrNull;
  IndexerConfig? forProvider(IndexerProvider provider) =>
      configs.where((c) => c.provider == provider).firstOrNull;
  Future<void> save(IndexerConfig config) => _mutate(
    () => [
      for (final old in configs)
        if (old.provider != config.provider)
          config.enabled
              ? old.copyWith(
                  networkIds: old.networkIds.difference(config.networkIds),
                )
              : old,
      config,
    ],
  );
  Future<void> remove(IndexerProvider provider) =>
      _mutate(() => configs.where((c) => c.provider != provider).toList());
  Future<void> _mutate(List<IndexerConfig> Function() change) {
    final operation = _tail.then((_) async {
      if (_disposed) return;
      busy = true;
      notifyListeners();
      try {
        final next = change();
        await write(
          jsonEncode({
            'version': 1,
            'services': next.map((c) => c.toJson()).toList(),
          }),
        );
        if (!_disposed) {
          configs = next;
          error = null;
        }
      } catch (_) {
        if (!_disposed) {
          error = const WalletMessage(MessageCode.discoverySaveFailed);
        }
        throw const WalletInputException(MessageCode.discoverySaveFailed);
      } finally {
        if (!_disposed) {
          busy = false;
          notifyListeners();
        }
      }
    });
    _tail = operation.catchError((_) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DiscoveredToken {
  const DiscoveredToken(this.token, this.units, {this.spam = false});
  final TokenDefinition token;
  final BigInt units;
  final bool spam;
}

class DiscoveryPage {
  const DiscoveryPage(this.tokens, {this.cursor, this.invalidCount = 0});
  final List<DiscoveredToken> tokens;
  final String? cursor;
  final int invalidCount;
}

abstract class AssetDiscoveryService {
  Future<DiscoveryPage> discover(
    EvmNetwork network,
    String address, {
    String? cursor,
    int limit = 100,
  });
  void dispose() {}
}

class HttpAssetDiscoveryService extends AssetDiscoveryService {
  HttpAssetDiscoveryService(this.config, {http.Client? client})
    : _client = client ?? http.Client();
  final IndexerConfig config;
  final http.Client _client;
  Future<Map<String, dynamic>> _get(
    Uri uri,
    Map<String, String> headers,
  ) async => _decode(
    await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10)),
  );
  Future<Map<String, dynamic>> _post(
    Uri uri,
    String method,
    List<Object> params,
  ) async => _decode(
    await _client
        .post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'id': 1,
            'method': method,
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 10)),
  );
  Map<String, dynamic> _decode(http.Response response) {
    if ([401, 403].contains(response.statusCode)) {
      throw const WalletInputException(MessageCode.discoveryUnauthorized);
    }
    if (response.statusCode == 429) {
      throw const WalletInputException(MessageCode.discoveryLimited);
    }
    if (response.statusCode != 200) {
      throw const WalletInputException(MessageCode.discoveryRequestFailed);
    }
    try {
      final json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (json['error'] != null || json['success'] == false) {
        throw const WalletInputException(MessageCode.discoveryResponseInvalid);
      }
      return json;
    } on WalletInputException {
      rethrow;
    } catch (_) {
      throw const WalletInputException(MessageCode.discoveryResponseInvalid);
    }
  }

  static BigInt _units(Object? value, {bool hex = false}) {
    if (value is! String ||
        !(hex ? RegExp(r'^0x[0-9a-fA-F]{1,64}$') : RegExp(r'^\d{1,78}$'))
            .hasMatch(value)) {
      throw const FormatException();
    }
    final units = hex
        ? BigInt.parse(value.substring(2), radix: 16)
        : BigInt.parse(value);
    if (units >= BigInt.one << 256) throw const FormatException();
    return units;
  }

  static DiscoveredToken _token(
    EvmNetwork n,
    Map data,
    BigInt units, {
    bool spam = false,
  }) {
    final decimals = data['decimals'] is int
        ? data['decimals'] as int
        : int.parse(data['decimals'] as String);
    final token = TokenDefinition(
      networkId: n.id,
      contract: data['address'] as String,
      symbol: data['symbol'] as String,
      decimals: decimals,
      name: (data['name'] ?? data['symbol']) as String,
    );
    token.validate(n);
    return DiscoveredToken(canonicalToken(token), units, spam: spam);
  }

  @override
  Future<DiscoveryPage> discover(
    EvmNetwork network,
    String address, {
    String? cursor,
    int limit = 100,
  }) async {
    if (!descriptorFor(config.provider).networkIds.contains(network.id)) {
      throw const WalletInputException(MessageCode.discoveryUnsupported);
    }
    network.validateAddress(address);
    try {
      return switch (config.provider) {
        IndexerProvider.moralis => await _moralis(
          network,
          address,
          cursor,
          limit,
        ),
        IndexerProvider.alchemy => await _alchemy(
          network,
          address,
          cursor,
          limit,
        ),
        IndexerProvider.trongrid => await _tron(
          network,
          address,
          cursor,
          limit,
        ),
      };
    } on WalletInputException {
      rethrow;
    } catch (_) {
      throw const WalletInputException(MessageCode.discoveryRequestFailed);
    }
  }

  Future<DiscoveryPage> _moralis(
    EvmNetwork n,
    String address,
    String? cursor,
    int limit,
  ) async {
    final json = await _get(
      Uri.https('deep-index.moralis.io', '/api/v2.2/wallets/$address/tokens', {
        'chain': '0x${n.id.toRadixString(16)}',
        'exclude_native': 'true',
        'exclude_spam': 'false',
        'limit': '$limit',
        'cursor': ?cursor,
      }),
      {'X-API-Key': config.apiKey},
    );
    final result = json['result'];
    if (result is! List) {
      throw const WalletInputException(MessageCode.discoveryResponseInvalid);
    }
    final tokens = <DiscoveredToken>[];
    var invalid = 0;
    for (final row in result) {
      try {
        final item = row as Map;
        if (item['native_token'] == true) continue;
        tokens.add(
          _token(
            n,
            {
              'address': item['token_address'],
              'symbol': item['symbol'],
              'name': item['name'],
              'decimals': item['decimals'],
            },
            _units(item['balance']),
            spam: item['possible_spam'] == true,
          ),
        );
      } catch (_) {
        invalid++;
      }
    }
    return DiscoveryPage(
      tokens,
      cursor: _cursor(json['cursor']),
      invalidCount: invalid,
    );
  }

  Future<DiscoveryPage> _alchemy(
    EvmNetwork n,
    String address,
    String? cursor,
    int limit,
  ) async {
    final uri = Uri.https(
      n.id == 1 ? 'eth-mainnet.g.alchemy.com' : 'polygon-mainnet.g.alchemy.com',
      '/v2/${config.apiKey}',
    );
    final json = await _post(uri, 'alchemy_getTokenBalances', [
      address,
      'erc20',
      {'maxCount': limit, 'pageKey': ?cursor},
    ]);
    final result = json['result'];
    if (result is! Map ||
        result['tokenBalances'] is! List ||
        (result['address'] as String?)?.toLowerCase() !=
            address.toLowerCase()) {
      throw const WalletInputException(MessageCode.discoveryResponseInvalid);
    }
    final tokens = <DiscoveredToken>[];
    var invalid = 0;
    final rows = result['tokenBalances'] as List;
    // Bound metadata concurrency; a large account must not fan out hundreds of requests.
    for (var start = 0; start < rows.length; start += 3) {
      await Future.wait(
        rows.skip(start).take(3).map((row) async {
          try {
            final item = row as Map;
            if (item['error'] != null) throw const FormatException();
            final units = _units(item['tokenBalance'], hex: true);
            if (units == BigInt.zero) return;
            final contract = item['contractAddress'] as String;
            n.validateAddress(contract);
            final metadata =
                (await _post(uri, 'alchemy_getTokenMetadata', [
                      contract,
                    ]))['result']
                    as Map;
            tokens.add(_token(n, {'address': contract, ...metadata}, units));
          } catch (e) {
            if (e is WalletInputException &&
                [
                  MessageCode.discoveryUnauthorized,
                  MessageCode.discoveryLimited,
                ].contains(e.code)) {
              rethrow;
            }
            invalid++;
          }
        }),
      );
    }
    return DiscoveryPage(
      tokens,
      cursor: _cursor(result['pageKey']),
      invalidCount: invalid,
    );
  }

  Future<DiscoveryPage> _tron(
    EvmNetwork n,
    String address,
    String? cursor,
    int limit,
  ) async {
    final json = await _get(
      Uri.https('api.trongrid.io', '/v1/accounts/$address/trc20/balance', {
        'limit': '$limit',
        'fingerprint': ?cursor,
      }),
      {'TRON-PRO-API-KEY': config.apiKey},
    );
    final rows = json['data'];
    if (rows is! List) {
      throw const WalletInputException(MessageCode.discoveryResponseInvalid);
    }
    final tokens = <DiscoveredToken>[];
    var invalid = 0;
    for (final row in rows) {
      try {
        final item = row as Map;
        final info = (item['token_info'] ?? item) as Map;
        tokens.add(
          _token(n, {
            'address': info['address'] ?? info['contract_address'],
            'name': info['name'],
            'symbol': info['symbol'],
            'decimals': info['decimals'],
          }, _units(item['balance'])),
        );
      } catch (_) {
        invalid++;
      }
    }
    return DiscoveryPage(
      tokens,
      cursor: _cursor((json['meta'] as Map?)?['fingerprint']),
      invalidCount: invalid,
    );
  }

  static String? _cursor(Object? value) {
    if (value == null || value == '') return null;
    if (value is! String || value.length > 4096) {
      throw const WalletInputException(MessageCode.discoveryResponseInvalid);
    }
    return value;
  }

  @override
  void dispose() => _client.close();
}

class DiscoverySnapshot {
  const DiscoverySnapshot({
    this.tokens = const [],
    this.cursor,
    this.pending = false,
    this.invalidData = false,
    this.incomplete = false,
    this.error,
  });
  final List<DiscoveredToken> tokens;
  final String? cursor;
  final bool pending, incomplete, invalidData;
  final WalletMessage? error;
}
