part of '../main.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({
    required this.theme,
    required this.error,
    required this.onCreate,
    required this.onImport,
    required this.onImportPrivateKey,
    required this.onBatchImport,
    this.supportsOmniVault = false,
    this.onAddressPool,
    required this.onToggleStyle,
    super.key,
  });
  final WalletTheme theme;
  final bool supportsOmniVault;
  final VoidCallback? onAddressPool;
  final WalletMessage? error;
  final VoidCallback onCreate,
      onImport,
      onImportPrivateKey,
      onBatchImport,
      onToggleStyle;

  Widget _intro(BuildContext context, bool mobile) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr(context, MessageCode.msgSelfCustodyEvmTron),
        style: TextStyle(
          color: theme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        tr(context, MessageCode.msgYourKeysYourWallet),
        style: TextStyle(
          color: theme.text,
          fontSize: mobile ? 30 : 40,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        tr(context, MessageCode.msgManageYourOnchainAssetsCreateAWalletOr),
        style: TextStyle(color: theme.muted, fontSize: 15, height: 1.7),
      ),
    ],
  );

  Widget _features(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _NoticeLine(
        theme: theme,
        icon: Icons.key_outlined,
        title: tr(context, MessageCode.msgSelfCustodyWallet),
        detail: tr(
          context,
          MessageCode.msgTransactionsAreSignedOnThisDeviceYouControl,
        ),
      ),
      const SizedBox(height: 20),
      _NoticeLine(
        theme: theme,
        icon: Icons.lock_outline,
        title: tr(context, MessageCode.msgSecureDeviceStorage),
        detail: tr(
          context,
          MessageCode.msgRecoveryCredentialsStayInThisDeviceSSecure,
        ),
      ),
      const SizedBox(height: 20),
      _NoticeLine(
        theme: theme,
        icon: Icons.public,
        title: tr(context, MessageCode.msgChooseYourNetworks),
        detail: tr(
          context,
          MessageCode.msgRpcConnectionsStartOnlyAfterYouEnableA,
        ),
      ),
    ],
  );

  Widget _actions(BuildContext context, bool mobile) => WalletCard(
    theme: theme,
    padding: EdgeInsets.all(mobile ? 20 : 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(context, MessageCode.msgGetStartedWithWallet),
          style: TextStyle(
            color: theme.text,
            fontSize: mobile ? 20 : 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(context, MessageCode.msgChooseHowToGetStarted),
          style: TextStyle(color: theme.muted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr(context, MessageCode.msgCreateWallet)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(tr(context, MessageCode.msgImportRecoveryPhrase)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onImportPrivateKey,
          icon: const Icon(Icons.vpn_key_outlined, size: 18),
          label: Text(tr(context, MessageCode.msgImportPrivateKey)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onBatchImport,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(tr(context, MessageCode.msgImportPrivateKeyFile)),
        ),
        const SizedBox(height: 12),
        Text(
          supportsOmniVault
              ? AppLocalizations.of(context).omniFileHint
              : tr(context, MessageCode.msgCsvTsvColumnsChainPrivateKey),
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.5),
        ),
        if (onAddressPool != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAddressPool,
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(AppLocalizations.of(context).omniPoolTitle),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            localized(context, error!),
            style: TextStyle(color: theme.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        Divider(color: theme.border, height: 1),
        const SizedBox(height: 16),
        Text(
          tr(context, MessageCode.msgKeepYourRecoveryPhraseAndPrivateKeysSafe),
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );

  Widget _mobileFeatures(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    alignment: WrapAlignment.center,
    children: [
      for (final feature in [
        (Icons.key_outlined, tr(context, MessageCode.msgSelfCustodyWallet)),
        (Icons.lock_outline, tr(context, MessageCode.msgSecureDeviceStorage)),
        (Icons.public, tr(context, MessageCode.msgChooseYourNetworks)),
      ])
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(feature.$1, color: theme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              localized(context, feature.$2),
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
          ],
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final layout = WalletLayout(constraints.maxWidth);
      final horizontal = layout.mobile ? 20.0 : 40.0;
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: layout.splitWelcome ? 1120 : 640,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandMark(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context).appName,
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const LanguageMenuButton(),
                      ],
                    ),
                    SizedBox(height: layout.mobile ? 32 : 24),
                    if (layout.splitWelcome)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 144).clamp(
                            0,
                            800,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _intro(context, false),
                                  const SizedBox(height: 32),
                                  _features(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 64),
                            SizedBox(
                              width: 400,
                              child: _actions(context, false),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _intro(context, layout.mobile),
                      const SizedBox(height: 24),
                      _actions(context, layout.mobile),
                      const SizedBox(height: 28),
                      layout.mobile
                          ? _mobileFeatures(context)
                          : _features(context),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NoticeLine extends StatelessWidget {
  const _NoticeLine({
    required this.theme,
    required this.icon,
    required this.title,
    required this.detail,
  });
  final WalletTheme theme;
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surfaceStrong,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localized(context, title),
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localized(context, detail),
              style: TextStyle(color: theme.muted, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}
