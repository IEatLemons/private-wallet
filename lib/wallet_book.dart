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
    required this.account,
    this.preferredNetworkId,
    required this.groupAccountCount,
  });
  final String id, groupId, name, groupName;
  final WalletKind kind;
  final int index, groupAccountCount;
  final int? preferredNetworkId;
  final WalletAccount account;
  String get displayName =>
      groupAccountCount == 1 ? groupName : '$groupName · $name';
  String? get derivationPath =>
      kind == WalletKind.mnemonic ? evmAccountDerivationPath(index) : null;
}

class WalletGroup {
  const WalletGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.accounts,
    this.preferredNetworkId,
  });
  final String id, name;
  final WalletKind kind;
  final int? preferredNetworkId;
  final List<WalletEntry> accounts;
}

class WalletPortfolio {
  const WalletPortfolio({required this.groups, this.activeAccountId});
  final List<WalletGroup> groups;
  final String? activeAccountId;
  List<WalletEntry> get accounts => [
    for (final group in groups) ...group.accounts,
  ];
  WalletEntry? get selected =>
      accounts.where((a) => a.id == activeAccountId).firstOrNull ??
      accounts.firstOrNull;
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
  });
  final String id, secret;
  String name;
  final WalletKind kind;
  final int? networkId;
  final List<_StoredAccount> accounts;
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
      throw const WalletInputException('名称需要包含 1 至 64 个字符。');
    }
    return value;
  }

  Future<_WalletBook> _loadBook() async {
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
          );
          if (kind == WalletKind.privateKey &&
              (group.networkId == null || group.networkId! <= 0)) {
            throw const FormatException();
          }
          // Validate secrets before returning any account; never silently drop a wallet.
          group.account(0);
          groups.add(group);
        }
        return _WalletBook(
          groups: groups,
          activeAccountId: json['activeAccountId'] as String?,
        );
      } catch (_) {
        throw const WalletInputException('本机钱包簿无法读取，请检查安全存储。');
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
        throw const WalletInputException('本机保存的私钥账户数据已损坏。');
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
    if (groups.isNotEmpty) {
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

  Future<WalletPortfolio> loadPortfolio() =>
      _changeBook((book) => book.snapshot());

  Future<WalletPortfolio> addMnemonicWallet(String mnemonic, {String? name}) {
    final phrase = WalletVault._normalizeMnemonic(mnemonic);
    final account = WalletAccount.fromMnemonic(phrase);
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
          name: _checkedName(name ?? (count == 0 ? '主钱包' : '钱包 ${count + 1}')),
          kind: WalletKind.mnemonic,
          secret: phrase,
          accounts: [_StoredAccount(0, '账户 1')],
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
  }) async {
    final networks = await loadNetworks();
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
          if (network == null) throw const WalletInputException('不支持的链。');
          final account = WalletAccount.fromPrivateKey(rows[i].privateKey);
          if (!seen.add('${network.id}:${account.privateKeyHex}')) {
            throw const WalletInputException('重复记录，已跳过。');
          }
          final group = _StoredGroup(
            id: _newWalletId(),
            name:
                '私钥账户 ${book.groups.where((g) => g.kind == WalletKind.privateKey).length + 1}',
            kind: WalletKind.privateKey,
            secret: account.privateKeyHex,
            networkId: network.id,
            accounts: [_StoredAccount(0, '账户 1')],
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

  Future<WalletPortfolio> addDerivedAccount(String groupId) => _changeBook((
    book,
  ) {
    final group = book.groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null || group.kind != WalletKind.mnemonic) {
      throw const WalletInputException('只有助记词钱包可以派生新账户。');
    }
    final next =
        group.accounts.map((a) => a.index).reduce((a, b) => a > b ? a : b) + 1;
    group.account(
      next,
    ); // Validate the derivation before changing persisted data.
    group.accounts.add(_StoredAccount(next, '账户 ${next + 1}'));
    book.activeAccountId = group.entryId(next);
    return book.snapshot();
  });

  Future<WalletPortfolio> selectAccount(String accountId) =>
      _changeBook((book) {
        if (!book.groups.any(
          (g) => g.accounts.any((a) => g.entryId(a.index) == accountId),
        )) {
          throw const WalletInputException('找不到此账户。');
        }
        book.activeAccountId = accountId;
        return book.snapshot();
      });

  Future<WalletPortfolio> renameWallet(String groupId, String name) =>
      _changeBook((book) {
        final group = book.groups.where((g) => g.id == groupId).firstOrNull;
        if (group == null) throw const WalletInputException('找不到此钱包。');
        group.name = _checkedName(name);
        return book.snapshot();
      });

  Future<WalletPortfolio> renameAccount(String accountId, String name) =>
      _changeBook((book) {
        for (final group in book.groups) {
          for (final account in group.accounts) {
            if (group.entryId(account.index) == accountId) {
              account.name = _checkedName(name);
              return book.snapshot();
            }
          }
        }
        throw const WalletInputException('找不到此账户。');
      });
}
