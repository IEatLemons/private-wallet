import 'dart:async';
import 'dart:convert';

import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/address_recovery.dart';
import 'package:stone_wallet/recovery_engine.dart' as engine;
import 'package:stone_wallet/wallet_core.dart';

import 'widget_test.dart' show MapSecretStore;
import 'wallet_management_test.dart' show phraseA, phraseB;

const base = "m/44'/60'/0'/0";
const target = '0x9858effd232b4033e47d90003d41ec34ecaeda94';
const legacy = 'TNNrLX8qUY6pYY29Wyh7bWCLZnuic39qjr';
const unmatched = '0xe4079dbbc13d661736562ad156c90dce0fa4f705';

Future<void> waitRecovery(bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      throw StateError('Recovery did not complete in time');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

class GatedRecoveryStore extends MapSecretStore {
  GatedRecoveryStore() : super({});
  final gate = Completer<void>();
  bool fail = false;
  @override
  Future<void> write(String key, String value) async {
    if (key == 'stone_wallet.recovery_tasks.v1') {
      await gate.future;
      if (fail) throw StateError('synthetic recovery storage failure');
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'address indices and account paths are sequential and fingerprints bind the base path',
    () {
      final sources = engine.materialsFromMnemonic(phraseA);
      final options = engine.Options()
        ..mode = 'index'
        ..basePath = base
        ..target = target
        ..index = 0
        ..endAccount = 3;
      final search = engine.Engine(options, sources);
      expect(search.familyCount, 1);
      expect(
        [for (var i = 0; i < 4; i++) search.probe(i).public['path']],
        [for (var i = 0; i < 4; i++) '$base/$i'],
      );
      expect(search.check(0)!.public['match'], 'standard_address_match');
      final changed = engine.Engine(
        engine.Options()
          ..mode = 'index'
          ..basePath = "m/44'/195'/0'/0"
          ..target = target
          ..index = 0,
        sources,
      );
      expect(changed.fingerprint, isNot(search.fingerprint));
      final accounts = engine.Engine(
        engine.Options()..target = target,
        sources,
      );
      expect(accounts.probe(0).public['counter'], 0);
      expect(accounts.probe(17).public['counter'], 0);
      expect(accounts.probe(18).public['counter'], 1);
      expect(accounts.probe(18).public['path'], "m/44'/0'/1'/0/925183485");
    },
  );

  test(
    'standard and legacy results persist privately and remain separate tasks',
    () async {
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final controller = AddressRecoveryController(vault);
      addTearDown(controller.dispose);
      await controller.load();
      await controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: target,
          mode: 'index',
          index: 0,
          end: 0,
        ),
      );
      await waitRecovery(() => !controller.running);
      final standard = controller.selected!;
      expect(standard.status, 'standard_address_match');
      expect(standard.cursor, 1);
      expect(
        standard.matches.single['derived_private_key'],
        WalletAccount.fromMnemonic(phraseA).privateKeyHex,
      );
      await controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: legacy,
          mode: 'index',
          index: 0,
          end: 0,
        ),
      );
      await waitRecovery(() => !controller.running);
      expect(controller.selected!.status, 'legacy_hash_match_only');
      expect(
        controller.selected!.matches.single['standard_address_matches_target'],
        false,
      );
      final reloaded = AddressRecoveryController(WalletVault(store: store));
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.tasks, hasLength(2));
      expect(reloaded.tasks.last.id, standard.id);
      expect(reloaded.tasks.last.matches.single['standard_evm'], target);
    },
  );

  test('public xpub legacy match cannot stop a private-key search', () async {
    final pub = BIP32
        .fromSeed(bip39.mnemonicToSeed(phraseA))
        .derivePath(base)
        .neutered()
        .toBase58();
    final controller = AddressRecoveryController(
      WalletVault(store: MapSecretStore({})),
    );
    addTearDown(controller.dispose);
    await controller.start(
      AddressRecoveryInput(
        mnemonic: phraseB,
        xpub: pub,
        target: legacy,
        mode: 'index',
        index: 0,
        end: 0,
      ),
    );
    await waitRecovery(() => !controller.running);
    expect(controller.selected!.status, 'range_exhausted');
    expect(controller.selected!.verification!['match'], 'legacy');
    expect(controller.selected!.verification!['origin_matches_base'], false);
    expect(controller.selected!.matches, isEmpty);
  });

  test(
    'standard-only searches retain legacy keys and continue to the range end',
    () async {
      final controller = AddressRecoveryController(
        WalletVault(store: MapSecretStore({})),
      );
      addTearDown(controller.dispose);
      await controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: legacy,
          mode: 'index',
          index: 0,
          end: 2,
          standardOnly: true,
        ),
      );
      await waitRecovery(() => !controller.running);
      expect(controller.selected!.status, 'range_exhausted');
      expect(controller.selected!.checked, 3);
      expect(controller.selected!.matches, hasLength(1));
      expect(
        controller.selected!.matches.single['match'],
        'legacy_hash_match_only',
      );
    },
  );

  test(
    'background search pauses, saves its next cursor, and resumes after reopening',
    () async {
      final store = MapSecretStore({});
      final controller = AddressRecoveryController(WalletVault(store: store));
      await controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: unmatched,
          mode: 'index',
          start: 42,
          end: 10000,
          cpuPercent: 10,
        ),
      );
      await waitRecovery(() => controller.selected!.checked > 0);
      await controller.pause();
      final old = controller.selected!;
      final cursor = old.cursor;
      expect(old.status, 'paused');
      expect(cursor, greaterThan(42));
      expect(
        controller.activeMicros /
            (controller.activeMicros + controller.sleepMicros),
        lessThanOrEqualTo(.101),
      );
      controller.dispose();
      final resumed = AddressRecoveryController(WalletVault(store: store));
      addTearDown(resumed.dispose);
      await resumed.load();
      expect(resumed.selected!.cursor, cursor);
      await resumed.resume(cpuPercent: 25);
      await waitRecovery(() => resumed.selected!.cursor > cursor);
      await resumed.pause();
      expect(resumed.selected!.id, old.id);
      expect(resumed.selected!.checked, greaterThan(old.checked));
      expect(resumed.error, isNull);
    },
  );

  test(
    'index search updates xpub verification at the actual matching index',
    () async {
      final pub = BIP32
          .fromSeed(bip39.mnemonicToSeed(phraseA))
          .derivePath(base)
          .neutered()
          .toBase58();
      final expected = WalletAccount.fromMnemonic(
        phraseA,
        accountIndex: 3,
      ).checksumAddress;
      final controller = AddressRecoveryController(
        WalletVault(store: MapSecretStore({})),
      );
      addTearDown(controller.dispose);
      await controller.start(
        AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: pub,
          target: expected,
          mode: 'index',
          end: 3,
        ),
      );
      await waitRecovery(() => !controller.running);
      expect(controller.selected!.checked, 4);
      expect(controller.selected!.verification!['index'], 3);
      expect(controller.selected!.verification!['match'], 'standard');
    },
  );

  test(
    'disposing during initial storage cannot launch an orphan search',
    () async {
      final store = GatedRecoveryStore();
      final controller = AddressRecoveryController(WalletVault(store: store));
      final starting = controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: unmatched,
          mode: 'index',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final pausing = controller.pause();
      controller.dispose();
      store.gate.complete();
      await starting;
      await pausing;
      expect(controller.running, false);
      expect(controller.selected!.checked, 0);
      final reloaded = AddressRecoveryController(WalletVault(store: store));
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.selected!.status, 'paused');
      expect(reloaded.selected!.reason, 'restart');
    },
  );

  test(
    'storage failure settles a pending pause and can resume after storage recovers',
    () async {
      final store = GatedRecoveryStore()..fail = true;
      final controller = AddressRecoveryController(WalletVault(store: store));
      addTearDown(controller.dispose);
      final starting = controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: target,
          mode: 'index',
          end: 0,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final pausing = controller.pause();
      store.gate.complete();
      await starting;
      await pausing;
      expect(controller.error, 'storage');
      expect(controller.running, false);
      store.fail = false;
      await controller.resume();
      await waitRecovery(() => !controller.running);
      expect(controller.selected!.status, 'standard_address_match');
      expect(controller.error, isNull);
    },
  );

  test(
    'malformed inputs are rejected without starting or storing a task',
    () async {
      final store = MapSecretStore({});
      final controller = AddressRecoveryController(WalletVault(store: store));
      addTearDown(controller.dispose);
      await expectLater(
        controller.start(
          const AddressRecoveryInput(mnemonic: 'bad', xpub: '', target: target),
        ),
        throwsA(isA<RecoveryInputException>()),
      );
      expect(controller.running, false);
      expect(store.values, isEmpty);
      final private = BIP32.fromSeed(bip39.mnemonicToSeed(phraseA)).toBase58();
      expect(
        () => AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: private,
          target: target,
        ).validate(),
        throwsA(isA<RecoveryInputException>()),
      );
    },
  );

  test(
    'macOS recovery records use the encrypted database channel and export only matches',
    () async {
      const channel = MethodChannel('asterkeel/wallet_database');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final records = <String, String>{};
      Map? exported;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'needsMigration':
            return false;
          case 'recovery.save':
            records[call.arguments['id'] as String] =
                call.arguments['payload'] as String;
            return null;
          case 'recovery.list':
            return records.values.toList().reversed.toList();
          case 'recovery.export':
            exported = jsonDecode(call.arguments['payload'] as String) as Map;
            return null;
          default:
            throw StateError(call.method);
        }
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final vault = WalletVault(
        store: MapSecretStore({}),
        useMacWalletDatabase: true,
      );
      final controller = AddressRecoveryController(vault);
      addTearDown(controller.dispose);
      await controller.start(
        const AddressRecoveryInput(
          mnemonic: phraseA,
          xpub: '',
          target: target,
          mode: 'index',
          index: 0,
          end: 0,
        ),
      );
      await waitRecovery(() => !controller.running);
      expect(records, hasLength(1));
      final loaded = await vault.loadRecoveryTasks();
      expect(loaded.single['status'], 'standard_address_match');
      await vault.exportRecoveryMatches(
        '/synthetic/result.json',
        controller.selected!.matches,
      );
      expect(exported!['format'], 'asterkeel-recovery-results-v1');
      expect(exported.toString(), isNot(contains(phraseA)));
      expect(exported!['matches'], hasLength(1));
    },
  );
}
