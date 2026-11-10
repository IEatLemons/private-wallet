part of '../main.dart';

class TokenDetailsPanel extends StatefulWidget {
  const TokenDetailsPanel({
    required this.theme,
    required this.holding,
    required this.address,
    required this.onRefresh,
    this.onWatch,
    super.key,
  });
  final WalletTheme theme;
  final TokenHolding holding;
  final String address;
  final Future<TokenHolding> Function() onRefresh;
  final Future<void> Function()? onWatch;
  @override
  State<TokenDetailsPanel> createState() => _TokenDetailsPanelState();
}

class _TokenDetailsPanelState extends State<TokenDetailsPanel> {
  late TokenHolding holding = widget.holding;
  bool busy = false, watched = false;
  WalletMessage? error;
  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await widget.onRefresh();
      if (mounted) setState(() => holding = next);
    } catch (e) {
      if (mounted) setState(() => error = walletMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => WalletPanel(
    theme: widget.theme,
    title: '${holding.token.symbol} · ${holding.network.name}',
    footer: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.onWatch != null)
          TextButton(
            onPressed: busy || watched
                ? null
                : () async {
                    setState(() => busy = true);
                    try {
                      await widget.onWatch!();
                      if (mounted) setState(() => watched = true);
                    } catch (e) {
                      if (mounted) setState(() => error = walletMessage(e));
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(
              tr(
                context,
                watched
                    ? MessageCode.discoveryWatched
                    : MessageCode.discoveryWatch,
              ),
            ),
          ),

        FilledButton.icon(
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: widget.address)),
          icon: const Icon(Icons.copy, size: 16),
          label: Text(tr(context, MessageCode.msgCopyReceiveAddress)),
        ),
        OutlinedButton(
          onPressed: busy || holding.state == TokenState.disabled
              ? null
              : refresh,
          child: Text(
            localized(
              context,
              busy
                  ? tr(context, MessageCode.msgQuerying)
                  : tr(context, MessageCode.msgRefreshBalance),
            ),
          ),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          displayQuantity(context, holding.amount),
          style: TextStyle(
            color: widget.theme.text,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          localized(context, error ?? holding.error ?? holding.status),
          style: TextStyle(color: widget.theme.muted),
        ),
        const SizedBox(height: 22),
        Text(
          localized(context, tokenRepresentation(context, holding.token)),
          style: TextStyle(color: widget.theme.text),
        ),
        const SizedBox(height: 16),
        Text(
          tr(context, MessageCode.msgCurrentAccountReceiveAddress),
          style: TextStyle(color: widget.theme.muted),
        ),
        const SizedBox(height: 8),
        SelectableText(
          localized(context, widget.address),
          style: TextStyle(color: widget.theme.text),
        ),
        const SizedBox(height: 16),
        Center(
          child: QrImageView(
            semanticsLabel: tr(
              context,
              MessageCode.msgCurrentAccountReceiveAddress,
            ),
            data: widget.address,
            size: 180,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(context, MessageCode.msgTokenContractDecimals, [
            holding.token.decimals,
          ]),
          style: TextStyle(color: widget.theme.muted),
        ),
        const SizedBox(height: 8),
        SelectableText(
          localized(context, holding.token.contract),
          style: TextStyle(color: widget.theme.text),
        ),
        const SizedBox(height: 16),
        Text(
          tr(
            context,
            MessageCode.msgCheckTheNetworkAndContractBeforeReceivingToken,
          ),
          style: TextStyle(
            color: widget.theme.muted,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class TokenManagerPanel extends StatefulWidget {
  const TokenManagerPanel({
    required this.theme,
    required this.networks,
    required this.initial,
    required this.onInspect,
    required this.onSave,
    super.key,
  });
  final WalletTheme theme;
  final List<EvmNetwork> networks;
  final List<TokenDefinition> initial;
  final Future<TokenDefinition> Function(EvmNetwork, String) onInspect;
  final Future<void> Function(List<TokenDefinition>) onSave;
  @override
  State<TokenManagerPanel> createState() => _TokenManagerPanelState();
}

class _TokenManagerPanelState extends State<TokenManagerPanel> {
  late List<TokenDefinition> tokens = List.of(widget.initial);
  late EvmNetwork network = widget.networks.first;
  final contract = TextEditingController();
  bool busy = false, custom = false;
  WalletMessage? error;
  TokenDefinition? inspected;
  @override
  void dispose() {
    contract.dispose();
    super.dispose();
  }

  Future<void> save(List<TokenDefinition> next) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(next);
      if (mounted) {
        setState(() {
          tokens = next;
          inspected = null;
          contract.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = walletMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      inspected = null;
    });
    try {
      final token = await widget.onInspect(network, contract.text.trim());
      if (mounted) setState(() => inspected = token);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is WalletInputException
              ? e.message
              : WalletMessage(
                  MessageCode.msgCannotReadThisTokenCheckTheNetworkContract,
                ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: WalletPanel(
      theme: widget.theme,
      title: tr(context, MessageCode.msgAddTokens),
      canClose: !busy,
      subtitle: tr(context, MessageCode.msgAddingATokenChangesItsDisplayOnlyIt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr(context, MessageCode.msgCommonStablecoins),
            style: TextStyle(
              color: widget.theme.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          for (final token in builtinTokens)
            SwitchListTile(
              key: ValueKey('watch-${token.key}'),
              contentPadding: EdgeInsets.zero,
              value: tokens.any((t) => t.key == token.key),
              title: Text(
                localized(
                  context,
                  '${token.symbol} · ${widget.networks.firstWhere((n) => n.id == token.networkId).name}',
                ),
                style: TextStyle(color: widget.theme.text, fontSize: 14),
              ),
              subtitle: Text(
                localized(context, tokenRepresentation(context, token)),
                style: TextStyle(color: widget.theme.muted, fontSize: 11),
              ),
              onChanged: busy
                  ? null
                  : (enabled) => save(
                      enabled
                          ? [...tokens, token]
                          : tokens.where((t) => t.key != token.key).toList(),
                    ),
            ),
          if (tokens.any((t) => t.trustedFamily == null)) ...[
            const SizedBox(height: 12),
            Text(
              tr(context, MessageCode.msgAddedCustomTokens),
              style: TextStyle(color: widget.theme.text),
            ),
            for (final token in tokens.where((t) => t.trustedFamily == null))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localized(context, token.symbol)),
                subtitle: Text(
                  localized(
                    context,
                    '${token.networkId} · ${shortAddress(token.contract)}',
                  ),
                ),
                trailing: IconButton(
                  tooltip: tr(context, MessageCode.msgHideToken),
                  onPressed: busy
                      ? null
                      : () => save(
                          tokens.where((t) => t.key != token.key).toList(),
                        ),
                  icon: const Icon(Icons.visibility_off_outlined),
                ),
              ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy ? null : () => setState(() => custom = !custom),
            icon: const Icon(Icons.add),
            label: Text(tr(context, MessageCode.msgAddCustomToken)),
          ),
          if (custom) ...[
            const SizedBox(height: 20),
            DropdownButtonFormField<EvmNetwork>(
              initialValue: network,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tr(context, MessageCode.msgNetwork),
              ),
              items: widget.networks
                  .map(
                    (n) => DropdownMenuItem(
                      value: n,
                      child: Text(localized(context, n.name)),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (n) {
                      if (n != null) {
                        setState(() {
                          network = n;
                          inspected = null;
                        });
                      }
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contract,
              enabled: !busy,
              autocorrect: false,
              onChanged: (_) => setState(() => inspected = null),
              decoration: InputDecoration(
                labelText: tr(context, MessageCode.msgTokenContractAddress),
                hintText: network.addressHint,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : inspect,
              child: Text(
                localized(
                  context,
                  busy
                      ? tr(context, MessageCode.msgProcessing)
                      : tr(context, MessageCode.msgReadTokenInfo),
                ),
              ),
            ),
            if (inspected case final TokenDefinition token) ...[
              const SizedBox(height: 12),
              Text(
                tr(context, MessageCode.msgDecimals, [
                  token.symbol,
                  token.decimals,
                ]),
                style: TextStyle(
                  color: widget.theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                localized(
                  context,
                  token.trustedFamily == null
                      ? tr(
                          context,
                          MessageCode
                              .msgCustomTokensWithMatchingTickersAreNotAutomatically,
                        )
                      : tr(
                          context,
                          MessageCode.msgMatchesAPresetContractItWillBeIncluded,
                          [token.trustedFamily],
                        ),
                ),
                style: TextStyle(
                  color: widget.theme.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy || tokens.any((t) => t.key == token.key)
                    ? null
                    : () => save([...tokens, token]),
                child: Text(
                  localized(
                    context,
                    tokens.any((t) => t.key == token.key)
                        ? tr(context, MessageCode.msgAdded)
                        : tr(context, MessageCode.msgConfirmAddition),
                  ),
                ),
              ),
            ],
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                localized(context, error!),
                style: TextStyle(
                  color: widget.theme.danger,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
