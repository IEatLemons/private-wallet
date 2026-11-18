part of 'wallet_core.dart';

/// Diagnostic address reproduction only. Legacy hashes are never signing accounts.
enum LegacyMnemonicMatch { standard, legacyHash, none }

class MnemonicAddressCandidate {
  const MnemonicAddressCandidate({
    required this.path,
    required this.standardAddress,
    required this.legacyAddress,
  });
  final String path, standardAddress, legacyAddress;
}

class LegacyMnemonicInspection {
  const LegacyMnemonicInspection({
    required this.candidates,
    required this.match,
    this.matched,
  });
  final List<MnemonicAddressCandidate> candidates;
  final LegacyMnemonicMatch match;
  final MnemonicAddressCandidate? matched;
}

/// Checks the supplied path and the known historical OmniVault xPub branches.
/// No phrase, private key or seed is retained in the returned public result.
LegacyMnemonicInspection inspectLegacyMnemonic({
  required String mnemonic,
  required String path,
  required String expectedAddress,
  required EvmNetwork network,
}) {
  final phrase = WalletVault._normalizeMnemonic(mnemonic);
  if (!bip39.validateMnemonic(phrase)) {
    throw const WalletInputException(
      MessageCode.msgInvalidRecoveryPhraseCheckTheWordsAndTheir,
    );
  }
  final canonical = normalizeDerivationPath(path);
  final target = expectedAddress.trim();
  network.validateAddress(target);
  final index = canonical.split('/').last;
  final paths = <String>{
    canonical,
    "m/44'/195'/0'/0/$index",
    "m/44'/60'/0'/0/$index",
    "m/44'/60'/1'/0/$index",
  };
  final master = BIP32.fromSeed(bip39.mnemonicToSeed(phrase));
  String address(List<int> bytes) => network.isTron
      ? base58.encode(Uint8List.fromList([0x41, ...bytes]))
      : EthereumAddress(Uint8List.fromList(bytes)).hexEip55;
  bool same(String value) => network.isTron
      ? value == target
      : value.toLowerCase() == target.toLowerCase();
  final candidates = <MnemonicAddressCandidate>[];
  for (final candidate in paths) {
    final key = master.derivePath(candidate).privateKey!;
    final coordinates = ec.privateKeyBytesToPublic(key);
    final standard = keccak256(coordinates).sublist(12);
    // Reproduce OmniVault's historical Keccak256(0x04 || X || Y) bug.
    final legacy = keccak256(
      Uint8List.fromList([0x04, ...coordinates]),
    ).sublist(12);
    candidates.add(
      MnemonicAddressCandidate(
        path: candidate,
        standardAddress: address(standard),
        legacyAddress: address(legacy),
      ),
    );
  }
  for (final candidate in candidates) {
    if (same(candidate.standardAddress)) {
      return LegacyMnemonicInspection(
        candidates: List.unmodifiable(candidates),
        match: LegacyMnemonicMatch.standard,
        matched: candidate,
      );
    }
  }
  for (final candidate in candidates) {
    if (same(candidate.legacyAddress)) {
      return LegacyMnemonicInspection(
        candidates: List.unmodifiable(candidates),
        match: LegacyMnemonicMatch.legacyHash,
        matched: candidate,
      );
    }
  }
  return LegacyMnemonicInspection(
    candidates: List.unmodifiable(candidates),
    match: LegacyMnemonicMatch.none,
  );
}

extension LegacyMnemonicAccounts on WalletVault {
  Future<LegacyMnemonicInspection> inspectLegacyAccount({
    required String groupId,
    required String path,
    required String expectedAddress,
    required EvmNetwork network,
  }) async {
    final String phrase;
    if (_database != null) {
      phrase = (await _macRow('derive', {'id': groupId}))['secret'] as String;
    } else {
      phrase = await _changeBook((book) {
        final group = book.groups
            .where((g) => g.id == groupId && g.kind == WalletKind.mnemonic)
            .firstOrNull;
        if (group == null) {
          throw const WalletInputException(MessageCode.msgWalletNotFound);
        }
        return group.secret;
      });
    }
    return _inspectLegacyInBackground(phrase, path, expectedAddress, network);
  }
}

Future<LegacyMnemonicInspection> _inspectLegacyInBackground(
  String phrase,
  String path,
  String address,
  EvmNetwork network,
) => Isolate.run(
  () => inspectLegacyMnemonic(
    mnemonic: phrase,
    path: path,
    expectedAddress: address,
    network: network,
  ),
);
