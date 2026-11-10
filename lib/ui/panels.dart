part of '../main.dart';

class WalletOption {
  const WalletOption({
    required this.name,
    required this.account,
    this.network,
    this.selected = false,
  });
  final String name;
  final WalletAccount account;
  final EvmNetwork? network;
  final bool selected;
}

class WalletPicker extends StatelessWidget {
  const WalletPicker({
    required this.theme,
    required this.options,
    required this.onSelect,
    super.key,
  });
  final WalletTheme theme;
  final List<WalletOption> options;
  final ValueChanged<WalletOption> onSelect;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: tr(context, MessageCode.msgSelectWallet),
    scrollBody: false,
    child: SizedBox(
      height: 360,
      child: ListView.separated(
        key: const ValueKey('wallet-list'),
        itemCount: options.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: theme.border),
        itemBuilder: (context, index) {
          final option = options[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            onTap: () => onSelect(option),
            leading: CircleAvatar(
              backgroundColor: theme.surfaceStrong,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: theme.primary,
                size: 20,
              ),
            ),
            title: Text(
              localized(context, option.name),
              style: TextStyle(
                color: theme.text,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              localized(
                context,
                '${option.network?.name ?? tr(context, MessageCode.msgRecoveryPhraseWallet)}\n${shortAddress(option.account.checksumAddress)}',
              ),
              style: TextStyle(color: theme.muted, fontSize: 12, height: 1.6),
            ),
            trailing: option.selected
                ? Icon(Icons.check_circle, color: theme.primary)
                : null,
          );
        },
      ),
    ),
  );
}

class ActionSheet extends StatelessWidget {
  const ActionSheet({
    required this.action,
    required this.theme,
    required this.walletName,
    this.network,
    this.networkLabel,
    required this.address,
    required this.onConfirm,
    super.key,
  });
  final WalletAction action;
  final String walletName, address;
  final String? networkLabel;
  final EvmNetwork? network;
  final WalletTheme theme;
  final VoidCallback onConfirm;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: switch (action) {
      WalletAction.send => tr(context, MessageCode.msgSend),
      WalletAction.receive => tr(context, MessageCode.msgReceive),
      WalletAction.swap => tr(context, MessageCode.msgSwap),
    },
    subtitle: tr(
      context,
      MessageCode.msgMakeSureTheReceivingNetworkMatchesTheNetwork,
    ),
    footer: FilledButton.icon(
      onPressed: onConfirm,
      icon: const Icon(Icons.copy_outlined, size: 18),
      label: Text(tr(context, MessageCode.msgCopyReceiveAddress)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WalletCard(
          theme: theme,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localized(context, walletName),
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                network == null
                    ? (networkLabel ??
                          tr(context, MessageCode.msgNoNetworkSelected))
                    : '${network!.name} · ${tr(context, network!.isTestnet ? MessageCode.msgTestnet : MessageCode.msgMainnet)}',
                style: TextStyle(color: theme.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: QrImageView(
            semanticsLabel: tr(
              context,
              MessageCode.msgCurrentAccountReceiveAddress,
            ),
            data: address,
            size: 176,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        SelectableText(
          localized(context, address),
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.text, fontSize: 14, height: 1.6),
        ),
      ],
    ),
  );
}

class NetworkSelectorSheet extends StatefulWidget {
  const NetworkSelectorSheet({
    required this.theme,
    required this.networks,
    required this.selectedNetworks,
    required this.currentNetwork,
    this.onEdit,
    super.key,
  });
  final WalletTheme theme;
  final List<EvmNetwork> networks, selectedNetworks;
  final EvmNetwork? currentNetwork;
  final Future<EvmNetwork?> Function(EvmNetwork?)? onEdit;
  @override
  State<NetworkSelectorSheet> createState() => _NetworkSelectorSheetState();
}

class _NetworkSelectorSheetState extends State<NetworkSelectorSheet> {
  late final List<EvmNetwork> networks = List.of(widget.networks);
  late final Set<int> selectedIds = widget.selectedNetworks
      .map((n) => n.id)
      .toSet();
  late int? currentId = widget.currentNetwork?.id ?? selectedIds.firstOrNull;

