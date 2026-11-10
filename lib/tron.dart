part of 'wallet_core.dart';

String tronAccountDerivationPath(int index) => "m/44'/195'/0'/0/$index";

Uint8List decodeTronAddress(String address) {
  try {
    final bytes = base58.decode(address);
    if (bytes.length != 21 ||
        bytes.first != 0x41 ||
        base58.encode(bytes) != address) {
      throw const FormatException();
    }
    return bytes;
  } catch (_) {
    throw const WalletInputException(
      MessageCode.msgEnterAValidTronAddressStartingWithT,
    );
  }
}

// Only TransferContract is supported. Encoding follows tronprotocol/protocol;
// all recipient/amount bytes are constructed locally, never trusted to an RPC.
List<int> _varint(BigInt value) {
  final bytes = <int>[];
  do {
    final low = (value & BigInt.from(127)).toInt();
    value >>= 7;
    bytes.add(low | (value == BigInt.zero ? 0 : 128));
  } while (value > BigInt.zero);
  return bytes;
}

List<int> _protoInt(int field, BigInt value) => [field << 3, ..._varint(value)];
List<int> _protoBytes(int field, List<int> value) => [
  (field << 3) | 2,
  ..._varint(BigInt.from(value.length)),
  ...value,
];

class TronNetworkService extends EvmNetworkService {
  TronNetworkService._({
    required super.network,
    required super.httpClient,
    required super.ownsHttpClient,
    required super.endpointTimeout,
  }) : super._(clients: []);

  static const genesisBlockId =
      '00000000000000001ebf88508a03865c71d452e25f4d51194196a1d22b6653dc';

