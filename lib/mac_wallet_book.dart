part of 'wallet_core.dart';

typedef _DatabaseRow = Map<Object?, Object?>;

class WalletPageCursor {
  const WalletPageCursor({this.sequence, this.term, this.group});
  final int? sequence;
  final String? term, group;
}

class WalletGroupPage {
  const WalletGroupPage(this.groups, this.next);
  final List<WalletGroup> groups;
  final WalletPageCursor? next;
}

class WalletAlias {
  const WalletAlias(this.id, this.platform, this.uid);
  final int id;
  final String platform, uid;
  String get name => '$platform · $uid';
}

extension MacWalletBook on WalletVault {
  Future<T> _serialize<T>(Future<T> Function() run) {
    final result = _mutationTail.then((_) => run());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _prepareDatabase() async {
    if (_databaseReady case final ready?) {
      return ready;
    }
    final ready = _migrateDatabase();
    _databaseReady = ready;
    try {
      await ready;
    } catch (_) {
      _databaseReady = null;
      rethrow;
    }
  }

  Future<void> _migrateDatabase() async {
    if (await _rawMacCall<bool>('needsMigration') != true) return;
    final book = await _loadBook(persistMigration: false);
    final groups = await Isolate.run(() => _migrationRecords(book));
    await _rawMacCall<void>('migrate', {
      'groups': groups,
      'activeId': book.activeAccountId,
    });
  }

  Future<T?> _rawMacCall<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await _database!.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw WalletInputException(switch (error.code) {
        'wallet_keychain' =>
          MessageCode.msgCannotAccessSecureDeviceStorageCheckThatKeychain,
        'account_missing' => MessageCode.msgAccountNotFound,
        'wallet_missing' => MessageCode.msgWalletNotFound,
        'derive_kind' =>
          MessageCode.msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts,
        'wallet_changed' => MessageCode.omniWalletChanged,
        'removal_changed' => MessageCode.manageWalletChanged,
        'derive_duplicate' => MessageCode.duplicateDerivationPath,
        'derive_index' => MessageCode.msgAccountIndexIsOutOfRange,
        _ => MessageCode.omniStorageError,
      });
    }
  }

  Future<T?> _macCall<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    await _prepareDatabase();
    return _rawMacCall<T>(method, arguments);
  }

  Future<_DatabaseRow> _macRow(
    String method, [
    Map<String, Object?>? arguments,
  ]) async => (await _macCall<_DatabaseRow>(method, arguments))!;

  Future<List<_DatabaseRow>> _macRows(
    String method, [
    Map<String, Object?>? arguments,
  ]) async =>
      (await _macCall<List<Object?>>(method, arguments))!.cast<_DatabaseRow>();

  Future<WalletPortfolio> _macSummary([
    String method = 'summary',
    Map<String, Object?>? arguments,
  ]) async => _summaryFromMac(await _macRow(method, arguments));

  Future<WalletPortfolio> _macFullPortfolio() async {
    final summary = await _macSummary();
    return WalletPortfolio(
      groups: (await _macRows('allGroups')).map(_macGroup).toList(),
      activeAccountId: summary.activeAccountId,
    );
  }

  Future<int?> loadPendingImportNetwork() async =>
      _database == null ? null : _macCall<int>('initialNetwork');

  Future<void> acknowledgeImportNetwork(int id) async {
    if (_database != null) {
      await _macCall<void>('ackInitialNetwork', {'id': id});
    }
  }

  Future<WalletGroupPage> loadWalletPage({
    String query = '',
    WalletPageCursor? after,
  }) async {
    final results = await _macRows('walletPage', {
      'query': query.trim(),
      'sequence': after?.sequence,
      'term': after?.term,
      'group': after?.group,
    });
    final page = results.take(50).toList();
    final last = page.lastOrNull;
    return WalletGroupPage(
      page.map(_macGroup).toList(),
      results.length <= 50
          ? null
          : WalletPageCursor(
              sequence: last!['sequence'] as int,
              term: last['term'] as String?,
              group: last['id'] as String,
            ),
    );
  }

  Future<List<WalletAlias>> loadWalletAliases(
    String groupId, {
    int after = 0,
  }) async => (await _macRows('aliasPage', {'id': groupId, 'after': after}))
      .map(
        (row) => WalletAlias(
          row['id'] as int,
          row['platform'] as String,
          row['uid'] as String,
        ),
      )
      .toList();

  Future<WalletPortfolio> _macAddMnemonic(
    String phrase,
    WalletAccount account, {
    String? name,
    String? accountName,
    String Function(int)? nameForWallet,
  }) => _serialize(() async {
    final summary = await _macRow('summary');
    final count =
        (summary['groups_count'] as int) - (summary['private_count'] as int);
    return _macSummary(
      'addMnemonic',
      _macRecord(
        id: _newWalletId(),
        kind: WalletKind.mnemonic,
        name: _checkedName(
          name ??
              nameForWallet?.call(count + 1) ??
              (count == 0 ? '主钱包' : '钱包 ${count + 1}'),
        ),
        secret: phrase,
        identity: account.addressHex.toLowerCase(),
        accounts: [
          _macAccountRecord(0, _checkedName(accountName ?? '账户 1'), account),
        ],
      ),
    );
  });

  Future<WalletPortfolio> _macAddDerived(
    String id,
    String? name, {
    String Function(int)? nameForAccount,
    String? evmPath,
    String? tronPath,
    bool legacyAddressMode = false,
  }) => _serialize(() async {
    final source = await _macRow('derive', {'id': id});
    final index = source['next_index'] as int;
    final evm = normalizeDerivationPath(
      evmPath ?? source['next_evm_path'] as String,
    );
    final tron = normalizeDerivationPath(
      tronPath ?? source['next_tron_path'] as String,
    );
    final account = WalletAccount.fromMnemonic(
      source['secret'] as String,
      accountIndex: index,
      evmPath: evm,
      tronPath: tron,
      legacyAddressMode: legacyAddressMode,
    );
    return _macSummary('addDerived', {
      'id': id,
      'account': _macAccountRecord(
        index,
        _checkedName(name ?? nameForAccount?.call(index) ?? '账户 ${index + 1}'),
        account,
        evmPath: evm,
        tronPath: tron,
        legacyAddressMode: legacyAddressMode,
      ),
    });
  });

  Future<BatchImportResult> _macImportPrivateRows(
    List<WalletImportRow> rows,
    List<EvmNetwork> networks, {
    required bool selectImported,
    required String Function(int)? nameForWallet,
    required String? accountName,
  }) => _serialize(() async {
    final errors = <WalletImportError>[];
    final imported = <ImportedWallet>[];
    final summary = await _macRow('summary');
    final count = summary['private_count'] as int;
    final records = <Map<String, Object?>>[];
    final candidates = <(int, ImportedWallet)>[];
    for (var index = 0; index < rows.length; index++) {
      try {
        final row = rows[index];
        final network = networkForValue(row.chain, networks: networks);
        if (network == null) {
          throw const WalletInputException(MessageCode.msgUnsupportedNetwork);
        }
        final account = WalletAccount.fromPrivateKey(row.privateKey);
        records.add(
          _macRecord(
            id: _newWalletId(),
            kind: WalletKind.privateKey,
            name: '',
            secret: account.privateKeyHex,
            identity: network.isTron
                ? account.tronAddress
                : account.addressHex.toLowerCase(),
            networkId: network.id,
            accounts: [
              _macAccountRecord(
                0,
                _checkedName(accountName ?? '账户 1'),
                account,
              ),
            ],
          ),
        );
        candidates.add((
          index + 1,
          ImportedWallet(networkId: network.id, account: account),
        ));
      } on WalletInputException catch (error) {
        errors.add(WalletImportError(index + 1, error.message));
      }
    }
    if (records.isNotEmpty) {
      // The database assigns names after deduplication and commits the valid
      // legacy rows together, just as the Keychain wallet book did.
      final names = [
        for (var index = 1; index <= records.length; index++)
          (nameForWallet?.call(count + index) ?? '私钥账户 ${count + index}')
              .trim(),
      ];
      final results = (await _macCall<List<Object?>>('addPrivate', {
        'groups': records,
        'names': names,
        'select': selectImported,
      }))!;
      for (var index = 0; index < candidates.length; index++) {
        final (row, wallet) = candidates[index];
        switch (results[index]) {
          case 'new':
            imported.add(wallet);
          case 'duplicate':
            errors.add(
              WalletImportError(
                row,
                const WalletMessage(MessageCode.msgDuplicateEntrySkipped),
              ),
            );
          case 'invalid_name':
            errors.add(
              WalletImportError(
                row,
                const WalletMessage(MessageCode.msgNamesMustContainCharacters),
              ),
            );
        }
      }
    }
    errors.sort((a, b) => a.row.compareTo(b.row));
    return BatchImportResult(imported: imported, errors: errors);
  });
}

