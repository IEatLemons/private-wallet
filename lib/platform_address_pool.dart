part of 'wallet_core.dart';

const _poolChains = ['bsc', 'tron'];
const _poolServiceKey = 'stone_wallet.v1.omni_connection';
const _poolBackupLimit = 64 * 1024 * 1024;
const _poolWireLimit = 4 * 1024 * 1024;
const _poolBackupHeader = 'asterkeel-omni-pool-backup-v1';

class AddressPoolException implements Exception {
  const AddressPoolException(this.code);
  final String code;
}

class OmniPoolConnection {
  OmniPoolConnection(
    String url,
    this.device,
    String publicKey,
    String fingerprint,
  ) : origin = Uri.parse(url.trim()),
      publicKey = publicKey.trim(),
      fingerprint = fingerprint.replaceAll(':', '').trim().toLowerCase() {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.authority.contains('@') ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(device) ||
        _digest(_poolPem(this.publicKey)) != this.fingerprint) {
      throw const AddressPoolException('connection');
    }
    _poolUnwrapKey(_poolPem(this.publicKey));
  }

  final Uri origin;
  final String device, publicKey, fingerprint;

  // Include the independently verified server key in the local namespace.
  String get service => '${origin.origin}#$fingerprint';

  Map<String, Object> toJson() => {
    'url': origin.origin,
    'device': device,
    'public_key': publicKey,
    'fingerprint': fingerprint,
  };
}

class OmniPoolDevice {
  const OmniPoolDevice(this.id, this.publicKey, this.fingerprint);
  final String id, publicKey, fingerprint;
}

String _digest(List<int> bytes) => hashes.sha256.convert(bytes).toString();

Uint8List _poolRandom(int count) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(count, (_) => random.nextInt(256)));
}

String _poolID() => bytesToHex(_poolRandom(24));

Uint8List _poolBytes(String value) => Uint8List.fromList(utf8.encode(value));

const _rsaSPKIAlgorithm = <int>[
  0x30,
  0x0d,
  0x06,
  0x09,
  0x2a,
  0x86,
  0x48,
  0x86,
  0xf7,
  0x0d,
  1,
  1,
  1,
  0x05,
  0x00,
];

Uint8List _poolDER(int tag, List<int> value) {
  final length = value.length;
  return Uint8List.fromList([
    tag,
    if (length < 128)
      length
    else if (length < 256) ...[
      0x81,
      length,
    ] else ...[
      0x82,
      length >> 8,
      length & 255,
    ],
    ...value,
  ]);
}

Uint8List _poolReadDER(int tag, Uint8List bytes, int offset) {
  if (offset + 2 > bytes.length || bytes[offset] != tag) {
    throw const AddressPoolException('connection');
  }
  var size = bytes[offset + 1];
  var start = offset + 2;
  if (size >= 128) {
    final count = size & 127;
    if (count < 1 || count > 2 || start + count > bytes.length) {
      throw const AddressPoolException('connection');
    }
    size = 0;
    for (var i = 0; i < count; i++) {
      size = (size << 8) + bytes[start++];
    }
  }
  if (start + size != bytes.length) {
    throw const AddressPoolException('connection');
  }
  return Uint8List.sublistView(bytes, start);
}

Uint8List _poolUnwrapKey(Uint8List data) {
  final contents = _poolReadDER(0x30, data, 0);
  if (contents.length < _rsaSPKIAlgorithm.length ||
      !listEquals(
        contents.sublist(0, _rsaSPKIAlgorithm.length),
        _rsaSPKIAlgorithm,
      )) {
    throw const AddressPoolException('connection');
  }
  final bits = _poolReadDER(0x03, contents, _rsaSPKIAlgorithm.length);
  if (bits.length < 385 ||
      bits.first != 0 ||
      !listEquals(bits.sublist(bits.length - 5), [2, 3, 1, 0, 1])) {
    throw const AddressPoolException('connection');
  }
  return Uint8List.sublistView(bits, 1);
}

Uint8List _poolPem(String text) {
  final match = RegExp(
    r'^-----BEGIN PUBLIC KEY-----\s+([A-Za-z0-9+/=\s]+?)\s+-----END PUBLIC KEY-----$',
  ).firstMatch(text);
  if (text.length > 8192 || match == null) {
    throw const AddressPoolException('connection');
  }
  return base64.decode(match[1]!.replaceAll(RegExp(r'\s'), ''));
}

