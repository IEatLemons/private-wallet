part of 'wallet_core.dart';

String evmAccountDerivationPath(int index) => "m/44'/60'/0'/0/$index";

/// Canonical absolute BIP32 child path, with each index below 2^31.
String normalizeDerivationPath(String path) {
  final value = path.trim();
  if (value.length > 4096 ||
      !RegExp(r"^m(?:/[0-9]+['hH]?)+$").hasMatch(value)) {
    throw const WalletInputException(MessageCode.invalidDerivationPath);
  }
  final parts = value.split('/').skip(1).toList();
  if (parts.length > 255) {
    throw const WalletInputException(MessageCode.invalidDerivationPath);
  }
  return 'm/${parts.map((part) {
    final hardened = RegExp(r"['hH]$").hasMatch(part);
    final index = int.tryParse(hardened ? part.substring(0, part.length - 1) : part);
    if (index == null || index < 0 || index >= 0x80000000) {
      throw const WalletInputException(MessageCode.invalidDerivationPath);
    }
    return "$index${hardened ? "'" : ''}";
  }).join('/')}';
}

String _unusedDerivationPath(
  int start,
  Iterable<String> used, {
  bool tron = false,
}) {
  final paths = used.toSet();
  for (var index = start; index < 0x80000000; index++) {
    final path = tron
        ? tronAccountDerivationPath(index)
        : evmAccountDerivationPath(index);
    if (!paths.contains(path)) return path;
  }
  throw const WalletInputException(MessageCode.msgAccountIndexIsOutOfRange);
}

enum WalletKind { mnemonic, privateKey }

/// Public wallet metadata. Recovery phrases are confined to the stored records.
class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.groupId,
    required this.name,
    required this.groupName,
    required this.kind,
    required this.index,
    WalletAccount? account,
    String? evmAddress,
    String? tronAddress,
    this.preferredNetworkId,
    this.evmPath,
    this.tronPath,
    this.legacyAddressMode = false,
    required this.groupAccountCount,
  }) : _account = account,
       _evmAddress = evmAddress,
       _tronAddress = tronAddress;
  final String id, groupId, name, groupName;
  final WalletKind kind;
  final int index, groupAccountCount;
  final int? preferredNetworkId;
  final WalletAccount? _account;
  final String? _evmAddress, _tronAddress;
  final String? evmPath, tronPath;
  final bool legacyAddressMode;
  WalletAccount get account =>
      _account ??
      (throw StateError('Signing material is not loaded for this account'));
  String addressFor(EvmNetwork? network) => network?.isTron == true
      ? (_tronAddress ?? account.tronAddress)
      : (_evmAddress ?? account.checksumAddress);

  String get displayName =>
      groupAccountCount == 1 ? groupName : '$groupName · $name';
  String? get derivationPath => kind == WalletKind.mnemonic
      ? evmPath ?? evmAccountDerivationPath(index)
      : null;
  String? derivationPathFor(EvmNetwork? network) => kind == WalletKind.mnemonic
      ? network?.isTron == true
            ? tronPath ?? tronAccountDerivationPath(index)
            : evmPath ?? evmAccountDerivationPath(index)
      : null;
}

class WalletGroup {
  const WalletGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.accounts,
    this.preferredNetworkId,
    this.hasAliases = false,
    this.suggestedEvmPath,
    this.suggestedTronPath,
  });
  final String id, name;
  final WalletKind kind;
  final int? preferredNetworkId;
  final bool hasAliases;
  final List<WalletEntry> accounts;
  final String? suggestedEvmPath, suggestedTronPath;
  int get nextAccountIndex =>
      accounts.fold<int>(-1, (n, a) => max(n, a.index)) + 1;
  String get nextEvmPath =>
      suggestedEvmPath ??
      _unusedDerivationPath(
        nextAccountIndex,
        accounts.map((a) => a.derivationPath!),
      );
  String get nextTronPath =>
      suggestedTronPath ??
      _unusedDerivationPath(
        nextAccountIndex,
        accounts.map((a) => a.derivationPathFor(tronMainnetNetwork)!),
        tron: true,
      );
}

