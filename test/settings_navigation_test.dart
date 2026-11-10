import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'asset_test_helpers.dart';
import 'preferences_localization_test.dart' show launch, strings;
import 'stablecoin_test.dart' show phrase;
import 'widget_test.dart' show MapSecretStore;

void main() {
  test(
    'settings registry searches all languages and aliases without user values',
    () {
      for (final query in ['零余额', '零餘額', 'zero', 'hide zero']) {
        expect(searchSettings(query).any((e) => e.id == 'hide-zero'), isTrue);
      }
      for (final query in ['RPC', '节点', '節點']) {
        expect(searchSettings(query).any((e) => e.id == 'networks'), isTrue);
      }
      expect(
        searchSettings('API Key').map((e) => e.id),
        containsAll([
          'indexers',
          'provider-moralis',
          'provider-alchemy',
          'provider-trongrid',
        ]),
      );
      expect(searchSettings('iCloud').single.unavailable, isTrue);
      expect(searchSettings('abandon abandon'), isEmpty);
      expect(searchSettings('0x0485'), isEmpty);
      expect(searchSettings('https://'), isEmpty);
      expect(searchSettings('   '), isEmpty);
      expect(
        settingsEntries.map((e) => e.id).toSet().length,
        settingsEntries.length,
      );
    },
  );

  testWidgets(
    'directory stays compact; hierarchy and search return retain state',
    (tester) async {
      await launch(tester, MapSecretStore({WalletVault.mnemonicKey: phrase}));
      await assetTap(tester, find.byKey(const ValueKey('open-settings')));
      expect(
        find.byKey(const ValueKey('settings-search-entry')),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('https://'), findsNothing);
      expect(find.byKey(const ValueKey('indexer-api-key')), findsNothing);
      await settingsEntryTap(tester, 'assets');
      await settingsEntryTap(tester, 'display');
      expect(find.byType(AssetDisplayControls), findsOneWidget);
      await assetTap(tester, find.byType(BackButton));
      expect(
        find.byKey(const ValueKey('settings-entry-watched-tokens')),
        findsOneWidget,
      );
      await assetTap(tester, find.byType(BackButton));
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-search-entry')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('settings-search-field')),
        '零余额',
      );
      await tester.pumpAndSettle();
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-result-hide-zero')),
      );
      expect(
        find.byKey(const ValueKey('settings-target-hide-zero')).hitTestable(),
        findsOneWidget,
      );
      await assetTap(
        tester,
        find.widgetWithText(SwitchListTile, strings(tester).portfolioHideZero),
      );
      expect(assetPrefs(tester).value.hideZero, isFalse);
      await assetTap(tester, find.byType(BackButton));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings-search-field')),
            )
            .controller!
            .text,
        '零余额',
      );
      assetPrefs(tester).update(language: AppLanguage.en);
      await tester.pumpAndSettle();
      expect(find.text('Hide confirmed zero balances'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('settings-search-field')),
        'not-a-real-setting',
      );
      await tester.pumpAndSettle();
      expect(find.text(strings(tester).settingsNoResults), findsOneWidget);
      await assetTap(
        tester,
        find.widgetWithText(TextButton, strings(tester).settingsClearSearch),
      );
      expect(
        find.byKey(const ValueKey('settings-result-language')),
        findsOneWidget,
      );
      await exitSettings(tester);
      expect(find.byType(AssetsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide directory, resizing, language and appearance retain navigation',
    (tester) async {
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      await launch(tester, store, size: const Size(1200, 850));
      await assetTap(tester, find.byKey(const ValueKey('open-settings')));
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-nav-general')),
      );
      await settingsEntryTap(tester, 'language');
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-language-zhHant')),
      );
      expect(find.text('繁體中文'), findsWidgets);
      for (final width in [390.0, 760.0, 1099.0, 1100.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 850);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('settings-language-en')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await assetTap(tester, find.byType(BackButton));
      await settingsEntryTap(tester, 'appearance');
      await assetTap(tester, find.byKey(const ValueKey('settings-theme-dark')));
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('settings-theme-dark'))),
        ).brightness,
        Brightness.dark,
      );
      expect(
        find.byKey(const ValueKey('settings-theme-light')),
        findsOneWidget,
      );
      await exitSettings(tester);
      expect(
        AppPreferences.fromRecord(
          store.values[WalletVault.appPreferencesKey],
        ).language,
        AppLanguage.zhHant,
      );
    },
  );

  testWidgets(
    'system back traverses settings while desktop Assets exits the whole stack',
    (tester) async {
      await launch(tester, MapSecretStore({WalletVault.mnemonicKey: phrase}));
      await assetTap(tester, find.byKey(const ValueKey('open-settings')));
      await settingsEntryTap(tester, 'assets');
      await settingsEntryTap(tester, 'display');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-entry-watched-tokens')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-search-entry')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(1200, 850);
      await tester.pumpAndSettle();
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-nav-general')),
      );
      await settingsEntryTap(tester, 'language');
      await assetTap(
        tester,
        find.descendant(
          of: find.byType(WalletRail),
          matching: find.text(strings(tester).msgAssets),
        ),
      );
      expect(find.byType(AssetsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-hub')), findsNothing);
    },
  );

  testWidgets(
    'provider search opens the matching detail; key draft survives locale, theme and resize',
    (tester) async {
      await launch(tester, MapSecretStore({WalletVault.mnemonicKey: phrase}));
      await assetTap(tester, find.byKey(const ValueKey('open-settings')));
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-search-entry')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('settings-search-field')),
        'Alchemy',
      );
      await tester.pumpAndSettle();
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-result-provider-alchemy')),
      );
      expect(find.text(strings(tester).discoveryDocs), findsOneWidget);
      await assetTap(tester, find.byKey(const ValueKey('configure-alchemy')));
      await tester.enterText(
        find.byKey(const ValueKey('indexer-api-key')),
        'synthetic-secret-draft',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      for (final language in [
        AppLanguage.zhHant,
        AppLanguage.en,
        AppLanguage.zhHans,
      ]) {
        assetPrefs(tester).update(language: language);
        (tester.state(find.byType(StoneWalletApp)) as dynamic).toggleStyle();
        tester.view.physicalSize = Size(
          language == AppLanguage.en ? 1200 : 360,
          850,
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('indexer-api-key')))
              .controller!
              .text,
          'synthetic-secret-draft',
        );
        expect(tester.takeException(), isNull);
      }
      await assetTap(tester, find.byTooltip(strings(tester).msgClose));
      await assetTap(tester, find.byType(BackButton));
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('settings-search-field')),
            )
            .controller!
            .text,
        'Alchemy',
      );
      await exitSettings(tester);
    },
  );

  testWidgets(
    'asset display shortcut enters directly and settings persist without changing wallet records',
    (tester) async {
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      await launch(tester, store);
      final before = Map.of(store.values)
        ..remove(WalletVault.appPreferencesKey);
      await assetMenu(tester, MessageCode.portfolioDisplaySettings);
      expect(find.byType(AssetDisplayControls), findsOneWidget);
      await assetTap(
        tester,
        find.widgetWithText(SwitchListTile, strings(tester).portfolioShowSpam),
      );
      await exitSettings(tester);
      expect(store.values..remove(WalletVault.appPreferencesKey), before);
      // Restore a serialized preference record to verify cold-load compatibility.
      store.values[WalletVault.appPreferencesKey] = jsonEncode(
        assetPrefs(tester).value.toJson(),
      );
      expect(
        AppPreferences.fromRecord(
          store.values[WalletVault.appPreferencesKey],
        ).showSpam,
        isTrue,
      );
    },
  );
}