class OmniPoolClient {
  OmniPoolClient(
    this.connection, {
    required this.deviceKey,
    required this.sign,
    required this.verify,
    http.Client? client,
    DateTime Function()? clock,
    String Function()? requestId,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _requestId = requestId ?? _poolID;

  final OmniPoolConnection connection;
  final String deviceKey;
  final Future<Uint8List> Function(Uint8List) sign;
  final Future<bool> Function(Uint8List, Uint8List, Uint8List) verify;
  final http.Client _client;
  final DateTime Function() _clock;
  final String Function() _requestId;

  void close() => _client.close();

  Future<Map<String, Object?>> request(
    String method,
    String route, {
    Map<String, String>? query,
    Map<String, Object?>? payload,
  }) async {
    final uri = connection.origin.replace(
      path: '/internal/v2/vault/$route',
      queryParameters: query,
    );
    final body = _poolBytes(payload == null ? '' : jsonEncode(payload));
    final time = (_clock().millisecondsSinceEpoch ~/ 1000).toString();
    final id = _requestId();
    final path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    String message(List<int> data) => [
      'omnivault-vault-request',
      '1',
      connection.device,
      deviceKey,
      method,
      path,
      _digest(data),
      time,
      id,
    ].join('\n');
    final signature = base64.encode(await sign(_poolBytes(message(body))));
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..bodyBytes = body
      ..headers.addAll({
        'Content-Type': 'application/json',
        'X-Vault-Version': '1',
        'X-Vault-Device': connection.device,
        'X-Vault-Key': deviceKey,
        'X-Vault-Time': time,
        'X-Vault-Request': id,
        'X-Vault-Signature': signature,
      });
    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      final raw = BytesBuilder(copy: false);
      await (() async {
        await for (final chunk in response.stream) {
          if (raw.length + chunk.length > _poolWireLimit) {
            throw const AddressPoolException('response');
          }
          raw.add(chunk);
        }
      })().timeout(const Duration(seconds: 30));
      final received = raw.takeBytes();
      final proof = response.headers['x-vault-signature'];
      if (proof == null) throw const AddressPoolException('signature');
      final responseMessage = _poolBytes(
        [
          'omnivault-vault-response',
          '1',
          id,
          _digest(_poolBytes('${message(const [])}$signature')),
          response.statusCode.toString(),
          _digest(received),
        ].join('\n'),
      );
      if (!await verify(
        _poolUnwrapKey(_poolPem(connection.publicKey)),
        responseMessage,
        base64.decode(proof),
      )) {
        throw const AddressPoolException('signature');
      }
      final data = (jsonDecode(utf8.decode(received)) as Map)
          .cast<String, Object?>();
      if (response.statusCode == 404 && data['error'] == 'BATCH_NOT_FOUND') {
        throw const AddressPoolException('batch_missing');
      }
      if (response.statusCode == 403) {
        throw const AddressPoolException('access');
      }
      if (response.statusCode != 200) {
        throw const AddressPoolException('rejected');
      }
      return data;
    } on FormatException {
      throw const AddressPoolException('response');
    } on TimeoutException {
      throw const AddressPoolException('network');
    } on IOException {
      throw const AddressPoolException('network');
    } on http.ClientException {
      throw const AddressPoolException('network');
    }
  }
}

String omniPoolAddressPath(String chain, int index) {
  if (!_poolChains.contains(chain) || index < 0 || index >= 0x80000000) {
    throw const AddressPoolException('range');
  }
  return "m/44'/${chain == 'bsc' ? 60 : 195}'/2'/0/$index";
}

List<String> deriveOmniPoolAddresses(
  String mnemonic,
  String chain,
  int first,
  int count,
) {
  if (count < 1 || count > 1000 || !bip39.validateMnemonic(mnemonic)) {
    throw const AddressPoolException('input');
  }
  final path = omniPoolAddressPath(chain, first);
  omniPoolAddressPath(chain, first + count - 1);
  final seed = bip39.mnemonicToSeed(mnemonic);
  try {
    final node = BIP32
        .fromSeed(seed)
        .derivePath(path.substring(0, path.lastIndexOf('/')));
    return List.generate(count, (i) {
      final key = node.derive(first + i).privateKey!;
      try {
        final address = EthPrivateKey(key).address;
        return chain == 'bsc'
            ? address.hex
            : base58.encode(
                Uint8List.fromList([0x41, ...address.addressBytes]),
              );
      } finally {
        key.fillRange(0, key.length, 0);
      }
    });
  } finally {
    seed.fillRange(0, seed.length, 0);
  }
}

Map<String, Object?> _poolSeed(String mnemonic) {
  final normalized = WalletVault._normalizeMnemonic(mnemonic);
  if (!bip39.validateMnemonic(normalized)) {
    throw const AddressPoolException('input');
  }
  return {
    'id': _poolID(),
    'mnemonic': normalized,
    'identity': _digest(_poolBytes(normalized)),
    'bsc_next': 0,
    'tron_next': 0,
  };
}

List<Map<String, Object?>> _poolRows(Object? value) =>
    (value as List).map((row) => (row as Map).cast<String, Object?>()).toList();

Map<String, Object?> _poolObject(Object? value) =>
    (value as Map).cast<String, Object?>();

String _poolCanonical(String chain, Object? address) {
  if (address is! String) throw const AddressPoolException('response');
  if (chain == 'bsc' && RegExp(r'^0x[0-9a-f]{40}$').hasMatch(address)) {
    return address;
  }
  if (chain == 'tron') {
    final bytes = base58.decode(address);
    if (bytes.length == 21 &&
        bytes.first == 65 &&
        base58.encode(bytes) == address) {
      return address;
    }
  }
  throw const AddressPoolException('response');
}

class OmniAddressPools {
  OmniAddressPools(this._vault);
  final WalletVault _vault;

