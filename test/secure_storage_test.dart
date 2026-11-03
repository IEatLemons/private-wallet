import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/wallet_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'macOS uses local Keychain for all operations and missing delete is idempotent',
    () async {
      final values = <String, String>{};
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final options = Map<String, dynamic>.from(args['options'] as Map);
        expect(options['usesDataProtectionKeychain'], 'false');
        expect(options['synchronizable'], 'false');
        final key = args['key'] as String;
        switch (call.method) {
          case 'read':
            return values[key];
          case 'write':
            values[key] = args['value'] as String;
            return null;
          case 'delete':
            values.remove(key);
            return null;
        }
        throw StateError('Unexpected method');
      });
      final store = FlutterSecretStore();
      await store.delete('test');
      expect(calls, ['read']);
      await store.write('test', 'synthetic');
      expect(await store.read('test'), 'synthetic');
      await store.delete('test');
      expect(values, isEmpty);
      expect(calls.where((c) => c == 'delete'), hasLength(1));
    },
  );

  test(
    'permission errors are surfaced without exposing native error details',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(
          code: 'Unexpected security result code',
          message: 'native diagnostic',
          details: -34018,
        );
      });
      final store = FlutterSecretStore();
      for (final operation in [
        () => store.read('test'),
        () => store.write('test', 'synthetic'),
        () => store.delete('test'),
      ]) {
        await expectLater(
          operation(),
          throwsA(
            isA<WalletInputException>()
                .having((e) => e.message, 'message', contains('重新编译'))
                .having(
                  (e) => e.message,
                  'message',
                  isNot(contains('native diagnostic')),
                ),
          ),
        );
      }
    },
  );
}
