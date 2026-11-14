import 'asset_test_helpers.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/main.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'package:web3dart/crypto.dart' as ec;

import 'network_management_test.dart' show tap, input;
import 'widget_test.dart' show MapSecretStore;

const phrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
const addressOne = 'TMVQGm1qAQYVdetCeGRRkTWYYrLXuHK2HC';
const mnemonicAddress = 'TUEZSdKsoDHQMeZwihtdoBiN46zxhGWYdH';
final keyOne = '1'.padLeft(64, '0');

http.Response reply(Object value) => http.Response(jsonEncode(value), 200);
Map<String, Object> headBlock() => {
  'blockID': '0000000000003039${'ab' * 24}',
  'block_header': {
    'raw_data': {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'number': 12345,
    },
  },
};

// Independent wire decoder: verify the locally signed protobuf contains only
// the transfer requested by the user, and no injected contract/fee fields.
Map<int, dynamic> fields(List<int> bytes) {
  var offset = 0;
  BigInt number() {
    var result = BigInt.zero, shift = 0;
    while (true) {
      final b = bytes[offset++];
      result |= BigInt.from(b & 127) << shift;
      if (b < 128) return result;
      shift += 7;
    }
  }

  final result = <int, dynamic>{};
  while (offset < bytes.length) {
    final tag = number().toInt();
    expect(result.containsKey(tag >> 3), false);
    if (tag & 7 == 0) {
      result[tag >> 3] = number();
    } else {
      expect(tag & 7, 2);
      final length = number().toInt();
      result[tag >> 3] = bytes.sublist(offset, offset + length);
      offset += length;
    }
  }
  return result;
}

