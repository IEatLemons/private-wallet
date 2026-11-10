part of 'wallet_core.dart';

class TokenDefinition {
  const TokenDefinition({
    required this.networkId,
    required this.contract,
    required this.symbol,
    required this.decimals,
    required this.name,
    this.family,
    this.representation = '自定义代币',
    this.defaultVisible = false,
  });
  final int networkId, decimals;
  final String contract, symbol, name, representation;
  // Only hard-coded, reviewed catalog entries may assign an aggregation family.
  final String? family;
  final bool defaultVisible;
  String get key =>
      '$networkId:${networkId == tronMainnetNetwork.id ? contract : contract.toLowerCase()}';
  String? get trustedFamily => builtinTokens
      .where(
        (t) => t.key == key && t.symbol == symbol && t.decimals == decimals,
      )
      .firstOrNull
      ?.family;
  void validate(EvmNetwork network) {
    if (network.id != networkId ||
        decimals < 0 ||
        decimals > 36 ||
        symbol.trim().isEmpty ||
        symbol.length > 24 ||
        name.trim().isEmpty ||
        name.length > 80) {
      throw const WalletInputException(
        MessageCode.msgInvalidTokenInformationReadTheContractAgain,
      );
    }
    network.validateAddress(contract);
    if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(symbol)) {
      throw const WalletInputException(
        MessageCode.msgTokenSymbolContainsInvalidCharacters,
      );
    }
  }

  String format(BigInt units) {
    final value = formatNativeAmount(units, decimals);
    return units > BigInt.zero && value == '0' ? '< 0.000001' : value;
  }

  Map<String, Object> toJson() => {
    'networkId': networkId,
    'contract': contract,
    'symbol': symbol,
    'decimals': decimals,
    'name': name,
  };
  factory TokenDefinition.fromJson(Map<String, dynamic> json) =>
      TokenDefinition(
        networkId: json['networkId'] as int,
        contract: json['contract'] as String,
        symbol: json['symbol'] as String,
        decimals: json['decimals'] as int,
        name: json['name'] as String,
      );
}

// Sources: Tether supported protocols, BNB Chain token mapping, USDT0 Polygon,
// and Circle's official USDC contract registry. Never group by ticker alone.
const builtinTokens = [
  TokenDefinition(
    networkId: 1,
    contract: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    symbol: 'USDT',
    decimals: 6,
    name: 'Tether USD',
    family: 'USDT',
    representation: 'Tether · ERC20',
    defaultVisible: true,
  ),
  TokenDefinition(
    networkId: 728126428,
    contract: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
    symbol: 'USDT',
    decimals: 6,
    name: 'Tether USD',
    family: 'USDT',
    representation: 'Tether · TRC20',
    defaultVisible: true,
  ),
  TokenDefinition(
    networkId: 56,
    contract: '0x55d398326f99059fF775485246999027B3197955',
    symbol: 'USDT',
    decimals: 18,
    name: 'Binance-Peg BSC-USD',
    family: 'USDT',
    representation: 'Binance-Peg · BEP20',
    defaultVisible: true,
  ),
  TokenDefinition(
    networkId: 137,
    contract: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    symbol: 'USDT0',
    decimals: 6,
    name: 'USDT0',
    family: 'USDT',
    representation: 'USDT0 · Polygon',
    defaultVisible: true,
  ),
  TokenDefinition(
    networkId: 1,
    contract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    symbol: 'USDC',
    decimals: 6,
    name: 'USD Coin',
    family: 'USDC',
    representation: 'Circle · ERC20',
  ),
  TokenDefinition(
    networkId: 137,
    contract: '0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359',
    symbol: 'USDC',
    decimals: 6,
    name: 'USD Coin',
    family: 'USDC',
    representation: 'Circle · Polygon',
  ),
];

TokenDefinition canonicalToken(TokenDefinition token) =>
    builtinTokens
        .where(
          (t) =>
              t.key == token.key &&
              t.symbol == token.symbol &&
              t.decimals == token.decimals,
        )
        .firstOrNull ??
    token;

BigInt decodeTokenUint(String hex) {
  final value = hex.replaceFirst(RegExp(r'^0x'), '');
  if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
    throw const WalletInputException(
      MessageCode.msgTheTokenContractReturnedAnInvalidValue,
    );
  }
  return BigInt.parse(value, radix: 16);
}

