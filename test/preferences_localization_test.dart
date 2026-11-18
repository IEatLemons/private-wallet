import 'asset_test_helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/l10n/generated/app_localizations.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';

import 'network_management_test.dart' show tap;
import 'stablecoin_test.dart' show TokenRpc, phrase;
import 'widget_test.dart' show MapSecretStore;

class LocalizedCreationVault extends WalletVault {
  LocalizedCreationVault(MapSecretStore store) : super(store: store);
  @override
  Future<WalletCreation> prepareNewWallet() async => WalletCreation(
    mnemonic: phrase,
    account: WalletAccount.fromMnemonic(phrase),
  );
}

const preview = bool.fromEnvironment('RENDER_LOCALES');
final previewKey = GlobalKey();
PreferencesController prefs(WidgetTester tester) => AppSettingsScope.of(
  tester.element(find.byType(WalletShell, skipOffstage: false)),
);
AppLocalizations strings(WidgetTester tester) => AppLocalizations.of(
  tester.element(find.byType(WalletShell, skipOffstage: false)),
);

Future<void> launch(
  WidgetTester tester,
  MapSecretStore store, {
  Size size = const Size(390, 844),
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final vault = WalletVault(store: store);
  await vault.saveSelectedNetworks([
    ethereumMainnetNetwork,
    bnbSmartChainNetwork,
    tronMainnetNetwork,
    polygonMainnetNetwork,
  ]);
  await tester.pumpWidget(
    RepaintBoundary(
      key: previewKey,
      child: StoneWalletApp(
        quoteService: TestQuoteService(),
        vault: vault,
        networkServiceBuilder: TokenRpc().service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (dark) {
    (tester.state(find.byType(StoneWalletApp)) as dynamic).toggleStyle();
    await tester.pumpAndSettle();
  }
}

Future<void> captureLocale(WidgetTester tester, String name) async {
  if (!preview) return;
  final boundary =
      previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/locale-previews');
    await dir.create(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (preview) {
      final font = ByteData.sublistView(
        await File('/System/Library/Fonts/STHeiti Light.ttc').readAsBytes(),
      );
      await (FontLoader('Roboto')..addFont(Future.value(font))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  test(
    'invalid preference fields fall back independently; unsupported categories stay hidden',
    () {
      for (final raw in [null, 'broken', '[]', '{"version":99}']) {
        expect(
          AppPreferences.fromRecord(raw).toJson(),
          const AppPreferences().toJson(),
        );
      }
      final p = AppPreferences.fromRecord(
        '{"version":1,"language":"zhHant","category":"nft","family":"USDC"}',
      );
      expect(p.language, AppLanguage.zhHant);
      expect(p.category, AssetCategory.stablecoins);
      expect(p.family, 'USDC');
      expect(
        AppPreferences.fromRecord(
          '{"language":42,"category":"tokens","family":"bad"}',
        ).category,
        AssetCategory.tokens,
      );
      expect(availableAssetCategories, [
        AssetCategory.stablecoins,
        AssetCategory.tokens,
      ]);
    },
  );

  test(
    'preference writes merge and serialize; a failed save does not break later saves or wallet records',
    () async {
      final gate = Completer<void>(), writes = <String>[];
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      final controller = PreferencesController(
        read: () async => null,
        write: (record) async {
          writes.add(record);
          if (writes.length == 1) {
            await gate.future;
            throw StateError('storage unavailable');
          }
          await WalletVault(store: store).writeAppPreferences(record);
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.update(language: AppLanguage.en);
      controller.update(category: AssetCategory.tokens);
      controller.update(family: 'USDC');
      await Future<void>.delayed(Duration.zero);
      expect(writes, hasLength(1));
      gate.complete();
      await controller.settled;
      expect(writes, hasLength(3));
      expect(controller.saveFailed, false);
      final restored = AppPreferences.fromRecord(
        store.values[WalletVault.appPreferencesKey],
      );
      expect(restored.language, AppLanguage.en);
      expect(restored.category, AssetCategory.tokens);
      expect(restored.family, 'USDC');
      expect(store.values[WalletVault.mnemonicKey], phrase);
      expect(store.values.keys.toSet(), {
        WalletVault.mnemonicKey,
        WalletVault.appPreferencesKey,
      });
    },
  );

  test(
    'locale resolution distinguishes script and Chinese regions and falls back to English',
    () {
      for (final locale in [
        const Locale('zh', 'TW'),
        const Locale('zh', 'HK'),
        const Locale('zh', 'MO'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        expect(
          resolveWalletLocale([
            locale,
          ], AppLocalizations.supportedLocales).scriptCode,
          'Hant',
        );
      }
      for (final locale in [
        const Locale('zh', 'CN'),
        const Locale('zh', 'SG'),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ]) {
        expect(
          resolveWalletLocale([locale], AppLocalizations.supportedLocales),
          const Locale('zh'),
        );
      }
      expect(
        resolveWalletLocale([
          const Locale('ja'),
        ], AppLocalizations.supportedLocales),
        const Locale('en'),
      );
    },
  );

  test('all ARB keys and placeholder types are complete across locales', () {
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    final keys = en.keys.where((k) => !k.toString().startsWith('@')).toSet();
    for (final locale in ['zh', 'zh_Hant']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map;
      expect(
        arb.keys.where((k) => !k.toString().startsWith('@')).toSet(),
        keys,
      );
      for (final key in keys) {
        expect(arb[key], isNotEmpty, reason: '$locale.$key');
        final placeholders =
            (en['@$key'] as Map?)?['placeholders'] as Map? ?? {};
        final actual = (arb['@$key'] as Map?)?['placeholders'] as Map? ?? {};
        expect(actual, placeholders, reason: '$locale.$key placeholders');
        for (final name in placeholders.keys) {
          expect(arb[key], contains('{$name'), reason: '$locale.$key.$name');
        }
      }
    }
  });

  testWidgets(
    'assets are the only home; settings return preserves category, search, scroll and account',
    (tester) async {
      final store = MapSecretStore({
        WalletVault.mnemonicKey: phrase,
        WalletVault.appPreferencesKey: 'broken preferences',
      });
      await launch(tester, store, size: const Size(390, 400));
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('portfolio-total')), findsOneWidget);
      expect(find.text('首页'), findsNothing);
      expect(find.text('NFT'), findsNothing);
      expect(find.text('RWA'), findsNothing);
      prefs(tester).update(
        selectedAssetId: 'usdc',
        filter: AssetFilter.tokens,
        hideZero: false,
        limit: 0,
      );
      await tester.pumpAndSettle();
      await assetMenu(tester, MessageCode.portfolioSearch);
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pumpAndSettle();
      final assetsState = tester.state(find.byType(AssetsPage));
      final controller = tester
          .widget<Scrollable>(find.byType(Scrollable).first)
          .controller!;
      controller.jumpTo(20);
      await tester.pump();
      final offset = controller.offset;
      final selectedAddress = tester
          .widget<WalletHeader>(find.byType(WalletHeader))
          .address;
      // Header is intentionally kept at the top of the asset scroller.
      await tap(tester, find.byKey(const ValueKey('open-settings')));
      prefs(tester).update(language: AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-hub')), findsOneWidget);
      expect(
        find.byType(AssetsPage),
        findsNothing,
      ); // The route remains mounted offstage.
      await tap(tester, find.byType(BackButton));
      expect(tester.state(find.byType(AssetsPage)), same(assetsState));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text ??
            tester
                .widget<EditableText>(find.byType(EditableText))
                .controller
                .text,
        'e',
      );
      expect(
        tester.widget<WalletHeader>(find.byType(WalletHeader)).address,
        selectedAddress,
      );
      expect(prefs(tester).value.filter, AssetFilter.tokens);
      expect(prefs(tester).value.selectedAssetId, 'usdc');
      controller.jumpTo(offset);
      await tester.pump();
      // Opening settings programmatically at a scrolled offset must not reset it.
      final shell =
          tester.state(find.byType(WalletShell, skipOffstage: false))
              as dynamic;
      // UI invocation uses the same route callback and does not alter the scroller.
      final header = tester.widget<WalletHeader>(find.byType(WalletHeader));
      header.onSettings();
      await tester.pumpAndSettle();
      await tap(tester, find.byType(BackButton));
      expect(controller.offset, offset);
      expect(shell.mounted, true);
      await prefs(tester).settled;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await launch(tester, store);
      expect(strings(tester).localeName, 'en');
      expect(prefs(tester).value.filter, AssetFilter.tokens);
      prefs(tester).update(filter: AssetFilter.all, view: AssetView.coin);
      await tester.pumpAndSettle();
      expect(prefs(tester).value.selectedAssetId, 'usdc');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'system and manual locale changes preserve import input, validation and network selection',
    (tester) async {
      tester.platformDispatcher.localesTestValue = [const Locale('zh', 'HK')];
      final store = MapSecretStore({});
      await tester.pumpWidget(
        StoneWalletApp(
          quoteService: TestQuoteService(),
          vault: WalletVault(store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(strings(tester).localeName, 'zh_Hant');
      await tap(tester, find.byKey(const ValueKey('language-menu')));
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<AppLanguage>, 'English'),
      );
      await tester.pumpAndSettle();
      expect(strings(tester).localeName, 'en');
      await tap(tester, find.text('Import private key'));
      await tester.enterText(
        find.byKey(const ValueKey('private-key-input')),
        'synthetic-invalid',
      );
      final dropdown = find.byType(DropdownButtonFormField<int>);
      await tap(tester, dropdown);
      await tap(tester, find.text('Ethereum Sepolia · Testnet').last);
      await tap(tester, find.text('Import and open wallet'));
      expect(
        find.text('Invalid private key. Enter 64 hexadecimal characters.'),
        findsOneWidget,
      );
      final state = tester.state(find.byType(ImportPrivateKeyPanel));
      prefs(tester).update(language: AppLanguage.zhHans);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(ImportPrivateKeyPanel)), same(state));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('private-key-input')))
            .controller!
            .text,
        'synthetic-invalid',
      );
      expect(find.text('Ethereum Sepolia · 测试网'), findsOneWidget);
      expect(find.text('私钥无效，应为 64 位十六进制字符串。'), findsOneWidget);
      prefs(tester).update(language: AppLanguage.system);
      tester.platformDispatcher.localesTestValue = [const Locale('ja')];
      await tester.pumpAndSettle();
      expect(strings(tester).localeName, 'en');
      await tap(tester, find.byTooltip('Close'));
      await tap(tester, find.text('Import recovery phrase'));
      await tester.enterText(find.byType(TextField), phrase);
      prefs(tester).update(language: AppLanguage.zhHant);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        phrase,
      );
      await tap(tester, find.text(strings(tester).msgImport));
      expect(find.byType(AssetsPage), findsOneWidget);
      expect(
        (await WalletVault(store: store).loadPortfolio()).groups.single.name,
        '主錢包',
      );
      prefs(tester).update(language: AppLanguage.en);
      await tester.pumpAndSettle();
      expect(
        find.text('主錢包'),
        findsOneWidget,
      ); // Persisted names never retranslate.
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in [
    AppLanguage.zhHans,
    AppLanguage.zhHant,
    AppLanguage.en,
  ]) {
    testWidgets(
      '${language.name}: create, derive and continue private-key import use local default names and return to assets',
      (tester) async {
        final store = MapSecretStore({
          WalletVault.appPreferencesKey: jsonEncode(
            AppPreferences(language: language).toJson(),
          ),
        });
        final vault = LocalizedCreationVault(store);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          StoneWalletApp(
            quoteService: TestQuoteService(),
            vault: vault,
            networkServiceBuilder: TokenRpc().service,
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.text(strings(tester).msgCreateWallet));
        expect(find.textContaining('abandon'), findsWidgets);
        await tap(tester, find.text(strings(tester).msgIWroteItDownVerify));
        for (final element in find.byType(TextField).evaluate().toList()) {
          await tester.enterText(find.byWidget(element.widget), 'abandon');
        }
        await tap(tester, find.text(strings(tester).msgVerifyAndOpenWallet));
        expect(find.byType(AssetsPage), findsOneWidget);
        var book = await vault.loadPortfolio();
        expect(book.groups.single.name, strings(tester).msgMainWallet);
        expect(book.selected!.name, strings(tester).msgAccountMore('1'));
        await tap(tester, find.text(book.groups.single.name));
        await tap(tester, find.byKey(const ValueKey('quick-manage-wallets')));
        await tap(
          tester,
          find.byKey(ValueKey('manage-wallet-${book.groups.single.id}')),
        );
        await tap(
          tester,
          find.byKey(ValueKey('derive-account-${book.groups.single.id}')),
        );
        book = await vault.loadPortfolio();
        expect(book.selected!.name, strings(tester).msgAccountMore('2'));
        await tap(tester, find.byIcon(Icons.arrow_back));
        expect(find.byType(AssetsPage), findsOneWidget);
        await tap(tester, find.byKey(const ValueKey('open-settings')));
        await settingsEntryTap(tester, 'wallets');
        await settingsEntryTap(tester, 'import-wallet');
        await tap(tester, find.text(strings(tester).msgImportPrivateKey));
        await tap(tester, find.byType(DropdownButtonFormField<int>));
        await tap(
          tester,
          find.text('Ethereum · ${strings(tester).msgMainnet}').last,
        );
        await tester.enterText(
          find.byKey(const ValueKey('private-key-input')),
          '1'.padLeft(64, '0'),
        );
        await tap(tester, find.text(strings(tester).msgImportAndOpenWallet));
        book = await vault.loadPortfolio();
        expect(book.groups, hasLength(2));
        expect(book.accounts, hasLength(3));
        expect(
          book.selected!.groupName,
          strings(tester).msgPrivateKeyAccount('1'),
        );
        expect(find.byKey(const ValueKey('settings-hub')), findsNothing);
        expect(find.byType(ImportPrivateKeyPanel), findsNothing);
        expect(find.byType(AssetsPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'uncertain broadcast hash, fields and disabled resubmission survive language changes',
    (tester) async {
      final controller = PreferencesController(
        read: () async => null,
        write: (_) async {},
      );
      await controller.load();
      addTearDown(controller.dispose);
      var calls = 0;
      final broadcast = Completer<String>();
      const hash =
          '0x111122223333444455556666777788889999aaaabbbbccccddddeeeeffff0000';
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: controller,
          builder: (_, _) => MaterialApp(
            locale: selectedLocale(controller.value.language),
            localeListResolutionCallback: resolveWalletLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SendSheet(
                theme: WalletTheme.light,
                network: ethereumMainnetNetwork,
                balanceWei: parseEtherToWei('1000'),
                onSend: (_, _) async {
                  calls++;
                  return broadcast.future;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        WalletAccount.fromMnemonic(phrase).checksumAddress,
      );
      await tester.enterText(
        find.byType(TextField).last,
        '0.123456789012345678',
      );
      await tester.tap(find.text('签名并广播'));
      await tester.pump();
      controller.update(language: AppLanguage.en);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        false,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      broadcast.completeError(RpcBroadcastException(hash));
      await tester.pumpAndSettle();
      expect(find.textContaining(hash), findsOneWidget);
      final state = tester.state(find.byType(SendSheet));
      for (final language in [
        AppLanguage.en,
        AppLanguage.zhHant,
        AppLanguage.zhHans,
      ]) {
        controller.update(language: language);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SendSheet)), same(state));
        expect(find.textContaining(hash), findsOneWidget);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          '0.123456789012345678',
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      }
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large amounts group as strings without floating point rounding; English quantities use plurals',
    (tester) async {
      await launch(tester, MapSecretStore({WalletVault.mnemonicKey: phrase}));
      prefs(tester).update(language: AppLanguage.en);
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AssetsPage));
      expect(
        displayQuantity(
          context,
          '123456789012345678901234.123456789012345678 USDT',
        ),
        '123,456,789,012,345,678,901,234.123456789012345678 USDT',
      );
      expect(displayQuantity(context, '< 0.000001'), '< 0.000001');
      expect(
        strings(tester).endpointCount(1),
        '1 endpoint · Automatic failover',
      );
      expect(
        strings(tester).endpointCount(2),
        '2 endpoints · Automatic failover',
      );
    },
  );

  for (final language in [
    AppLanguage.zhHans,
    AppLanguage.zhHant,
    AppLanguage.en,
  ]) {
    for (final config in [
      (const Size(390, 844), false, 1.0),
      (const Size(360, 740), true, 1.3),
      (const Size(1200, 850), false, 1.3),
    ]) {
      testWidgets(
        '${language.name} ${config.$1.width} dark=${config.$2} scale=${config.$3} preview and all messages',
        (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = config.$3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final store = MapSecretStore({
            WalletVault.mnemonicKey: phrase,
            WalletVault.appPreferencesKey: jsonEncode(
              AppPreferences(language: language).toJson(),
            ),
          });
          await launch(tester, store, size: config.$1, dark: config.$2);
          final context = tester.element(find.byType(AssetsPage));
          final arb =
              jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
          for (final code in MessageCode.values) {
            final placeholders =
                (arb['@${code.name}'] as Map?)?['placeholders'] as Map? ?? {};
            final args = placeholders.values
                .map<Object>((p) => (p as Map)['type'] == 'int' ? 2 : 'USDT')
                .toList();
            expect(
              tr(context, code, args),
              isNotEmpty,
              reason: '${language.name}.${code.name}',
            );
          }
          expect(find.byKey(const ValueKey('portfolio-total')), findsOneWidget);
          expect(find.byType(BottomNavigationBar), findsNothing);
          expect(find.byType(NavigationBar), findsNothing);
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-assets',
          );
          await tap(tester, find.byKey(const ValueKey('open-settings')));
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-settings',
          );
          await settingsEntryTap(tester, 'display');
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-settings-display',
          );
          await tap(tester, find.byType(BackButton));
          await tap(
            tester,
            find.byKey(const ValueKey('settings-search-entry')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('settings-search-field')),
            'API Key',
          );
          await tester.pumpAndSettle();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-settings-search',
          );
          await exitSettings(tester);
          await selectCoin(tester, 'usdt');
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-coins',
          );
          await assetMenu(tester, MessageCode.discoveryServices);
          await captureLocale(
            tester,
            '${language.name}-${config.$1.width.toInt()}-indexers',
          );
          await exitSettings(tester);

          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
