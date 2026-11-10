part of '../main.dart';

class AssetDisplayControls extends StatelessWidget {
  const AssetDisplayControls({required this.theme, this.wrap, super.key});
  final Widget Function(String, Widget)? wrap;
  final WalletTheme theme;
  @override
  Widget build(BuildContext context) {
    final controller = AppSettingsScope.of(context), p = controller.value;
    Widget choice<T>(
      String id,
      String label,
      T value,
      List<DropdownMenuItem<T>> items,
      ValueChanged<T> select,
    ) => (wrap ?? (_, child) => child)(
      id,
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: TextStyle(color: theme.muted, fontSize: 12)),
            DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: items,
              onChanged: (v) {
                if (v != null) select(v);
              },
            ),
          ],
        ),
      ),
    );
    Widget option(String id, Widget child) =>
        (wrap ?? (_, child) => child)(id, child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        choice(
          'display-mode',
          tr(context, MessageCode.portfolioDisplayMode),
          p.display,
          [
            for (final v in AssetDisplay.values)
              DropdownMenuItem(
                value: v,
                child: Text(
                  tr(
                    context,
                    v == AssetDisplay.simple
                        ? MessageCode.portfolioSimple
                        : MessageCode.portfolioDetailed,
                  ),
                ),
              ),
          ],
          (v) => controller.update(display: v),
        ),
        choice(
          'initial-count',
          tr(context, MessageCode.portfolioInitialCount),
          p.limit,
          [
            for (final v in [3, 5, 10, 0])
              DropdownMenuItem(
                value: v,
                child: Text(
                  v == 0
                      ? tr(context, MessageCode.portfolioAll)
                      : localized(context, v),
                ),
              ),
          ],
          (v) => controller.update(limit: v),
        ),
        choice('sort', tr(context, MessageCode.portfolioSort), p.sort, [
          for (final v in AssetSort.values)
            DropdownMenuItem(
              value: v,
              child: Text(
                tr(context, switch (v) {
                  AssetSort.value => MessageCode.portfolioSortValue,
                  AssetSort.stableFirst => MessageCode.portfolioStableFirst,
                  AssetSort.name => MessageCode.portfolioSortName,
                }),
              ),
            ),
        ], (v) => controller.update(sort: v)),
        option(
          'hide-zero',
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr(context, MessageCode.portfolioHideZero),
              style: const TextStyle(fontSize: 14),
            ),
            value: p.hideZero,
            onChanged: (v) => controller.update(hideZero: v),
          ),
        ),
        option(
          'show-spam',
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr(context, MessageCode.portfolioShowSpam),
              style: const TextStyle(fontSize: 14),
            ),
            value: p.showSpam,
            onChanged: (v) => controller.update(showSpam: v),
          ),
        ),
      ],
    );
  }
}

Future<void> openServiceLink(BuildContext context, String url) async {
  try {
    if (await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder(
          builder: (context) =>
              Text(tr(context, MessageCode.discoveryLinkCopied)),
        ),
      ),
    );
  }
}

class IndexerConfigPanel extends StatefulWidget {
  const IndexerConfigPanel({
    required this.theme,
    required this.descriptor,
    required this.networks,
    required this.onSave,
    required this.onTest,
    this.initial,
    super.key,
  });
  final WalletTheme theme;
  final IndexerDescriptor descriptor;
  final IndexerConfig? initial;
  final List<EvmNetwork> networks;
  final Future<void> Function(IndexerConfig) onSave;
  final Future<void> Function(IndexerConfig, EvmNetwork) onTest;
  @override
  State<IndexerConfigPanel> createState() => _IndexerConfigPanelState();
}

class _IndexerConfigPanelState extends State<IndexerConfigPanel> {
  late final keyController = TextEditingController(
    text: widget.initial?.apiKey ?? '',
  );
  late final selected = <int>{
    ...widget.initial?.networkIds.where(
          (id) => widget.networks.any((n) => n.id == id),
        ) ??
        widget.networks.map((n) => n.id),
  };
  bool busy = false, connected = false;
  WalletMessage? error;
  @override
  void dispose() {
    keyController.dispose();
    super.dispose();
  }

  WalletTheme get theme => Theme.of(context).brightness == Brightness.dark
      ? WalletTheme.dark
      : WalletTheme.light;

  Future<void> submit({required bool save}) async {
    if (busy) return;
    try {
      final key = keyController.text.trim();
      if (key.isEmpty || key.length > 1024 || RegExp(r'\s').hasMatch(key)) {
        throw const WalletInputException(MessageCode.discoveryKeyRequired);
      }
      if (selected.isEmpty) {
        throw const WalletInputException(MessageCode.discoveryChooseNetwork);
      }
      final config = IndexerConfig(
        provider: widget.descriptor.provider,
        apiKey: key,
        networkIds: selected,
      );
      setState(() {
        busy = true;
        error = null;
        connected = false;
      });
      if (save) {
        await widget.onSave(config);
        if (mounted) closeWalletPanel(context, true);
      } else {
        for (final n in widget.networks.where((n) => selected.contains(n.id))) {
          await widget.onTest(config, n);
        }
        if (mounted) setState(() => connected = true);
      }
    } catch (e) {
      if (mounted) setState(() => error = walletMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: WalletPanel(
      theme: theme,
      title: tr(context, MessageCode.discoveryConfigureProvider, [
        widget.descriptor.name,
      ]),
      canClose: !busy,
      footer: FilledButton(
        key: const ValueKey('save-indexer'),
        onPressed: busy ? null : () => submit(save: true),
        child: Text(
          tr(
            context,
            busy ? MessageCode.msgProcessing : MessageCode.discoverySaveEnable,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, widget.descriptor.guide),
            style: TextStyle(color: theme.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('indexer-api-key'),
            controller: keyController,
            enabled: !busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            onChanged: (_) => setState(() => connected = false),
            decoration: InputDecoration(
              labelText: tr(context, MessageCode.discoveryApiKey),
              helperText: tr(context, MessageCode.discoveryKeyHint),
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(context, MessageCode.discoveryAssignments),
            style: TextStyle(color: theme.muted, fontSize: 13),
          ),
          for (final n in widget.networks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(n.name),
              value: selected.contains(n.id),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      v == true ? selected.add(n.id) : selected.remove(n.id);
                      connected = false;
                    }),
            ),
          OutlinedButton(
            key: const ValueKey('test-indexer'),
            onPressed: busy ? null : () => submit(save: false),
            child: Text(tr(context, MessageCode.discoveryTest)),
          ),
          if (connected)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                tr(context, MessageCode.discoveryConnected),
                style: TextStyle(color: theme.primary),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                localized(context, error),
                style: TextStyle(color: theme.danger),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            tr(context, MessageCode.discoveryPrivacy),
            style: TextStyle(color: theme.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
