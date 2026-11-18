part of 'wallet_core.dart';

String evmAccountDerivationPath(int index) => "m/44'/60'/0'/0/$index";

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
  WalletAccount get account =>
      _account ??
      (throw StateError('Signing material is not loaded for this account'));
  String addressFor(EvmNetwork? network) => network?.isTron == true
      ? (_tronAddress ?? account.tronAddress)
      : (_evmAddress ?? account.checksumAddress);

  String get displayName =>
      groupAccountCount == 1 ? groupName : '$groupName · $name';
  String? get derivationPath =>
      kind == WalletKind.mnemonic ? evmAccountDerivationPath(index) : null;
  String? derivationPathFor(EvmNetwork? network) => kind == WalletKind.mnemonic
      ? network?.isTron == true
            ? tronAccountDerivationPath(index)
            : evmAccountDerivationPath(index)
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
  });
  final String id, name;
  final WalletKind kind;
  final int? preferredNetworkId;
  final bool hasAliases;
  final List<WalletEntry> accounts;
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
  _StoredAccount(this.index, this.name);
  final int index;
  String name;
  Map<String, Object> toJson() => {'index': index, 'name': name};
}

class _StoredGroup {
  _StoredGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.secret,
    required this.accounts,
    this.networkId,
    int? nextAccountIndex,
  }) : nextAccountIndex =
           nextAccountIndex ??
           accounts.fold<int>(
                 0,
                 (maximum, a) => a.index > maximum ? a.index : maximum,
               ) +
               1;
  final String id, secret;
  String name;
  final WalletKind kind;
  final int? networkId;
  final List<_StoredAccount> accounts;
  int nextAccountIndex;
  String entryId(int index) => '$id:$index';
  WalletAccount account(int index) => kind == WalletKind.mnemonic
      ? WalletAccount.fromMnemonic(secret, accountIndex: index)
      : WalletAccount.fromPrivateKey(secret);
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
    'nextAccountIndex': nextAccountIndex,
    'accounts': [for (final a in accounts) a.toJson()],
  };
}

class _WalletBook {
  _WalletBook({
    required this.groups,
    this.activeAccountId,
    Map<String, dynamic>? balances,
  }) : balances = balances ?? {};
  final List<_StoredGroup> groups;
  String? activeAccountId;
  final Map<String, dynamic> balances;
  WalletPortfolio snapshot() => WalletPortfolio(
    groups: List.unmodifiable(groups.map((g) => g.snapshot())),
    activeAccountId: activeAccountId,
  );
  Map<String, Object?> toJson() => {
    'version': 2,
    'groups': groups.map((g) => g.toJson()).toList(),
    'activeAccountId': activeAccountId,
    'balances': balances,
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
            accounts.add(
              _StoredAccount(index, _checkedName(a['name'] as String)),
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
            nextAccountIndex: value['nextAccountIndex'] as int?,
          );
          if (kind == WalletKind.privateKey &&
              (group.networkId == null || group.networkId! <= 0)) {
            throw const FormatException();
          }
          if (group.nextAccountIndex <=
              accounts.map((a) => a.index).reduce((a, b) => a > b ? a : b)) {
            throw const FormatException();
          }
          // Validate secrets before returning any account; never silently drop a wallet.
          group.account(0);
          groups.add(group);
        }
        return _WalletBook(
          groups: groups,
          activeAccountId: json['activeAccountId'] as String?,
          balances: Map<String, dynamic>.from(json['balances'] as Map? ?? {}),
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
    String Function(int)? nameForAccount,
  }) => _database != null
      ? _macAddDerived(groupId, name, nameForAccount)
      : _changeBook((book) {
          final group = book.groups.where((g) => g.id == groupId).firstOrNull;
          if (group == null || group.kind != WalletKind.mnemonic) {
            throw const WalletInputException(
              MessageCode
                  .msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts,
            );
          }
          final next = group.nextAccountIndex;
          group.account(
            next,
          ); // Validate the derivation before changing persisted data.
          group.accounts.add(
            _StoredAccount(
              next,
              _checkedName(
                name ?? nameForAccount?.call(next) ?? '账户 ${next + 1}',
              ),
            ),
          );
          group.nextAccountIndex = next + 1;
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