  Future<Map<String, dynamic>> _post(
    int index,
    String path,
    Map<String, Object> body,
  ) async {
    if (_disposed) throw StateError('RPC service disposed');
    final root = network.rpcUrls[index].replaceFirst(RegExp(r'/+$'), '');
    final response = await _httpClient
        .post(
          Uri.parse('$root/$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(endpointTimeout);
    if (_disposed) throw StateError('RPC service disposed');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('TRON HTTP ${response.statusCode}');
    }
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (result.containsKey('Error') || result.containsKey('error')) {
      throw const WalletInputException(
        MessageCode.msgTheTronEndpointReturnedAnErrorTryAnother,
      );
    }
    return result;
  }

  Future<T> _withTronFailover<T>(Future<T> Function(int) operation) async {
    final first = _activeIndex;
    Object? lastError;
    for (var offset = 0; offset < network.rpcUrls.length; offset++) {
      final index = (first + offset) % network.rpcUrls.length;
      try {
        final genesis = await _post(index, 'wallet/getblockbynum', {'num': 0});
        if (genesis['blockID'] != genesisBlockId) {
          throw const WalletInputException(
            MessageCode.msgTronNetworkMismatchAMainnetEndpointIsRequired,
          );
        }
        final value = await operation(index);
        if (_disposed) throw StateError('RPC service disposed');
        _activeIndex = index;
        return value;
      } catch (e) {
        if (_disposed) rethrow;
        lastError = e;
      }
    }
    if (lastError is WalletInputException) throw lastError;
    throw WalletInputException(
      MessageCode.msgAllTronEndpointsAreUnavailableTryAgainLater,
      arguments: [network.rpcUrls.length],
    );
  }

  @override
  Future<void> checkConnection() => _withTronFailover((_) async {});

  @override
  Future<String> readTokenContract(
    String contract,
    String signature,
    String parameter,
  ) => _withTronFailover((index) async {
    decodeTronAddress(contract);
    final result = await _post(index, 'wallet/triggerconstantcontract', {
      'owner_address': contract,
      'contract_address': contract,
      'function_selector': signature,
      'parameter': parameter,
      'visible': true,
    });
    final status = result['result'];
    final values = result['constant_result'];
    if (status is! Map ||
        status['result'] != true ||
        values is! List ||
        values.length != 1 ||
        values.single is! String) {
      throw const WalletInputException(
        MessageCode.msgTrcQueryFailedCheckTheContractAndEndpoint,
      );
    }
    final value = values.single as String;
    validateTokenResponse(signature, value);
    return value;
  });

  @override
  Future<EtherAmount> getNativeBalance(
    WalletAccount account,
  ) => _withTronFailover((index) async {
    final address = account.tronAddress;
    final result = await _post(index, 'wallet/getaccount', {
      'address': address,
      'visible': true,
    });
    // An unactivated address is returned as {} by java-tron, not an RPC error.
    if (result.isEmpty) return EtherAmount.inWei(BigInt.zero);
    final returned = result['address'];
    final hex = bytesToHex(decodeTronAddress(address));
    if (returned != address && returned.toString().toLowerCase() != hex) {
      throw const WalletInputException(
        MessageCode.msgTheTronEndpointReturnedADifferentAccountS,
      );
    }
    final balance = result['balance'] ?? 0;
    if (balance is! int || balance < 0) {
      throw const WalletInputException(
        MessageCode.msgTheTronEndpointReturnedAnInvalidBalance,
      );
    }
    // Compatibility container: getInWei carries atomic SUN here, not ETH Wei.
    return EtherAmount.inWei(BigInt.from(balance));
  });

  @override
  Future<String> sendNative({
    required WalletAccount account,
    required String recipient,
    required BigInt amountWei,
  }) async {
    final owner = decodeTronAddress(account.tronAddress);
    final to = decodeTronAddress(recipient);
    if (amountWei <= BigInt.zero ||
        amountWei > BigInt.parse('9223372036854775807')) {
      throw const WalletInputException(MessageCode.msgTrxAmountIsOutOfRange);
    }
    final (blockId, timestamp) = await _withTronFailover((index) async {
      final block = await _post(index, 'wallet/getnowblock', {});
      final blockId = block['blockID'] as String? ?? '';
      final header = (block['block_header'] as Map?)?['raw_data'] as Map?;
      final timestamp = header?['timestamp'];
      final number = header?['number'];
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(blockId) ||
          timestamp is! int ||
          number is! int ||
          number <= 0 ||
          int.parse(blockId.substring(0, 16), radix: 16) != number ||
          (timestamp - now).abs() > const Duration(minutes: 3).inMilliseconds) {
        throw const WalletInputException(
          MessageCode.msgTronReferenceBlockIsInvalidOrStaleCheck,
        );
      }
      return (blockId, timestamp);
    });
    final expiration = timestamp + const Duration(minutes: 10).inMilliseconds;
    final transfer = [
      ..._protoBytes(1, owner),
      ..._protoBytes(2, to),
      ..._protoInt(3, amountWei),
    ];
    const typeUrl = 'type.googleapis.com/protocol.TransferContract';
    final contract = [
      ..._protoInt(1, BigInt.one),
      ..._protoBytes(2, [
        ..._protoBytes(1, utf8.encode(typeUrl)),
        ..._protoBytes(2, transfer),
      ]),
    ];
    final refBytes = blockId.substring(12, 16);
    final refHash = blockId.substring(16, 32);
    final raw = Uint8List.fromList([
      ..._protoBytes(1, ec.hexToBytes(refBytes)),
      ..._protoBytes(4, ec.hexToBytes(refHash)),
      ..._protoInt(8, BigInt.from(expiration)),
      ..._protoBytes(11, contract),
      ..._protoInt(14, BigInt.from(timestamp)),
    ]);
    final digest = Uint8List.fromList(hashes.sha256.convert(raw).bytes);
    final hash = bytesToHex(digest);
    final signature = ec.sign(digest, account._tronCredentials.privateKey);
    String scalar(BigInt value) => value.toRadixString(16).padLeft(64, '0');
    final signatureHex =
        '${scalar(signature.r)}${scalar(signature.s)}${(signature.v - 27).toRadixString(16).padLeft(2, '0')}';
    final signed = <String, Object>{
      'visible': false,
      'txID': hash,
      'raw_data_hex': bytesToHex(raw),
      'raw_data': {
        'ref_block_bytes': refBytes,
        'ref_block_hash': refHash,
        'expiration': expiration,
        'timestamp': timestamp,
        'contract': [
          {
            'type': 'TransferContract',
            'parameter': {
              'type_url': typeUrl,
              'value': {
                'owner_address': bytesToHex(owner),
                'to_address': bytesToHex(to),
                'amount': amountWei.toInt(),
              },
            },
          },
        ],
      },
      'signature': [signatureHex],
    };
    var attempted = false;
    try {
      return await _withTronFailover((index) async {
        // Never rebuild or re-sign after a timeout: retries broadcast identical bytes.
        attempted = true;
        final result = await _post(
          index,
          'wallet/broadcasttransaction',
          signed,
        );
        if (result['result'] != true || result['txid'] != hash) {
          throw const WalletInputException(
            MessageCode.msgTheTronEndpointDidNotConfirmTheBroadcast,
          );
        }
        return hash;
      });
    } catch (_) {
      if (attempted) throw RpcBroadcastException(hash);
      rethrow;
    }
  }
}