WalletPortfolio _summaryFromMac(_DatabaseRow row) {
  final selected = row['selected'] as _DatabaseRow?;
  return WalletPortfolio(
    groups: const [],
    activeAccountId: row['active_id'] as String?,
    groupCount: row['groups_count'] as int,
    accountCount: row['accounts_count'] as int,
    selected: selected == null
        ? null
        : _macEntry(
            selected,
            groupId: selected['group_id'] as String,
            name: selected['group_name'] as String,
            kind: WalletKind.values.byName(selected['kind'] as String),
            networkId: selected['network_id'] as int?,
            count: selected['group_count'] as int,
            secret: selected['secret'] as String,
          ),
  );
}

WalletGroup _macGroup(_DatabaseRow row) {
  final id = row['id'] as String;
  final name = row['name'] as String;
  final kind = WalletKind.values.byName(row['kind'] as String);
  final network = row['network_id'] as int?;
  final accounts = (row['accounts'] as List<Object?>).cast<_DatabaseRow>();
  return WalletGroup(
    id: id,
    name: name,
    kind: kind,
    preferredNetworkId: network,
    hasAliases: row['has_aliases'] == 1,
    suggestedAccountIndex:
        row['next_index'] as int? ?? row['next_account_index'] as int?,
    suggestedEvmPath: row['next_evm_path'] as String?,
    suggestedTronPath: row['next_tron_path'] as String?,
    accounts: [
      for (final entry in accounts)
        _macEntry(
          entry,
          groupId: id,
          name: name,
          kind: kind,
          networkId: network,
          count: row['account_count'] as int? ?? accounts.length,
          secret: row['secret'] as String?,
        ),
    ],
  );
}

