part of '../main.dart';

enum _OmniPanelResult { legacy }

class _OmniVaultImportPanel extends StatefulWidget {
  const _OmniVaultImportPanel({
    required this.theme,
    required this.vault,
    required this.path,
    required this.accountName,
    required this.onCommitted,
  });

  final WalletTheme theme;
  final WalletVault vault;
  final String path, accountName;
  final Future<void> Function(OmniImportCommit) onCommitted;

  @override
  State<_OmniVaultImportPanel> createState() => _OmniVaultImportPanelState();
}

class _OmniVaultImportPanelState extends State<_OmniVaultImportPanel> {
  OmniVaultPreview? _preview;
  Map<OmniImportStatus, int>? _counts;
  OmniImportCommit? _committed;
  WalletMessage? _error;
  OmniImportStatus? _filter;
  List<OmniImportRow> _rows = const [];
  final _cursors = [0];
  int _read = 0;
  int _request = 0;
  bool _hasNext = false;
  bool _busy = false;
  bool _loading = false;
  bool _closing = false;
  bool _finished = false;
  Future<void>? _opening;
  DateTime? _lastProgress;

  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<void> _open() async {
    try {
      final preview = await widget.vault.beginOmniVaultPreview(
        widget.path,
        accountName: widget.accountName,
        onProgress: (count) {
          if (!mounted || _closing) return;
          final now = DateTime.now();
          if (_lastProgress case final last?
              when now.difference(last).inMilliseconds < 150) {
            return;
          }
          _lastProgress = now;
          setState(() => _read = count);
        },
      );
      _preview = preview;
      _opening = null;
      if (!mounted || _closing) {
        await preview.close();
        return;
      }
      final counts = await preview.ready;
      if (!mounted || _closing) return;
      if (counts == null) {
        await _close(_OmniPanelResult.legacy);
      } else {
        setState(() => _counts = counts);
        await _load();
      }
    } catch (error) {
      if (!mounted || _closing) return;
      setState(() => _error = walletMessage(error));
      try {
        await _preview?.close();
      } catch (_) {
        if (mounted && !_closing) {
          setState(
            () => _error = const WalletMessage(MessageCode.omniStorageError),
          );
        }
      }
    }
  }

