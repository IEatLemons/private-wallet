part of 'wallet_core.dart';

enum WalletManagementSort { value, name, newest }

class WalletManagementQuery {
  const WalletManagementQuery({
    this.search = '',
    this.chain,
    this.platform,
    this.kind,
    this.sort = WalletManagementSort.value,
    this.enabled = const [],
  });
  final String search;
  final int? chain;
  final String? platform;
  final WalletKind? kind;
  final WalletManagementSort sort;
  final List<int> enabled;
  Map<String, Object?> toJson() => {
    'query': search.trim(),
    'chain': chain,
    'platform': platform,
    'kind': kind?.name,
    'sort': sort.name,
    'enabled': enabled,
  };
}

/// Persisted flags shared with the native wallet database.
abstract final class BalanceCoverage {
  static const partial = 1, missingPrices = 2, failed = 4, missingAccounts = 8;
}

class ManagedWallet {
  const ManagedWallet(
    this.group, {
    this.platform,
    this.amount,
    this.coverage = 0,
    this.updatedAt,
    this.attemptedAt,
  });
  final WalletGroup group;
  final String? platform;
  final ExactDecimal? amount;
  final int coverage;
  bool get incomplete => coverage != 0;
  bool get queryFailed => coverage & BalanceCoverage.failed != 0;
  bool get unpriced => coverage & BalanceCoverage.missingPrices != 0;
  final DateTime? updatedAt, attemptedAt;
}

class WalletManagementPage {
  const WalletManagementPage(this.wallets, this.total, this.more);
  final List<ManagedWallet> wallets;
  final int total;
  final bool more;
}

class WalletRemovalPreview {
  WalletRemovalPreview({
    required this.token,
    required this.wallets,
    required this.accounts,
    required this.active,
    this.ids = const {},
    this.accountId,
    this.revision,
  });
  final String token;
  final int wallets, accounts;
  final bool active;
  final Set<String> ids;
  final String? accountId, revision;
}

DateTime? _managementTime(Object? time) =>
    time is int ? DateTime.fromMillisecondsSinceEpoch(time) : null;
ExactDecimal? _managementAmount(Object? value) =>
    value is String ? ExactDecimal(BigInt.parse(value), 72) : null;

extension WalletManagementStorage on WalletVault {
  Future<Map<String, dynamic>> _balanceRecords() async =>
      (await _loadBook()).balances;

  String _managementRevision(_WalletBook book) =>
      jsonEncode(Map.of(book.toJson())..remove('balances'));

  Future<WalletManagementPage> managementPage(
    WalletManagementQuery query, {
    int offset = 0,
  }) async {
    if (_database != null) {
      final row = await _macRow('managementPage', {
        ...query.toJson(),
        'offset': offset,
      });
      return WalletManagementPage(
        (row['groups'] as List)
            .cast<_DatabaseRow>()
            .map(
              (r) => ManagedWallet(
                _macGroup(r),
                platform: r['platform'] as String?,
                amount: _managementAmount(r['amount']),
                coverage: r['incomplete'] as int? ?? 0,
                updatedAt: _managementTime(r['updated_at']),
                attemptedAt: _managementTime(r['attempted_at']),
              ),
            )
            .toList(),
        row['total'] as int,
        row['more'] as bool,
      );
    }
    final portfolio = await loadPortfolio();
    final cache = await _balanceRecords();
    final wallets = <ManagedWallet>[];
    final search = query.search.toLowerCase().trim();
    for (final group in portfolio.groups) {
      if (query.kind != null && group.kind != query.kind) continue;
      if (query.platform != null && query.platform!.isNotEmpty) continue;
      if (query.chain != null &&
          group.preferredNetworkId != query.chain &&
          !(group.preferredNetworkId == null &&
              query.enabled.contains(query.chain))) {
        continue;
      }
      final terms = [
        group.name,
        for (final a in group.accounts) ...[
          a.name,
          a.addressFor(null),
          a.addressFor(tronMainnetNetwork),
        ],
      ];
      if (search.isNotEmpty &&
          !terms.any((term) => term.toLowerCase().startsWith(search))) {
        continue;
      }
      final records = <Map>[];
      for (final a in group.accounts) {
        records.addAll(
          (cache[a.id] as List? ?? []).cast<Map>().where(
            (r) => query.chain == null || r['chain'] == query.chain,
          ),
        );
      }
      ExactDecimal? amount;
      for (final record in records) {
        final value = _managementAmount(record['amount']);
        if (value != null) amount = (amount ?? ExactDecimal.zero) + value;
      }
      final times =
          records
              .map((r) => _managementTime(r['updated_at']))
              .whereType<DateTime>()
              .toList()
            ..sort();
      final attempts =
          records
              .map((r) => _managementTime(r['attempted_at']))
              .whereType<DateTime>()
              .toList()
            ..sort();
      wallets.add(
        ManagedWallet(
          group,
          amount: amount,
          coverage: records.fold<int>(
            records.length < group.accounts.length
                ? BalanceCoverage.missingAccounts
                : 0,
            (flags, r) =>
                flags |
                (r['incomplete'] as int? ?? 0) |
                (r['failed'] == 1 ? BalanceCoverage.failed : 0),
          ),
          updatedAt: times.length == records.length ? times.firstOrNull : null,
          attemptedAt: attempts.firstOrNull,
        ),
      );
    }
    final order = {
      for (var i = 0; i < portfolio.groups.length; i++)
        portfolio.groups[i].id: i,
    };
    wallets.sort((a, b) {
      final int comparison;
      switch (query.sort) {
        case WalletManagementSort.value:
          comparison = a.amount == null
              ? (b.amount == null ? 0 : 1)
              : b.amount == null
              ? -1
              : b.amount!.compareTo(a.amount!);
        case WalletManagementSort.name:
          comparison = a.group.name.toLowerCase().compareTo(
            b.group.name.toLowerCase(),
          );
        case WalletManagementSort.newest:
          comparison = order[b.group.id]!.compareTo(order[a.group.id]!);
      }
      return comparison != 0 ? comparison : a.group.id.compareTo(b.group.id);
    });
    return WalletManagementPage(
      wallets.skip(offset).take(50).toList(),
      wallets.length,
      offset + 50 < wallets.length,
    );
  }

