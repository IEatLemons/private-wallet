import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:bip32/bip32.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/address_recovery.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart' show RpcFixture, start, tap;
import 'wallet_management_test.dart' show phraseA;
import 'widget_test.dart' show MapSecretStore;

Future<void> pumpRecovery(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!done()) {
      if (DateTime.now().isAfter(end)) {
        throw StateError('Recovery UI did not finish');
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await tester.pump();
    }
  });
  await tester.pump();
}

void main() {
  for (final size in [const Size(1200, 900), const Size(390, 844)]) {
    testWidgets(
      'dedicated recovery view starts sequential search and hides private output at ${size.width}',
      (tester) async {
        final vault = WalletVault(
          store: MapSecretStore({WalletVault.mnemonicKey: phraseA}),
        );
        await start(tester, vault, RpcFixture(), size: size);
        final preview = GlobalKey();
        if (const bool.fromEnvironment('RENDER_RECOVERY')) {
          final app = tester.widget<StoneWalletApp>(
            find.byType(StoneWalletApp),
          );
          await tester.pumpWidget(RepaintBoundary(key: preview, child: app));
          await tester.pumpAndSettle();
        }
        final entry = size.width > 800
            ? find.byKey(const ValueKey('wallet-nav-recovery'))
            : find.byKey(const ValueKey('open-recovery'));
        await tap(tester, entry);
        expect(find.byType(AddressRecoveryPage), findsOneWidget);
        final page = tester.widget<AddressRecoveryPage>(
          find.byType(AddressRecoveryPage),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('recovery-mnemonic')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('recovery-mnemonic')),
          phraseA,
        );
        final pub = BIP32
            .fromSeed(bip39.mnemonicToSeed(phraseA))
            .derivePath("m/44'/60'/0'/0")
            .neutered()
            .toBase58();
        await tester.enterText(
          find.byKey(const ValueKey('recovery-xpub')),
          pub,
        );
        await tester.enterText(
          find.byKey(const ValueKey('recovery-target')),
          '0x9858effd232b4033e47d90003d41ec34ecaeda94',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('recovery-start-task')),
        );
        await tester.tap(find.byKey(const ValueKey('recovery-start-task')));
        await tester.pump();
        await pumpRecovery(
          tester,
          () =>
              page.controller.selected?.status == 'standard_address_match' &&
              !page.controller.running,
        );
        await tester.pumpAndSettle();
        expect(page.controller.selected!.checked, 3);
        if (const bool.fromEnvironment('RENDER_RECOVERY')) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('recovery-mnemonic')),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                preview.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final capture = await boundary.toImage(pixelRatio: 1);
            final bytes = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/asterkeel-recovery-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          });
        }
        final secret =
            page.controller.selected!.matches.single['derived_private_key']
                as String;
        expect(find.text(secret), findsNothing);
        await tap(tester, find.byKey(const ValueKey('recovery-reveal-0')));
        expect(find.text(secret), findsOneWidget);
        expect(find.textContaining('配置的 xPub 在所选索引下匹配标准目标地址'), findsOneWidget);
        expect(find.byKey(const ValueKey('recovery-export')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'search continues across pages and can pause from the recovery workspace',
    (tester) async {
      final vault = WalletVault(
        store: MapSecretStore({WalletVault.mnemonicKey: phraseA}),
      );
      await start(tester, vault, RpcFixture(), size: const Size(1200, 900));
      await tap(tester, find.byKey(const ValueKey('wallet-nav-recovery')));
      final controller = tester
          .widget<AddressRecoveryPage>(find.byType(AddressRecoveryPage))
          .controller;
      await tester.runAsync(
        () => controller.start(
          const AddressRecoveryInput(
            mnemonic: phraseA,
            xpub: '',
            target: '0xe4079dbbc13d661736562ad156c90dce0fa4f705',
            mode: 'index',
            cpuPercent: 10,
            end: 10000,
          ),
        ),
      );
      await pumpRecovery(tester, () => controller.selected!.checked > 0);
      await tester.tap(find.byKey(const ValueKey('wallet-nav-assets')));
      await tester.pump();
      final checked = controller.selected!.checked;
      await pumpRecovery(tester, () => controller.selected!.checked > checked);
      expect(controller.running, true);
      expect(find.byType(AddressRecoveryPage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('wallet-nav-recovery')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('recovery-pause')));
      await tester.tap(find.byKey(const ValueKey('recovery-pause')));
      await tester.pump();
      await pumpRecovery(tester, () => !controller.running);
      await tester.pumpAndSettle();
      expect(controller.selected!.status, 'paused');
      expect(find.byKey(const ValueKey('recovery-resume')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recovery workspace is available before creating an ordinary wallet',
    (tester) async {
      final vault = WalletVault(store: MapSecretStore({}));
      await start(tester, vault, RpcFixture(), size: const Size(390, 844));
      await tap(tester, find.byKey(const ValueKey('onboarding-recovery')));
      expect(find.byType(AddressRecoveryPage), findsOneWidget);
      expect(find.byKey(const ValueKey('recovery-mnemonic')), findsOneWidget);
      expect((await vault.loadPortfolio()).accounts, isEmpty);
      await tap(tester, find.byType(BackButton));
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
