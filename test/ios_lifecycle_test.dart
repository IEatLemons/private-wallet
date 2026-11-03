import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'widget_test.dart' show MapSecretStore;

const testPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

class FixedCreationVault extends WalletVault {
  FixedCreationVault() : super(store: MapSecretStore({}));
  @override
  Future<WalletCreation> prepareNewWallet() async => WalletCreation(
    mnemonic: testPhrase,
    account: WalletAccount.fromMnemonic(testPhrase),
  );
}

class DisposalProbe extends StatefulWidget {
  const DisposalProbe({required this.onDispose, super.key});
  final VoidCallback onDispose;
  @override
  State<DisposalProbe> createState() => _DisposalProbeState();
}

class _DisposalProbeState extends State<DisposalProbe> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: WalletTheme.light,
    title: 'probe',
    footer: FilledButton(
      onPressed: () => Navigator.pop(context, 'done'),
      child: const Text('finish'),
    ),
    child: TextField(controller: controller),
  );
}

void main() {
  for (final width in [402.0, 1200.0]) {
    testWidgets('panel result waits for input disposal at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 874);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var disposed = false;
      bool? disposedWhenReturned;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await showWalletPanel<String>(
                    context: context,
                    builder: (_) =>
                        DisposalProbe(onDispose: () => disposed = true),
                  );
                  disposedWhenReturned = disposed;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'synthetic');
      await tester.tap(find.text('finish'));
      await tester.pumpAndSettle();
      expect(
        disposedWhenReturned,
        isTrue,
        reason:
            'Do not replace the underlying page while the dismissed input route is still mounted',
      );
    });
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(StoneWalletApp(vault: FixedCreationVault()));
    await tester.pumpAndSettle();
  }

  testWidgets('iOS mnemonic route opens without starting native text input', (
    tester,
  ) async {
    await start(tester);
    await tester.ensureVisible(find.text('导入助记词'));
    await tester.tap(find.text('导入助记词'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'iOS creation replaces recovery words with focused fields and closes route',
    (tester) async {
      await start(tester);
      await tester.ensureVisible(find.text('创建新钱包'));
      await tester.tap(find.text('创建新钱包'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我已记录，继续验证'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pump();
      for (final field in find.byType(TextField).evaluate().toList()) {
        await tester.enterText(find.byWidget(field.widget), 'abandon');
      }
      await tester.tap(find.text('验证并进入钱包'));
      await tester.pump();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryPhraseSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS dismisses focused imports and switches theme without inherited dependents',
    (tester) async {
      await start(tester);
      for (var pass = 0; pass < 3; pass++) {
        for (final label in ['导入助记词', '导入私钥']) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(TextField).first);
          await tester.enterText(
            find.byType(TextField).first,
            'synthetic-test',
          );
          tester.view.viewInsets = const FakeViewPadding(bottom: 336);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('关闭'));
          await tester.pump();
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.ensureVisible(find.byTooltip('切换主题'));
        await tester.tap(find.byTooltip('切换主题'));
        await tester.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS quickly closes imports during keyboard and route animations',
    (tester) async {
      await start(tester);
      for (final label in ['导入助记词', '导入私钥']) {
        for (final delay in [0, 50, 150]) {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pump();
          await tester.pump(Duration(milliseconds: delay));
          tester.view.viewInsets = const FakeViewPadding(bottom: 336);
          await tester.pump();
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '关闭',
                ),
              )
              .onPressed!();
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('iOS closes imports with text selection toolbar visible', (
    tester,
  ) async {
    await start(tester);
    for (final label in ['导入助记词', '导入私钥']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'synthetic input for selection',
      );
      await tester.longPress(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS swipe-dismisses imports with focused text fields', (
    tester,
  ) async {
    await start(tester);
    for (final label in ['导入助记词', '导入私钥']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'synthetic');
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(WalletPanel), const Offset(0, 700));
      await tester.pump();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      if (find.byTooltip('关闭').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'iOS mnemonic import closes focused bottom sheet and opens home',
    (tester) async {
      await start(tester);
      await tester.ensureVisible(find.text('导入助记词'));
      await tester.tap(find.text('导入助记词'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), testPhrase);
      tester.view.viewInsets = const FakeViewPadding(bottom: 336);
      await tester.pumpAndSettle();
      await tester.tap(find.text('导入'));
      await tester.pump();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