class WalletPortfolio {
  const WalletPortfolio({
    required this.groups,
    this.activeAccountId,
    WalletEntry? selected,
    int? groupCount,
    int? accountCount,
  }) : _selected = selected,
       _groupCount = groupCount,
       _accountCount = accountCount;
  final List<WalletGroup> groups;
  final String? activeAccountId;
  final WalletEntry? _selected;
  final int? _groupCount, _accountCount;
  int get groupCount => _groupCount ?? groups.length;
  int get accountCount =>
      _accountCount ??
      groups.fold(0, (sum, group) => sum + group.accounts.length);
  List<WalletEntry> get accounts => [
    for (final group in groups) ...group.accounts,
  ];
  WalletEntry? get selected {
    if (_selected != null) return _selected;
    for (final group in groups) {
      for (final entry in group.accounts) {
        if (entry.id == activeAccountId) return entry;
      }
    }
    return groups.firstOrNull?.accounts.firstOrNull;
  }
}

class _StoredAccount {
  _StoredAccount(
    this.index,
    this.name, {
    this.evmPath,
    this.tronPath,
    this.legacyAddressMode = false,
  });
  final int index;
  String name;
  final String? evmPath, tronPath;
  final bool legacyAddressMode;
  Map<String, Object> toJson() => {
    'index': index,
    'name': name,
    'evmPath': ?evmPath,
    'tronPath': ?tronPath,
    if (legacyAddressMode) 'legacyAddressMode': true,
  };
}

class _StoredGroup {
  _StoredGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.secret,
    required this.accounts,
    this.networkId,
  });
  final String id, secret;
  String name;
  final WalletKind kind;
  final int? networkId;
  final List<_StoredAccount> accounts;
  String entryId(int index) => '$id:$index';
  WalletAccount account(int index) {
    final entry = accounts.where((a) => a.index == index).firstOrNull;
    return kind == WalletKind.mnemonic
        ? WalletAccount.fromMnemonic(
            secret,
            accountIndex: index,
            evmPath: entry?.evmPath,
            tronPath: entry?.tronPath,
            legacyAddressMode: entry?.legacyAddressMode ?? false,
          )
        : WalletAccount.fromPrivateKey(secret);
  }

  WalletGroup snapshot() => WalletGroup(
    id: id,
    name: name,
    kind: kind,
    preferredNetworkId: networkId,
    accounts: List.unmodifiable([
      for (final a in accounts)
        WalletEntry(
          id: entryId(a.index),
          groupId: id,
          name: a.name,
          groupName: name,
          kind: kind,
          index: a.index,
          account: account(a.index),
          evmPath: a.evmPath,
          tronPath: a.tronPath,
          legacyAddressMode: a.legacyAddressMode,
          preferredNetworkId: networkId,
          groupAccountCount: accounts.length,
        ),
    ]),
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'secret': secret,
    'networkId': networkId,
    'accounts': [for (final a in accounts) a.toJson()],
  };
}

class _WalletBook {
  _WalletBook({required this.groups, this.activeAccountId});
  final List<_StoredGroup> groups;
  String? activeAccountId;
  WalletPortfolio snapshot() => WalletPortfolio(
    groups: List.unmodifiable(groups.map((g) => g.snapshot())),
    activeAccountId: activeAccountId,
  );
  Map<String, Object?> toJson() => {
    'version': 2,
    'groups': groups.map((g) => g.toJson()).toList(),
    'activeAccountId': activeAccountId,
  };
}

extension WalletManagement on WalletVault {
  static final _random = Random.secure();
  String _newWalletId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  String _checkedName(String name) {
    final value = name.trim();
    if (value.isEmpty || value.length > 64) {
      throw const WalletInputException(
        MessageCode.msgNamesMustContainCharacters,
      );
    }
    return value;
  }