WalletEntry _macEntry(
  _DatabaseRow row, {
  required String groupId,
  required String name,
  required WalletKind kind,
  required int? networkId,
  required int count,
  required String? secret,
}) {
  final index = row['account_index'] as int;
  return WalletEntry(
    id: row['id'] as String,
    groupId: groupId,
    name: row['name'] as String,
    groupName: name,
    kind: kind,
    index: index,
    evmPath: row['evm_path'] as String?,
    tronPath: row['tron_path'] as String?,
    legacyAddressMode: row['legacy_address_mode'] == 1,
    groupAccountCount: count,
    preferredNetworkId: networkId,
    evmAddress: row['evm'] as String,
    tronAddress: row['tron'] as String,
    account: secret == null
        ? null
        : kind == WalletKind.mnemonic
        ? WalletAccount.fromMnemonic(
            secret,
            accountIndex: index,
            evmPath: row['evm_path'] as String?,
            tronPath: row['tron_path'] as String?,
            legacyAddressMode: row['legacy_address_mode'] == 1,
          )
        : WalletAccount.fromPrivateKey(secret),
  );
}

List<Map<String, Object?>> _migrationRecords(_WalletBook book) =>
    book.groups.map(_migrationRecord).toList();

Map<String, Object?> _migrationRecord(_StoredGroup group) {
  final accounts = [
    for (final entry in group.accounts)
      _macAccountRecord(
        entry.index,
        entry.name,
        group.account(entry.index),
        evmPath: entry.evmPath,
        tronPath: entry.tronPath,
        legacyAddressMode: entry.legacyAddressMode,
      ),
  ];
  final first = accounts.firstWhere((row) => row['account_index'] == 0);
  return {
    ..._macRecord(
      id: group.id,
      name: group.name,
      kind: group.kind,
      secret: group.secret,
      networkId: group.networkId,
      identity: group.networkId == tronMainnetNetwork.id
          ? first['tron'] as String
          : (first['evm'] as String).toLowerCase(),
      accounts: accounts,
    ),
    'nextAccountIndex': group.nextAccountIndex,
  };
}

Map<String, Object?> _macRecord({
  required String id,
  required String name,
  required WalletKind kind,
  required String secret,
  required String identity,
  required List<Map<String, Object?>> accounts,
  int? networkId,
}) => {
  'id': id,
  'name': name,
  'kind': kind.name,
  'secret': secret,
  'identity': identity,
  'network_id': networkId,
  'accounts': accounts,
};

Map<String, Object?> _macAccountRecord(
  int index,
  String name,
  WalletAccount account, {
  String? evmPath,
  String? tronPath,
  bool legacyAddressMode = false,
}) => {
  'account_index': index,
  'name': name,
  'evm': account.checksumAddress,
  'tron': account.tronAddress,
  'evm_path': evmPath,
  'tron_path': tronPath,
  'legacy_address_mode': legacyAddressMode ? 1 : 0,
};