  Map<String, Object?> _scope(OmniPoolConnection connection, String platform) =>
      {'service': connection.service, 'platform': platform};

  Future<T?> _db<T>(String name, [Map<String, Object?>? args]) {
    if (!_vault.supportsOmniVaultImport) {
      throw const AddressPoolException('access');
    }
    return _vault._rawMacCall<T>('pool.$name', args);
  }

  Future<OmniPoolDevice> device() async {
    final rsa = (await _db<Uint8List>('device'))!;
    final encoded = _poolDER(0x30, [
      ..._rsaSPKIAlgorithm,
      ..._poolDER(3, [0, ...rsa]),
    ]);
    final fingerprint = _digest(encoded);
    final pem = base64
        .encode(encoded)
        .replaceAllMapped(RegExp('.{64}'), (m) => '${m[0]}\n')
        .trimRight();
    return OmniPoolDevice(
      fingerprint.substring(0, 32),
      '-----BEGIN PUBLIC KEY-----\n$pem\n-----END PUBLIC KEY-----',
      fingerprint,
    );
  }

  Future<OmniPoolConnection?> connection() async {
    final raw = await _vault._store.read(_poolServiceKey);
    if (raw == null) return null;
    final data = _poolObject(jsonDecode(raw));
    return OmniPoolConnection(
      data['url'] as String,
      data['device'] as String,
      data['public_key'] as String,
      data['fingerprint'] as String,
    );
  }

  Future<void> connect(OmniPoolConnection connection) async {
    await platforms(connection);
    await _vault._store.write(_poolServiceKey, jsonEncode(connection));
  }