  Future<_WalletBook> _loadBook({bool persistMigration = true}) async {
    final raw = await _store.read(WalletVault.walletBookKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (json['version'] != 2) throw const FormatException();
        final groups = <_StoredGroup>[];
        final ids = <String>{};
        for (final item in json['groups'] as List) {
          final value = Map<String, dynamic>.from(item as Map);
          final id = value['id'] as String;
          if (id.isEmpty || !ids.add(id)) throw const FormatException();
          final kind = WalletKind.values.byName(value['kind'] as String);
          final accounts = <_StoredAccount>[];
          final indices = <int>{};
          for (final a in value['accounts'] as List) {
            final index = a['index'] as int;
            if (index < 0 || index >= 0x80000000 || !indices.add(index)) {
              throw const FormatException();
            }
            if (a['legacyAddressMode'] != null &&
                a['legacyAddressMode'] is! bool) {
              throw const FormatException();
            }
            accounts.add(
              _StoredAccount(
                index,
                _checkedName(a['name'] as String),
                legacyAddressMode: a['legacyAddressMode'] == true,
                evmPath: a['evmPath'] == null
                    ? null
                    : normalizeDerivationPath(a['evmPath'] as String),
                tronPath: a['tronPath'] == null
                    ? null
                    : normalizeDerivationPath(a['tronPath'] as String),
              ),
            );
          }
          if (accounts.isEmpty ||
              !indices.contains(0) ||
              (kind == WalletKind.privateKey &&
                  (accounts.length != 1 || accounts.first.index != 0))) {
            throw const FormatException();
          }
          final group = _StoredGroup(
            id: id,
            name: _checkedName(value['name'] as String),
            kind: kind,
            secret: value['secret'] as String,
            networkId: value['networkId'] as int?,
            accounts: accounts,
          );
          if (kind == WalletKind.privateKey &&
              (group.networkId == null || group.networkId! <= 0)) {
            throw const FormatException();
          }
          // Validate secrets before returning any account; never silently drop a wallet.
          final evmPaths = <String>{}, tronPaths = <String>{};
          for (final entry in accounts) {
            if (kind == WalletKind.mnemonic &&
                (!evmPaths.add(
                      '${entry.legacyAddressMode}:${entry.evmPath ?? evmAccountDerivationPath(entry.index)}',
                    ) ||
                    !tronPaths.add(
                      '${entry.legacyAddressMode}:${entry.tronPath ?? tronAccountDerivationPath(entry.index)}',
                    ))) {
              throw const FormatException();
            }
          }
          group.account(0);
          groups.add(group);
        }
        return _WalletBook(
          groups: groups,
          activeAccountId: json['activeAccountId'] as String?,
        );
      } catch (_) {
        throw const WalletInputException(
          MessageCode.msgCannotReadTheWalletBookCheckSecureStorage,
        );
      }
    }

