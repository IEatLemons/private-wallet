part of '../main.dart';

class AddressRecoveryPage extends StatefulWidget {
  const AddressRecoveryPage({
    required this.controller,
    required this.theme,
    this.active = true,
    this.onBack,
    super.key,
  });
  final AddressRecoveryController controller;
  final WalletTheme theme;
  final bool active;
  final VoidCallback? onBack;
  @override
  State<AddressRecoveryPage> createState() => _AddressRecoveryPageState();
}

class _AddressRecoveryPageState extends State<AddressRecoveryPage> {
  final phrase = TextEditingController();
  final xpub = TextEditingController();
  final passphrase = TextEditingController();
  final target = TextEditingController();
  final basePath = TextEditingController(text: "m/44'/60'/0'/0");
  final index = TextEditingController(text: '0');
  final start = TextEditingController(text: '0');
  final end = TextEditingController(text: '2147483647');
  String mode = 'account';
  int cpu = 25;
  bool standardOnly = false,
      showPhrase = false,
      showPassphrase = false,
      dirty = false,
      exporting = false;
  final revealed = <int>{};
  String? inputError, filledTask;
  AddressRecoveryController get controller => widget.controller;
  AppLocalizations get s => AppLocalizations.of(context);
  WalletTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    controller.addListener(changed);
    startWhenVisible();
  }

  @override
  void didUpdateWidget(covariant AddressRecoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(changed);
      controller.addListener(changed);
      filledTask = null;
    }
    startWhenVisible();
  }

  void startWhenVisible() {
    if (widget.active && !controller.loaded && !controller.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(controller.load());
      });
    }
    fillSelected();
  }

  void fillSelected() {
    final task = controller.selected;
    if (task == null || task.id == filledTask) return;
    final input = task.input;
    phrase.text = input.mnemonic;
    xpub.text = input.xpub;
    passphrase.text = input.passphrase;
    target.text = input.target;
    basePath.text = input.basePath;
    index.text = input.index.toString();
    start.text = input.start.toString();
    end.text = input.end.toString();
    mode = input.mode;
    cpu = input.cpuPercent;
    standardOnly = input.standardOnly;
    filledTask = task.id;
    dirty = false;
    showPhrase = false;
    showPassphrase = false;
    revealed.clear();
    inputError = null;
  }

  void changed() {
    if (mounted) setState(fillSelected);
  }

  @override
  void dispose() {
    controller.removeListener(changed);
    for (final field in [
      phrase,
      xpub,
      passphrase,
      target,
      basePath,
      index,
      start,
      end,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void clearForm() {
    controller.select('');
    setState(() {
      for (final field in [phrase, xpub, passphrase, target]) {
        field.clear();
      }
      basePath.text = "m/44'/60'/0'/0";
      index.text = '0';
      start.text = '0';
      end.text = '2147483647';
      mode = 'account';
      cpu = 25;
      standardOnly = false;
      dirty = false;
      filledTask = null;
      showPhrase = false;
      showPassphrase = false;
      revealed.clear();
      inputError = null;
    });
  }

  Future<void> startTask() async {
    try {
      final input = AddressRecoveryInput(
        mnemonic: phrase.text,
        xpub: xpub.text.trim(),
        target: target.text.trim(),
        passphrase: passphrase.text,
        mode: mode,
        basePath: basePath.text,
        index: int.tryParse(index.text) ?? -1,
        start: int.tryParse(start.text) ?? -1,
        end: int.tryParse(end.text) ?? -1,
        cpuPercent: cpu,
        standardOnly: standardOnly,
      );
      input.validate();
      setState(() => inputError = null);
      await controller.start(input);
    } on RecoveryInputException catch (e) {
      if (mounted) setState(() => inputError = e.code);
    } catch (_) {
      if (mounted) setState(() => inputError = 'storage');
    }
  }

  String errorText(String code) => switch (code) {
    'mnemonic' => s.msgInvalidRecoveryPhraseCheckTheWordsAndTheir,
    'xpub' => s.recoveryInvalidXpub,
    'target' => s.recoveryInvalidTarget,
    'range' => s.recoveryInvalidRange,
    'path' => s.recoveryInvalidPath,
    'storage' => s.recoveryStorageError,
    _ => s.recoveryWorkerError,
  };
  String statusText(String value) => switch (value) {
    'starting' || 'running' => s.recoveryRunning,
    'pausing' => s.recoveryPausing,
    'paused' => s.recoveryPaused,
    'standard_address_match' => s.recoveryStandardMatch,
    'legacy_hash_match_only' => s.recoveryLegacyMatch,
    'range_exhausted' => s.recoveryExhausted,
    'error' => s.recoveryError,
    _ => s.recoveryReady,
  };
  Widget card(Widget child) =>
      WalletCard(theme: theme, padding: const EdgeInsets.all(20), child: child);
  Widget input(
    TextEditingController field,
    String label,
    String key, {
    bool secret = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      key: ValueKey(key),
      controller: field,
      enabled: !controller.running,
      obscureText:
          secret && !(identical(field, phrase) ? showPhrase : showPassphrase),
      minLines: 1,
      maxLines:
          secret && !(identical(field, phrase) ? showPhrase : showPassphrase)
          ? 1
          : lines,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartQuotesType: SmartQuotesType.disabled,
      smartDashesType: SmartDashesType.disabled,
      onChanged: (_) => setState(() {
        dirty = true;
        inputError = null;
      }),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: secret
            ? IconButton(
                onPressed: () => setState(() {
                  if (identical(field, phrase)) {
                    showPhrase = !showPhrase;
                  } else {
                    showPassphrase = !showPassphrase;
                  }
                }),
                tooltip:
                    (identical(field, phrase) ? showPhrase : showPassphrase)
                    ? s.recoveryHide
                    : s.recoveryShow,
                icon: Icon(
                  (identical(field, phrase) ? showPhrase : showPassphrase)
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
    ),
  );

  Widget form() => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        input(
          phrase,
          s.recoveryMnemonic,
          'recovery-mnemonic',
          secret: true,
          lines: 3,
        ),
        input(xpub, s.recoveryXpub, 'recovery-xpub', lines: 2),
        input(
          passphrase,
          s.recoveryPassphrase,
          'recovery-passphrase',
          secret: true,
        ),
        input(target, s.recoveryTarget, 'recovery-target', lines: 2),
        DropdownButtonFormField<String>(
          key: ValueKey('recovery-mode-$mode'),
          initialValue: mode,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.recoveryMode),
          items: [
            DropdownMenuItem(
              value: 'account',
              child: Text(s.recoveryAccountMode),
            ),
            DropdownMenuItem(value: 'index', child: Text(s.recoveryIndexMode)),
          ],
          onChanged: controller.running
              ? null
              : (value) => setState(() {
                  mode = value!;
                  dirty = true;
                }),
        ),
        const SizedBox(height: 8),
        Text(
          mode == 'account' ? s.recoveryAccountHint : s.recoveryIndexHint,
          style: TextStyle(color: theme.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (mode == 'account')
          input(index, s.recoveryFixedIndex, 'recovery-fixed-index')
        else
          input(basePath, s.recoveryBasePath, 'recovery-base-path'),
        Row(
          children: [
            Expanded(child: input(start, s.recoveryStart, 'recovery-start')),
            const SizedBox(width: 12),
            Expanded(child: input(end, s.recoveryEnd, 'recovery-end')),
          ],
        ),
        Text('${s.recoveryCpu} · $cpu%'),
        Slider(
          key: const ValueKey('recovery-cpu'),
          value: cpu.toDouble(),
          min: 5,
          max: 50,
          divisions: 9,
          onChanged: controller.running
              ? null
              : (value) => setState(() => cpu = value.round()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.recoveryStandardOnly),
          value: standardOnly,
          onChanged: controller.running
              ? null
              : (value) => setState(() {
                  standardOnly = value;
                  dirty = true;
                }),
        ),
        const SizedBox(height: 8),
        Text(
          s.recoveryResources,
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 12),
        Text(
          s.recoverySavedHint,
          style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
        ),
        if (inputError ?? controller.error case final String code) ...[
          const SizedBox(height: 12),
          Text(
            errorText(code),
            key: const ValueKey('recovery-error'),
            style: TextStyle(color: theme.danger),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!controller.running)
              FilledButton.icon(
                key: const ValueKey('recovery-start-task'),
                onPressed: controller.loading ? null : startTask,
                icon: const Icon(Icons.play_arrow),
                label: Text(s.recoveryStartTask),
              ),
            if (!controller.running && controller.selected?.canResume == true)
              OutlinedButton.icon(
                key: const ValueKey('recovery-resume'),
                onPressed: dirty
                    ? null
                    : () => controller.resume(cpuPercent: cpu),
                icon: const Icon(Icons.restart_alt),
                label: Text(s.recoveryResume),
              ),
            if (controller.running)
              FilledButton.icon(
                key: const ValueKey('recovery-pause'),
                onPressed: controller.pausing ? null : controller.pause,
                icon: const Icon(Icons.pause),
                label: Text(s.recoveryPause),
              ),
          ],
        ),
      ],
    ),
  );

  Widget progress() {
    final task = controller.selected;
    final verification = task?.verification;
    final probe = task?.probe;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            statusText(task?.status ?? 'ready'),
            key: const ValueKey('recovery-status'),
            style: TextStyle(
              color: task?.status == 'legacy_hash_match_only'
                  ? theme.danger
                  : theme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (controller.running) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _stat(s.recoveryChecked, '${task?.checked ?? 0}'),
              _stat(
                s.recoveryNext,
                '${task == null || task.familyCount == 0 ? 0 : task.cursor ~/ task.familyCount}',
              ),
              _stat(s.recoverySpeed, controller.rate.toStringAsFixed(1)),
            ],
          ),
          if (probe != null) ...[
            const SizedBox(height: 16),
            Text(
              s.recoveryCurrentPath,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            SelectableText(
              probe['path'] as String,
              key: const ValueKey('recovery-current-path'),
            ),
            const SizedBox(height: 12),
            Text(
              s.recoveryStandardAddress,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            SelectableText(
              'EVM · ${probe['standard_evm']}\nTRON · ${probe['standard_tron']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              s.recoveryLegacyAddress,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            SelectableText(
              'EVM · ${probe['legacy_evm']}\nTRON · ${probe['legacy_tron']}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (verification != null &&
              verification['match'] != 'not_provided') ...[
            const Divider(height: 32),
            Text(
              '${s.recoveryVerification} · #${verification['index']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(switch (verification['match']) {
              'standard' => s.recoveryXpubStandard,
              'legacy' => s.recoveryXpubLegacy,
              _ => s.recoveryXpubNone,
            }),
            if (verification['origin_matches_base'] == false) ...[
              const SizedBox(height: 8),
              Text(
                s.recoveryOriginMismatch,
                style: TextStyle(color: theme.danger, fontSize: 12),
              ),
            ],
          ],
          const Divider(height: 32),
          Text(
            s.recoveryWarning,
            style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: theme.muted, fontSize: 12)),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          color: theme.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Future<void> exportMatches() async {
    final task = controller.selected;
    if (task == null || task.matches.isEmpty || exporting) return;
    setState(() => exporting = true);
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: s.recoveryExport,
        fileName: 'asterkeel-recovery-${task.id.substring(0, 8)}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (path != null) {
        await controller.vault.exportRecoveryMatches(path, [
          for (final match in task.matches) Map<String, Object?>.from(match),
        ]);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.recoveryExported)));
        }
      }
    } catch (_) {
      if (mounted) setState(() => inputError = 'storage');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget results() {
    final matches = controller.selected?.matches ?? [];
    if (matches.isEmpty) return const SizedBox.shrink();
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < matches.length; i++) ...[
            if (i > 0) const Divider(height: 32),
            Text(
              matches[i]['match'] == 'standard_address_match'
                  ? s.recoveryStandardMatch
                  : s.recoveryLegacyMatch,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: matches[i]['match'] == 'standard_address_match'
                    ? theme.primary
                    : theme.danger,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              matches[i]['match'] == 'standard_address_match'
                  ? s.recoveryMatchHint
                  : s.recoveryWarning,
            ),
            const SizedBox(height: 12),
            SelectableText(matches[i]['path'] as String),
            const SizedBox(height: 8),
            Text(
              s.recoveryStandardAddress,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            SelectableText(
              'EVM · ${matches[i]['standard_evm']}\nTRON · ${matches[i]['standard_tron']}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              s.recoveryPrivateKey,
              style: TextStyle(color: theme.muted, fontSize: 12),
            ),
            SelectableText(
              revealed.contains(i)
                  ? matches[i]['derived_private_key'] as String
                  : '••••••••••••••••••••••••••••••••',
              key: ValueKey('recovery-key-$i'),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  key: ValueKey('recovery-reveal-$i'),
                  onPressed: () => setState(() {
                    if (!revealed.add(i)) revealed.remove(i);
                  }),
                  icon: Icon(
                    revealed.contains(i)
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  label: Text(
                    revealed.contains(i) ? s.recoveryHide : s.recoveryShow,
                  ),
                ),
                IconButton(
                  tooltip: s.recoveryCopyKey,
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: matches[i]['derived_private_key'] as String,
                    ),
                  ),
                  icon: const Icon(Icons.copy_outlined),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('recovery-export'),
            onPressed: exporting ? null : exportMatches,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(s.recoveryExport),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = WalletLayout.of(context).gutter;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(gutter),
          child: Row(
            children: [
              if (widget.onBack != null) BackButton(onPressed: widget.onBack),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.recoveryTitle,
                      style: TextStyle(
                        color: theme.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.recoveryIntro,
                      style: TextStyle(color: theme.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (controller.running)
                IconButton(
                  key: const ValueKey('recovery-pause-header'),
                  tooltip: s.recoveryPause,
                  onPressed: controller.pausing ? null : controller.pause,
                  icon: const Icon(Icons.pause_circle_outline),
                ),
              if (!controller.running)
                IconButton(
                  key: const ValueKey('recovery-new'),
                  tooltip: s.recoveryNew,
                  onPressed: controller.running ? null : clearForm,
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
        ),
        Expanded(
          child: controller.loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.tasks.isNotEmpty) ...[
                            DropdownButtonFormField<String>(
                              key: ValueKey((
                                'recovery-history',
                                controller.selected?.id,
                              )),
                              initialValue: controller.selected?.id,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: s.recoveryHistory,
                              ),
                              items: [
                                for (final task in controller.tasks)
                                  DropdownMenuItem(
                                    value: task.id,
                                    child: Text(
                                      '${shortAddress(task.input.target)} · ${statusText(task.status)} · ${DateFormat('MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(task.createdAt))}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: controller.running
                                  ? null
                                  : (id) {
                                      if (id != null) controller.select(id);
                                    },
                            ),
                            const SizedBox(height: 16),
                          ],
                          LayoutBuilder(
                            builder: (context, box) {
                              final right = Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  progress(),
                                  const SizedBox(height: 16),
                                  results(),
                                ],
                              );
                              return box.maxWidth >= 900
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: form()),
                                        const SizedBox(width: 20),
                                        Expanded(child: right),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        form(),
                                        const SizedBox(height: 16),
                                        right,
                                      ],
                                    );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