  Future<WalletGroup> managementGroup(String id) async => _database != null
      ? _macGroup(await _macRow('managementGroup', {'id': id}))
      : (await loadPortfolio()).groups.firstWhere(
          (g) => g.id == id,
          orElse: () =>
              throw const WalletInputException(MessageCode.msgWalletNotFound),
        );

  Future<List<WalletEntry>> managementAccounts(
    WalletGroup group, {
    int after = -1,
  }) async {
    if (_database == null) {
      return group.accounts.where((a) => a.index > after).take(51).toList();
    }
    final rows = await _macRows('accountPage', {
      'id': group.id,
      'after': after,
    });
    return rows
        .map(
          (row) => _macEntry(
            row,
            groupId: group.id,
            name: group.name,
            kind: group.kind,
            networkId: group.preferredNetworkId,
            count: group.accounts.first.groupAccountCount,
            secret: null,
          ),
        )
        .toList();
  }

  Future<List<String>> managementPlatforms({String after = ''}) async {
    if (_database == null) return [];
    return (await _macRows('platformPage', {
      'after': after,
    })).map((r) => r['platform'] as String).toList();
  }

  Future<WalletRemovalPreview> prepareRemoval({
    Set<String>? ids,
    Set<String> excluded = const {},
    String? accountId,
    WalletManagementQuery? query,
  }) async {
    if (ids == null && accountId == null && query == null) {
      throw const WalletInputException(
        MessageCode.msgOperationFailedPleaseTryAgain,
      );
    }
    if (_database != null) {
      final row = await _macRow('prepareRemoval', {
        ...?query?.toJson(),
        if (ids != null) 'ids': ids.toList(),
        'excluded': excluded.toList(),
        'account': accountId,
      });
      return WalletRemovalPreview(
        token: row['token'] as String,
        wallets: row['wallets'] as int,
        accounts: row['accounts'] as int,
        active: row['active'] as bool,
        accountId: accountId,
      );
    }
    final book = await _changeBook((b) => b);
    var targets = ids?.toSet() ?? <String>{};
    if (accountId != null) {
      final group = book.groups
          .where((g) => g.accounts.any((a) => g.entryId(a.index) == accountId))
          .firstOrNull;
      if (group == null ||
          group.kind != WalletKind.mnemonic ||
          group.entryId(0) == accountId) {
        throw const WalletInputException(
          MessageCode.msgOperationFailedPleaseTryAgain,
        );
      }
      targets = {group.id};
    } else if (ids == null && query != null) {
      var offset = 0;
      while (true) {
        final page = await managementPage(query, offset: offset);
        targets.addAll(page.wallets.map((w) => w.group.id));
        if (!page.more) break;
        offset += 50;
      }
      targets.removeAll(excluded);
    }
    if (targets.isEmpty ||
        targets.any((id) => !book.groups.any((g) => g.id == id))) {
      throw const WalletInputException(MessageCode.msgWalletNotFound);
    }
    final groups = book.groups.where((g) => targets.contains(g.id));
    final preview = WalletRemovalPreview(
      token: _newWalletId(),
      wallets: accountId == null ? groups.length : 0,
      accounts: accountId == null
          ? groups.fold<int>(0, (sum, g) => sum + g.accounts.length)
          : 1,
      active: accountId == null
          ? groups.any(
              (g) => g.accounts.any(
                (a) => g.entryId(a.index) == book.activeAccountId,
              ),
            )
          : book.activeAccountId == accountId,
      ids: targets,
      accountId: accountId,
      revision: _managementRevision(book),
    );
    _removals[preview.token] = preview;
    return preview;
  }