  Future<T> _remote<T>(
    OmniPoolConnection c,
    Future<T> Function(OmniPoolClient) run,
  ) async {
    final identity = await device();
    final client = OmniPoolClient(
      c,
      deviceKey: identity.fingerprint,
      sign: (message) async =>
          (await _db<Uint8List>('sign', {'message': message}))!,
      verify: (key, message, signature) async =>
          await _db<bool>('verify', {
            'key': key,
            'message': message,
            'signature': signature,
          }) ==
          true,
    );
    try {
      return await run(client);
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, Object?>>> platforms(OmniPoolConnection c) => _remote(
    c,
    (client) async =>
        _poolRows((await client.request('GET', 'platforms'))['platforms']),
  );

  Future<bool> hasSeed(OmniPoolConnection c, String platform) async =>
      await _db<bool>('hasSeed', _scope(c, platform)) == true;

  String newMnemonic() => bip39.generateMnemonic(strength: 256);

  Future<void> initialize(
    OmniPoolConnection c,
    String platform,
    String mnemonic,
  ) => _vault._serialize(
    () => _db<void>('create', {..._scope(c, platform), ..._poolSeed(mnemonic)}),
  );

  Future<void> generate(
    OmniPoolConnection c,
    String platform,
    String chain,
    int count,
  ) => _vault._serialize(() async {
    if (!_poolChains.contains(chain) || count < 1 || count > 1000) {
      throw const AddressPoolException('range');
    }
    final scope = _scope(c, platform);
    final seed = await _db<Map<Object?, Object?>>('active', scope);
    if (seed == null) throw const AddressPoolException('input');
    final first = seed['${chain}_next'] as int;
    final mnemonic = seed['mnemonic'] as String;
    final addresses = await _derivePoolInBackground(
      mnemonic,
      chain,
      first,
      count,
    );
    final id = _poolID();
    final wallet = seed['id'] as String;
    final payload = {
      'id': id,
      'platform': platform,
      'addresses': [
        for (final address in addresses)
          {'chain': chain, 'address': address, 'wallet_id': wallet},
      ],
    };
    await _db<void>('generate', {
      ...scope,
      'id': id,
      'chain': chain,
      'seed': wallet,
      'first_index': first,
      'count': count,
      'payload': jsonEncode(payload),
    });
  });

  Future<List<Map<String, Object?>>> batches(
    OmniPoolConnection c,
    String platform,
  ) async => _poolRows(await _db<List<Object?>>('list', _scope(c, platform)));

  Future<void> upload(OmniPoolConnection c, String platform, String id) =>
      _vault._serialize(() async {
        final scope = _scope(c, platform);
        final batch = await _db<Map<Object?, Object?>>('batch', {
          ...scope,
          'id': id,
        });
        if (batch == null || batch['backed_up'] != 1) {
          throw const AddressPoolException('backup_required');
        }
        final payload = _poolObject(jsonDecode(batch['payload'] as String));
        await _remote(c, (client) async {
          Map<String, Object?>? existing;
          try {
            existing = await client.request(
              'GET',
              'batches',
              query: {'platform': platform, 'id': id},
            );
          } on AddressPoolException catch (e) {
            if (e.code != 'batch_missing') rethrow;
          }
          if (existing != null) {
            if (!_sameBatch(existing, payload)) {
              throw const AddressPoolException('binding');
            }
          } else {
            final receipt = await client.request(
              'POST',
              'batches',
              payload: payload,
            );
            if (receipt['id'] != id) {
              throw const AddressPoolException('response');
            }
          }
        });
        await _db<void>('markUploaded', {
          ...scope,
          'ids': [
            {'id': id},
          ],
        });
      });

  bool _sameBatch(Map<String, Object?> a, Map<String, Object?> b) {
    if (a['id'] != b['id'] || a['platform'] != b['platform']) return false;
    final aa = _poolRows(a['addresses']), bb = _poolRows(b['addresses']);
    if (aa.length != bb.length) return false;
    for (var i = 0; i < aa.length; i++) {
      for (final field in ['chain', 'address', 'wallet_id']) {
        if (aa[i][field] != bb[i][field]) return false;
      }
    }
    return true;
  }

  Future<Map<String, Object?>> snapshot(
    OmniPoolConnection c,
    String platform,
  ) async {
    final raw = await _db<String>('snapshot', _scope(c, platform));
    return raw == null ? {} : _poolObject(jsonDecode(raw));
  }

  Future<void> sync(
    OmniPoolConnection c,
    String platform,
  ) => _vault._serialize(() async {
    final previous = await snapshot(c, platform);
    final fresh = await _remote(c, (client) async {
      final query = {'platform': platform};
      final inventory = _poolRows(
        (await client.request('GET', 'inventory', query: query))['inventory'],
      );
      if (inventory.length != 2 ||
          !inventory.map((x) => x['chain']).toSet().containsAll(_poolChains) ||
          inventory.any(
            (x) => [
              'available',
              'allocated',
              'threshold',
            ].any((key) => x[key] is! int || (x[key] as int) < 0),
          )) {
        throw const AddressPoolException('response');
      }
      final all = <Map<String, Object?>>[];
      final old = {
        for (final item in _poolRows(previous['addresses'] ?? []))
          if (item['state'] == 'allocated')
            '${item['chain']}:${item['address']}': item,
      };
      for (final chain in _poolChains) {
        var after = '';
        do {
          final data = await client.request(
            'GET',
            'addresses',
            query: {...query, 'chain': chain, 'after': after},
          );
          final page = _poolRows(data['addresses']);
          final next = data['next'];
          if (next is! String ||
              page.length > 500 ||
              all.length + page.length > 1000000 ||
              (next.isNotEmpty &&
                  (page.length != 500 || page.last['address'] != next))) {
            throw const AddressPoolException('response');
          }
          var last = after;
          for (final row in page) {
            final address = _poolCanonical(chain, row['address']);
            final state = row['state'];
            if (address.compareTo(last) <= 0 ||
                row['chain'] != chain ||
                !['available', 'allocated', 'disabled'].contains(state) ||
                (state == 'allocated' &&
                    (row['platform'] != platform ||
                        ![
                          'address',
                          'collection_order',
                        ].contains(row['kind']) ||
                        row['owner'] is! String ||
                        (row['owner'] as String).isEmpty))) {
              throw const AddressPoolException('binding');
            }
            final known = old.remove('$chain:$address');
            if (known != null &&
                [
                  'state',
                  'platform',
                  'kind',
                  'owner',
                  'wallet_id',
                  'batch_id',
                ].any((field) => known[field] != row[field])) {
              throw const AddressPoolException('binding');
            }
            last = address;
            all.add(row);
          }
          after = next;
        } while (after.isNotEmpty);
      }
      if (old.isNotEmpty) throw const AddressPoolException('binding');
      return {
        'inventory': inventory,
        'addresses': all,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      };
    });
    await _db<void>('saveSnapshot', {
      ..._scope(c, platform),
      'payload': jsonEncode(fresh),
    });
  });

  Future<void> backup(
    OmniPoolConnection c,
    String platform,
    File file,
    String passphrase,
  ) => _vault._serialize(() async {
    final scope = _scope(c, platform);
    final data = _poolObject(await _db<Map<Object?, Object?>>('backup', scope));
    if (_poolRows(data['seeds']).isEmpty) {
      throw const AddressPoolException('input');
    }
    final content = {'service': c.service, 'platform': platform, ...data};
    final encrypted = await _encryptPoolInBackground(content, passphrase);
    await file.create(exclusive: true);
    await file.writeAsBytes(encrypted, flush: true);
    final reopened = await _readPoolBackup(
      file,
      passphrase,
      c.service,
      platform,
    );
    if (jsonEncode(reopened) != jsonEncode(content)) {
      throw const AddressPoolException('backup');
    }
    await _db<void>('markBackedUp', {
      ...scope,
      'ids': [
        for (final batch in _poolRows(reopened['batches'])) {'id': batch['id']},
      ],
    });
  });

  Future<void> restore(
    OmniPoolConnection c,
    String platform,
    File file,
    String passphrase,
  ) => _vault._serialize(() async {
    final data = await _readPoolBackup(file, passphrase, c.service, platform);
    await _db<void>('restore', {
      ..._scope(c, platform),
      'seeds': data['seeds'],
      'batches': data['batches'],
      'active': _poolSeed(newMnemonic()),
    });
  });
}

Future<List<String>> _derivePoolInBackground(
  String mnemonic,
  String chain,
  int first,
  int count,
) => Isolate.run(() => deriveOmniPoolAddresses(mnemonic, chain, first, count));

Future<Uint8List> _encryptPoolInBackground(
  Map<String, Object?> data,
  String passphrase,
) => Isolate.run(() => _poolEncrypt(data, passphrase));

Uint8List _poolCipher(
  bool encrypt,
  Uint8List input,
  String passphrase,
  Uint8List salt,
  Uint8List nonce,
) {
  if (passphrase.runes.length < 12) {
    throw const AddressPoolException('passphrase');
  }
  final password = _poolBytes(passphrase);
  final argon = Argon2BytesGenerator()
    ..init(
      Argon2Parameters(
        Argon2Parameters.ARGON2_id,
        salt,
        desiredKeyLength: 32,
        iterations: 3,
        memory: 65536,
        lanes: 4,
      ),
    );
  final key = Uint8List(32);
  try {
    argon.deriveKey(password, 0, key, 0);
    return (GCMBlockCipher(AESEngine())..init(
          encrypt,
          AEADParameters(
            KeyParameter(key),
            128,
            nonce,
            _poolBytes(_poolBackupHeader),
          ),
        ))
        .process(input);
  } finally {
    key.fillRange(0, key.length, 0);
    password.fillRange(0, password.length, 0);
  }
}

Uint8List _poolEncrypt(Map<String, Object?> data, String passphrase) {
  final raw = _poolBytes(jsonEncode(data));
  if (raw.length > _poolBackupLimit - 64) {
    throw const AddressPoolException('backup');
  }
  final salt = _poolRandom(16);
  final nonce = _poolRandom(12);
  try {
    return Uint8List.fromList([
      ..._poolBytes(_poolBackupHeader),
      ...salt,
      ...nonce,
      ..._poolCipher(true, raw, passphrase, salt, nonce),
    ]);
  } finally {
    raw.fillRange(0, raw.length, 0);
  }
}

Future<Map<String, Object?>> _readPoolBackup(
  File file,
  String password,
  String service,
  String platform,
) async {
  final raw = BytesBuilder(copy: false);
  await for (final data in file.openRead()) {
    if (raw.length + data.length > _poolBackupLimit) {
      throw const AddressPoolException('backup');
    }
    raw.add(data);
  }
  final bytes = raw.takeBytes();
  return Isolate.run(() {
    try {
      final offset = _poolBackupHeader.length;
      if (bytes.length < offset + 44 ||
          utf8.decode(bytes.sublist(0, offset)) != _poolBackupHeader) {
        throw const AddressPoolException('backup');
      }
      final plain = _poolCipher(
        false,
        Uint8List.sublistView(bytes, offset + 28),
        password,
        Uint8List.sublistView(bytes, offset, offset + 16),
        Uint8List.sublistView(bytes, offset + 16, offset + 28),
      );
      try {
        final decoded = _poolObject(jsonDecode(utf8.decode(plain)));
        _verifyPoolBackup(decoded, service, platform);
        return decoded;
      } finally {
        plain.fillRange(0, plain.length, 0);
      }
    } catch (_) {
      throw const AddressPoolException('backup');
    }
  });
}

void _verifyPoolBackup(
  Map<String, Object?> data,
  String service,
  String platform,
) {
  const invalid = AddressPoolException('backup');
  if (data['service'] != service || data['platform'] != platform) throw invalid;
  final seeds = <String, Map<String, Object?>>{};
  final indices = <(String, String), int>{};
  final identities = <String>{};
  for (final seed in _poolRows(data['seeds'])) {
    final mnemonic = seed['mnemonic'] as String;
    final id = seed['id'] as String;
    final identity = _digest(_poolBytes(mnemonic));
    if (!RegExp(r'^[0-9a-f]{48}$').hasMatch(id) ||
        seeds.containsKey(id) ||
        !bip39.validateMnemonic(mnemonic) ||
        seed['identity'] != identity ||
        !identities.add(identity)) {
      throw invalid;
    }
    seeds[id] = seed;
    for (final chain in _poolChains) {
      indices[(id, chain)] = 0;
    }
  }
  if (seeds.isEmpty) throw invalid;
  final batches = _poolRows(data['batches']);
  final ids = <String>{};
  for (final batch in batches) {
    final chain = batch['chain'] as String;
    final seed = batch['seed'] as String;
    final first = batch['first_index'];
    final id = batch['id'] as String;
    final key = (seed, chain);
    if (!RegExp(r'^[0-9a-f]{48}$').hasMatch(id) ||
        !ids.add(id) ||
        !indices.containsKey(key) ||
        first is! int ||
        first != indices[key]) {
      throw invalid;
    }
    final payload = _poolObject(jsonDecode(batch['payload'] as String));
    final addresses = _poolRows(payload['addresses']);
    if (payload['id'] != id || payload['platform'] != platform) throw invalid;
    final derived = deriveOmniPoolAddresses(
      seeds[seed]!['mnemonic'] as String,
      chain,
      first,
      addresses.length,
    );
    for (var i = 0; i < derived.length; i++) {
      final addr = addresses[i];
      if (addr['chain'] != chain ||
          addr['address'] != derived[i] ||
          addr['wallet_id'] != seed) {
        throw invalid;
      }
    }
    indices[key] = first + addresses.length;
  }
  for (final entry in indices.entries) {
    final (seed, chain) = entry.key;
    if (seeds[seed]!['${chain}_next'] != entry.value) throw invalid;
  }
}
