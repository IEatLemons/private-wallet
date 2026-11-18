import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/preferences.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'asset_test_helpers.dart';
import 'network_management_test.dart' show RpcFixture;
import 'widget_test.dart' show MapSecretStore;

MapSecretStore fixtureStore(int count) => MapSecretStore({
  WalletVault.walletBookKey: jsonEncode({
    'version': 2,
    'activeAccountId': 'fixture-000:0',
    'groups': [
      for (var i = 0; i < count; i++)
        {
          'id': 'fixture-${i.toString().padLeft(3, '0')}',
          'name': 'Platform · ${i.toString().padLeft(4, '0')}',
          'kind': 'privateKey',
          'networkId': 56,
          'secret': '1'.padLeft(64, '0'),
          'accounts': [
            {'index': 0, 'name': '账户 1'},
          ],
        },
    ],
  }),
  WalletVault.selectedNetworkKey: '56',
});

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('RENDER_MANAGEMENT')) {
      await (FontLoader('Roboto')..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '/System/Library/Fonts/STHeiti Light.ttc',
                ).readAsBytes(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  for (final (width, dark, scale) in [
    (1200.0, false, 1.0),
    (390.0, false, 1.0),
    (1200.0, true, 1.3),
    (390.0, true, 1.3),
  ]) {
    testWidgets(
      'management filters, previews and removes all matches at $width dark=$dark scale=$scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 850);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final store = fixtureStore(146);
        store.values[WalletVault.appPreferencesKey] = jsonEncode(
          AppPreferences(
            appearance: dark ? AppAppearance.dark : AppAppearance.light,
          ).toJson(),
        );
        final vault = WalletVault(store: store), rpc = RpcFixture();
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: StoneWalletApp(
              vault: vault,
              quoteService: TestQuoteService(),
              networkServiceBuilder: rpc.service,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rail = find.byType(WalletRail);
        final railElement = width > 760 ? tester.element(rail) : null;
        if (width > 760) {
          await assetTap(
            tester,
            find.byKey(const ValueKey('wallet-nav-wallets')),
          );
        } else {
          await assetTap(tester, find.text('Platform · 0000'));
          await assetTap(
            tester,
            find.byKey(const ValueKey('quick-manage-wallets')),
          );
        }
        expect(
          find.byKey(const ValueKey('wallet-management-page')),
          findsOneWidget,
        );
        expect(find.text('146 个钱包'), findsOneWidget);
        if (railElement != null) {
          expect(tester.element(rail), same(railElement));
        }
        if (const bool.fromEnvironment('RENDER_MANAGEMENT')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage();
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/asterkeel-management-$width-$dark.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.enterText(
          find.byKey(const ValueKey('manage-search')),
          'Platform · 014',
        );
        await tester.pumpAndSettle();
        expect(find.text('6 个钱包'), findsOneWidget);
        await assetTap(tester, find.byKey(const ValueKey('manage-select-all')));
        expect(find.text('已选 6 个'), findsOneWidget);
        await assetTap(
          tester,
          find.byKey(const ValueKey('manage-delete-selected')),
        );
        expect(find.text('删除 6 个钱包、6 个账户'), findsOneWidget);
        await assetTap(tester, find.text('取消'));
        expect((await vault.loadWalletSummary()).groupCount, 146);
        await assetTap(
          tester,
          find.byKey(const ValueKey('manage-delete-selected')),
        );
        await assetTap(
          tester,
          find.byKey(const ValueKey('manage-confirm-delete')),
        );
        expect((await vault.loadWalletSummary()).groupCount, 140);
        expect(
          (await vault.loadWalletSummary()).activeAccountId,
          'fixture-000:0',
        );
        expect(await vault.loadSelectedNetworkId(), 56);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'deleting the current wallet selects the next and deleting the last returns to welcome',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final vault = WalletVault(store: fixtureStore(2));
      await tester.pumpWidget(
        StoneWalletApp(
          vault: vault,
          quoteService: TestQuoteService(),
          networkServiceBuilder: RpcFixture().service,
        ),
      );
      await tester.pumpAndSettle();
      await assetTap(tester, find.byKey(const ValueKey('wallet-nav-wallets')));
      await assetTap(
        tester,
        find.byKey(const ValueKey('manage-wallet-fixture-000')),
      );
      await assetTap(
        tester,
        find.byKey(const ValueKey('manage-delete-wallet')),
      );
      expect(find.textContaining('包含当前账户'), findsOneWidget);
      await assetTap(
        tester,
        find.byKey(const ValueKey('manage-confirm-delete')),
      );
      expect(
        (await vault.loadWalletSummary()).activeAccountId,
        'fixture-001:0',
      );
      await assetTap(tester, find.byKey(const ValueKey('manage-select-all')));
      await assetTap(
        tester,
        find.byKey(const ValueKey('manage-delete-selected')),
      );
      await assetTap(
        tester,
        find.byKey(const ValueKey('manage-confirm-delete')),
      );
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect((await vault.loadWalletSummary()).groupCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
