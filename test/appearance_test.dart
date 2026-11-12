import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'asset_test_helpers.dart';
import 'preferences_localization_test.dart' show launch;
import 'stablecoin_test.dart' show phrase;
import 'widget_test.dart' show MapSecretStore;

Brightness brightness(WidgetTester tester) => Theme.of(
  tester.element(find.byKey(const ValueKey('settings-theme-system'))),
).brightness;

void main() {
  test(
    'appearance defaults safely and serializes alongside other preferences',
    () async {
      for (final raw in [
        null,
        '{"version":1}',
        '{"version":1,"appearance":"invalid"}',
        '{"version":1,"appearance":42}',
      ]) {
        expect(AppPreferences.fromRecord(raw).appearance, AppAppearance.system);
      }
      for (final appearance in AppAppearance.values) {
        final record = jsonEncode(
          AppPreferences(appearance: appearance).toJson(),
        );
        expect(AppPreferences.fromRecord(record).appearance, appearance);
      }
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      final vault = WalletVault(store: store);
      final controller = PreferencesController(
        read: vault.readAppPreferences,
        write: vault.writeAppPreferences,
      );
      addTearDown(controller.dispose);
      await controller.load();
      controller.update(appearance: AppAppearance.dark);
      controller.update(language: AppLanguage.zhHant);
      controller.update(limit: 10);
      await controller.settled;
      final restored = AppPreferences.fromRecord(
        await vault.readAppPreferences(),
      );
      expect(restored.appearance, AppAppearance.dark);
      expect(restored.language, AppLanguage.zhHant);
      expect(restored.limit, 10);
      expect(store.values[WalletVault.mnemonicKey], phrase);
    },
  );

  testWidgets(
    'system theme updates live; manual overrides, navigation and restart persist',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final store = MapSecretStore({WalletVault.mnemonicKey: phrase});
      await launch(tester, store);
      final assetState = tester.state(find.byType(AssetsPage));
      final account = tester
          .widget<WalletHeader>(find.byType(WalletHeader))
          .address;
      await assetTap(tester, find.byKey(const ValueKey('open-settings')));
      await settingsEntryTap(tester, 'general');
      await settingsEntryTap(tester, 'appearance');
      for (final mode in ['system', 'light', 'dark']) {
        expect(find.byKey(ValueKey('settings-theme-$mode')), findsOneWidget);
      }
      expect(assetPrefs(tester).value.appearance, AppAppearance.system);
      expect(brightness(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-theme-light')),
      );
      expect(brightness(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
      await assetTap(tester, find.byKey(const ValueKey('settings-theme-dark')));
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      await assetTap(
        tester,
        find.byKey(const ValueKey('settings-theme-system')),
      );
      expect(brightness(tester), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.dark);
      await assetTap(tester, find.byType(BackButton));
      // The summary describes the selected mode, even while system brightness is dark.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('settings-entry-appearance')),
          matching: find.text('跟随系统'),
        ),
        findsOneWidget,
      );
      await exitSettings(tester);
      expect(tester.state(find.byType(AssetsPage)), same(assetState));
      expect(
        tester.widget<WalletHeader>(find.byType(WalletHeader)).address,
        account,
      );
      await assetPrefs(tester).settled;
      expect(
        AppPreferences.fromRecord(
          store.values[WalletVault.appPreferencesKey],
        ).appearance,
        AppAppearance.system,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await launch(tester, store);
      expect(assetPrefs(tester).value.appearance, AppAppearance.system);
      expect(
        Theme.of(tester.element(find.byType(AssetsPage))).brightness,
        Brightness.dark,
      );
      assetPrefs(tester).update(appearance: AppAppearance.light);
      await tester.pumpAndSettle();
      await assetPrefs(tester).settled;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await launch(tester, store);
      expect(assetPrefs(tester).value.appearance, AppAppearance.light);
      expect(
        Theme.of(tester.element(find.byType(AssetsPage))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