void validateTokenResponse(String signature, String value) {
  if (signature == 'symbol()') {
    final symbol = decodeTokenSymbol(value);
    if (symbol.isEmpty ||
        symbol.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(symbol)) {
      throw const WalletInputException(MessageCode.msgInvalidTokenSymbol);
    }
  } else {
    final number = decodeTokenUint(value);
    if (signature == 'decimals()' && number > BigInt.from(36)) {
      throw const WalletInputException(
        MessageCode.msgOnlyTokensWithDecimalsAreSupported,
      );
    }
  }
}

String decodeTokenSymbol(String hex) {
  final bytes = ec.hexToBytes(hex);
  if (bytes.length == 32) {
    return utf8.decode(bytes.takeWhile((b) => b != 0).toList());
  }
  if (bytes.length < 64) {
    throw const WalletInputException(MessageCode.msgCannotReadTheTokenSymbol);
  }
  final offset = ec.bytesToUnsignedInt(bytes.sublist(0, 32));
  if (offset != BigInt.from(32)) {
    throw const WalletInputException(MessageCode.msgInvalidTokenSymbolEncoding);
  }
  final length = ec.bytesToUnsignedInt(bytes.sublist(32, 64));
  if (length <= BigInt.zero ||
      length > BigInt.from(24) ||
      bytes.length < 64 + length.toInt()) {
    throw const WalletInputException(MessageCode.msgInvalidTokenSymbolLength);
  }
  return utf8.decode(bytes.sublist(64, 64 + length.toInt()));
}

extension TokenStorage on WalletVault {
  static const tokensKey = 'stone_wallet.v1.watched_tokens';
  Future<List<TokenDefinition>> loadTokens() async {
    final raw = await _store.read(tokensKey);
    if (raw == null) {
      return builtinTokens.where((t) => t.defaultVisible).toList();
    }
    try {
      final networks = await loadNetworks();
      final tokens = <TokenDefinition>[];
      final seen = <String>{};
      for (final item in jsonDecode(raw) as List) {
        final token = canonicalToken(
          TokenDefinition.fromJson(Map<String, dynamic>.from(item as Map)),
        );
        token.validate(networks.firstWhere((n) => n.id == token.networkId));
        if (!seen.add(token.key)) throw const FormatException();
        tokens.add(token);
      }
      return tokens;
    } catch (_) {
      throw const WalletInputException(
        MessageCode.msgCannotReadTheSavedTokenListExistingRecords,
      );
    }
  }

  Future<void> saveTokens(List<TokenDefinition> tokens) async {
    final networks = await loadNetworks();
    final seen = <String>{};
    for (final token in tokens) {
      token.validate(networks.firstWhere((n) => n.id == token.networkId));
      if (!seen.add(token.key)) {
        throw const WalletInputException(
          MessageCode.msgThisTokenHasAlreadyBeenAddedOnThis,
        );
      }
    }
    await _store.write(
      tokensKey,
      jsonEncode(tokens.map((t) => t.toJson()).toList()),
    );
  }
}

enum TokenState { disabled, pending, ready, failed }

class TokenHolding {
  const TokenHolding({
    required this.token,
    required this.network,
    required this.state,
    this.units,
    this.error,
  });
  final TokenDefinition token;
  final EvmNetwork network;
  final TokenState state;
  final BigInt? units;
  final WalletMessage? error;
  bool get known => state == TokenState.ready && units != null;
  String get amount =>
      known ? '${token.format(units!)} ${token.symbol}' : '— ${token.symbol}';
  WalletMessage get status => switch (state) {
    TokenState.disabled => WalletMessage(MessageCode.msgNetworkDisabled),
    TokenState.pending => WalletMessage(MessageCode.msgQueryingMore),
    TokenState.ready => WalletMessage(MessageCode.msgSynced),
    TokenState.failed => WalletMessage(MessageCode.msgQueryFailed),
  };
}

class StablecoinTotal {
  StablecoinTotal(this.family, List<TokenHolding> all)
    : holdings = all
          .where((h) => h.token.trustedFamily == family && !h.network.isTestnet)
          .toList();
  final String family;
  final List<TokenHolding> holdings;
  int get knownCount => holdings.where((h) => h.known).length;
  bool get complete => holdings.isNotEmpty && knownCount == holdings.length;
  BigInt get scaledUnits => holdings
      .where((h) => h.known)
      .fold(
        BigInt.zero,
        (sum, h) => sum + h.units! * BigInt.from(10).pow(36 - h.token.decimals),
      );
  String get amount {
    if (knownCount == 0) return '—';
    final value = formatNativeAmount(scaledUnits, 36);
    return scaledUnits > BigInt.zero && value == '0' ? '< 0.000001' : value;
  }
}
