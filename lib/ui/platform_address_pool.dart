part of '../main.dart';

class _OmniPoolPage extends StatefulWidget {
  const _OmniPoolPage({required this.vault, this.active = true, this.onBack});
  final WalletVault vault;
  final bool active;
  final VoidCallback? onBack;

  @override
  State<_OmniPoolPage> createState() => _OmniPoolPageState();
}

class _OmniPoolPageState extends State<_OmniPoolPage> {
  late final pools = OmniAddressPools(widget.vault);
  bool started = false;
  AppLocalizations get strings => AppLocalizations.of(context);
  OmniPoolConnection? connection;
  OmniPoolDevice? device;
  List<Map<String, Object?>> platforms = [];
  List<Map<String, Object?>> batches = [];
  Map<String, Object?> snapshot = {};
  String? platform;
  String chain = '';
  String generationChain = 'bsc';
  String filter = '';
  String search = '';
  bool showBatches = false;
  int batchPage = 0;
  final addressSearch = TextEditingController();
  int page = 0;
  bool hasSeed = false;
  bool busy = false;
  bool setup = false;
  String? error;
  final url = TextEditingController();
  final key = TextEditingController();
  final fingerprint = TextEditingController();
  final count = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    startWhenVisible();
  }

  @override
  void didUpdateWidget(covariant _OmniPoolPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    startWhenVisible();
  }

  void startWhenVisible() {
    if (!widget.active || started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(run(load));
    });
  }

  @override
  void dispose() {
    for (final field in [url, key, fingerprint, count, addressSearch]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on AddressPoolException catch (failure) {
      if (mounted) error = failure.code;
    } catch (_) {
      if (mounted) error = 'unknown';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    device = await pools.device();
    final saved = await pools.connection();
    if (!mounted) return;
    connection = saved;
    setup = saved == null;
    if (saved != null) {
      url.text = saved.origin.origin;
      key.text = saved.publicKey;
      fingerprint.text = saved.fingerprint;
      await loadPlatforms(saved);
    }
  }

  Future<void> loadPlatforms(OmniPoolConnection saved) async {
    final result = await pools.platforms(saved);
    if (!mounted) return;
    platforms = result;
    if (!platforms.any((row) => row['code'] == platform)) {
      selectPlatform(platforms.firstOrNull?['code'] as String?);
    }
    await readLocal();
    await syncIfNeeded();
  }

  void selectPlatform(String? value) {
    platform = value;
    hasSeed = false;
    batches = [];
    snapshot = {};
    search = '';
    addressSearch.clear();
    page = 0;
    batchPage = 0;
    showBatches = false;
  }

  Future<void> syncIfNeeded() async {
    final c = connection, p = platform;
    if (!mounted || c == null || p == null || snapshot.isNotEmpty) return;
    await sync(c, p);
  }

  Future<void> sync(OmniPoolConnection c, String p) async {
    await pools.sync(c, p);
    await readLocal();
    page = 0;
  }

  Future<void> readLocal() async {
    final c = connection, p = platform;
    if (c == null || p == null) {
      batches = [];
      snapshot = {};
      hasSeed = false;
      return;
    }
    final exists = await pools.hasSeed(c, p);
    final list = await pools.batches(c, p);
    final data = await pools.snapshot(c, p);
    if (!mounted) return;
    hasSeed = exists;
    batches = list;
    snapshot = data;
  }

  Future<void> saveConnection() => run(() async {
    final id = device?.id;
    if (id == null) return;
    final next = OmniPoolConnection(url.text, id, key.text, fingerprint.text);
    await pools.connect(next);
    if (!mounted) return;
    connection = next;
    setup = false;
    selectPlatform(null);
    await loadPlatforms(next);
  });

  Future<void> initialize({required bool create}) => run(() async {
    final c = connection!, p = platform!;
    final mnemonic = create ? pools.newMnemonic() : null;
    final confirmed = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OmniPoolSecretDialog(mnemonic: mnemonic),
    );
    if (confirmed == null || !mounted) return;
    await pools.initialize(c, p, confirmed);
    await readLocal();
  });

  Future<void> backup({required bool restore}) => run(() async {
    final c = connection!, p = platform!;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => _OmniPoolSecretDialog(restore: restore),
    );
    if (passphrase == null || !mounted) return;
    if (restore) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['akpool'],
      );
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      await pools.restore(c, p, File(path), passphrase);
    } else {
      final path = await FilePicker.platform.saveFile(
        fileName:
            'asterkeel-address-pool-${DateTime.now().millisecondsSinceEpoch}.akpool',
        type: FileType.custom,
        allowedExtensions: const ['akpool'],
      );
      if (path == null || !mounted) return;
      await pools.backup(c, p, File(path), passphrase);
    }
    await readLocal();
  });

  String errorText(String code) => switch (code) {
    'access' => strings.omniPoolAccessError,
    'connection' => strings.omniPoolConnectionError,
    'backup_required' => strings.omniPoolNeedsBackup,
    'backup' || 'passphrase' => strings.omniPoolBackupError,
    'network' => strings.omniPoolNetworkError,
    'binding' || 'signature' || 'response' => strings.omniPoolVerificationError,
    'range' || 'input' => strings.omniPoolInputError,
    _ => strings.omniPoolError,
  };

  Widget connectionForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(strings.omniPoolSetupHelp),
      if (device case final identity?) ...[
        const SizedBox(height: 12),
        SelectableText('${strings.omniPoolDevice}: ${identity.id}'),
        SelectableText(
          '${strings.omniPoolFingerprint}: ${identity.fingerprint}',
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => Clipboard.setData(
                    ClipboardData(text: identity.publicKey),
                  ),
            icon: const Icon(Icons.copy_outlined),
            label: Text(strings.omniPoolCopyPublicKey),
          ),
        ),
      ],
      TextField(
        enabled: !busy,
        controller: url,
        decoration: const InputDecoration(labelText: 'HTTPS URL'),
      ),
      TextField(
        enabled: !busy,
        controller: key,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(labelText: strings.omniPoolServerKey),
      ),
      TextField(
        enabled: !busy,
        controller: fingerprint,
        decoration: InputDecoration(labelText: strings.omniPoolFingerprint),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            onPressed: busy ? null : saveConnection,
            child: Text(strings.omniPoolConnect),
          ),
          if (connection != null)
            TextButton(
              onPressed: busy ? null : () => setState(() => setup = false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
        ],
      ),
    ],
  );

  Widget platformView() {
    final c = connection, p = platform;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (platforms.isNotEmpty)
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(('omni-platform', platform)),
                  initialValue: platform,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: strings.omniPoolPlatform,
                  ),
                  items: [
                    for (final item in platforms)
                      DropdownMenuItem(
                        value: item['code'] as String,
                        child: Text(
                          "${item['name']} · ${item['code']}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => run(() async {
                          if (value == platform) return;
                          selectPlatform(value);
                          await readLocal();
                          await syncIfNeeded();
                        }),
                ),
              )
            else
              Text(strings.omniPoolNoPlatforms),
            if (c != null && p != null)
              OutlinedButton.icon(
                onPressed: busy ? null : () => run(() => sync(c, p)),
                icon: const Icon(Icons.sync),
                label: Text(strings.omniPoolSync),
              ),
            if (c != null)
              PopupMenuButton<String>(
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                enabled: !busy,
                onSelected: (action) {
                  if (action == 'connect') {
                    setState(() => setup = true);
                  } else {
                    unawaited(run(() => loadPlatforms(c)));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Text(strings.omniPoolRefreshPlatforms),
                  ),
                  PopupMenuItem(
                    value: 'connect',
                    child: Text(strings.omniPoolConnection),
                  ),
                ],
              ),
          ],
        ),
        if (c != null && p != null) ...[
          ...inventorySummary(),
          const SizedBox(height: 20),
          if (!hasSeed)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: busy ? null : () => initialize(create: true),
                  child: Text(strings.omniPoolCreate),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => initialize(create: false),
                  child: Text(strings.msgImportRecoveryPhrase),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => backup(restore: true),
                  child: Text(strings.omniPoolRestore),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(('omni-batch-chain', generationChain)),
                    initialValue: generationChain,
                    decoration: InputDecoration(
                      labelText: strings.omniPoolChain,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bsc', child: Text('BSC')),
                      DropdownMenuItem(value: 'tron', child: Text('TRON')),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => generationChain = value!),
                  ),
                ),
                SizedBox(
                  width: 132,
                  child: TextField(
                    controller: count,
                    enabled: !busy,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: strings.omniPoolCount,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await pools.generate(
                            c,
                            p,
                            generationChain,
                            int.tryParse(count.text) ?? 0,
                          );
                          showBatches = true;
                          batchPage = 0;
                          await readLocal();
                        }),
                  child: Text(strings.omniPoolGenerate),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => backup(restore: false),
                  child: Text(strings.omniPoolBackup),
                ),
              ],
            ),
          const SizedBox(height: 20),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: Text(strings.omniPoolAddresses),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.layers_outlined),
                  label: Text(strings.omniPoolBatches),
                ),
              ],
              selected: {showBatches},
              onSelectionChanged: (value) =>
                  setState(() => showBatches = value.single),
            ),
          ),
          const SizedBox(height: 12),
          if (showBatches) ...batchList(c, p) else ...inventory(),
        ] else if (!busy)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              strings.omniPoolSetupHelp,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  List<Widget> inventorySummary() {
    final rows = (snapshot['inventory'] as List?)?.cast<Map>() ?? [];
    final theme = Theme.of(context);
    return [
      const SizedBox(height: 16),
      for (final chain in ['bsc', 'tron'])
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Builder(
            builder: (_) {
              final item = rows
                  .where((row) => row['chain'] == chain)
                  .firstOrNull;
              final low =
                  item != null &&
                  (item['available'] as int) < (item['threshold'] as int);
              return Text(
                "${chain.toUpperCase()} · ${strings.omniPoolAvailable} ${item?['available'] ?? '—'} · ${strings.omniPoolAllocated} ${item?['allocated'] ?? '—'} · ${strings.omniPoolThreshold} ${item?['threshold'] ?? '—'}",
                style: low
                    ? TextStyle(color: theme.colorScheme.error)
                    : theme.textTheme.bodyMedium,
              );
            },
          ),
        ),
    ];
  }

  List<Widget> batchList(OmniPoolConnection c, String p) {
    if (batches.isEmpty) return [Text(strings.omniNoRows)];
    const perPage = 20;
    return [
      pagination(
        batchPage,
        batches.length,
        perPage,
        (next) => batchPage = next,
      ),
      for (final item in batches.skip(batchPage * perPage).take(perPage))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "${item['chain'].toString().toUpperCase()} · ${(item['id'] as String).substring(0, 12)}",
          ),
          subtitle: Text(
            item['uploaded'] == 1
                ? strings.omniPoolUploaded
                : item['backed_up'] == 1
                ? strings.omniPoolReady
                : strings.omniPoolNeedsBackup,
          ),
          trailing: item['uploaded'] == 1
              ? null
              : TextButton(
                  onPressed: busy || item['backed_up'] != 1
                      ? null
                      : () => run(() async {
                          await pools.upload(c, p, item['id'] as String);
                          await readLocal();
                          await sync(c, p);
                        }),
                  child: Text(strings.omniPoolUpload),
                ),
        ),
    ];
  }

  Widget pagination(
    int current,
    int length,
    int pageSize,
    ValueChanged<int> change,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$length'),
      IconButton(
        tooltip: strings.omniPreviousPage,
        onPressed: current == 0
            ? null
            : () => setState(() => change(current - 1)),
        icon: const Icon(Icons.navigate_before),
      ),
      IconButton(
        tooltip: strings.omniNextPage,
        onPressed: (current + 1) * pageSize >= length
            ? null
            : () => setState(() => change(current + 1)),
        icon: const Icon(Icons.navigate_next),
      ),
    ],
  );

  List<Widget> inventory() {
    const pageSize = 40;
    final addresses = ((snapshot['addresses'] as List?)?.cast<Map>() ?? [])
        .where(
          (row) =>
              (chain.isEmpty || row['chain'] == chain) &&
              (filter.isEmpty || row['state'] == filter) &&
              (search.isEmpty ||
                  ['address', 'owner'].any(
                    (field) => (row[field] as String? ?? '')
                        .toLowerCase()
                        .contains(search),
                  )),
        )
        .toList();
    String stateLabel(String state) => switch (state) {
      'available' => strings.omniPoolAvailable,
      'allocated' => strings.omniPoolAllocated,
      'disabled' => strings.omniPoolDisabled,
      _ => strings.omniAllRows,
    };
    return [
      TextField(
        controller: addressSearch,
        onChanged: (value) => setState(() {
          search = value.trim().toLowerCase();
          page = 0;
        }),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: strings.omniPoolSearchAddress,
        ),
      ),
      Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: chain,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(strings.omniPoolAllChains),
              ),
              DropdownMenuItem(value: 'bsc', child: Text('BSC')),
              DropdownMenuItem(value: 'tron', child: Text('TRON')),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                    page = 0;
                    chain = value!;
                  }),
          ),
          DropdownButton<String>(
            value: filter,
            items: [
              for (final status in ['', 'available', 'allocated', 'disabled'])
                DropdownMenuItem(
                  value: status,
                  child: Text(stateLabel(status)),
                ),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                    page = 0;
                    filter = value!;
                  }),
          ),
          pagination(page, addresses.length, pageSize, (next) => page = next),
        ],
      ),
      if (addresses.isEmpty) Text(strings.omniNoRows),
      for (final row in addresses.skip(page * pageSize).take(pageSize))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: SelectableText(row['address'] as String),
          subtitle: Text(
            [
              (row['chain'] as String).toUpperCase(),
              stateLabel(row['state'] as String),
              if ((row['owner'] as String? ?? '').isNotEmpty)
                "${row['kind'] == 'collection_order' || (row['owner'] as String).startsWith('payment_order:') ? strings.omniPoolOrder : 'UID'} · ${row['owner']}",
            ].join(' · '),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gutter = WalletLayout.of(context).gutter;
    return ExcludeFocus(
      excluding: !widget.active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 8),
            child: Row(
              children: [
                if (widget.onBack != null) BackButton(onPressed: widget.onBack),
                Flexible(
                  child: Text(
                    strings.omniPoolTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              key: const PageStorageKey('omni-pool-page'),
              padding: EdgeInsets.fromLTRB(gutter, 12, gutter, gutter),
              children: [
                if (error case final failure?) ...[
                  Text(
                    errorText(failure),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (device == null)
                  OutlinedButton(
                    onPressed: busy ? null : () => run(load),
                    child: Text(strings.omniPoolRetry),
                  )
                else if (setup)
                  connectionForm()
                else
                  platformView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OmniPoolSecretDialog extends StatefulWidget {
  const _OmniPoolSecretDialog({this.mnemonic, this.restore});
  final String? mnemonic;
  final bool? restore;

  @override
  State<_OmniPoolSecretDialog> createState() => _OmniPoolSecretDialogState();
}

class _OmniPoolSecretDialogState extends State<_OmniPoolSecretDialog> {
  final input = TextEditingController();
  final confirmation = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final words = widget.mnemonic?.split(' ');
    final password = widget.restore != null;
    final saving = widget.restore == false;
    final valid = password
        ? input.text.runes.length >= 12 &&
              (!saving || input.text == confirmation.text)
        : words == null
        ? input.text.trim().isNotEmpty
        : input.text.trim().toLowerCase() == words[2] &&
              confirmation.text.trim().toLowerCase() == words[17];
    return AlertDialog(
      title: Text(
        password
            ? (saving ? s.omniPoolBackup : s.omniPoolRestore)
            : words == null
            ? s.msgImportRecoveryPhrase
            : s.omniPoolCreate,
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (words != null) ...[
                Text(s.omniPoolWriteWords),
                const SizedBox(height: 12),
                Text(
                  [
                    for (final (index, word) in words.indexed)
                      '${index + 1}. $word',
                  ].join('  '),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: input,
                autofocus: true,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: password
                      ? s.omniPoolPassphrase
                      : words == null
                      ? s.msgEnterYourOrWordRecoveryPhrase
                      : s.omniPoolWord(3),
                ),
              ),
              if (saving || words != null)
                TextField(
                  controller: confirmation,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: saving
                        ? s.omniPoolConfirmPassphrase
                        : s.omniPoolWord(18),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.of(context).pop(widget.mnemonic ?? input.text)
              : null,
          child: Text(s.omniPoolContinue),
        ),
      ],
    );
  }
}
