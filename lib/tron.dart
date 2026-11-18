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

// Transaction encoding follows tronprotocol/protocol;
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

List<int> _protoInt(int field, BigInt value) => [
  ..._varint(BigInt.from(field << 3)),
  ..._varint(value),
];
List<int> _protoBytes(int field, List<int> value) => [
  ..._varint(BigInt.from((field << 3) | 2)),
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
        if (_disposed || e is _TransferRejected) rethrow;
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
  Future<EtherAmount> getNativeBalanceForAddress(String address) async {
    decodeTronAddress(address);
    return _withTronFailover((index) => _tronBalance(index, address));
  }

  Future<EtherAmount> _tronBalance(int index, String address) async {
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
  }

  @override
  Future<String> sendNative({
    required WalletAccount account,
    required String recipient,
    required BigInt amountWei,
  }) async {
    account._requireSigningAccount();
    final owner = decodeTronAddress(account.tronAddress);
    final to = decodeTronAddress(recipient);
    if (amountWei <= BigInt.zero ||
        amountWei > BigInt.parse('9223372036854775807')) {
      throw const WalletInputException(MessageCode.msgTrxAmountIsOutOfRange);
    }
    return _sendTron(account, _nativeContract(owner, to, amountWei));
  }

  @override
  Future<PreparedWalletTransfer> prepareTransfer({
    required WalletAccount account,
    required String recipient,
    required BigInt amount,
    TokenDefinition? token,
  }) async {
    account._requireSigningAccount();
    final address = account.tronAddress;
    final owner = decodeTronAddress(address);
    final to = decodeTronAddress(recipient);
    _validateTransfer(network, token, amount);
    final nativeValue = token == null ? amount : BigInt.zero;
    final (contract, feeLimit, fee) = await _withTronFailover((index) async {
      final balance = (await _tronBalance(index, address)).getInWei;
      _requireBalance(balance, nativeValue);
      final params = await _tronFeeParameters(index);
      final resources = await _post(index, 'wallet/getaccountresource', {
        'address': address,
        'visible': true,
      });
      BigInt remaining(String limit, String used) {
        final available =
            _tronResource(resources[limit]) - _tronResource(resources[used]);
        return available < BigInt.zero ? BigInt.zero : available;
      }

      final staked = remaining('NetLimit', 'NetUsed');
      final free = remaining('freeNetLimit', 'freeNetUsed');
      // Covers the encoded transfer, signature and transaction result.
      final bandwidth = BigInt.from(350);
      final bandwidthBurn = staked >= bandwidth || free >= bandwidth
          ? BigInt.zero
          : bandwidth * _tronParameter(params, 'getTransactionFee');
      if (token == null) {
        final recipientAccount = await _post(index, 'wallet/getaccount', {
          'address': recipient,
          'visible': true,
        });
        final creationBurn = recipientAccount.isNotEmpty
            ? bandwidthBurn
            : _tronParameter(params, 'getCreateNewAccountFeeInSystemContract') +
                  (staked >=
                          bandwidth *
                              _tronParameter(
                                params,
                                'getCreateNewAccountBandwidthRate',
                              )
                      ? BigInt.zero
                      : _tronParameter(params, 'getCreateAccountFee'));
        _requireFeeBalance(balance, nativeValue, creationBurn);
        return (_nativeContract(owner, to, amount), BigInt.zero, creationBurn);
      }

      final contractAddress = decodeTronAddress(token.contract);
      final decimals = await _tronTokenCall(
        index,
        address,
        token.contract,
        'decimals()',
        '',
      );
      _requireTokenDecimals(token, decimals.$1);
      final tokenBalance = await _tronTokenCall(
        index,
        address,
        token.contract,
        'balanceOf(address)',
        bytesToHex(_addressWord(owner.sublist(1))),
      );
      _requireBalance(decodeTokenUint(tokenBalance.$1), amount);
      final data = _transferData(to.sublist(1), amount);
      final (result, energy) = await _tronTokenCall(
        index,
        address,
        token.contract,
        _transferSignature,
        bytesToHex(data.sublist(4)),
      );
      _requireTransferSuccess(result);
      if (energy <= BigInt.zero) {
        throw const WalletInputException(MessageCode.transferFeeUnavailable);
      }
      final energyPrice = _tronParameter(params, 'getEnergyFee');
      // Leave room for Energy to increase between review and execution.
      final budget =
          (energy * BigInt.from(12) + BigInt.from(9)) ~/ BigInt.from(10);
      final feeLimit = budget * energyPrice;
      if (energyPrice <= BigInt.zero ||
          feeLimit > _int64Max ||
          feeLimit > _tronParameter(params, 'getMaxFeeLimit')) {
        throw const WalletInputException(MessageCode.transferFeeUnavailable);
      }
      final energyAvailable = remaining('EnergyLimit', 'EnergyUsed');
      final energyBurn = budget > energyAvailable
          ? (budget - energyAvailable) * energyPrice
          : BigInt.zero;
      final fee = energyBurn + bandwidthBurn;
      _requireFeeBalance(balance, BigInt.zero, fee);
      return (_tokenContract(owner, contractAddress, data), feeLimit, fee);
    });
    return PreparedWalletTransfer._(
      fee: fee,
      send: () => _sendTron(
        account,
        contract,
        feeLimit: feeLimit,
        reviewedCost: nativeValue + fee,
      ),
    );
  }

  Future<(String, BigInt)> _tronTokenCall(
    int index,
    String owner,
    String contract,
    String selector,
    String parameter,
  ) async {
    final response = await _post(index, 'wallet/triggerconstantcontract', {
      'owner_address': owner,
      'contract_address': contract,
      'function_selector': selector,
      'parameter': parameter,
      'visible': true,
    });
    final result = response['result'];
    final values = response['constant_result'];
    if (result is! Map || result['result'] != true) {
      if (selector == _transferSignature) {
        throw const _TransferRejected(MessageCode.transferSimulationFailed);
      }
      throw const WalletInputException(
        MessageCode.msgTrcQueryFailedCheckTheContractAndEndpoint,
      );
    }
    if (selector == _transferSignature &&
        (values == null || values is List && values.isEmpty)) {
      return ('', _tronResource(response['energy_used']));
    }
    if (values is! List || values.length != 1 || values.single is! String) {
      throw const WalletInputException(
        MessageCode.msgTrcQueryFailedCheckTheContractAndEndpoint,
      );
    }
    return (values.single as String, _tronResource(response['energy_used']));
  }

  Future<Map<String, Object?>> _tronFeeParameters(int index) async {
    final result = await _post(index, 'wallet/getchainparameters', {});
    final items = result['chainParameter'];
    if (items is! List) {
      throw const WalletInputException(MessageCode.transferFeeUnavailable);
    }
    return {
      for (final item in items.whereType<Map>())
        if (item['key'] is String) item['key'] as String: item['value'] ?? 0,
    };
  }

  Future<String> _sendTron(
    WalletAccount account,
    _TronContract contract, {
    BigInt? feeLimit,
    BigInt? reviewedCost,
  }) async {
    account._requireSigningAccount();
    final (blockId, timestamp) = await _withTronFailover((index) async {
      if (reviewedCost != null) {
        final balance = (await _tronBalance(
          index,
          account.tronAddress,
        )).getInWei;
        _requireFeeBalance(balance, reviewedCost, BigInt.zero);
      }
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
    final typeUrl = 'type.googleapis.com/protocol.${contract.name}';
    final encodedContract = [
      ..._protoInt(1, BigInt.from(contract.type)),
      ..._protoBytes(2, [
        ..._protoBytes(1, utf8.encode(typeUrl)),
        ..._protoBytes(2, contract.bytes),
      ]),
    ];
    final refBytes = blockId.substring(12, 16);
    final refHash = blockId.substring(16, 32);
    final raw = Uint8List.fromList([
      ..._protoBytes(1, ec.hexToBytes(refBytes)),
      ..._protoBytes(4, ec.hexToBytes(refHash)),
      ..._protoInt(8, BigInt.from(expiration)),
      ..._protoBytes(11, encodedContract),
      ..._protoInt(14, BigInt.from(timestamp)),
      if (feeLimit != null && feeLimit > BigInt.zero)
        ..._protoInt(18, feeLimit),
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
        if (feeLimit != null && feeLimit > BigInt.zero)
          'fee_limit': feeLimit.toInt(),
        'contract': [
          {
            'type': contract.name,
            'parameter': {'type_url': typeUrl, 'value': contract.value},
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
        if (result['result'] != true ||
            (result['txid'] != null && result['txid'] != hash)) {
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

class _TronContract {
  const _TronContract(this.type, this.name, this.bytes, this.value);
  final int type;
  final String name;
  final List<int> bytes;
  final Map<String, Object> value;
}

_TronContract _nativeContract(
  List<int> owner,
  List<int> recipient,
  BigInt amount,
) => _TronContract(
  1,
  'TransferContract',
  [
    ..._protoBytes(1, owner),
    ..._protoBytes(2, recipient),
    ..._protoInt(3, amount),
  ],
  {
    'owner_address': bytesToHex(owner),
    'to_address': bytesToHex(recipient),
    'amount': amount.toInt(),
  },
);

_TronContract _tokenContract(
  List<int> owner,
  List<int> contract,
  List<int> data,
) => _TronContract(
  31,
  'TriggerSmartContract',
  [
    ..._protoBytes(1, owner),
    ..._protoBytes(2, contract),
    ..._protoBytes(4, data),
  ],
  {
    'owner_address': bytesToHex(owner),
    'contract_address': bytesToHex(contract),
    'data': bytesToHex(data),
  },
);

BigInt _tronResource(Object? value) {
  if (value == null) return BigInt.zero;
  if (value is! int || value < 0) {
    throw const WalletInputException(MessageCode.transferFeeUnavailable);
  }
  return BigInt.from(value);
}

BigInt _tronParameter(Map<String, Object?> params, String key) {
  if (!params.containsKey(key)) {
    throw const WalletInputException(MessageCode.transferFeeUnavailable);
  }
  return _tronResource(params[key]);
}
