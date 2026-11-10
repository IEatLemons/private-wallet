import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stone_wallet/asset_discovery.dart';
import 'package:stone_wallet/wallet_core.dart';
import 'widget_test.dart' show MapSecretStore;

const address = '0x9858EfFD232B4033E47d90003D41EC34EcaEda94';
const secret = 'synthetic-service-key';
Map<String, Object> row(
  String contract, {
  String balance = '1000000',
  Object decimals = 6,
  bool spam = false,
}) => {
  'token_address': contract,
  'symbol': 'USDT',
  'name': 'Tether',
  'decimals': decimals,
  'balance': balance,
  'possible_spam': spam,
};
void main() {
  test(
    'Moralis parses raw units, cursor and spam and never accepts bad metadata as zero',
    () async {
      final service = HttpAssetDiscoveryService(
        IndexerConfig(
          provider: IndexerProvider.moralis,
          apiKey: secret,
          networkIds: {1},
        ),
        client: MockClient((r) async {
          expect(r.headers['X-API-Key'] ?? r.headers['x-api-key'], secret);
          expect(r.url.queryParameters['chain'], '0x1');
          expect(r.url.queryParameters['exclude_native'], 'true');
          expect(r.url.queryParameters['cursor'], 'next');
          return http.Response(
            jsonEncode({
              'result': [
                row(builtinTokens.first.contract),
                row('0x${'11' * 20}', spam: true),
                row('invalid'),
                row('0x${'22' * 20}', balance: '1.2'),
                row('0x${'33' * 20}', decimals: 99),
              ],
              'cursor': 'tail',
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final page = await service.discover(
        ethereumMainnetNetwork,
        address,
        cursor: 'next',
      );
      expect(page.tokens, hasLength(2));
      expect(page.invalidCount, 3);
      expect(page.cursor, 'tail');
      expect(page.tokens.first.token.trustedFamily, 'USDT');
      expect(page.tokens.last.token.trustedFamily, isNull);
      expect(page.tokens.last.spam, true);
      expect(page.tokens.first.units, BigInt.from(1000000));
    },
  );
  test(
    'Alchemy validates owner, follows page keys and fetches metadata only for positive balances',
    () async {
      var metadata = 0;
      final service = HttpAssetDiscoveryService(
        IndexerConfig(
          provider: IndexerProvider.alchemy,
          apiKey: secret,
          networkIds: {137},
        ),
        client: MockClient((r) async {
          expect(r.url.host, 'polygon-mainnet.g.alchemy.com');
          expect(r.url.path, '/v2/$secret');
          final body = jsonDecode(r.body) as Map;
          if (body['method'] == 'alchemy_getTokenBalances') {
            expect((body['params'] as List)[1], 'erc20');
            expect((body['params'] as List)[2], {
              'maxCount': 100,
              'pageKey': 'start',
            });
            return http.Response(
              jsonEncode({
                'result': {
                  'address': address,
                  'tokenBalances': [
                    {
                      'contractAddress': builtinTokens[3].contract,
                      'tokenBalance': '0x1',
                    },
                    {
                      'contractAddress': '0x${'44' * 20}',
                      'tokenBalance': '0x0',
                    },
                  ],
                  'pageKey': 'end',
                },
              }),
              200,
            );
          }
          expect(body['method'], 'alchemy_getTokenMetadata');
          metadata++;
          return http.Response(
            '{"result":{"symbol":"USDT0","name":"USDT0","decimals":6}}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final page = await service.discover(
        polygonMainnetNetwork,
        address,
        cursor: 'start',
      );
      expect(page.tokens.single.units, BigInt.one);
      expect(page.tokens.single.token.trustedFamily, 'USDT');
      expect(page.cursor, 'end');
      expect(metadata, 1);
    },
  );
  test('TronGrid uses mainnet, API-key header and raw TRC20 units', () async {
    final owner = WalletAccount.fromPrivateKey(
      '1'.padLeft(64, '0'),
    ).tronAddress;
    final service = HttpAssetDiscoveryService(
      IndexerConfig(
        provider: IndexerProvider.trongrid,
        apiKey: secret,
        networkIds: {tronMainnetNetwork.id},
      ),
      client: MockClient((r) async {
        expect(r.url.host, 'api.trongrid.io');
        expect(r.url.path, '/v1/accounts/$owner/trc20/balance');
        expect(
          r.headers['TRON-PRO-API-KEY'] ?? r.headers['tron-pro-api-key'],
          secret,
        );
        return http.Response(
          jsonEncode({
            'data': [
              {
                'token_info': {
                  'address': builtinTokens[1].contract,
                  'name': 'Tether USD',
                  'symbol': 'USDT',
                  'decimals': 6,
                },
                'balance': '10000000000000000000',
              },
            ],
            'meta': {'fingerprint': 'more'},
          }),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final page = await service.discover(tronMainnetNetwork, owner);
    expect(page.tokens.single.units, BigInt.parse('10000000000000000000'));
    expect(page.cursor, 'more');
    expect(page.tokens.single.token.trustedFamily, 'USDT');
  });
  for (final entry in {
    401: MessageCode.discoveryUnauthorized,
    403: MessageCode.discoveryUnauthorized,
    429: MessageCode.discoveryLimited,
    503: MessageCode.discoveryRequestFailed,
    200: MessageCode.discoveryResponseInvalid,
  }.entries) {
    test(
      'indexer HTTP ${entry.key} returns a localized error code without exposing credentials',
      () async {
        final service = HttpAssetDiscoveryService(
          IndexerConfig(
            provider: IndexerProvider.moralis,
            apiKey: secret,
            networkIds: {1},
          ),
          client: MockClient(
            (r) async => http.Response('{"result":"bad"}', entry.key),
          ),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.discover(ethereumMainnetNetwork, address),
          throwsA(
            isA<WalletInputException>()
                .having((e) => e.code, 'code', entry.value)
                .having(
                  (e) => e.toString(),
                  'redacted',
                  isNot(contains(secret)),
                ),
          ),
        );
      },
    );
  }
  test(
    'indexer assignments persist separately, replace per chain and serialize concurrent saves',
    () async {
      final store = MapSecretStore({
            WalletVault.mnemonicKey: 'existing secret',
          }),
          vault = WalletVault(store: MapSecretStore({}));
      final settings = IndexerSettings(
        read: () async => null,
        write: (s) async => store.write(WalletVault.assetIndexerConfigsKey, s),
      );
      addTearDown(settings.dispose);
      await settings.load();
      await Future.wait([
        settings.save(
          IndexerConfig(
            provider: IndexerProvider.moralis,
            apiKey: secret,
            networkIds: {1, 56},
          ),
        ),
        settings.save(
          IndexerConfig(
            provider: IndexerProvider.alchemy,
            apiKey: 'other-key',
            networkIds: {1, 137},
          ),
        ),
      ]);
      expect(settings.forNetwork(1)!.provider, IndexerProvider.alchemy);
      expect(settings.forNetwork(56)!.provider, IndexerProvider.moralis);
      final restored = IndexerSettings(
        read: () => store.read(WalletVault.assetIndexerConfigsKey),
        write: vault.writeAssetIndexerConfigs,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.forNetwork(137)!.apiKey, 'other-key');
      expect(store.values[WalletVault.mnemonicKey], 'existing secret');
      await settings.remove(IndexerProvider.alchemy);
      expect(settings.forNetwork(1), isNull);
      expect(settings.forNetwork(56), isNotNull);
    },
  );
  test(
    'corrupt settings are reported and preserved without blocking wallets',
    () async {
      final store = MapSecretStore({
        WalletVault.assetIndexerConfigsKey: 'broken',
      });
      final settings = IndexerSettings(
        read: () => store.read(WalletVault.assetIndexerConfigsKey),
        write: (s) => store.write(WalletVault.assetIndexerConfigsKey, s),
      );
      addTearDown(settings.dispose);
      await settings.load();
      expect(settings.error!.code, MessageCode.discoverySettingsUnreadable);
      expect(settings.configs, isEmpty);
      expect(store.values[WalletVault.assetIndexerConfigsKey], 'broken');
    },
  );
  test('wrong Alchemy owner and non-uint256 values are rejected', () async {
    final service = HttpAssetDiscoveryService(
      IndexerConfig(
        provider: IndexerProvider.alchemy,
        apiKey: secret,
        networkIds: {1},
      ),
      client: MockClient(
        (r) async => http.Response(
          '{"result":{"address":"0x0000000000000000000000000000000000000000","tokenBalances":[]}}',
          200,
        ),
      ),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.discover(ethereumMainnetNetwork, address),
      throwsA(
        isA<WalletInputException>().having(
          (e) => e.code,
          'code',
          MessageCode.discoveryResponseInvalid,
        ),
      ),
    );
  });
}
