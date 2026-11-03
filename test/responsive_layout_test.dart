import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'widget_test.dart' show EmptyStore, MapSecretStore;

const mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const render = bool.fromEnvironment('RENDER_LAYOUTS');
const renderFont = String.fromEnvironment('LAYOUT_FONT');
final captureKey = GlobalKey();

Future<void> viewport(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!render) return;
  await tester.pumpAndSettle();
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/layout-previews');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> app(
  WidgetTester tester, {
  bool loaded = false,
  bool dark = false,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: captureKey,
      child: StoneWalletApp(
        key: UniqueKey(),
        vault: WalletVault(
          store: loaded
              ? MapSecretStore({WalletVault.mnemonicKey: mnemonic})
              : EmptyStore(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (dark) {
    await tester.tap(find.byTooltip('切换主题'));
    await tester.pumpAndSettle();
  }
}

Future<void> navigateSettings(WidgetTester tester, bool mobile) async {
  await tester.tap(mobile ? find.text('设置') : find.byTooltip('设置'));
  await tester.pumpAndSettle();
}

Widget panelHarness(
  WidgetBuilder builder, {
  double width = 480,
  bool fullscreen = false,
  bool dismissible = true,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(
        onPressed: () => showWalletPanel<void>(
          context: context,
          width: width,
          mobileFullscreen: fullscreen,
          dismissible: dismissible,
          builder: builder,
        ),
        child: const Text('open'),
      ),
    ),
  ),
);

void main() {
  stressTests();
  setUpAll(() async {
    if (render && renderFont.isNotEmpty) {
      final bytes = await File(renderFont).readAsBytes();
      await (FontLoader(
        'Roboto',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  const sizes = [
    Size(1440, 900),
    Size(1200, 800),
    Size(800, 600),
    Size(390, 844),
    Size(360, 640),
    Size(759, 800),
    Size(760, 800),
    Size(999, 800),
    Size(1000, 800),
    Size(1099, 800),
    Size(1100, 800),
  ];
  for (final size in sizes) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}px ${dark ? 'dark' : 'light'} scale $scale: pages and overlays',
          (tester) async {
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await viewport(tester, size);
            await app(tester, dark: dark);
            final batch = find.text('批量导入私钥表格');
            expect(batch, findsOneWidget);
            if (scale == 1 &&
                (size == const Size(1200, 800) ||
                    size == const Size(390, 844))) {
              expect(
                batch.hitTestable(),
                findsOneWidget,
                reason: 'All welcome actions must fit the first viewport',
              );
              await capture(
                tester,
                '${size.width == 390 ? 'mobile' : 'desktop'}-welcome${dark ? '-dark' : ''}',
              );
            }
            await tester.ensureVisible(find.text('导入助记词'));
            await tester.tap(find.text('导入助记词'));
            await tester.pumpAndSettle();
            expect(find.byType(WalletPanel), findsOneWidget);
            expect(
              find.byType(Dialog),
              size.width >= 760 ? findsOneWidget : findsNothing,
            );
            if (!dark &&
                scale == 1 &&
                (size.width == 1200 || size.width == 390)) {
              await capture(
                tester,
                '${size.width == 390 ? 'mobile' : 'desktop'}-import',
              );
            }
            await tester.tap(find.byTooltip('关闭'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);

            await app(tester, loaded: true, dark: dark);
            expect(
              find.byType(WalletRail),
              size.width >= 760 ? findsOneWidget : findsNothing,
            );
            expect(
              find.byType(WalletBottomBar),
              size.width < 760 ? findsOneWidget : findsNothing,
            );
            final portfolioRect = tester.getRect(find.byType(PortfolioHero));
            final activityRect = tester.getRect(find.byType(ActivityPanel));
            if (size.width >= 1100) {
              expect(activityRect.left, greaterThan(portfolioRect.right));
            } else {
              expect(activityRect.top, greaterThan(portfolioRect.bottom));
            }
            if (scale == 1 && (size.width == 1200 || size.width == 390)) {
              await capture(
                tester,
                '${size.width == 390 ? 'mobile' : 'desktop'}-home${dark ? '-dark' : ''}',
              );
            }
            await tester.tap(find.text('选择网络'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('Ethereum Sepolia'));
            expect(find.text('保存网络选择'), findsNothing);
            expect(find.text('断开所有网络').hitTestable(), findsOneWidget);
            await tester.tap(find.byTooltip('关闭'));
            await tester.pumpAndSettle();
            await navigateSettings(tester, size.width < 760);
            expect(find.text('网络与 RPC'), findsOneWidget);
            if (scale == 1 && (size.width == 1200 || size.width == 390)) {
              await capture(
                tester,
                '${size.width == 390 ? 'mobile' : 'desktop'}-settings${dark ? '-dark' : ''}',
              );
            }
            await tester.ensureVisible(
              find.text('iCloud / Google Drive 云备份（暂未接入）'),
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
        );
      }
    }
  }

  testWidgets('resizing preserves the selected wallet and navigation', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await viewport(tester, const Size(1200, 800));
    await app(tester, loaded: true);
    await navigateSettings(tester, false);
    for (final width in [1099.0, 760.0, 759.0, 390.0, 1100.0]) {
      await viewport(tester, Size(width, 800));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('主钱包'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('100 wallets and import errors scroll without moving footer', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final account = WalletAccount.fromMnemonic(mnemonic);
    for (final size in [const Size(1200, 800), const Size(360, 640)]) {
      await viewport(tester, size);
      await tester.pumpWidget(
        panelHarness(
          (context) => WalletPicker(
            theme: WalletTheme.light,
            options: List.generate(
              100,
              (i) => WalletOption(
                name: '账户 $i',
                account: account,
                network: ethereumSepoliaNetwork,
              ),
            ),
            onSelect: (_) => Navigator.pop(context),
          ),
          width: 560,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('账户 99'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('账户 99'),
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('wallet-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('账户 99'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        panelHarness(
          (_) => ImportResultDialog(
            theme: WalletTheme.light,
            importedCount: 5,
            errors: List.generate(100, (i) => WalletImportError(i, '无效数据')),
          ),
          width: 640,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('知道了').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(find.text('第 99 条：无效数据'), 300);
      expect(find.text('知道了').hitTestable(), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('mobile keyboard keeps import and send actions accessible', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await viewport(tester, const Size(360, 640));
    for (final send in [false, true]) {
      await tester.pumpWidget(
        panelHarness(
          (_) => send
              ? SendSheet(
                  theme: WalletTheme.light,
                  network: ethereumSepoliaNetwork,
                  balanceWei: BigInt.zero,
                  onSend: (_, _) async => 'test',
                )
              : const ImportWalletDialog(theme: WalletTheme.light),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final button = find.text(send ? '签名并广播' : '导入');
      expect(button.hitTestable(), findsOneWidget);
      expect(tester.getRect(button).bottom, lessThan(340));
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(
        find.byType(TextField).first,
        send ? accountAddress : mnemonic,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'recovery uses mobile full screen, validates words before saving',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await viewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        panelHarness(
          (_) => const RecoveryPhraseSheet(
            theme: WalletTheme.light,
            mnemonic: mnemonic,
          ),
          width: 640,
          fullscreen: true,
          dismissible: false,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byTooltip('关闭'), findsNothing);
      await tester.tap(find.text('我已记录，继续验证'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('验证并进入钱包'));
      await tester.pumpAndSettle();
      expect(find.text('助记词校验不正确，请重新核对第 2、6、10 个单词。'), findsOneWidget);
      for (final field in find.byType(TextField).evaluate().toList()) {
        await tester.enterText(find.byWidget(field.widget), 'abandon');
      }
      await tester.tap(find.text('验证并进入钱包'));
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryPhraseSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

const accountAddress = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';

// Additional stress cases are kept outside the matrix so their failure is easy to identify.
void stressTests() {
  testWidgets('long network labels, RPC URLs and addresses wrap', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final network = EvmNetwork(
      id: 1,
      name: 'Ethereum Sepolia with a very long network display name',
      nativeSymbol: 'ETH',
      rpcUrl: 'https://example.invalid/${'long-path/' * 20}',
      explorerUrl: '',
      isTestnet: true,
    );
    for (final size in [
      const Size(360, 640),
      const Size(800, 600),
      const Size(1200, 800),
    ]) {
      await viewport(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    WalletHeader(
                      theme: WalletTheme.light,
                      walletName: '很长的钱包名称' * 10,
                      address: accountAddress,
                      networkLabel: network.name,
                      onWalletTap: () {},
                      onToggleStyle: () {},
                      onNetworkTap: () {},
                    ),
                    SettingsPage(
                      theme: WalletTheme.light,
                      address: accountAddress,
                      networks: [network],
                      currentNetwork: network,
                      networkServices: const {},
                      responsiveNetworkIds: const {},
                      onManageNetworks: () {},
                      onBatchImport: () {},
                      onRefresh: () async {},
                      onToggleStyle: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'desktop Escape closes ordinary panels and a busy send stays open',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await viewport(tester, const Size(1200, 800));
      await tester.pumpWidget(
        panelHarness((_) => const ImportWalletDialog(theme: WalletTheme.light)),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(WalletPanel), findsNothing);
      final completion = Completer<String>();
      await tester.pumpWidget(
        panelHarness(
          (_) => SendSheet(
            theme: WalletTheme.light,
            network: ethereumSepoliaNetwork,
            balanceWei: parseEtherToWei('1'),
            onSend: (_, _) => completion.future,
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, accountAddress);
      await tester.enterText(find.byType(TextField).last, '0.1');
      await tester.tap(find.text('签名并广播'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(SendSheet), findsOneWidget);
      expect(find.byTooltip('关闭'), findsNothing);
      completion.completeError(const WalletInputException('测试网络不可用'));
      await tester.pumpAndSettle();
      expect(find.text('测试网络不可用'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching to the mnemonic wallet actually changes the active address',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await viewport(tester, const Size(1200, 800));
      final privateKey = '1'.padLeft(64, '0');
      await tester.pumpWidget(
        StoneWalletApp(
          vault: WalletVault(
            store: MapSecretStore({
              WalletVault.mnemonicKey: mnemonic,
              WalletVault.privateKeyWalletsKey: jsonEncode([
                {'chainId': 1, 'privateKey': privateKey},
              ]),
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('私钥账户 1'), findsOneWidget);
      await tester.tap(find.text('私钥账户 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('主钱包'));
      await tester.pumpAndSettle();
      expect(find.text(shortAddress(accountAddress)), findsOneWidget);
      expect(find.text('主钱包'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
