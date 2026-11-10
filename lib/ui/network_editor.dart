part of '../main.dart';

class NetworkEditorPanel extends StatefulWidget {
  const NetworkEditorPanel({
    required this.theme,
    required this.networks,
    required this.onSave,
    required this.onCheck,
    this.network,
    super.key,
  });
  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final EvmNetwork? network;
  final Future<void> Function(EvmNetwork) onSave;
  final Future<void> Function(EvmNetwork) onCheck;
  @override
  State<NetworkEditorPanel> createState() => _NetworkEditorPanelState();
}

class _NetworkEditorPanelState extends State<NetworkEditorPanel> {
  late final name = TextEditingController(text: widget.network?.name);
  late final chainId = TextEditingController(
    text: widget.network?.id.toString(),
  );
  late final symbol = TextEditingController(text: widget.network?.nativeSymbol);
  late final rpc = TextEditingController(
    text: widget.network?.rpcUrls.join('\n'),
  );
  late final explorer = TextEditingController(
    text: widget.network?.explorerUrl,
  );
  late bool testnet = widget.network?.isTestnet ?? false;
  bool saving = false, checking = false;
  WalletMessage? error, checkStatus;
  @override
  void dispose() {
    for (final c in [name, chainId, symbol, rpc, explorer]) {
      c.dispose();
    }
    super.dispose();
  }

  EvmNetwork _value() {
    final id = int.tryParse(chainId.text.trim());
    if (id == null) {
      throw const WalletInputException(
        MessageCode.msgChainIdMustBeAValidPositiveInteger,
      );
    }
    if (widget.network == null && widget.networks.any((n) => n.id == id)) {
      throw const WalletInputException(
        MessageCode.msgThisChainIdAlreadyExistsEditItsRpc,
      );
    }
    final network = EvmNetwork(
      id: id,
      name: name.text.trim(),
      nativeSymbol: symbol.text.trim(),
      rpcUrl: _rpcUrls.first,
      fallbackRpcUrls: _rpcUrls.skip(1).toList(),
      explorerUrl: explorer.text.trim(),
      isTestnet: testnet,
      protocol: widget.network?.protocol ?? NetworkProtocol.evm,
    );
    network.validate();
    return network;
  }

  List<String> get _rpcUrls {
    final urls = rpc.text
        .split(RegExp(r'\s+'))
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    if (urls.isEmpty) {
      throw const WalletInputException(
        MessageCode.msgConfigureAtLeastOneRpcUrl,
      );
    }
    return urls;
  }

  Future<void> _check() async {
    try {
      final network = _value();
      setState(() {
        checking = true;
        error = null;
        checkStatus = null;
      });
      await widget.onCheck(network);
      if (mounted) {
        setState(
          () => checkStatus = network.isTron
              ? WalletMessage(
                  MessageCode.msgTronHttpApiIsAvailableTheMainnetGenesis,
                )
              : WalletMessage(
                  MessageCode.msgRpcIsAvailableAndItsChainIdMatches,
                ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is WalletInputException
              ? e.message
              : WalletMessage(
                  MessageCode.msgConnectionCheckFailedCheckTheRpcUrlNetwork,
                ),
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  Future<void> _save() async {
    try {
      final network = _value();
      setState(() {
        saving = true;
        error = null;
      });
      await widget.onSave(network);
      if (mounted) Navigator.pop(context, network);
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is WalletInputException
              ? e.message
              : WalletMessage(
                  MessageCode.msgCouldNotSaveNetworkSettingsPleaseTryAgain,
                );
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool enabled = true,
    TextInputType? type,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: TextField(
      controller: controller,
      enabled: enabled && !saving && !checking,
      autocorrect: false,
      keyboardType: type,
      onChanged: (_) {
        if (checkStatus != null) setState(() => checkStatus = null);
      },
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: WalletPanel(
      theme: widget.theme,
      title: widget.network == null
          ? tr(context, MessageCode.msgAddCustomEvmNetwork)
          : tr(context, MessageCode.msgEditNetworkAndRpc),
      subtitle: tr(context, MessageCode.msgEnterOneRpcUrlPerLineInPriority),
      canClose: !saving,
      footer: FilledButton(
        onPressed: saving || checking ? null : _save,
        child: Text(
          localized(
            context,
            saving
                ? tr(context, MessageCode.msgSaving)
                : tr(context, MessageCode.msgSaveNetworkSettings),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            tr(context, MessageCode.msgNetworkName),
            name,
            hint: tr(context, MessageCode.msgForExampleBase),
          ),
          if (widget.network?.isTron != true)
            _field(
              'Chain ID',
              chainId,
              hint: tr(context, MessageCode.msgForExample),
              enabled: widget.network == null,
              type: TextInputType.number,
            ),
          _field(
            tr(context, MessageCode.msgNativeCurrencySymbol),
            symbol,
            hint: tr(context, MessageCode.msgForExampleEth),
            enabled: widget.network?.isTron != true,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              controller: rpc,
              enabled: !saving && !checking,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.multiline,
              onChanged: (_) => setState(() => checkStatus = null),
              decoration: InputDecoration(
                labelText: tr(context, MessageCode.msgRpcUrl),
                hintText: tr(
                  context,
                  MessageCode.msgHttpsPrimaryEndpointHttpsBackupEndpoint,
                ),
                helperText: tr(
                  context,
                  MessageCode.msgOneUrlPerLineOrderSetsPriorityDuplicates,
                ),
              ),
            ),
          ),
          if (widget.network != null &&
              supportedNetworks.any((n) => n.id == widget.network!.id))
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: saving || checking
                    ? null
                    : () => setState(() {
                        rpc.text = supportedNetworks
                            .firstWhere((n) => n.id == widget.network!.id)
                            .rpcUrls
                            .join('\n');
                        checkStatus = null;
                        error = null;
                      }),
                icon: const Icon(Icons.restore, size: 16),
                label: Text(
                  tr(context, MessageCode.msgRestoreBuiltInFreeEndpoints),
                ),
              ),
            ),
          _field(
            tr(context, MessageCode.msgBlockExplorerUrlOptional),
            explorer,
            hint: 'https://…',
            type: TextInputType.url,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr(context, MessageCode.msgTestnet)),
            value: testnet,
            onChanged: saving || checking || widget.network?.isTron == true
                ? null
                : (v) => setState(() => testnet = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving || checking ? null : _check,
            icon: const Icon(Icons.network_check, size: 18),
            label: Text(
              localized(
                context,
                checking
                    ? tr(context, MessageCode.msgChecking)
                    : tr(context, MessageCode.msgCheckRpcConnection),
              ),
            ),
          ),
          if (checkStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                localized(context, checkStatus!),
                style: TextStyle(color: widget.theme.success, fontSize: 13),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                localized(context, error!),
                style: TextStyle(color: widget.theme.danger, fontSize: 13),
              ),
            ),
        ],
      ),
    ),
  );
}
