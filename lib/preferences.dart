import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

enum AppLanguage { system, zhHans, zhHant, en }

enum WalletPage { assets, settings }

enum AssetCategory { stablecoins, tokens, nft, rwa }

enum AssetView { overview, coin }

enum AssetDisplay { simple, detailed }

enum AssetSort { value, stableFirst, name }

enum AssetFilter { all, stablecoins, tokens }

enum AddressScope { all, evm, tron }

// Unsupported categories have no route, network provider, or visible empty tab.
const availableAssetCategories = [
  AssetCategory.stablecoins,
  AssetCategory.tokens,
];

class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.system,
    this.category = AssetCategory.stablecoins,
    this.family = 'USDT',
    this.view = AssetView.overview,
    this.display = AssetDisplay.simple,
    this.sort = AssetSort.value,
    this.filter = AssetFilter.all,
    this.addressScope = AddressScope.all,
    this.limit = 5,
    this.networkFilter = 0,
    this.hideZero = true,
    this.showSpam = false,
    this.selectedAssetId = 'usdt',
  });
  final AppLanguage language;
  final AssetCategory category;
  final String family;
  final AssetView view;
  final AssetDisplay display;
  final AssetSort sort;
  final AssetFilter filter;
  final AddressScope addressScope;
  final int limit;
  final int networkFilter;
  final bool hideZero;
  final bool showSpam;
  final String selectedAssetId;
  AppPreferences copyWith({
    AppLanguage? language,
    AssetCategory? category,
    String? family,
    AssetView? view,
    AssetDisplay? display,
    AssetSort? sort,
    AssetFilter? filter,
    AddressScope? addressScope,
    int? limit,
    int? networkFilter,
    bool? hideZero,
    bool? showSpam,
    String? selectedAssetId,
  }) => AppPreferences(
    language: language ?? this.language,
    category: category ?? this.category,
    family: family ?? this.family,
    view: view ?? this.view,
    display: display ?? this.display,
    sort: sort ?? this.sort,
    filter: filter ?? this.filter,
    addressScope: addressScope ?? this.addressScope,
    limit: limit ?? this.limit,
    networkFilter: networkFilter ?? this.networkFilter,
    hideZero: hideZero ?? this.hideZero,
    showSpam: showSpam ?? this.showSpam,
    selectedAssetId: selectedAssetId ?? this.selectedAssetId,
  );
  Map<String, Object> toJson() => {
    'version': 1,
    'language': language.name,
    'category': category.name,
    'family': family,
    'view': view.name,
    'display': display.name,
    'sort': sort.name,
    'filter': filter.name,
    'addressScope': addressScope.name,
    'limit': limit,
    'networkFilter': networkFilter,
    'hideZero': hideZero,
    'showSpam': showSpam,
    'selectedAssetId': selectedAssetId,
  };
  factory AppPreferences.fromRecord(String? raw) {
    try {
      final json = jsonDecode(raw ?? '{}') as Map;
      if (json['version'] != null && json['version'] != 1) {
        return const AppPreferences();
      }
      T pick<T extends Enum>(String key, List<T> values, T fallback) =>
          values.where((v) => v.name == json[key]).firstOrNull ?? fallback;
      return AppPreferences(
        language: pick('language', AppLanguage.values, AppLanguage.system),
        category: pick(
          'category',
          availableAssetCategories,
          AssetCategory.stablecoins,
        ),
        family: json['family'] == 'USDC' ? 'USDC' : 'USDT',
        view: pick('view', AssetView.values, AssetView.overview),
        display: pick('display', AssetDisplay.values, AssetDisplay.simple),
        sort: pick('sort', AssetSort.values, AssetSort.value),
        filter: pick('filter', AssetFilter.values, AssetFilter.all),
        addressScope: pick(
          'addressScope',
          AddressScope.values,
          AddressScope.all,
        ),
        limit: [0, 3, 5, 10].contains(json['limit']) ? json['limit'] as int : 5,
        networkFilter:
            json['networkFilter'] is int && json['networkFilter'] >= 0
            ? json['networkFilter'] as int
            : 0,
        hideZero: json['hideZero'] is bool ? json['hideZero'] as bool : true,
        showSpam: json['showSpam'] is bool ? json['showSpam'] as bool : false,
        selectedAssetId:
            json['selectedAssetId'] is String &&
                (json['selectedAssetId'] as String).isNotEmpty &&
                (json['selectedAssetId'] as String).length <= 160
            ? json['selectedAssetId'] as String
            : (json['family'] == 'USDC' ? 'usdc' : 'usdt'),
      );
    } catch (_) {
      return const AppPreferences();
    }
  }
}

class PreferencesController extends ChangeNotifier {
  PreferencesController({required this.read, required this.write});
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  AppPreferences value = const AppPreferences();
  bool loaded = false, disposed = false;
  bool saveFailed = false;
  Future<void> _tail = Future.value();
  Future<void> load() async {
    try {
      value = AppPreferences.fromRecord(await read());
    } catch (_) {
      value = const AppPreferences();
    }
    if (disposed) return;
    loaded = true;
    notifyListeners();
  }

  void update({
    AppLanguage? language,
    AssetCategory? category,
    String? family,
    AssetView? view,
    AssetDisplay? display,
    AssetSort? sort,
    AssetFilter? filter,
    AddressScope? addressScope,
    int? limit,
    int? networkFilter,
    bool? hideZero,
    bool? showSpam,
    String? selectedAssetId,
  }) {
    value = value.copyWith(
      language: language,
      category: category,
      family: family,
      view: view,
      display: display,
      sort: sort,
      filter: filter,
      addressScope: addressScope,
      limit: limit,
      networkFilter: networkFilter,
      hideZero: hideZero,
      showSpam: showSpam,
      selectedAssetId: selectedAssetId,
    );
    final snapshot = jsonEncode(value.toJson());
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await write(snapshot);
        saveFailed = false;
      } catch (_) {
        saveFailed = true;
      }
      if (!disposed) notifyListeners();
    });
  }

  Future<void> get settled => _tail;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
