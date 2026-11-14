part of 'wallet_core.dart';

/// An unsigned review bound to one account, network, recipient, and amount.
class PreparedWalletTransfer {
  PreparedWalletTransfer._({
    required this.fee,
    required Future<String> Function() send,
  }) : _send = send,
       _preparedAt = DateTime.now();

  /// Fee in the network's atomic native units. On TRON this is an estimate
  /// based on the sender's resources and the approved Energy budget.
  final BigInt fee;
  final DateTime _preparedAt;
  final Future<String> Function() _send;
  bool _used = false;

  Future<String> broadcast() async {
    if (_used ||
        DateTime.now().difference(_preparedAt) > const Duration(minutes: 2)) {
      throw const WalletInputException(MessageCode.transferReviewExpired);
    }
    _used = true;
    return _send();
  }
}

class _TransferRejected extends WalletInputException {
  const _TransferRejected(super.code);
}

final _uint256Max = (BigInt.one << 256) - BigInt.one;
final _int64Max = (BigInt.one << 63) - BigInt.one;
const _transferSignature = 'transfer(address,uint256)';

EthereumAddress _evmRecipient(String address) {
  try {
    return EthereumAddress.fromHex(address, enforceEip55: false);
  } on ArgumentError {
    throw const _TransferRejected(MessageCode.transferInvalidRecipient);
  }
}

void _validateTransfer(
  EvmNetwork network,
  TokenDefinition? token,
  BigInt amount,
) {
  token?.validate(network);
  if (amount <= BigInt.zero) {
    throw const _TransferRejected(MessageCode.msgAmountMustBeGreaterThanZero);
  }
  if (amount > (token == null && network.isTron ? _int64Max : _uint256Max)) {
    throw const _TransferRejected(MessageCode.transferAmountTooLarge);
  }
}

Uint8List _addressWord(List<int> address) =>
    Uint8List(32)..setRange(12, 32, address);

Uint8List _tokenCall(String signature, [List<int> arguments = const []]) =>
    Uint8List.fromList([
      ...keccak256(utf8.encode(signature)).take(4),
      ...arguments,
    ]);

Uint8List _transferData(List<int> recipient, BigInt amount) =>
    _tokenCall(_transferSignature, [
      ..._addressWord(recipient),
      ...ec.hexToBytes(amount.toRadixString(16).padLeft(64, '0')),
    ]);

void _requireTokenDecimals(TokenDefinition token, String response) {
  if (decodeTokenUint(response) != BigInt.from(token.decimals)) {
    throw const _TransferRejected(MessageCode.transferTokenDecimalsChanged);
  }
}

void _requireTransferSuccess(String response) {
  // Legacy tokens (including some USDT contracts) may return no data.
  if (response == '' || response == '0x') return;
  if (decodeTokenUint(response) != BigInt.one) {
    throw const _TransferRejected(MessageCode.transferSimulationFailed);
  }
}

void _requireBalance(BigInt balance, BigInt amount) {
  if (balance < amount) {
    throw const _TransferRejected(
      MessageCode.msgAmountExceedsTheAvailableBalance,
    );
  }
}

void _requireFeeBalance(BigInt balance, BigInt value, BigInt fee) {
  if (balance < value + fee) {
    throw const _TransferRejected(MessageCode.transferInsufficientFee);
  }
}

Future<T> _simulateEvm<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on RPCError catch (error) {
    final message = error.message.toLowerCase();
    if (message.contains('insufficient funds')) {
      throw const _TransferRejected(MessageCode.transferInsufficientFee);
    }
    if (error.errorCode == 3 || message.contains('revert')) {
      throw const _TransferRejected(MessageCode.transferSimulationFailed);
    }
    rethrow;
  }
}