  Future<void> _close([_OmniPanelResult? result]) async {
    if (_closing) return;
    setState(() => _closing = true);
    _request++;
    try {
      if (_preview == null) await _opening;
      await _preview?.close();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized(context, walletMessage(error)))),
        );
      }
    }
    if (!mounted) return;
    _finished = true;
    closeWalletPanel(context, result);
  }

  @override
  void dispose() {
    if (!_finished && _preview != null) {
      unawaited(_preview!.close().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final rows = await _preview!.page(after: _cursors.last, status: _filter);
      if (!mounted || request != _request) return;
      setState(() {
        _hasNext = rows.length > 50;
        _rows = rows.take(50).toList();
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = walletMessage(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _commit() async {
    setState(() => _busy = true);
    try {
      final result = await _preview!.commit();
      if (!mounted) return;
      setState(() => _committed = result);
      await widget.onCommitted(result);
    } catch (error) {
      if (mounted) setState(() => _error = walletMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _status(AppLocalizations s, OmniImportStatus status) =>
      switch (status) {
        OmniImportStatus.newWallet => s.omniNewWallet,
        OmniImportStatus.alias => s.omniAliasesAdded,
        OmniImportStatus.duplicate => s.omniDuplicates,
        OmniImportStatus.skipped => s.omniSkipped,
        OmniImportStatus.failed => s.omniFailed,
      };

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final theme = widget.theme;
    final counts = _counts;
    final committed = _committed;
    final canImport =
        counts != null &&
        (counts[OmniImportStatus.newWallet] ?? 0) +
                (counts[OmniImportStatus.alias] ?? 0) >
            0;
    final disabled = _busy || _closing;
    return WalletPanel(
      theme: theme,
      title: committed == null ? s.omniImportTitle : s.omniImportResult,
      canClose: false,
      scrollBody: false,
      footer: Wrap(
        spacing: 12,
        children: [
          OutlinedButton(
            onPressed: disabled ? null : () => _close(),
            child: Text(
              committed != null || _error != null
                  ? s.msgDone
                  : MaterialLocalizations.of(context).cancelButtonLabel,
            ),
          ),
          if (committed == null && canImport)
            FilledButton(
              key: const ValueKey('omni-confirm-import'),
              onPressed: disabled || _error != null || _loading
                  ? null
                  : _commit,
              child: Text(s.omniConfirm),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_closing || _busy || (counts == null && _error == null))
            const LinearProgressIndicator(),
          if (counts == null && _error == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s.omniReading(_read)),
            ),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                localized(context, error),
                style: TextStyle(color: theme.danger),
              ),
            ),
          if (counts != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final status in <OmniImportStatus?>[
                  null,
                  ...OmniImportStatus.values,
                ])
                  ChoiceChip(
                    label: Text(
                      status == null
                          ? s.omniAllRows
                          : '${_status(s, status)} ${counts[status] ?? 0}',
                    ),
                    selected: _filter == status,
                    onSelected: disabled
                        ? null
                        : (_) {
                            setState(() {
                              _filter = status;
                              _cursors.removeRange(1, _cursors.length);
                            });
                            unawaited(_load());
                          },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SizedBox(
                height: 330,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _rows.isEmpty
                    ? Center(child: Text(s.omniNoRows))
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (_, index) {
                          final row = _rows[index];
                          final subtitle = [
                            if (row.platform != null)
                              '${row.platform} · ${row.uid}',
                            if (row.networkId != null)
                              row.networkId == tronMainnetNetwork.id
                                  ? 'TRON'
                                  : 'BSC',
                            if (row.address != null) row.address!,
                            if (row.error != null) tr(context, row.error!),
                          ].join('  ·  ');
                          return ListTile(
                            dense: true,
                            title: Text(
                              '${s.omniLine(row.line)} · ${_status(s, row.status)}',
                            ),
                            subtitle: subtitle.isEmpty ? null : Text(subtitle),
                          );
                        },
                      ),
              ),
            ),
            _WalletPageButtons(
              previous: _cursors.length > 1 && !_loading && !disabled
                  ? () {
                      _cursors.removeLast();
                      unawaited(_load());
                    }
                  : null,
              next: _hasNext && !_loading && !disabled
                  ? () {
                      _cursors.add(_rows.last.line);
                      unawaited(_load());
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletPageButtons extends StatelessWidget {
  const _WalletPageButtons({this.previous, this.next});
  final VoidCallback? previous, next;

  @override
  Widget build(BuildContext context) {
    if (previous == null && next == null) return const SizedBox.shrink();
    final s = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: s.omniPreviousPage,
          onPressed: previous,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: s.omniNextPage,
          onPressed: next,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WalletAliasesPanel extends StatefulWidget {
  const _WalletAliasesPanel({
    required this.theme,
    required this.vault,
    required this.group,
  });

  final WalletTheme theme;
  final WalletVault vault;
  final WalletGroup group;

  @override
  State<_WalletAliasesPanel> createState() => _WalletAliasesPanelState();
}

class _WalletAliasesPanelState extends State<_WalletAliasesPanel> {
  final _cursors = [0];
  late Future<List<WalletAlias>> _rows = _get();

  Future<List<WalletAlias>> _get() =>
      widget.vault.loadWalletAliases(widget.group.id, after: _cursors.last);

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: AppLocalizations.of(context).omniWalletAliases,
    subtitle: widget.group.name,
    scrollBody: false,
    child: FutureBuilder<List<WalletAlias>>(
      future: _rows,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(localized(context, walletMessage(snapshot.error!)));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final aliases = snapshot.requireData;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SizedBox(
                height: 320,
                child: ListView.builder(
                  itemCount: aliases.length.clamp(0, 50),
                  itemBuilder: (context, index) =>
                      ListTile(dense: true, title: Text(aliases[index].name)),
                ),
              ),
            ),
            _WalletPageButtons(
              previous: _cursors.length > 1
                  ? () => setState(() {
                      _cursors.removeLast();
                      _rows = _get();
                    })
                  : null,
              next: aliases.length > 50
                  ? () => setState(() {
                      _cursors.add(aliases[49].id);
                      _rows = _get();
                    })
                  : null,
            ),
          ],
        );
      },
    ),
  );
}