  Future<List<Map<Object?, Object?>>> removalPage(
    String token, {
    int offset = 0,
  }) async {
    if (_database != null) {
      return _macRows('removalPage', {'token': token, 'offset': offset});
    }
    final preview = _removals[token]!;
    return (await loadPortfolio()).groups
        .where((g) => preview.ids.contains(g.id))
        .skip(offset)
        .take(51)
        .map((g) => <Object?, Object?>{'id': g.id, 'name': g.name})
        .toList();
  }

  Future<void> cancelRemoval(String token) async {
    if (_database != null) {
      await _macCall<void>('cancelRemoval', {'token': token});
    } else {
      _removals.remove(token);
    }
  }

  Future<WalletPortfolio> commitRemoval(String token) async {
    if (_database != null) {
      return _serialize(() => _macSummary('commitRemoval', {'token': token}));
    }
    return _changeBook((book) async {
      final preview = _removals[token];
      if (preview == null || preview.revision != _managementRevision(book)) {
        throw const WalletInputException(MessageCode.manageWalletChanged);
      }
      final deletedAccounts = <String>{};
      if (preview.accountId case final id?) {
        final group = book.groups.firstWhere((g) => preview.ids.contains(g.id));
        deletedAccounts.add(id);
        group.accounts.removeWhere((a) => group.entryId(a.index) == id);
        if (book.activeAccountId == id) book.activeAccountId = group.entryId(0);
      } else {
        for (final g in book.groups.where((g) => preview.ids.contains(g.id))) {
          deletedAccounts.addAll(g.accounts.map((a) => g.entryId(a.index)));
        }
        book.groups.removeWhere((g) => preview.ids.contains(g.id));
        if (deletedAccounts.contains(book.activeAccountId)) {
          book.activeAccountId = book.groups.firstOrNull?.entryId(0);
        }
      }
      book.balances.removeWhere((id, _) => deletedAccounts.contains(id));
      return book.snapshot();
    });
  }

  Future<bool> saveManagementBalance(
    String id,
    List<Map<String, Object?>> records,
  ) async {
    final time = DateTime.now().millisecondsSinceEpoch;
    if (_database != null) {
      return await _macCall<bool>('saveBalance', {
            'id': id,
            'records': records,
            'time': time,
          }) ??
          false;
    }
    return _changeBook((book) async {
      if (!book.groups.any(
        (g) => g.accounts.any((a) => g.entryId(a.index) == id),
      )) {
        return false;
      }
      final cache = book.balances;
      final previous = (cache[id] as List? ?? []).cast<Map>();
      cache[id] = [
        for (final record in records)
          {
            ...record,
            'updated_at': record['failed'] == 0 ? time : null,
            if (record['failed'] == 1)
              ...?previous
                  .where(
                    (r) =>
                        r['chain'] == record['chain'] &&
                        r['updated_at'] != null,
                  )
                  .firstOrNull,
            'attempted_at': time,
            'failed': record['failed'],
            'incomplete': record['incomplete'],
          },
      ];
      return true;
    });
  }

  Future<List<Map<Object?, Object?>>> managementBalanceDetails(
    String groupId, {
    int after = -1,
  }) async {
    if (_database != null) {
      return _macRows('balanceDetails', {'id': groupId, 'after': after});
    }
    final group = await managementGroup(groupId);
    final cache = await _balanceRecords();
    return [
      for (final a in group.accounts.where((a) => a.index > after).take(50))
        for (final r in cache[a.id] as List? ?? [])
          {
            ...(r as Map).cast<Object?, Object?>(),
            'account_id': a.id,
            'network_id': r['chain'],
          },
    ];
  }
}