  void _toggle(EvmNetwork network) => setState(() {
    if (!selectedIds.add(network.id)) {
      selectedIds.remove(network.id);
      if (currentId == network.id) currentId = selectedIds.firstOrNull;
    } else {
      currentId ??= network.id;
    }
  });

  void _save() {
    final selected = networks.where((n) => selectedIds.contains(n.id)).toList();
    Navigator.pop(
      context,
      NetworkSelectionResult(
        networks: selected,
        current: selected.where((n) => n.id == currentId).firstOrNull,
      ),
    );
  }

  void _setCurrent(EvmNetwork network) => setState(() {
    selectedIds.add(network.id);
    currentId = network.id;
  });

  Future<void> _edit(EvmNetwork? network) async {
    final result = await widget.onEdit?.call(network);
    if (!mounted || result == null) return;
    setState(() {
      final index = networks.indexWhere((n) => n.id == result.id);
      if (index < 0) {
        networks.add(result);
        selectedIds.add(result.id);
        currentId = result.id;
      } else {
        networks[index] = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: tr(context, MessageCode.msgManageNetworks),
    subtitle: tr(
      context,
      MessageCode.msgEnableMultipleNetworksToViewBalancesOnlySelected,
    ),
    footer: FilledButton(
      onPressed: _save,
      child: Text(
        localized(
          context,
          selectedIds.isEmpty
              ? tr(context, MessageCode.msgDisconnectAllNetworks)
              : tr(context, MessageCode.msgSaveNetworkSelection),
        ),
      ),
    ),
    child: Column(
      children: [
        Text(
          tr(context, MessageCode.msgTapANetworkNameToUseItFor),
          style: TextStyle(color: widget.theme.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (widget.onEdit != null)
          OutlinedButton.icon(
            onPressed: () => _edit(null),
            icon: const Icon(Icons.add),
            label: Text(tr(context, MessageCode.msgAddCustomNetwork)),
          ),
        const SizedBox(height: 12),
        for (final network in networks)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: selectedIds.contains(network.id),
                  onChanged: (_) => _toggle(network),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _setCurrent(network),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localized(context, network.name),
                            style: TextStyle(
                              color: widget.theme.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (currentId == network.id)
                            Text(
                              tr(context, MessageCode.msgTransactionNetwork),
                              style: TextStyle(
                                color: widget.theme.primary,
                                fontSize: 12,
                              ),
                            ),
                          if (widget.onEdit != null)
                            TextButton(
                              onPressed: () => _edit(network),
                              child: Text(tr(context, MessageCode.msgEditRpc)),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            localized(
                              context,
                              '${network.identifierLabel} · ${network.nativeSymbol} · ${network.isTestnet ? tr(context, MessageCode.msgTestnet) : tr(context, MessageCode.msgMainnet)}',
                            ),
                            style: TextStyle(
                              color: widget.theme.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: tr(context, MessageCode.msgUseForTransactions),
                  onPressed: () => _setCurrent(network),
                  icon: Icon(
                    currentId == network.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selectedIds.contains(network.id)
                        ? widget.theme.primary
                        : widget.theme.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class NetworkSelectionResult {
  const NetworkSelectionResult({
    required this.networks,
    this.current,
    this.clear = false,
  });
  final List<EvmNetwork> networks;
  final EvmNetwork? current;
  final bool clear;
}

class RecoveryPhraseSheet extends StatefulWidget {
  const RecoveryPhraseSheet({
    required this.theme,
    required this.mnemonic,
    this.allowCancel = false,
    super.key,
  });
  final WalletTheme theme;
  final String mnemonic;
  final bool allowCancel;
  @override
  State<RecoveryPhraseSheet> createState() => _RecoveryPhraseSheetState();
}

class _RecoveryPhraseSheetState extends State<RecoveryPhraseSheet> {
  static const indexes = [1, 5, 9];
  late final words = widget.mnemonic.split(' ');
  final controllers = List.generate(3, (_) => TextEditingController());
  bool verifying = false;
  WalletMessage? error;
  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _continue() {
    if (!verifying) {
      setState(() => verifying = true);
      return;
    }
    final valid = indexes.asMap().entries.every(
      (e) =>
          controllers[e.key].text.trim().toLowerCase() ==
          words[e.value].toLowerCase(),
    );
    if (!valid) {
      setState(
        () => error = WalletMessage(
          MessageCode.msgRecoveryPhraseVerificationFailedCheckWordsAnd,
        ),
      );
      return;
    }
    closeWalletPanel(context, true);
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: verifying
        ? tr(context, MessageCode.msgVerifyRecoveryPhrase)
        : tr(context, MessageCode.msgWriteDownRecoveryPhrase),
    canClose: widget.allowCancel,
    expandBody: WalletLayout.of(context).mobile,
    footer: FilledButton(
      onPressed: _continue,
      child: Text(
        localized(
          context,
          verifying
              ? tr(context, MessageCode.msgVerifyAndOpenWallet)
              : tr(context, MessageCode.msgIWroteItDownVerify),
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localized(
            context,
            verifying
                ? tr(context, MessageCode.msgWrittenVerify)
                : tr(context, MessageCode.msgWriteDownVerify),
          ),
          style: TextStyle(
            color: widget.theme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          localized(
            context,
            verifying
                ? tr(
                    context,
                    MessageCode.msgEnterTheRequestedWordsToFinishCreatingYour,
                  )
                : tr(context, MessageCode.msgWriteDownTheseWordsInOrderAndKeep),
          ),
          style: TextStyle(
            color: widget.theme.muted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        if (!verifying)
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = WalletLayout.of(context).mobile ? 2 : 3;
              final cellWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final entry in words.asMap().entries)
                    Container(
                      width: cellWidth,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: widget.theme.surfaceStrong,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        localized(context, '${entry.key + 1}. ${entry.value}'),
                        style: TextStyle(
                          color: widget.theme.text,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        else
          for (final entry in indexes.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[entry.key],
                autofocus: entry.key == 0,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: entry.key == 2
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: (_) => entry.key == 2
                    ? _continue()
                    : FocusScope.of(context).nextFocus(),
                decoration: InputDecoration(
                  labelText: tr(context, MessageCode.msgWord, [
                    entry.value + 1,
                  ]),
                ),
              ),
            ),
        const SizedBox(height: 20),
        Text(
          tr(context, MessageCode.msgDoNotScreenshotCopyOrSendYourRecovery),
          style: TextStyle(
            color: widget.theme.danger,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            localized(context, error!),
            style: TextStyle(color: widget.theme.danger, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class ImportWalletDialog extends StatefulWidget {
  const ImportWalletDialog({required this.theme, super.key});
  final WalletTheme theme;
  @override
  State<ImportWalletDialog> createState() => _ImportWalletDialogState();
}

class _ImportWalletDialogState extends State<ImportWalletDialog> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: tr(context, MessageCode.msgImportWallet),
    subtitle: tr(
      context,
      MessageCode.msgEnterYourExistingRecoveryPhraseSeparatingWordsWith,
    ),
    footer: FilledButton(
      onPressed: () => closeWalletPanel(context, controller.text),
      child: Text(tr(context, MessageCode.msgImport)),
    ),
    child: TextField(
      controller: controller,
      // Let the mobile route settle before connecting the native keyboard.
      // The user taps the field to enter or paste; desktop keeps autofocus.
      autofocus: !WalletLayout.of(context).mobile,
      minLines: 4,
      maxLines: 6,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      style: TextStyle(color: widget.theme.text, fontSize: 14, height: 1.6),
      decoration: InputDecoration(
        hintText: tr(context, MessageCode.msgEnterYourOrWordRecoveryPhrase),
      ),
    ),
  );
}

class ImportPrivateKeyPanel extends StatefulWidget {
  const ImportPrivateKeyPanel({
    required this.theme,
    required this.networks,
    required this.onImport,
    this.currentNetwork,
    super.key,
  });

  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final EvmNetwork? currentNetwork;
  final Future<ImportedWallet> Function(String, EvmNetwork) onImport;

  @override
  State<ImportPrivateKeyPanel> createState() => _ImportPrivateKeyPanelState();
}

class _ImportPrivateKeyPanelState extends State<ImportPrivateKeyPanel> {
  final controller = TextEditingController();
  late EvmNetwork? network = widget.currentNetwork;
  bool obscure = true;
  bool importing = false;
  WalletMessage? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (importing) return;
    final selected = network;
    if (selected == null) {
      setState(
        () => error = WalletMessage(
          MessageCode.msgChooseANetworkToViewAfterImporting,
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      importing = true;
      error = null;
    });
    try {
      final imported = await widget.onImport(controller.text, selected);
      controller.clear();
      if (mounted) closeWalletPanel(context, imported);
    } catch (e) {
      if (mounted) {
        setState(() {
          importing = false;
          error = e is WalletInputException
              ? e.message
              : WalletMessage(
                  MessageCode.msgPrivateKeyImportFailedPleaseTryAgain,
                );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !importing,
    child: WalletPanel(
      theme: widget.theme,
      title: tr(context, MessageCode.msgImportPrivateKey),
      subtitle: tr(
        context,
        MessageCode.msgRestoreAnAccountWithAnEvmTronHexadecimal,
      ),
      canClose: !importing,
      footer: FilledButton(
        onPressed: importing ? null : _submit,
        child: Text(
          localized(
            context,
            importing
                ? tr(context, MessageCode.msgImporting)
                : tr(context, MessageCode.msgImportAndOpenWallet),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: network?.id,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr(context, MessageCode.msgNetwork),
            ),
            hint: Text(tr(context, MessageCode.msgSelectANetwork)),
            items: [
              for (final n in widget.networks)
                DropdownMenuItem(
                  value: n.id,
                  child: Text(
                    localized(
                      context,
                      '${n.name} · ${n.isTestnet ? tr(context, MessageCode.msgTestnet) : tr(context, MessageCode.msgMainnet)}',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: importing
                ? null
                : (id) => setState(() {
                    network = widget.networks.firstWhere((n) => n.id == id);
                    error = null;
                  }),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('private-key-input'),
            controller: controller,
            enabled: !importing,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: tr(context, MessageCode.msgPrivateKey),
              hintText: tr(
                context,
                MessageCode.msgHexadecimalCharactersOptionallyPrefixedWithX,
              ),
              suffixIcon: IconButton(
                tooltip: obscure
                    ? tr(context, MessageCode.msgShowPrivateKey)
                    : tr(context, MessageCode.msgHidePrivateKey),
                onPressed: importing
                    ? null
                    : () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(
              context,
              MessageCode.msgPrivateKeysStayInSecureDeviceStorageAfter,
            ),
            style: TextStyle(
              color: widget.theme.muted,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              localized(context, error!),
              style: TextStyle(color: widget.theme.danger, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}

class ImportResultDialog extends StatelessWidget {
  const ImportResultDialog({
    required this.theme,
    required this.errors,
    this.importedCount = 0,
    super.key,
  });
  final WalletTheme theme;
  final List<WalletImportError> errors;
  final int importedCount;
  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: theme,
    title: tr(context, MessageCode.msgImportResults),
    scrollBody: false,
    footer: FilledButton(
      onPressed: () => Navigator.pop(context),
      child: Text(tr(context, MessageCode.msgDone)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          child: Text(
            tr(context, MessageCode.msgImportedSkippedOrFailed, [
              importedCount,
              errors.length,
            ]),
            style: TextStyle(color: theme.text, fontSize: 15),
          ),
        ),
        if (errors.isNotEmpty)
          Flexible(
            child: SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: errors.length,
                separatorBuilder: (_, _) => Divider(color: theme.border),
                itemBuilder: (_, index) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    tr(context, MessageCode.msgRow, [
                      errors[index].row,
                      errors[index].message,
                    ]),
                    style: TextStyle(
                      color: theme.danger,
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class SendSheet extends StatefulWidget {
  const SendSheet({
    required this.theme,
    required this.network,
    required this.balanceWei,
    required this.onSend,
    super.key,
  });
  final WalletTheme theme;
  final EvmNetwork network;
  final BigInt? balanceWei;
  final Future<String> Function(String recipient, String amount) onSend;
  @override
  State<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends State<SendSheet> {
  final recipientController = TextEditingController(),
      amountController = TextEditingController();
  bool sending = false;
  WalletMessage? error;
  String? uncertainHash;
  @override
  void dispose() {
    recipientController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (sending || uncertainHash != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final recipient = recipientController.text.trim(),
          amount = amountController.text.trim();
      widget.network.validateAddress(recipient);
      final wei = widget.network.parseAmount(amount);
      if (wei <= BigInt.zero) {
        throw const WalletInputException(
          MessageCode.msgAmountMustBeGreaterThanZero,
        );
      }
      if (widget.balanceWei != null && wei > widget.balanceWei!) {
        throw const WalletInputException(
          MessageCode.msgAmountExceedsTheAvailableBalance,
        );
      }
      setState(() {
        sending = true;
        error = null;
      });
      final tx = await widget.onSend(recipient, amount);
      if (mounted) Navigator.pop(context, tx);
    } catch (e) {
      if (mounted) {
        setState(() {
          sending = false;
          error = walletMessage(e);
          if (e is RpcBroadcastException) uncertainHash = e.transactionHash;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: WalletPanel(
      theme: widget.theme,
      title: tr(context, MessageCode.msgSendMore, [
        widget.network.nativeSymbol,
      ]),
      canClose: !sending,
      subtitle: tr(context, MessageCode.msgSignedOnThisDevice, [
        widget.network.name,
        widget.network.isTestnet
            ? tr(context, MessageCode.msgTestnet)
            : tr(context, MessageCode.msgMainnet),
      ]),
      footer: FilledButton(
        onPressed: sending || uncertainHash != null ? null : _submit,
        child: sending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                localized(
                  context,
                  uncertainHash != null
                      ? tr(
                          context,
                          MessageCode.msgCheckTheTransactionStatusFirst,
                        )
                      : tr(context, MessageCode.msgSignAndBroadcast),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: recipientController,
            enabled: !sending,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: tr(context, MessageCode.msgRecipientAddress),
              hintText: widget.network.addressHint,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: amountController,
            enabled: !sending,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: tr(context, MessageCode.msgAmount, [
                widget.network.nativeSymbol,
              ]),
              hintText: '0.00',
            ),
          ),
          const SizedBox(height: 16),
          if (widget.balanceWei != null)
            Text(
              tr(context, MessageCode.msgAvailable, [
                displayQuantity(
                  context,
                  widget.network.formatAmount(widget.balanceWei!),
                ),
                widget.network.nativeSymbol,
                widget.network.isTron
                    ? tr(
                        context,
                        MessageCode
                            .msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay,
                      )
                    : tr(context, MessageCode.msgGasFeesAreChargedSeparately),
              ]),
              style: TextStyle(
                color: widget.theme.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(
              localized(context, error!),
              style: TextStyle(color: widget.theme.danger, fontSize: 13),
            ),
          ],
          if (uncertainHash != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              tr(context, MessageCode.msgTransactionHash, [uncertainHash]),
              style: TextStyle(color: widget.theme.text, fontSize: 13),
            ),
          ],
        ],
      ),
    ),
  );
}