    // Migrate only after every old record is validated. Preserve the old keys as
    // a recovery copy, and write the entire new book atomically under one key.
    final groups = <_StoredGroup>[];
    final mnemonic = await _store.read(WalletVault.mnemonicKey);
    if (mnemonic != null && mnemonic.trim().isNotEmpty) {
      final phrase = WalletVault._normalizeMnemonic(mnemonic);
      WalletAccount.fromMnemonic(phrase);
      groups.add(
        _StoredGroup(
          id: _newWalletId(),
          name: '主钱包',
          kind: WalletKind.mnemonic,
          secret: phrase,
          accounts: [_StoredAccount(0, '账户 1')],
        ),
      );
    }
    final privateKeys = await _store.read(WalletVault.privateKeyWalletsKey);
    if (privateKeys != null && privateKeys.trim().isNotEmpty) {
      try {
        for (final item in jsonDecode(privateKeys) as List) {
          final account = WalletAccount.fromPrivateKey(
            item['privateKey'] as String,
          );
          final chain = item['chainId'] as int;
          if (chain <= 0) throw const FormatException();
          groups.add(
            _StoredGroup(
              id: _newWalletId(),
              name:
                  '私钥账户 ${groups.where((g) => g.kind == WalletKind.privateKey).length + 1}',
              kind: WalletKind.privateKey,
              secret: account.privateKeyHex,
              networkId: chain,
              accounts: [_StoredAccount(0, '账户 1')],
            ),
          );
        }
      } catch (_) {
        throw const WalletInputException(
          MessageCode.msgSavedPrivateKeyAccountDataIsCorrupted,
        );
      }
    }
    // Keep the previous version's initial preference when migrating.
    final selected =
        groups.where((g) => g.kind == WalletKind.privateKey).firstOrNull ??
        groups.firstOrNull;
    final book = _WalletBook(
      groups: groups,
      activeAccountId: selected?.entryId(0),
    );
    if (persistMigration && groups.isNotEmpty) {
      await _store.write(WalletVault.walletBookKey, jsonEncode(book.toJson()));
    }
    return book;
  }

  Future<T> _changeBook<T>(FutureOr<T> Function(_WalletBook) change) {
    final operation = _mutationTail.then((_) async {
      final book = await _loadBook();
      final before = jsonEncode(book.toJson());
      final result = await change(book);
      final after = jsonEncode(book.toJson());
      if (after != before) await _store.write(WalletVault.walletBookKey, after);
      return result;
    });
    _mutationTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> exportRecoveryMatches(
    String path,
    List<Map<String, Object?>> matches,
  ) async {
    final payload = jsonEncode({
      'format': 'asterkeel-recovery-results-v1',
      'matches': matches,
    });
    if (_database != null) {
      await _macCall<void>('recovery.export', {
        'path': path,
        'payload': payload,
      });
    } else {
      await File(path).writeAsString(payload, flush: true);
    }
  }

  Future<List<Map<String, Object?>>> loadRecoveryTasks() async {
    if (_database != null) {
      final records = (await _macCall<List<Object?>>('recovery.list'))!;
      return [
        for (final raw in records)
          Map<String, Object?>.from(jsonDecode(raw as String) as Map),
      ];
    }
    final raw = await _store.read('stone_wallet.recovery_tasks.v1');
    if (raw == null) return [];
    return [
      for (final record in jsonDecode(raw) as List)
        Map<String, Object?>.from(record as Map),
    ];
  }

  Future<void> saveRecoveryTask(Map<String, Object?> record) =>
      _serialize(() async {
        final id = record['id'] as String;
        final payload = jsonEncode(record);
        if (_database != null) {
          await _macCall<void>('recovery.save', {
            'id': id,
            'payload': payload,
            'updated_at': record['updated_at'],
          });
        } else {
          final records = await loadRecoveryTasks();
          records.removeWhere((r) => r['id'] == id);
          records.insert(0, record);
          await _store.write(
            'stone_wallet.recovery_tasks.v1',
            jsonEncode(records),
          );
        }
      });

  Future<WalletPortfolio> loadPortfolio() => _database != null
      ? _macFullPortfolio()
      : _changeBook((book) => book.snapshot());

  Future<WalletPortfolio> loadWalletSummary() =>
      _database != null ? _macSummary() : loadPortfolio();

  /// Reads wallet addresses in book order without selecting or unlocking accounts.
  Stream<WalletEntry> walletBalanceEntries() async* {
    if (_database != null) {
      WalletPageCursor? cursor;
      do {
        final page = await loadWalletPage(after: cursor);
        for (final group in page.groups) {
          for (final entry in group.accounts) {
            yield entry;
          }
        }
        cursor = page.next;
      } while (cursor != null);
      return;
    }

    final book = await _changeBook((book) => book);
    for (final group in book.groups) {
      for (final account in group.accounts) {
        final owner = group.account(account.index);
        yield WalletEntry(
          id: group.entryId(account.index),
          groupId: group.id,
          name: account.name,
          groupName: group.name,
          kind: group.kind,
          index: account.index,
          evmPath: account.evmPath,
          tronPath: account.tronPath,
          legacyAddressMode: account.legacyAddressMode,
          evmAddress: owner.checksumAddress,
          tronAddress: owner.tronAddress,
          preferredNetworkId: group.networkId,
          groupAccountCount: group.accounts.length,
        );
      }
    }
  }

  Future<WalletPortfolio> addMnemonicWallet(
    String mnemonic, {
    String? name,
    String? accountName,
    String Function(int)? nameForWallet,
  }) {
    final phrase = WalletVault._normalizeMnemonic(mnemonic);
    final account = WalletAccount.fromMnemonic(phrase);
    if (_database != null) {
      return _macAddMnemonic(
        phrase,
        account,
        name: name,
        accountName: accountName,
        nameForWallet: nameForWallet,
      );
    }
    return _changeBook((book) {
      final existing = book.groups
          .where(
            (g) =>
                g.kind == WalletKind.mnemonic &&
                g.account(0).address == account.address,
          )
          .firstOrNull;
      if (existing != null) {
        book.activeAccountId = existing.entryId(0);
      } else {
        final count = book.groups
            .where((g) => g.kind == WalletKind.mnemonic)
            .length;
        final group = _StoredGroup(
          id: _newWalletId(),
          name: _checkedName(
            name ??
                nameForWallet?.call(count + 1) ??
                (count == 0 ? '主钱包' : '钱包 ${count + 1}'),
          ),
          kind: WalletKind.mnemonic,
          secret: phrase,
          accounts: [_StoredAccount(0, _checkedName(accountName ?? '账户 1'))],
        );
        book.groups.add(group);
        book.activeAccountId = group.entryId(0);
      }
      return book.snapshot();
    });
  }

  Future<BatchImportResult> importPrivateKeyRows(
    List<WalletImportRow> rows, {
    bool selectImported = false,
    String Function(int)? nameForWallet,
    String? accountName,
  }) async {
    final networks = await loadNetworks();
    if (_database != null) {
      return _macImportPrivateRows(
        rows,
        networks,
        selectImported: selectImported,
        nameForWallet: nameForWallet,
        accountName: accountName,
      );
    }
    return _changeBook((book) {
      final seen = {
        for (final g in book.groups.where(
          (g) => g.kind == WalletKind.privateKey,
        ))
          '${g.networkId}:${g.secret}',
      };
      final imported = <ImportedWallet>[];
      final errors = <WalletImportError>[];
      for (var i = 0; i < rows.length; i++) {
        try {
          final network = networkForValue(rows[i].chain, networks: networks);
          if (network == null) {
            throw const WalletInputException(MessageCode.msgUnsupportedNetwork);
          }
          final account = WalletAccount.fromPrivateKey(rows[i].privateKey);
          if (!seen.add('${network.id}:${account.privateKeyHex}')) {
            throw const WalletInputException(
              MessageCode.msgDuplicateEntrySkipped,
            );
          }
          final group = _StoredGroup(
            id: _newWalletId(),
            name: _checkedName(
              nameForWallet?.call(
                    book.groups
                            .where((g) => g.kind == WalletKind.privateKey)
                            .length +
                        1,
                  ) ??
                  '私钥账户 ${book.groups.where((g) => g.kind == WalletKind.privateKey).length + 1}',
            ),
            kind: WalletKind.privateKey,
            secret: account.privateKeyHex,
            networkId: network.id,
            accounts: [_StoredAccount(0, _checkedName(accountName ?? '账户 1'))],
          );
          book.groups.add(group);
          if (selectImported || book.activeAccountId == null) {
            book.activeAccountId = group.entryId(0);
          }
          imported.add(ImportedWallet(networkId: network.id, account: account));
        } on WalletInputException catch (error) {
          errors.add(WalletImportError(i + 1, error.message));
        }
      }
      return BatchImportResult(imported: imported, errors: errors);
    });
  }

  Future<WalletPortfolio> addDerivedAccount(
    String groupId, {
    String? name,
    String? evmPath,
    String? tronPath,
    bool legacyAddressMode = false,
  }) => _database != null
      ? _macAddDerived(
          groupId,
          name,
          evmPath: evmPath,
          tronPath: tronPath,
          legacyAddressMode: legacyAddressMode,
        )
      : _changeBook((book) {
          final group = book.groups.where((g) => g.id == groupId).firstOrNull;
          if (group == null || group.kind != WalletKind.mnemonic) {
            throw const WalletInputException(
              MessageCode
                  .msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts,
            );
          }
          final next = group.accounts.map((a) => a.index).reduce(max) + 1;
          final evmPaths = group.accounts.map(
            (a) => a.evmPath ?? evmAccountDerivationPath(a.index),
          );
          final tronPaths = group.accounts.map(
            (a) => a.tronPath ?? tronAccountDerivationPath(a.index),
          );
          final evm = normalizeDerivationPath(
            evmPath ?? _unusedDerivationPath(next, evmPaths),
          );
          final tron = normalizeDerivationPath(
            tronPath ?? _unusedDerivationPath(next, tronPaths, tron: true),
          );
          if (group.accounts.any(
            (a) =>
                a.legacyAddressMode == legacyAddressMode &&
                ((a.evmPath ?? evmAccountDerivationPath(a.index)) == evm ||
                    (a.tronPath ?? tronAccountDerivationPath(a.index)) == tron),
          )) {
            throw const WalletInputException(
              MessageCode.duplicateDerivationPath,
            );
          }
          WalletAccount.fromMnemonic(
            group.secret,
            accountIndex: next,
            evmPath: evm,
            tronPath: tron,
            legacyAddressMode: legacyAddressMode,
          );
          group.accounts.add(
            _StoredAccount(
              next,
              _checkedName(name ?? '账户 ${next + 1}'),
              evmPath: evm,
              tronPath: tron,
              legacyAddressMode: legacyAddressMode,
            ),
          );
          book.activeAccountId = group.entryId(next);
          return book.snapshot();
        });

  Future<WalletPortfolio> selectAccount(String accountId) => _database != null
      ? _macSummary('select', {'id': accountId})
      : _changeBook((book) {
          if (!book.groups.any(
            (g) => g.accounts.any((a) => g.entryId(a.index) == accountId),
          )) {
            throw const WalletInputException(MessageCode.msgAccountNotFound);
          }
          book.activeAccountId = accountId;
          return book.snapshot();
        });

  Future<WalletPortfolio> renameWallet(String groupId, String name) =>
      _database != null
      ? _macSummary('rename', {'id': groupId, 'name': _checkedName(name)})
      : _changeBook((book) {
          final group = book.groups.where((g) => g.id == groupId).firstOrNull;
          if (group == null) {
            throw const WalletInputException(MessageCode.msgWalletNotFound);
          }
          group.name = _checkedName(name);
          return book.snapshot();
        });

  Future<WalletPortfolio> renameAccount(String accountId, String name) =>
      _database != null
      ? _macSummary('rename', {
          'id': accountId,
          'name': _checkedName(name),
          'account': true,
        })
      : _changeBook((book) {
          for (final group in book.groups) {
            for (final account in group.accounts) {
              if (group.entryId(account.index) == accountId) {
                account.name = _checkedName(name);
                return book.snapshot();
              }
            }
          }
          throw const WalletInputException(MessageCode.msgAccountNotFound);
        });
}