void main() {
  test(
    'BNB and TRON catalog, aliases and legacy network records preserve protocols',
    () async {
      final vault = WalletVault(store: MapSecretStore({}));
      final networks = await vault.loadNetworks();
      expect(networks.map((n) => n.id), containsAll([56, 728126428]));
      expect(networkForValue('币安')!.id, 56);
      expect(networkForValue('波场')!.isTron, true);
      expect(networkForValue('BSC')!.protocol, NetworkProtocol.evm);
      final json = ethereumMainnetNetwork.toJson()..remove('protocol');
      expect(EvmNetwork.fromJson(json).isTron, false);
      await vault.saveNetwork(
        tronMainnetNetwork.copyWith(rpcUrls: ['https://custom.example/api']),
      );
      final saved = (await vault.loadNetworks()).singleWhere((n) => n.isTron);
      expect(saved.rpcUrls, ['https://custom.example/api']);
      expect(saved.nativeDecimals, 6);
      expect(
        () => EvmNetwork.fromJson({...saved.toJson(), 'protocol': 'evm'}),
        throwsA(isA<WalletInputException>()),
      );
    },
  );

  test(
    'TRON mnemonic and private-key address vectors, derivation and import persist',
    () async {
      final account = WalletAccount.fromMnemonic(phrase);
      expect(account.tronAddress, mnemonicAddress);
      expect(
        account.checksumAddress,
        '0x9858EfFD232B4033E47d90003D41EC34EcaEda94',
      );
      expect(WalletAccount.fromPrivateKey(keyOne).tronAddress, addressOne);
      final store = MapSecretStore({});
      final vault = WalletVault(store: store);
      final root = await vault.addMnemonicWallet(phrase);
      final child = (await vault.addDerivedAccount(
        root.groups.single.id,
      )).selected!;
      expect(child.derivationPathFor(tronMainnetNetwork), "m/44'/195'/0'/0/1");
      expect(child.account.tronAddress, isNot(mnemonicAddress));
      expect(
        (await WalletVault(
          store: store,
        ).loadPortfolio()).selected!.account.tronAddress,
        child.account.tronAddress,
      );
      await vault.importPrivateKeyWallet(
        privateKey: keyOne,
        networkId: tronMainnetNetwork.id,
      );
      final imported = (await vault.loadPortfolio()).selected!;
      expect(imported.account.addressFor(tronMainnetNetwork), addressOne);
      expect(imported.derivationPathFor(tronMainnetNetwork), isNull);
    },
  );

  test(
    'TRX uses six decimals and rejects EVM addresses and damaged checksums',
    () {
      expect(tronMainnetNetwork.parseAmount('1.234567'), BigInt.from(1234567));
      expect(tronMainnetNetwork.formatAmount(BigInt.one), '0.000001');
      expect(
        bnbSmartChainNetwork.parseAmount('1.234567890123456789'),
        BigInt.parse('1234567890123456789'),
      );
      expect(
        () => tronMainnetNetwork.parseAmount('1.0000001'),
        throwsA(isA<WalletInputException>()),
      );
      expect(
        () => tronMainnetNetwork.validateAddress('0x${'01' * 20}'),
        throwsA(isA<WalletInputException>()),
      );
      expect(
        () => decodeTronAddress('${addressOne.substring(0, 33)}A'),
        throwsA(isA<WalletInputException>()),
      );
      expect(
        () => bnbSmartChainNetwork.validateAddress(addressOne),
        throwsA(anything),
      );
    },
  );

  test(
    'TRON balance failover checks genesis, uses SUN, handles unactivated accounts',
    () async {
      var empty = false;
      final calls = <Uri>[];
      final client = MockClient((r) async {
        calls.add(r.url);
        if (r.url.host == 'bad.example') {
          return http.Response('rate limited', 429);
        }
        if (r.url.path.endsWith('getblockbynum')) {
          return reply({'blockID': TronNetworkService.genesisBlockId});
        }
        expect(jsonDecode(r.body), {'address': addressOne, 'visible': true});
        return reply(empty ? {} : {'address': addressOne, 'balance': 1234567});
      });
      final service = EvmNetworkService(
        network: tronMainnetNetwork.copyWith(
          rpcUrls: ['https://bad.example', 'https://good.example'],
        ),
        httpClient: client,
      );
      final account = WalletAccount.fromPrivateKey(keyOne);
      expect(
        (await service.getNativeBalance(account)).getInWei,
        BigInt.from(1234567),
      );
      expect(service.activeRpcUrl, 'https://good.example');
      calls.clear();
      empty = true;
      expect((await service.getNativeBalance(account)).getInWei, BigInt.zero);
      expect(calls.every((u) => u.host == 'good.example'), true);
      await service.dispose();
    },
  );

  test(
    'wrong TRON network and malformed balances never become zero or broadcast',
    () async {
      for (final wrongChain in [true, false]) {
        final service = EvmNetworkService(
          network: tronMainnetNetwork,
          httpClient: MockClient((r) async {
            if (r.url.path.endsWith('getblockbynum')) {
              return reply({
                'blockID': wrongChain
                    ? 'nile'
                    : TronNetworkService.genesisBlockId,
              });
            }
            expect(r.url.path.endsWith('getaccount'), true);
            return reply({'address': addressOne, 'balance': 'bad'});
          }),
        );
        await expectLater(
          service.getNativeBalance(WalletAccount.fromPrivateKey(keyOne)),
          throwsA(isA<WalletInputException>()),
        );
        await service.dispose();
      }
    },
  );

  test(
    'TRX transfer signs exact local protobuf, hashes with SHA256 and retries identical bytes',
    () async {
      final bodies = <String>[];
      final owner = WalletAccount.fromPrivateKey(keyOne);
      final to = WalletAccount.fromPrivateKey('2'.padLeft(64, '0')).tronAddress;
      final service = EvmNetworkService(
        network: tronMainnetNetwork,
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('getblockbynum')) {
            return reply({'blockID': TronNetworkService.genesisBlockId});
          }
          if (r.url.path.endsWith('getnowblock')) return reply(headBlock());
          expect(r.url.path.endsWith('broadcasttransaction'), true);
          bodies.add(r.body);
          if (bodies.length == 1) throw TimeoutException('response lost');
          return reply({'result': true, 'txid': jsonDecode(r.body)['txID']});
        }),
      );
      final hash = await service.sendNative(
        account: owner,
        recipient: to,
        amountWei: BigInt.from(1234567),
      );
      expect(bodies, hasLength(2));
      expect(bodies[0], bodies[1]);
      expect(bodies.first.contains(keyOne), false);
      final body = jsonDecode(bodies.first) as Map;
      final raw = ec.hexToBytes(body['raw_data_hex'] as String);
      final digest = Uint8List.fromList(sha256.convert(raw).bytes);
      expect(ec.bytesToHex(digest), hash);
      final message = fields(raw);
      expect(message.keys.toSet(), {1, 4, 8, 11, 14});
      expect(ec.bytesToHex(message[1] as List<int>), '3039');
      expect(ec.bytesToHex(message[4] as List<int>), 'ab' * 8);
      final contract = fields(message[11] as List<int>);
      expect(contract.keys.toSet(), {1, 2});
      expect(contract[1], BigInt.one);
      final any = fields(contract[2] as List<int>);
      expect(
        utf8.decode(any[1] as List<int>),
        'type.googleapis.com/protocol.TransferContract',
      );
      final transfer = fields(any[2] as List<int>);
      expect(transfer.keys.toSet(), {1, 2, 3});
      expect(transfer[1], decodeTronAddress(addressOne));
      expect(transfer[2], decodeTronAddress(to));
      expect(transfer[3], BigInt.from(1234567));
      final sig = ec.hexToBytes((body['signature'] as List).single as String);
      expect(sig, hasLength(65));
      final recovered = ec.ecRecover(
        digest,
        ec.MsgSignature(
          ec.bytesToUnsignedInt(sig.sublist(0, 32)),
          ec.bytesToUnsignedInt(sig.sublist(32, 64)),
          sig.last + 27,
        ),
      );
      expect(
        recovered,
        ec.privateKeyBytesToPublic(owner.credentials.privateKey),
      );
      expect(message[8], (message[14] as BigInt) + BigInt.from(600000));
      await service.dispose();
    },
  );

  test(
    'mnemonic transfer signs with the TRON key rather than its EVM key',
    () async {
      final owner = WalletAccount.fromMnemonic(phrase);
      Map<String, dynamic>? broadcast;
      final service = EvmNetworkService(
        network: tronMainnetNetwork,
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('getblockbynum')) {
            return reply({'blockID': TronNetworkService.genesisBlockId});
          }
          if (r.url.path.endsWith('getnowblock')) return reply(headBlock());
          broadcast = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          return reply({'result': true, 'txid': broadcast!['txID']});
        }),
      );
      await service.sendNative(
        account: owner,
        recipient: addressOne,
        amountWei: BigInt.one,
      );
      final sig = ec.hexToBytes(
        (broadcast!['signature'] as List).single as String,
      );
      final digest = ec.hexToBytes(broadcast!['txID'] as String);
      final publicKey = ec.ecRecover(
        digest,
        ec.MsgSignature(
          ec.bytesToUnsignedInt(sig.sublist(0, 32)),
          ec.bytesToUnsignedInt(sig.sublist(32, 64)),
          sig.last + 27,
        ),
      );
      expect([
        0x41,
        ...ec.keccak256(publicKey).sublist(12),
      ], decodeTronAddress(mnemonicAddress));
      expect(
        publicKey,
        isNot(ec.privateKeyBytesToPublic(owner.credentials.privateKey)),
      );
      await service.dispose();
    },
  );

  test('stale TRON head fails over before signing or broadcasting', () async {
    final calls = <Uri>[];
    final service = EvmNetworkService(
      network: tronMainnetNetwork,
      httpClient: MockClient((r) async {
        calls.add(r.url);
        if (r.url.path.endsWith('getblockbynum')) {
          return reply({'blockID': TronNetworkService.genesisBlockId});
        }
        if (r.url.path.endsWith('getnowblock')) {
          return reply(
            r.url.host == 'api.trongrid.io'
                ? {'blockID': 'stale'}
                : headBlock(),
          );
        }
        expect(r.url.host, 'tron-rpc.publicnode.com');
        return reply({'result': true, 'txid': jsonDecode(r.body)['txID']});
      }),
    );
    final hash = await service.sendNative(
      account: WalletAccount.fromPrivateKey(keyOne),
      recipient: mnemonicAddress,
      amountWei: BigInt.one,
    );
    expect(hash, hasLength(64));
    expect(calls.where((u) => u.path.endsWith('getnowblock')).length, 2);
    expect(
      calls.where((u) => u.path.endsWith('broadcasttransaction')).length,
      1,
    );
    await service.dispose();
  });

  test(
    'uncertain TRON broadcast keeps hash and stale blocks never sign',
    () async {
      for (final stale in [true, false]) {
        var broadcasts = 0;
        final service = EvmNetworkService(
          network: tronMainnetNetwork,
          httpClient: MockClient((r) async {
            if (r.url.path.endsWith('getblockbynum')) {
              return reply({'blockID': TronNetworkService.genesisBlockId});
            }
            if (r.url.path.endsWith('getnowblock')) {
              final block = headBlock();
              if (stale) {
                ((block['block_header'] as Map)['raw_data']
                        as Map)['timestamp'] =
                    1;
              }
              return reply(block);
            }
            broadcasts++;
            throw TimeoutException('lost');
          }),
        );
        await expectLater(
          service.sendNative(
            account: WalletAccount.fromPrivateKey(keyOne),
            recipient: mnemonicAddress,
            amountWei: BigInt.one,
          ),
          throwsA(
            stale
                ? isA<WalletInputException>().having(
                    (e) => e is RpcBroadcastException,
                    'broadcast',
                    false,
                  )
                : isA<RpcBroadcastException>().having(
                    (e) => e.transactionHash.length,
                    'hash length',
                    64,
                  ),
          ),
        );
        expect(broadcasts, stale ? 0 : 2);
        await service.dispose();
      }
    },
  );

  for (final size in [const Size(1200, 800), const Size(390, 844)]) {
    testWidgets(
      'TRON balance, receive, account path and send validation at ${size.width}',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final vault = WalletVault(
          store: MapSecretStore({WalletVault.mnemonicKey: phrase}),
        );
        await vault.saveSelectedNetwork(tronMainnetNetwork);
        await tester.pumpWidget(
          StoneWalletApp(
            quoteService: TestQuoteService(),
            vault: vault,
            networkServiceBuilder: (network) => EvmNetworkService(
              network: network,
              httpClient: MockClient((r) async {
                if (r.url.path.endsWith('getblockbynum')) {
                  return reply({'blockID': TronNetworkService.genesisBlockId});
                }
                return reply({'address': mnemonicAddress, 'balance': 1234567});
              }),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<WalletHeader>(find.byType(WalletHeader)).address,
          mnemonicAddress,
        );
        await allOtherCoins(tester);
        expect(
          nativePosition(tester, tronMainnetNetwork.id).amount,
          '1.234567 TRX',
        );
        await nativeDetails(tester, tronMainnetNetwork.id);
        await tap(tester, find.text('接收'));
        expect(
          tester.widget<ActionSheet>(find.byType(ActionSheet)).address,
          mnemonicAddress,
        );
        await tap(tester, find.byTooltip('关闭').last);
        await nativeDetails(tester, tronMainnetNetwork.id);
        await tap(
          tester,
          find.descendant(
            of: find.byType(AssetDetailsPanel),
            matching: find.text('发送'),
          ),
        );
        await input(tester, '收款地址', '0x${'01' * 20}');
        await input(tester, '金额（TRX）', '1');
        await tap(tester, find.text('核对转账'));
        expect(find.textContaining('请输入有效的 TRON 地址'), findsOneWidget);
        await tap(tester, find.byTooltip('关闭').last);
        await tap(tester, find.byKey(const ValueKey('open-settings')));
        await settingsEntryTap(tester, 'security-backup');
        await settingsEntryTap(tester, 'security');
        await tester.ensureVisible(find.text("m/44'/195'/0'/0/0"));
        expect(find.text("m/44'/195'/0'/0/0"), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
