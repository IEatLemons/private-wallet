import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/wallet_core.dart';

const _phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const _uri = 'https://omni.example';
const _password = 'test backup passphrase';

OmniPoolConnection _connection() {
  // Synthetic SPKI for request construction. This test stubs signing/verification.
  final der = Uint8List.fromList([
    0x30,
    0x82,
    1,
    0x96,
    0x30,
    0x0d,
    6,
    9,
    0x2a,
    0x86,
    0x48,
    0x86,
    0xf7,
    0x0d,
    1,
    1,
    1,
    5,
    0,
    3,
    0x82,
    1,
    0x83,
    0,
    ...List.filled(381, 0),
    2,
    3,
    1,
    0,
    1,
  ]);
  return OmniPoolConnection(
    _uri,
    'device',
    '-----BEGIN PUBLIC KEY-----\n${base64.encode(der)}\n-----END PUBLIC KEY-----',
    sha256.convert(der).toString(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pool branches are deterministic and distinct from ordinary accounts',
    () {
      final evm = deriveOmniPoolAddresses(_phrase, 'bsc', 0, 3);
      final tron = deriveOmniPoolAddresses(_phrase, 'tron', 0, 3);
      expect(deriveOmniPoolAddresses(_phrase, 'bsc', 1, 2), evm.skip(1));
      expect(evm.toSet(), hasLength(3));
      expect(tron.toSet(), hasLength(3));
      expect(evm.first, isNot(WalletAccount.fromMnemonic(_phrase).addressHex));
      expect(
        tron.first,
        isNot(WalletAccount.fromMnemonic(_phrase).tronAddress),
      );
      expect(
        () => deriveOmniPoolAddresses(_phrase, 'bsc', 0x7fffffff, 2),
        throwsA(isA<AddressPoolException>()),
      );
    },
  );

  test('signed response binds request, exact path, status and body', () async {
    final connection = _connection();
    const id = 'aabb';
    const time = '500';
    const contents = '{"platforms":[]}';
    final observed = <String>[];
    var valid = true;
    final client = OmniPoolClient(
      connection,
      deviceKey: 'device-key',
      clock: () => DateTime.fromMillisecondsSinceEpoch(500000),
      requestId: () => id,
      sign: (message) async {
        observed.add(utf8.decode(message));
        return Uint8List.fromList([1, 2, 3]);
      },
      verify: (_, message, signature) async {
        observed.add(utf8.decode(message));
        expect(signature, [10]);
        return valid;
      },
      client: MockClient((request) async {
        expect(request.followRedirects, isFalse);
        expect(request.headers['X-Vault-Signature'], 'AQID');
        return http.Response(
          contents,
          200,
          headers: {'x-vault-signature': 'Cg=='},
        );
      }),
    );
    addTearDown(client.close);
    final response = await client.request(
      'GET',
      'platforms',
      query: {'q': 'space +'},
    );
    expect(response['platforms'], []);
    final emptyHash = sha256.convert(const []).toString();
    final requestMessage = [
      'omnivault-vault-request',
      '1',
      'device',
      'device-key',
      'GET',
      '/internal/v2/vault/platforms?q=space+%2B',
      emptyHash,
      time,
      id,
    ].join('\n');
    expect(observed, [
      requestMessage,
      [
        'omnivault-vault-response',
        '1',
        id,
        sha256.convert(utf8.encode('${requestMessage}AQID')).toString(),
        '200',
        sha256.convert(utf8.encode(contents)).toString(),
      ].join('\n'),
    ]);
    valid = false;
    await expectLater(
      client.request('GET', 'platforms'),
      throwsA(
        isA<AddressPoolException>().having((e) => e.code, 'code', 'signature'),
      ),
    );
  });

  test(
    'verified backup restores historical batches and starts a fresh seed',
    () async {
      final connection = _connection();
      final directory = await Directory.systemTemp.createTemp();
      addTearDown(() async => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.akpool');
      final generated = <Map<String, Object?>>[];
      final seeds = <Map<String, Object?>>[];
      final calls = <String>[];
      Map<Object?, Object?>? restored;
      var failNextBatch = true;
      const channel = MethodChannel('asterkeel/wallet_database');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        calls.add(call.method);
        switch (call.method) {
          case 'pool.create':
            seeds.add(
              Map.of(args)
                ..remove('service')
                ..remove('platform'),
            );
          case 'pool.active':
            return Map.of(seeds.single);
          case 'pool.generate':
            if (failNextBatch) {
              failNextBatch = false;
              throw PlatformException(code: 'wallet_database');
            }
            generated.add(
              Map.of(args)
                ..remove('service')
                ..remove('platform')
                ..remove('count'),
            );
            final next = '${args['chain']}_next';
            seeds.single[next] =
                (seeds.single[next] as int) + (args['count'] as int);
          case 'pool.backup':
            return {'seeds': seeds, 'batches': generated};
          case 'pool.markBackedUp':
            expect((args['ids'] as List), hasLength(2));
          case 'pool.restore':
            restored = args;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final pools = OmniAddressPools(WalletVault(useMacWalletDatabase: true));
      await pools.initialize(connection, 'shop', _phrase);
      await expectLater(
        pools.generate(connection, 'shop', 'bsc', 1),
        throwsA(isA<WalletInputException>()),
      );
      await Future.wait([
        pools.generate(connection, 'shop', 'bsc', 1),
        pools.generate(connection, 'shop', 'bsc', 1),
      ]);
      expect(generated.map((batch) => batch['first_index']), [0, 1]);
      await pools.backup(connection, 'shop', file, _password);
      expect(latin1.decode(await file.readAsBytes()), isNot(contains(_phrase)));
      await expectLater(
        pools.restore(connection, 'shop', file, 'wrong test passphrase'),
        throwsA(isA<AddressPoolException>()),
      );
      expect(restored, isNull);
      await pools.restore(connection, 'shop', file, _password);
      expect(restored!['batches'], hasLength(2));
      expect((restored!['active'] as Map)['mnemonic'], isNot(_phrase));
      expect(calls.where((call) => call == 'pool.markBackedUp'), hasLength(1));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
