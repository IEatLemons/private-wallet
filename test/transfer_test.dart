import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'package:web3dart/crypto.dart' as ec;
import 'package:web3dart/web3dart.dart'
    show EtherAmount, EthereumAddress, Transaction, signTransactionRaw;

import 'network_management_test.dart'
    show RpcFixture, input, rpcResult, start, tap;
import 'tron_test.dart'
    show addressOne, fields, headBlock, keyOne, mnemonicAddress, reply;
import 'widget_test.dart' show MapSecretStore;

final _account = WalletAccount.fromPrivateKey(keyOne);
const _recipient = '0x1111111111111111111111111111111111111111';
String _word(int value) => value.toRadixString(16).padLeft(64, '0');
final _evmToken = builtinTokens.firstWhere((token) => token.networkId == 56);
final _tronToken = builtinTokens.firstWhere(
  (token) => token.networkId == tronMainnetNetwork.id,
);

void main() {
  test('zero-decimal tokens accept only whole amounts', () {
    expect(parseNativeAmount('42', 0), BigInt.from(42));
    expect(
      () => parseNativeAmount('1.1', 0),
      throwsA(isA<WalletInputException>()),
    );
  });

  for (final outcome in [
    'success',
    'low-fee-balance',
    'false-return',
    'decimals-changed',
  ]) {
    test(
      'BEP20 checks the exact contract and only signs an approved review ($outcome)',
      () async {
        final broadcasts = <String>[];
        final amount = BigInt.parse('1230000000000000000');
        final calldata =
            '0xa9059cbb${_recipient.substring(2).padLeft(64, '0')}${amount.toRadixString(16).padLeft(64, '0')}';
        final service = EvmNetworkService(
          network: bnbSmartChainNetwork,
          httpClient: MockClient((request) async {
            final rpc = jsonDecode(request.body) as Map;
            final params = rpc['params'] as List;
            switch (rpc['method']) {
              case 'eth_chainId':
                return rpcResult(request, '0x38');
              case 'eth_call':
                final call = params.first as Map;
                expect(
                  call['to'].toString().toLowerCase(),
                  _evmToken.contract.toLowerCase(),
                );
                final data = call['data'] as String;
                if (data == '0x313ce567') {
                  return rpcResult(
                    request,
                    '0x${_word(outcome == 'decimals-changed' ? 6 : 18)}',
                  );
                }
                if (data.startsWith('0x70a08231')) {
                  return rpcResult(
                    request,
                    '0x${(amount * BigInt.two).toRadixString(16).padLeft(64, '0')}',
                  );
                }
                expect(data, calldata);
                expect(
                  call['from'].toString().toLowerCase(),
                  _account.addressHex,
                );
                return rpcResult(
                  request,
                  '0x${_word(outcome == 'false-return' ? 0 : 1)}',
                );
              case 'eth_getBalance':
                return rpcResult(
                  request,
                  outcome == 'low-fee-balance' ? '0x0' : '0xfffffff',
                );
              case 'eth_gasPrice':
                return rpcResult(request, '0x2');
              case 'eth_estimateGas':
                expect(params.first['data'], calldata);
                expect(params.first['value'], '0x0');
                return rpcResult(request, '0x10000');
              case 'eth_getTransactionCount':
                expect(params.last, 'pending');
                return rpcResult(request, '0x1');
              case 'eth_sendRawTransaction':
                final raw = params.single as String;
                broadcasts.add(raw);
                return rpcResult(
                  request,
                  ec.bytesToHex(
                    ec.keccak256(ec.hexToBytes(raw)),
                    include0x: true,
                  ),
                );
              default:
                throw StateError('Unexpected test method');
            }
          }),
        );
        addTearDown(service.dispose);
        final future = service.prepareTransfer(
          account: _account,
          recipient: _recipient,
          amount: amount,
          token: _evmToken,
        );
        if (outcome != 'success') {
          await expectLater(
            future,
            throwsA(
              isA<WalletInputException>().having(
                (error) => error.code,
                'code',
                switch (outcome) {
                  'false-return' => MessageCode.transferSimulationFailed,
                  'decimals-changed' =>
                    MessageCode.transferTokenDecimalsChanged,
                  _ => MessageCode.transferInsufficientFee,
                },
              ),
            ),
          );
          expect(broadcasts, isEmpty);
          return;
        }
        final prepared = await future;
        expect(prepared.fee, BigInt.from(131072));
        expect(broadcasts, isEmpty);
        expect(await prepared.broadcast(), startsWith('0x'));
        final expected = signTransactionRaw(
          Transaction(
            from: _account.address,
            to: EthereumAddress.fromHex(_evmToken.contract),
            value: EtherAmount.inWei(BigInt.zero),
            data: ec.hexToBytes(calldata),
            gasPrice: EtherAmount.inWei(BigInt.two),
            maxGas: 65536,
            nonce: 1,
          ),
          _account.credentials,
          chainId: bnbSmartChainNetwork.id,
        );
        expect(ec.hexToBytes(broadcasts.single), expected);
        await expectLater(
          prepared.broadcast(),
          throwsA(isA<WalletInputException>()),
        );
        expect(broadcasts, hasLength(1));
      },
    );
  }

  test(
    'TRC20 builds and signs the reviewed transfer locally and retries identical bytes',
    () async {
      final broadcasts = <String>[];
      final recipientBytes = decodeTronAddress(mnemonicAddress).sublist(1);
      final parameter =
          '${ec.bytesToHex(recipientBytes).padLeft(64, '0')}${_word(1250000)}';
      final service = EvmNetworkService(
        network: tronMainnetNetwork,
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          switch (request.url.path.split('/').last) {
            case 'getblockbynum':
              return reply({'blockID': TronNetworkService.genesisBlockId});
            case 'getaccount':
              return reply({'address': addressOne, 'balance': 100000000});
            case 'getaccountresource':
              return reply({'freeNetLimit': 600, 'EnergyLimit': 50000});
            case 'getchainparameters':
              return reply({
                'chainParameter': [
                  {'key': 'getEnergyFee', 'value': 100},
                  {'key': 'getMaxFeeLimit', 'value': 15000000000},
                ],
              });
            case 'triggerconstantcontract':
              expect(body['owner_address'], addressOne);
              expect(body['contract_address'], _tronToken.contract);
              final selector = body['function_selector'];
              if (selector == 'transfer(address,uint256)') {
                expect(body['parameter'], parameter);
              }
              return reply({
                'result': {'result': true},
                'constant_result': [
                  _word(switch (selector) {
                    'decimals()' => 6,
                    'balanceOf(address)' => 2000000,
                    _ => 1,
                  }),
                ],
                'energy_used': 65000,
                'transaction': {'raw_data_hex': 'untrusted'},
              });
            case 'getnowblock':
              return reply(headBlock());
            case 'broadcasttransaction':
              broadcasts.add(request.body);
              if (broadcasts.length == 1) {
                return http.Response('unavailable', 503);
              }
              return reply({'result': true, 'txid': body['txID']});
            default:
              throw StateError('Unexpected test path');
          }
        }),
      );
      addTearDown(service.dispose);
      final prepared = await service.prepareTransfer(
        account: _account,
        recipient: mnemonicAddress,
        amount: BigInt.from(1250000),
        token: _tronToken,
      );
      expect(prepared.fee, BigInt.from(2800000));
      expect(broadcasts, isEmpty);
      final hash = await prepared.broadcast();
      expect(broadcasts, hasLength(2));
      expect(broadcasts.first, broadcasts.last);
      final submitted = jsonDecode(broadcasts.last) as Map;
      final raw = ec.hexToBytes(submitted['raw_data_hex'] as String);
      expect(sha256.convert(raw).toString(), hash);
      final tx = fields(raw);
      expect(tx[18], BigInt.from(7800000));
      final contract = fields(tx[11] as List<int>);
      expect(contract[1], BigInt.from(31));
      final payload = fields(fields(contract[2] as List<int>)[2] as List<int>);
      expect(payload.keys, [1, 2, 4]);
      expect(payload[1], decodeTronAddress(addressOne));
      expect(payload[2], decodeTronAddress(_tronToken.contract));
      expect(ec.bytesToHex(payload[4] as List<int>), 'a9059cbb$parameter');
      final signature = ec.hexToBytes(
        (submitted['signature'] as List).single as String,
      );
      final signer = ec.ecRecover(
        ec.hexToBytes(hash),
        ec.MsgSignature(
          ec.bytesToUnsignedInt(signature.sublist(0, 32)),
          ec.bytesToUnsignedInt(signature.sublist(32, 64)),
          signature.last + 27,
        ),
      );
      expect([
        0x41,
        ...ec.keccak256(signer).sublist(12),
      ], decodeTronAddress(addressOne));
    },
  );

  testWidgets('asset home sends BSC USDT only after reviewing amount and fee', (
    tester,
  ) async {
    final vault = WalletVault(store: MapSecretStore({}));
    await vault.importPrivateKeyWallet(privateKey: keyOne, networkId: 56);
    await vault.saveSelectedNetwork(bnbSmartChainNetwork);
    var broadcasts = 0;
    final rpc = RpcFixture()
      ..handler = (request, network) async {
        final json = jsonDecode(request.body) as Map;
        final params = json['params'] as List;
        switch (json['method']) {
          case 'eth_chainId':
            return rpcResult(request, '0x38');
          case 'eth_getBalance':
            return rpcResult(request, '0xfffffff');
          case 'eth_call':
            final data = params.first['data'] as String;
            if (data == '0x313ce567') {
              return rpcResult(request, '0x${_word(18)}');
            }
            if (data.startsWith('0xa9059cbb')) {
              return rpcResult(request, '0x${_word(1)}');
            }
            return rpcResult(
              request,
              '0x${(BigInt.from(2) * BigInt.from(10).pow(18)).toRadixString(16).padLeft(64, '0')}',
            );
          case 'eth_gasPrice':
            return rpcResult(request, '0x1');
          case 'eth_estimateGas':
            return rpcResult(request, '0x10000');
          case 'eth_getTransactionCount':
            return rpcResult(request, '0x0');
          case 'eth_sendRawTransaction':
            broadcasts++;
            return rpcResult(
              request,
              ec.bytesToHex(
                ec.keccak256(ec.hexToBytes(params.single as String)),
                include0x: true,
              ),
            );
          default:
            throw StateError('Unexpected test method');
        }
      };
    await start(tester, vault, rpc);
    await tap(tester, find.byKey(const ValueKey('portfolio-send')));
    await tap(tester, find.text('USDT · BNB Smart Chain'));
    await input(tester, '收款地址', _recipient);
    await input(tester, '金额（USDT）', '1');
    await tap(tester, find.text('核对转账'));
    expect(broadcasts, 0);
    expect(find.text('预计网络手续费'), findsOneWidget);
    await tap(tester, find.text('签名并广播'));
    expect(broadcasts, 1);
    expect(find.text('查看链上交易'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
