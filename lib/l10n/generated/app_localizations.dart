import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Asterkeel Wallet'**
  String get appName;

  /// No description provided for @msgSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get msgSyncing;

  /// No description provided for @msgRefreshAssets.
  ///
  /// In en, this message translates to:
  /// **'Refresh assets'**
  String get msgRefreshAssets;

  /// No description provided for @msgManageNetworks.
  ///
  /// In en, this message translates to:
  /// **'Manage networks'**
  String get msgManageNetworks;

  /// No description provided for @msgStablecoins.
  ///
  /// In en, this message translates to:
  /// **'Stablecoins'**
  String get msgStablecoins;

  /// No description provided for @msgOtherCoins.
  ///
  /// In en, this message translates to:
  /// **'Other coins'**
  String get msgOtherCoins;

  /// No description provided for @msgAddTokens.
  ///
  /// In en, this message translates to:
  /// **'Add tokens'**
  String get msgAddTokens;

  /// No description provided for @msgSearchAssetsOrNetworks.
  ///
  /// In en, this message translates to:
  /// **'Search assets or networks'**
  String get msgSearchAssetsOrNetworks;

  /// No description provided for @msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear.
  ///
  /// In en, this message translates to:
  /// **'Native coins pay network fees. Unsynced balances appear as —.'**
  String get msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear;

  /// No description provided for @msgTokensAreIdentifiedByNetworkAndContractMatching.
  ///
  /// In en, this message translates to:
  /// **'Tokens are identified by network and contract. Matching tickers are not automatically combined.'**
  String get msgTokensAreIdentifiedByNetworkAndContractMatching;

  /// No description provided for @msgNoMatchingAssets.
  ///
  /// In en, this message translates to:
  /// **'No matching assets.'**
  String get msgNoMatchingAssets;

  /// {p0} 资产详情
  ///
  /// In en, this message translates to:
  /// **'{p0} asset details'**
  String msgAssetDetails(String p0);

  /// No description provided for @msgSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get msgSend;

  /// No description provided for @msgReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get msgReceive;

  /// No description provided for @msgUseThisNetwork.
  ///
  /// In en, this message translates to:
  /// **'Use this network'**
  String get msgUseThisNetwork;

  /// No description provided for @msgRefreshBalance.
  ///
  /// In en, this message translates to:
  /// **'Refresh balance'**
  String get msgRefreshBalance;

  /// No description provided for @msgNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get msgNetwork;

  /// No description provided for @msgWalletAddress.
  ///
  /// In en, this message translates to:
  /// **'Wallet address'**
  String get msgWalletAddress;

  /// No description provided for @msgRpcUrl.
  ///
  /// In en, this message translates to:
  /// **'RPC URL'**
  String get msgRpcUrl;

  /// No description provided for @msgBlockExplorer.
  ///
  /// In en, this message translates to:
  /// **'Block explorer'**
  String get msgBlockExplorer;

  /// No description provided for @msgExplorerLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Explorer link copied'**
  String get msgExplorerLinkCopied;

  /// No description provided for @msgCopyExplorerLink.
  ///
  /// In en, this message translates to:
  /// **'Copy explorer link'**
  String get msgCopyExplorerLink;

  /// No description provided for @msgSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get msgSystemDefault;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageTraditionalChinese.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

  /// No description provided for @msgLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get msgLanguage;

  /// No description provided for @msgPreferencesCouldNotBeSavedPreviousSettingsMay.
  ///
  /// In en, this message translates to:
  /// **'Preferences could not be saved. Previous settings may return after restarting.'**
  String get msgPreferencesCouldNotBeSavedPreviousSettingsMay;

  /// No description provided for @msgYourKeysYourWallet.
  ///
  /// In en, this message translates to:
  /// **'Your keys,\nyour wallet.'**
  String get msgYourKeysYourWallet;

  /// No description provided for @msgManageYourOnchainAssetsCreateAWalletOr.
  ///
  /// In en, this message translates to:
  /// **'Manage your onchain assets.\nCreate a wallet or import an existing account to start.'**
  String get msgManageYourOnchainAssetsCreateAWalletOr;

  /// No description provided for @msgSelfCustodyWallet.
  ///
  /// In en, this message translates to:
  /// **'Self-custody wallet'**
  String get msgSelfCustodyWallet;

  /// No description provided for @msgTransactionsAreSignedOnThisDeviceYouControl.
  ///
  /// In en, this message translates to:
  /// **'Transactions are signed on this device. You control your keys.'**
  String get msgTransactionsAreSignedOnThisDeviceYouControl;

  /// No description provided for @msgSecureDeviceStorage.
  ///
  /// In en, this message translates to:
  /// **'Secure device storage'**
  String get msgSecureDeviceStorage;

  /// No description provided for @msgRecoveryCredentialsStayInThisDeviceSSecure.
  ///
  /// In en, this message translates to:
  /// **'Recovery credentials stay in this device’s secure storage.'**
  String get msgRecoveryCredentialsStayInThisDeviceSSecure;

  /// No description provided for @msgChooseYourNetworks.
  ///
  /// In en, this message translates to:
  /// **'Choose your networks'**
  String get msgChooseYourNetworks;

  /// No description provided for @msgRpcConnectionsStartOnlyAfterYouEnableA.
  ///
  /// In en, this message translates to:
  /// **'RPC connections start only after you enable a network.'**
  String get msgRpcConnectionsStartOnlyAfterYouEnableA;

  /// No description provided for @msgGetStartedWithWallet.
  ///
  /// In en, this message translates to:
  /// **'Get started with Asterkeel Wallet'**
  String get msgGetStartedWithWallet;

  /// No description provided for @msgChooseHowToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Choose how to get started'**
  String get msgChooseHowToGetStarted;

  /// No description provided for @msgCreateWallet.
  ///
  /// In en, this message translates to:
  /// **'Create wallet'**
  String get msgCreateWallet;

  /// No description provided for @msgImportRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Import recovery phrase'**
  String get msgImportRecoveryPhrase;

  /// No description provided for @msgImportPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Import private key'**
  String get msgImportPrivateKey;

  /// No description provided for @msgImportPrivateKeyFile.
  ///
  /// In en, this message translates to:
  /// **'Import private-key file'**
  String get msgImportPrivateKeyFile;

  /// No description provided for @msgCsvTsvColumnsChainPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'CSV / TSV · Columns: chain, private key'**
  String get msgCsvTsvColumnsChainPrivateKey;

  /// No description provided for @msgKeepYourRecoveryPhraseAndPrivateKeysSafe.
  ///
  /// In en, this message translates to:
  /// **'Keep your recovery phrase and private keys safe. They restore access to your wallet.'**
  String get msgKeepYourRecoveryPhraseAndPrivateKeysSafe;

  /// No description provided for @msgNetworksAndRpc.
  ///
  /// In en, this message translates to:
  /// **'Networks and RPC'**
  String get msgNetworksAndRpc;

  /// No description provided for @msgNoNetworkSelectedEnableANetworkToQuery.
  ///
  /// In en, this message translates to:
  /// **'No network selected. Enable a network to query balances.'**
  String get msgNoNetworkSelectedEnableANetworkToQuery;

  /// No description provided for @msgTransactionNetwork.
  ///
  /// In en, this message translates to:
  /// **'Transaction network'**
  String get msgTransactionNetwork;

  /// No description provided for @msgTestnet.
  ///
  /// In en, this message translates to:
  /// **'Testnet'**
  String get msgTestnet;

  /// No description provided for @msgMainnet.
  ///
  /// In en, this message translates to:
  /// **'Mainnet'**
  String get msgMainnet;

  /// {p0} 个节点 · 失败自动切换
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{{p0} endpoint · Automatic failover} other{{p0} endpoints · Automatic failover}}'**
  String endpointCount(int p0);

  /// No description provided for @msgActiveEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Active endpoint'**
  String get msgActiveEndpoint;

  /// No description provided for @msgSyncingMore.
  ///
  /// In en, this message translates to:
  /// **'○ Syncing…'**
  String get msgSyncingMore;

  /// No description provided for @msgRpcConnected.
  ///
  /// In en, this message translates to:
  /// **'● RPC connected'**
  String get msgRpcConnected;

  /// No description provided for @msgNotSynced.
  ///
  /// In en, this message translates to:
  /// **'○ Not synced'**
  String get msgNotSynced;

  /// No description provided for @msgEditRpc.
  ///
  /// In en, this message translates to:
  /// **'Edit RPC'**
  String get msgEditRpc;

  /// No description provided for @msgAddCustomNetwork.
  ///
  /// In en, this message translates to:
  /// **'Add custom network'**
  String get msgAddCustomNetwork;

  /// No description provided for @msgWalletSecurity.
  ///
  /// In en, this message translates to:
  /// **'Wallet security'**
  String get msgWalletSecurity;

  /// No description provided for @msgAccountSource.
  ///
  /// In en, this message translates to:
  /// **'Account source'**
  String get msgAccountSource;

  /// No description provided for @msgDerivationPath.
  ///
  /// In en, this message translates to:
  /// **'Derivation path'**
  String get msgDerivationPath;

  /// No description provided for @msgPrivateKeyImport.
  ///
  /// In en, this message translates to:
  /// **'Private-key import'**
  String get msgPrivateKeyImport;

  /// No description provided for @msgRecoveryPhrasesAndPrivateKeysRemainInSecure.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrases and private keys remain in secure device storage. Keep an offline backup.'**
  String get msgRecoveryPhrasesAndPrivateKeysRemainInSecure;

  /// No description provided for @msgWalletManagement.
  ///
  /// In en, this message translates to:
  /// **'Wallet management'**
  String get msgWalletManagement;

  /// {p0} 个钱包 · {p1} 个账户
  /// 创建、导入更多钱包，或在助记词钱包下继续添加账户。
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{{p0} wallet} other{{p0} wallets}} · {p1, plural, one{{p1} account} other{{p1} accounts}}\nCreate or import wallets, or add accounts to a recovery-phrase wallet.'**
  String walletAndAccountSummary(int p0, int p1);

  /// No description provided for @msgManageWalletsAndAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage wallets and accounts'**
  String get msgManageWalletsAndAccounts;

  /// No description provided for @msgChooseFileToImport.
  ///
  /// In en, this message translates to:
  /// **'Choose file to import'**
  String get msgChooseFileToImport;

  /// No description provided for @msgBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get msgBackup;

  /// No description provided for @msgIcloudGoogleDriveBackupNotConnected.
  ///
  /// In en, this message translates to:
  /// **'iCloud / Google Drive backup (not connected)'**
  String get msgIcloudGoogleDriveBackupNotConnected;

  /// No description provided for @msgKeepYourRecoveryCredentialsInASecureOffline.
  ///
  /// In en, this message translates to:
  /// **'Keep your recovery credentials in a secure offline location.'**
  String get msgKeepYourRecoveryCredentialsInASecureOffline;

  /// No description provided for @msgOnchainAssets.
  ///
  /// In en, this message translates to:
  /// **'Onchain assets'**
  String get msgOnchainAssets;

  /// No description provided for @msgViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get msgViewAll;

  /// No description provided for @msgAssets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get msgAssets;

  /// No description provided for @msgBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get msgBalance;

  /// No description provided for @msgStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get msgStatus;

  /// No description provided for @msgSynced.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get msgSynced;

  /// {p0}/{p1}
  /// 链已查询
  ///
  /// In en, this message translates to:
  /// **'{p0}/{p1}\n{p1, plural, one{network queried} other{networks queried}}'**
  String msgNetworksQueried(String p0, int p1);

  /// No description provided for @msgQueriedBalanceDistribution.
  ///
  /// In en, this message translates to:
  /// **'Queried balance distribution'**
  String get msgQueriedBalanceDistribution;

  /// No description provided for @msgStablecoinOverview.
  ///
  /// In en, this message translates to:
  /// **'Stablecoin overview'**
  String get msgStablecoinOverview;

  /// No description provided for @msgRefreshStablecoins.
  ///
  /// In en, this message translates to:
  /// **'Refresh stablecoins'**
  String get msgRefreshStablecoins;

  /// 当前账户 · {p0}
  ///
  /// In en, this message translates to:
  /// **'Current account · {p0}'**
  String msgCurrentAccount(String p0);

  /// 已展示 {p0} 总量
  ///
  /// In en, this message translates to:
  /// **'Tracked {p0} total'**
  String msgTrackedTotal(String p0);

  /// No description provided for @msgQueriedSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Queried subtotal'**
  String get msgQueriedSubtotal;

  /// {p0}/{p1} 条链已查询{p2}
  ///
  /// In en, this message translates to:
  /// **'{p0}/{p1} {p1, plural, one{network queried} other{networks queried}}{p2}'**
  String msgNetworksQueriedMore(String p0, int p1, String p2);

  /// No description provided for @msgFullySynced.
  ///
  /// In en, this message translates to:
  /// **' · Fully synced'**
  String get msgFullySynced;

  /// No description provided for @msgCoverageIsIncomplete.
  ///
  /// In en, this message translates to:
  /// **' · Coverage is incomplete'**
  String get msgCoverageIsIncomplete;

  /// No description provided for @msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities.
  ///
  /// In en, this message translates to:
  /// **'Includes tracked USDT0 / Binance-Peg versions. Token quantities only, not a USD valuation.'**
  String get msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities;

  /// No description provided for @msgOnlyAddedCircleUsdcContractsAreCountedBy.
  ///
  /// In en, this message translates to:
  /// **'Only added Circle USDC contracts are counted, by token quantity.'**
  String get msgOnlyAddedCircleUsdcContractsAreCountedBy;

  /// No description provided for @msgViewNetworkDistribution.
  ///
  /// In en, this message translates to:
  /// **'View network distribution →'**
  String get msgViewNetworkDistribution;

  /// 各链 {p0}
  ///
  /// In en, this message translates to:
  /// **'{p0} by network'**
  String msgByNetwork(String p0);

  /// No description provided for @msgEnableQueryNetworks.
  ///
  /// In en, this message translates to:
  /// **'Enable query networks'**
  String get msgEnableQueryNetworks;

  /// 尚未添加 {p0}
  ///
  /// In en, this message translates to:
  /// **'No {p0} added yet'**
  String msgNoAddedYet(String p0);

  /// No description provided for @msgAddTokensToViewTheirNetworkDistribution.
  ///
  /// In en, this message translates to:
  /// **'Add tokens to view their network distribution.'**
  String get msgAddTokensToViewTheirNetworkDistribution;

  /// No description provided for @msgEnableStablecoinNetworks.
  ///
  /// In en, this message translates to:
  /// **'Enable stablecoin networks'**
  String get msgEnableStablecoinNetworks;

  /// 占已查询余额 {p0}%
  ///
  /// In en, this message translates to:
  /// **'{p0}% of queried balances'**
  String msgOfQueriedBalances(String p0);

  /// No description provided for @msgZeroBalance.
  ///
  /// In en, this message translates to:
  /// **'Zero balance'**
  String get msgZeroBalance;

  /// No description provided for @msgAwaitingOnchainBalance.
  ///
  /// In en, this message translates to:
  /// **'Awaiting onchain balance'**
  String get msgAwaitingOnchainBalance;

  /// No description provided for @msgCopyReceiveAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy receive address'**
  String get msgCopyReceiveAddress;

  /// No description provided for @msgQuerying.
  ///
  /// In en, this message translates to:
  /// **'Querying…'**
  String get msgQuerying;

  /// No description provided for @msgCurrentAccountReceiveAddress.
  ///
  /// In en, this message translates to:
  /// **'Current account receive address'**
  String get msgCurrentAccountReceiveAddress;

  /// 合约地址 · {p0} 位精度
  ///
  /// In en, this message translates to:
  /// **'Token contract · {p0, plural, one{{p0} decimal} other{{p0} decimals}}'**
  String msgTokenContractDecimals(int p0);

  /// No description provided for @msgCheckTheNetworkAndContractBeforeReceivingToken.
  ///
  /// In en, this message translates to:
  /// **'Check the network and contract before receiving. Token transfers are not available here yet.'**
  String get msgCheckTheNetworkAndContractBeforeReceivingToken;

  /// No description provided for @msgCannotReadThisTokenCheckTheNetworkContract.
  ///
  /// In en, this message translates to:
  /// **'Cannot read this token. Check the network, contract and endpoint.'**
  String get msgCannotReadThisTokenCheckTheNetworkContract;

  /// No description provided for @msgAddingATokenChangesItsDisplayOnlyIt.
  ///
  /// In en, this message translates to:
  /// **'Adding a token changes its display only. It does not approve or send a transaction.'**
  String get msgAddingATokenChangesItsDisplayOnlyIt;

  /// No description provided for @msgCommonStablecoins.
  ///
  /// In en, this message translates to:
  /// **'Common stablecoins'**
  String get msgCommonStablecoins;

  /// No description provided for @msgAddedCustomTokens.
  ///
  /// In en, this message translates to:
  /// **'Added custom tokens'**
  String get msgAddedCustomTokens;

  /// No description provided for @msgHideToken.
  ///
  /// In en, this message translates to:
  /// **'Hide token'**
  String get msgHideToken;

  /// No description provided for @msgAddCustomToken.
  ///
  /// In en, this message translates to:
  /// **'Add custom token'**
  String get msgAddCustomToken;

  /// No description provided for @msgTokenContractAddress.
  ///
  /// In en, this message translates to:
  /// **'Token contract address'**
  String get msgTokenContractAddress;

  /// No description provided for @msgProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get msgProcessing;

  /// No description provided for @msgReadTokenInfo.
  ///
  /// In en, this message translates to:
  /// **'Read token info'**
  String get msgReadTokenInfo;

  /// {p0} · {p1} 位精度
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1, plural, one{{p1} decimal} other{{p1} decimals}}'**
  String msgDecimals(String p0, int p1);

  /// No description provided for @msgCustomTokensWithMatchingTickersAreNotAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Custom tokens with matching tickers are not automatically included in USDT / USDC totals.'**
  String get msgCustomTokensWithMatchingTickersAreNotAutomatically;

  /// 已匹配预置合约，将计入 {p0} 汇总。
  ///
  /// In en, this message translates to:
  /// **'Matches a preset contract. It will be included in the {p0} total.'**
  String msgMatchesAPresetContractItWillBeIncluded(String p0);

  /// No description provided for @msgAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get msgAdded;

  /// No description provided for @msgConfirmAddition.
  ///
  /// In en, this message translates to:
  /// **'Confirm addition'**
  String get msgConfirmAddition;

  /// No description provided for @msgSwitchTheme.
  ///
  /// In en, this message translates to:
  /// **'Switch theme'**
  String get msgSwitchTheme;

  /// No description provided for @msgClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get msgClose;

  /// No description provided for @msgSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Select wallet'**
  String get msgSelectWallet;

  /// No description provided for @msgRecoveryPhraseWallet.
  ///
  /// In en, this message translates to:
  /// **'Recovery-phrase wallet'**
  String get msgRecoveryPhraseWallet;

  /// No description provided for @msgSwap.
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get msgSwap;

  /// No description provided for @msgMakeSureTheReceivingNetworkMatchesTheNetwork.
  ///
  /// In en, this message translates to:
  /// **'Make sure the receiving network matches the network you selected.'**
  String get msgMakeSureTheReceivingNetworkMatchesTheNetwork;

  /// No description provided for @msgEnableMultipleNetworksToViewBalancesOnlySelected.
  ///
  /// In en, this message translates to:
  /// **'Enable multiple networks to view balances. Only selected networks connect to RPC after you save.'**
  String get msgEnableMultipleNetworksToViewBalancesOnlySelected;

  /// No description provided for @msgDisconnectAllNetworks.
  ///
  /// In en, this message translates to:
  /// **'Disconnect all networks'**
  String get msgDisconnectAllNetworks;

  /// No description provided for @msgSaveNetworkSelection.
  ///
  /// In en, this message translates to:
  /// **'Save network selection'**
  String get msgSaveNetworkSelection;

  /// No description provided for @msgTapANetworkNameToUseItFor.
  ///
  /// In en, this message translates to:
  /// **'Tap a network name to use it for transactions. Checkboxes enable additional networks for balance queries.'**
  String get msgTapANetworkNameToUseItFor;

  /// No description provided for @msgUseForTransactions.
  ///
  /// In en, this message translates to:
  /// **'Use for transactions'**
  String get msgUseForTransactions;

  /// No description provided for @msgRecoveryPhraseVerificationFailedCheckWordsAnd.
  ///
  /// In en, this message translates to:
  /// **'Recovery phrase verification failed. Check words 2, 6 and 10.'**
  String get msgRecoveryPhraseVerificationFailedCheckWordsAnd;

  /// No description provided for @msgVerifyRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Verify recovery phrase'**
  String get msgVerifyRecoveryPhrase;

  /// No description provided for @msgWriteDownRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Write down recovery phrase'**
  String get msgWriteDownRecoveryPhrase;

  /// No description provided for @msgVerifyAndOpenWallet.
  ///
  /// In en, this message translates to:
  /// **'Verify and open wallet'**
  String get msgVerifyAndOpenWallet;

  /// No description provided for @msgIWroteItDownVerify.
  ///
  /// In en, this message translates to:
  /// **'I wrote it down — verify'**
  String get msgIWroteItDownVerify;

  /// No description provided for @msgWrittenVerify.
  ///
  /// In en, this message translates to:
  /// **'Written ✓     →     ② Verify'**
  String get msgWrittenVerify;

  /// No description provided for @msgWriteDownVerify.
  ///
  /// In en, this message translates to:
  /// **'① Write down     →     ② Verify'**
  String get msgWriteDownVerify;

  /// No description provided for @msgEnterTheRequestedWordsToFinishCreatingYour.
  ///
  /// In en, this message translates to:
  /// **'Enter the requested words to finish creating your wallet.'**
  String get msgEnterTheRequestedWordsToFinishCreatingYour;

  /// No description provided for @msgWriteDownTheseWordsInOrderAndKeep.
  ///
  /// In en, this message translates to:
  /// **'Write down these words in order and keep them in a secure offline location.'**
  String get msgWriteDownTheseWordsInOrderAndKeep;

  /// 第 {p0} 个单词
  ///
  /// In en, this message translates to:
  /// **'Word {p0}'**
  String msgWord(String p0);

  /// No description provided for @msgDoNotScreenshotCopyOrSendYourRecovery.
  ///
  /// In en, this message translates to:
  /// **'Do not screenshot, copy or send your recovery phrase. Verification happens on this device.'**
  String get msgDoNotScreenshotCopyOrSendYourRecovery;

  /// No description provided for @msgImportWallet.
  ///
  /// In en, this message translates to:
  /// **'Import wallet'**
  String get msgImportWallet;

  /// No description provided for @msgEnterYourExistingRecoveryPhraseSeparatingWordsWith.
  ///
  /// In en, this message translates to:
  /// **'Enter your existing recovery phrase, separating words with spaces.'**
  String get msgEnterYourExistingRecoveryPhraseSeparatingWordsWith;

  /// No description provided for @msgImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get msgImport;

  /// No description provided for @msgEnterYourOrWordRecoveryPhrase.
  ///
  /// In en, this message translates to:
  /// **'Enter your 12- or 24-word recovery phrase'**
  String get msgEnterYourOrWordRecoveryPhrase;

  /// No description provided for @msgChooseANetworkToViewAfterImporting.
  ///
  /// In en, this message translates to:
  /// **'Choose a network to view after importing.'**
  String get msgChooseANetworkToViewAfterImporting;

  /// No description provided for @msgPrivateKeyImportFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Private-key import failed. Please try again.'**
  String get msgPrivateKeyImportFailedPleaseTryAgain;

  /// No description provided for @msgRestoreAnAccountWithAnEvmTronHexadecimal.
  ///
  /// In en, this message translates to:
  /// **'Restore an account with an EVM / TRON hexadecimal private key. No recovery phrase is required.'**
  String get msgRestoreAnAccountWithAnEvmTronHexadecimal;

  /// No description provided for @msgImporting.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get msgImporting;

  /// No description provided for @msgImportAndOpenWallet.
  ///
  /// In en, this message translates to:
  /// **'Import and open wallet'**
  String get msgImportAndOpenWallet;

  /// No description provided for @msgSelectANetwork.
  ///
  /// In en, this message translates to:
  /// **'Select a network'**
  String get msgSelectANetwork;

  /// No description provided for @msgPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Private key'**
  String get msgPrivateKey;

  /// No description provided for @msgHexadecimalCharactersOptionallyPrefixedWithX.
  ///
  /// In en, this message translates to:
  /// **'64 hexadecimal characters, optionally prefixed with 0x'**
  String get msgHexadecimalCharactersOptionallyPrefixedWithX;

  /// No description provided for @msgShowPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Show private key'**
  String get msgShowPrivateKey;

  /// No description provided for @msgHidePrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Hide private key'**
  String get msgHidePrivateKey;

  /// No description provided for @msgPrivateKeysStayInSecureDeviceStorageAfter.
  ///
  /// In en, this message translates to:
  /// **'Private keys stay in secure device storage. After import, the selected network is queried for balances. Private keys are never sent to RPC.'**
  String get msgPrivateKeysStayInSecureDeviceStorageAfter;

  /// No description provided for @msgImportResults.
  ///
  /// In en, this message translates to:
  /// **'Import results'**
  String get msgImportResults;

  /// No description provided for @msgDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get msgDone;

  /// 成功 {p0} 条 · 跳过或失败 {p1} 条
  ///
  /// In en, this message translates to:
  /// **'{p0} imported · {p1} skipped or failed'**
  String msgImportedSkippedOrFailed(String p0, String p1);

  /// 第 {p0} 条：{p1}
  ///
  /// In en, this message translates to:
  /// **'Row {p0}: {p1}'**
  String msgRow(String p0, String p1);

  /// No description provided for @msgAmountMustBeGreaterThanZero.
  ///
  /// In en, this message translates to:
  /// **'Amount must be greater than zero.'**
  String get msgAmountMustBeGreaterThanZero;

  /// No description provided for @msgAmountExceedsTheAvailableBalance.
  ///
  /// In en, this message translates to:
  /// **'Amount exceeds the available balance.'**
  String get msgAmountExceedsTheAvailableBalance;

  /// 发送 {p0}
  ///
  /// In en, this message translates to:
  /// **'Send {p0}'**
  String msgSendMore(String p0);

  /// {p0} · {p1} · 在本机完成签名
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1} · Signed on this device'**
  String msgSignedOnThisDevice(String p0, String p1);

  /// No description provided for @msgCheckTheTransactionStatusFirst.
  ///
  /// In en, this message translates to:
  /// **'Check the transaction status first'**
  String get msgCheckTheTransactionStatusFirst;

  /// No description provided for @msgSignAndBroadcast.
  ///
  /// In en, this message translates to:
  /// **'Sign and broadcast'**
  String get msgSignAndBroadcast;

  /// No description provided for @msgRecipientAddress.
  ///
  /// In en, this message translates to:
  /// **'Recipient address'**
  String get msgRecipientAddress;

  /// 金额（{p0}）
  ///
  /// In en, this message translates to:
  /// **'Amount ({p0})'**
  String msgAmount(String p0);

  /// 可用余额：{p0} {p1} · {p2}
  ///
  /// In en, this message translates to:
  /// **'Available: {p0} {p1} · {p2}'**
  String msgAvailable(String p0, String p1, String p2);

  /// No description provided for @msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay.
  ///
  /// In en, this message translates to:
  /// **'Insufficient bandwidth consumes TRX. An unactivated recipient may incur extra fees.'**
  String get msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay;

  /// No description provided for @msgGasFeesAreChargedSeparately.
  ///
  /// In en, this message translates to:
  /// **'Gas fees are charged separately'**
  String get msgGasFeesAreChargedSeparately;

  /// 交易哈希：{p0}
  ///
  /// In en, this message translates to:
  /// **'Transaction hash: {p0}'**
  String msgTransactionHash(String p0);

  /// No description provided for @msgSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get msgSettings;

  /// No description provided for @msgYourKeysStayWithYouTransactionsAreSigned.
  ///
  /// In en, this message translates to:
  /// **'Your keys stay with you\nTransactions are signed on this device'**
  String get msgYourKeysStayWithYouTransactionsAreSigned;

  /// No description provided for @msgHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get msgHome;

  /// No description provided for @msgChooseNetwork.
  ///
  /// In en, this message translates to:
  /// **'Choose network'**
  String get msgChooseNetwork;

  /// No description provided for @msgChainIdMustBeAValidPositiveInteger.
  ///
  /// In en, this message translates to:
  /// **'Chain ID must be a valid positive integer.'**
  String get msgChainIdMustBeAValidPositiveInteger;

  /// No description provided for @msgThisChainIdAlreadyExistsEditItsRpc.
  ///
  /// In en, this message translates to:
  /// **'This Chain ID already exists. Edit its RPC settings instead.'**
  String get msgThisChainIdAlreadyExistsEditItsRpc;

  /// No description provided for @msgConfigureAtLeastOneRpcUrl.
  ///
  /// In en, this message translates to:
  /// **'Configure at least one RPC URL.'**
  String get msgConfigureAtLeastOneRpcUrl;

  /// No description provided for @msgTronHttpApiIsAvailableTheMainnetGenesis.
  ///
  /// In en, this message translates to:
  /// **'TRON HTTP API is available. The mainnet genesis block was verified.'**
  String get msgTronHttpApiIsAvailableTheMainnetGenesis;

  /// No description provided for @msgRpcIsAvailableAndItsChainIdMatches.
  ///
  /// In en, this message translates to:
  /// **'RPC is available and its Chain ID matches the network.'**
  String get msgRpcIsAvailableAndItsChainIdMatches;

  /// No description provided for @msgConnectionCheckFailedCheckTheRpcUrlNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection check failed. Check the RPC URL, network or credentials.'**
  String get msgConnectionCheckFailedCheckTheRpcUrlNetwork;

  /// No description provided for @msgCouldNotSaveNetworkSettingsPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save network settings. Please try again.'**
  String get msgCouldNotSaveNetworkSettingsPleaseTryAgain;

  /// No description provided for @msgAddCustomEvmNetwork.
  ///
  /// In en, this message translates to:
  /// **'Add custom EVM network'**
  String get msgAddCustomEvmNetwork;

  /// No description provided for @msgEditNetworkAndRpc.
  ///
  /// In en, this message translates to:
  /// **'Edit network and RPC'**
  String get msgEditNetworkAndRpc;

  /// No description provided for @msgEnterOneRpcUrlPerLineInPriority.
  ///
  /// In en, this message translates to:
  /// **'Enter one RPC URL per line in priority order. Failed endpoints are skipped and working ones are preferred.'**
  String get msgEnterOneRpcUrlPerLineInPriority;

  /// No description provided for @msgSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get msgSaving;

  /// No description provided for @msgSaveNetworkSettings.
  ///
  /// In en, this message translates to:
  /// **'Save network settings'**
  String get msgSaveNetworkSettings;

  /// No description provided for @msgNetworkName.
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get msgNetworkName;

  /// No description provided for @msgForExampleBase.
  ///
  /// In en, this message translates to:
  /// **'For example: Base'**
  String get msgForExampleBase;

  /// No description provided for @msgForExample.
  ///
  /// In en, this message translates to:
  /// **'For example: 8453'**
  String get msgForExample;

  /// No description provided for @msgNativeCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Native currency symbol'**
  String get msgNativeCurrencySymbol;

  /// No description provided for @msgForExampleEth.
  ///
  /// In en, this message translates to:
  /// **'For example: ETH'**
  String get msgForExampleEth;

  /// No description provided for @msgHttpsPrimaryEndpointHttpsBackupEndpoint.
  ///
  /// In en, this message translates to:
  /// **'https://primary-endpoint\nhttps://backup-endpoint'**
  String get msgHttpsPrimaryEndpointHttpsBackupEndpoint;

  /// No description provided for @msgOneUrlPerLineOrderSetsPriorityDuplicates.
  ///
  /// In en, this message translates to:
  /// **'One URL per line. Order sets priority. Duplicates are removed.'**
  String get msgOneUrlPerLineOrderSetsPriorityDuplicates;

  /// No description provided for @msgRestoreBuiltInFreeEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Restore built-in free endpoints'**
  String get msgRestoreBuiltInFreeEndpoints;

  /// No description provided for @msgBlockExplorerUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Block explorer URL (optional)'**
  String get msgBlockExplorerUrlOptional;

  /// No description provided for @msgChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get msgChecking;

  /// No description provided for @msgCheckRpcConnection.
  ///
  /// In en, this message translates to:
  /// **'Check RPC connection'**
  String get msgCheckRpcConnection;

  /// No description provided for @msgOperationFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Operation failed. Please try again.'**
  String get msgOperationFailedPleaseTryAgain;

  /// No description provided for @msgRenameAccount.
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get msgRenameAccount;

  /// No description provided for @msgRenameWallet.
  ///
  /// In en, this message translates to:
  /// **'Rename wallet'**
  String get msgRenameWallet;

  /// {p0} · {p1} 个账户
  ///
  /// In en, this message translates to:
  /// **'{p0} · {p1, plural, one{{p1} account} other{{p1} accounts}}'**
  String walletAccountCount(String p0, int p1);

  /// No description provided for @msgPrivateKeyWallet.
  ///
  /// In en, this message translates to:
  /// **'Private-key wallet'**
  String get msgPrivateKeyWallet;

  /// No description provided for @msgCopyAccountAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy account address'**
  String get msgCopyAccountAddress;

  /// No description provided for @msgAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get msgAddAccount;

  /// {p0} 个钱包 · {p1} 个账户
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{{p0} wallet} other{{p0} wallets}} · {p1, plural, one{{p1} account} other{{p1} accounts}}'**
  String walletAndAccountCount(int p0, int p1);

  /// No description provided for @msgARecoveryPhraseWalletCanHaveMultipleAccounts.
  ///
  /// In en, this message translates to:
  /// **'A recovery-phrase wallet can have multiple accounts. A different recovery phrase or private key creates a separate wallet.'**
  String get msgARecoveryPhraseWalletCanHaveMultipleAccounts;

  /// No description provided for @msgSearchWalletsAccountsOrAddresses.
  ///
  /// In en, this message translates to:
  /// **'Search wallets, accounts or addresses'**
  String get msgSearchWalletsAccountsOrAddresses;

  /// No description provided for @msgNoMatchingWalletsOrAccounts.
  ///
  /// In en, this message translates to:
  /// **'No matching wallets or accounts'**
  String get msgNoMatchingWalletsOrAccounts;

  /// No description provided for @msgExistingWalletsAreKeptYouCanSwitchAt.
  ///
  /// In en, this message translates to:
  /// **'Existing wallets are kept. You can switch at any time.'**
  String get msgExistingWalletsAreKeptYouCanSwitchAt;

  /// No description provided for @msgRestoreAWalletAndAddDerivedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Restore a wallet and add derived accounts'**
  String get msgRestoreAWalletAndAddDerivedAccounts;

  /// No description provided for @msgImportOneEvmTronAccount.
  ///
  /// In en, this message translates to:
  /// **'Import one EVM / TRON account'**
  String get msgImportOneEvmTronAccount;

  /// No description provided for @msgImportMultipleAccountsFromCsvTsv.
  ///
  /// In en, this message translates to:
  /// **'Import multiple accounts from CSV / TSV'**
  String get msgImportMultipleAccountsFromCsvTsv;

  /// No description provided for @msgNamesMustContainCharacters.
  ///
  /// In en, this message translates to:
  /// **'Names must contain 1–64 characters.'**
  String get msgNamesMustContainCharacters;

  /// No description provided for @msgSaveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get msgSaveName;

  /// No description provided for @msgName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get msgName;

  /// No description provided for @msgCustomToken.
  ///
  /// In en, this message translates to:
  /// **'Custom token'**
  String get msgCustomToken;

  /// No description provided for @msgInvalidTokenInformationReadTheContractAgain.
  ///
  /// In en, this message translates to:
  /// **'Invalid token information. Read the contract again.'**
  String get msgInvalidTokenInformationReadTheContractAgain;

  /// No description provided for @msgTokenSymbolContainsInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'Token symbol contains invalid characters.'**
  String get msgTokenSymbolContainsInvalidCharacters;

  /// No description provided for @msgTheTokenContractReturnedAnInvalidValue.
  ///
  /// In en, this message translates to:
  /// **'The token contract returned an invalid value.'**
  String get msgTheTokenContractReturnedAnInvalidValue;

  /// No description provided for @msgInvalidTokenSymbol.
  ///
  /// In en, this message translates to:
  /// **'Invalid token symbol.'**
  String get msgInvalidTokenSymbol;

  /// No description provided for @msgOnlyTokensWithDecimalsAreSupported.
  ///
  /// In en, this message translates to:
  /// **'Only tokens with 0–36 decimals are supported.'**
  String get msgOnlyTokensWithDecimalsAreSupported;

  /// No description provided for @msgCannotReadTheTokenSymbol.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the token symbol.'**
  String get msgCannotReadTheTokenSymbol;

  /// No description provided for @msgInvalidTokenSymbolEncoding.
  ///
  /// In en, this message translates to:
  /// **'Invalid token symbol encoding.'**
  String get msgInvalidTokenSymbolEncoding;

  /// No description provided for @msgInvalidTokenSymbolLength.
  ///
  /// In en, this message translates to:
  /// **'Invalid token symbol length.'**
  String get msgInvalidTokenSymbolLength;

  /// No description provided for @msgCannotReadTheSavedTokenListExistingRecords.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the saved token list. Existing records were not overwritten.'**
  String get msgCannotReadTheSavedTokenListExistingRecords;

  /// No description provided for @msgThisTokenHasAlreadyBeenAddedOnThis.
  ///
  /// In en, this message translates to:
  /// **'This token has already been added on this network.'**
  String get msgThisTokenHasAlreadyBeenAddedOnThis;

  /// No description provided for @msgNetworkDisabled.
  ///
  /// In en, this message translates to:
  /// **'Network disabled'**
  String get msgNetworkDisabled;

  /// No description provided for @msgQueryingMore.
  ///
  /// In en, this message translates to:
  /// **'Querying'**
  String get msgQueryingMore;

  /// No description provided for @msgQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Query failed'**
  String get msgQueryFailed;

  /// No description provided for @msgTronMainnetIdentifierDoesNotMatchTheProtocol.
  ///
  /// In en, this message translates to:
  /// **'TRON mainnet identifier does not match the protocol.'**
  String get msgTronMainnetIdentifierDoesNotMatchTheProtocol;

  /// No description provided for @msgEnterTheNetworkNameAndNativeCurrencySymbol.
  ///
  /// In en, this message translates to:
  /// **'Enter the network name and native currency symbol.'**
  String get msgEnterTheNetworkNameAndNativeCurrencySymbol;

  /// No description provided for @msgEnterAValidHttpHttpsUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid HTTP / HTTPS URL.'**
  String get msgEnterAValidHttpHttpsUrl;

  /// No description provided for @msgCannotAccessKeychainQuitRebuildAndRunThe.
  ///
  /// In en, this message translates to:
  /// **'Cannot access Keychain (-34018). Quit, rebuild and run the app. Hot reload cannot update native signing permissions.'**
  String get msgCannotAccessKeychainQuitRebuildAndRunThe;

  /// No description provided for @msgCannotAccessSecureDeviceStorageCheckThatKeychain.
  ///
  /// In en, this message translates to:
  /// **'Cannot access secure device storage. Check that Keychain is unlocked and access is allowed.'**
  String get msgCannotAccessSecureDeviceStorageCheckThatKeychain;

  /// No description provided for @msgCannotReadSavedNetworkSettingsCheckTheStored.
  ///
  /// In en, this message translates to:
  /// **'Cannot read saved network settings. Check the stored configuration.'**
  String get msgCannotReadSavedNetworkSettingsCheckTheStored;

  /// No description provided for @msgAccountIndexIsOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Account index is out of range.'**
  String get msgAccountIndexIsOutOfRange;

  /// No description provided for @msgInvalidRecoveryPhraseCheckTheWordsAndTheir.
  ///
  /// In en, this message translates to:
  /// **'Invalid recovery phrase. Check the words and their order.'**
  String get msgInvalidRecoveryPhraseCheckTheWordsAndTheir;

  /// No description provided for @msgCannotDeriveTheEvmPrivateKey.
  ///
  /// In en, this message translates to:
  /// **'Cannot derive the EVM private key.'**
  String get msgCannotDeriveTheEvmPrivateKey;

  /// No description provided for @msgInvalidPrivateKeyEnterHexadecimalCharacters.
  ///
  /// In en, this message translates to:
  /// **'Invalid private key. Enter 64 hexadecimal characters.'**
  String get msgInvalidPrivateKeyEnterHexadecimalCharacters;

  /// No description provided for @msgPrivateKeyValueIsOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Private key value is out of range.'**
  String get msgPrivateKeyValueIsOutOfRange;

  /// No description provided for @msgInvalidPrivateKeyCannotCreateAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Invalid private key. Cannot create an account.'**
  String get msgInvalidPrivateKeyCannotCreateAnAccount;

  /// No description provided for @msgBinance.
  ///
  /// In en, this message translates to:
  /// **'Binance'**
  String get msgBinance;

  /// No description provided for @msgTron.
  ///
  /// In en, this message translates to:
  /// **'TRON'**
  String get msgTron;

  /// RPC 链不匹配：预期 {p0}，实际 {p1}。
  ///
  /// In en, this message translates to:
  /// **'RPC network mismatch: expected {p0}, received {p1}.'**
  String msgRpcNetworkMismatchExpectedReceived(String p0, String p1);

  /// 全部 {p0} 个 RPC 节点均不可用，请稍后重试或编辑节点列表。
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{The RPC endpoint is unavailable.} other{All {p0} RPC endpoints are unavailable.}} Try again later or edit the endpoint list.'**
  String msgAllRpcEndpointsAreUnavailableTryAgainLater(int p0);

  /// No description provided for @msgTheTokenAndNetworkDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'The token and network do not match.'**
  String get msgTheTokenAndNetworkDoNotMatch;

  /// No description provided for @msgTheRpcReturnedADifferentTransactionHash.
  ///
  /// In en, this message translates to:
  /// **'The RPC returned a different transaction hash.'**
  String get msgTheRpcReturnedADifferentTransactionHash;

  /// No description provided for @msgBroadcastStatusIsUncertainCheckTheTransactionHash.
  ///
  /// In en, this message translates to:
  /// **'Broadcast status is uncertain. Check the transaction hash before trying again to avoid duplicate transfers.'**
  String get msgBroadcastStatusIsUncertainCheckTheTransactionHash;

  /// 请输入有效金额，最多支持 {p0} 位小数。
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount with at most {p0, plural, one{{p0} decimal place} other{{p0} decimal places}}.'**
  String msgEnterAValidAmountWithAtMostDecimal(int p0);

  /// No description provided for @msgMainWallet.
  ///
  /// In en, this message translates to:
  /// **'Main wallet'**
  String get msgMainWallet;

  /// No description provided for @msgNoNetworkSelected.
  ///
  /// In en, this message translates to:
  /// **'No network selected'**
  String get msgNoNetworkSelected;

  /// No description provided for @msgChooseANetworkToView.
  ///
  /// In en, this message translates to:
  /// **'Choose a network to view'**
  String get msgChooseANetworkToView;

  /// No description provided for @msgRpcNotConnected.
  ///
  /// In en, this message translates to:
  /// **'RPC not connected'**
  String get msgRpcNotConnected;

  /// No description provided for @msgNativeAsset.
  ///
  /// In en, this message translates to:
  /// **'Native asset'**
  String get msgNativeAsset;

  /// No description provided for @msgConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get msgConnectionFailed;

  /// No description provided for @msgAwaitingSync.
  ///
  /// In en, this message translates to:
  /// **'Awaiting sync'**
  String get msgAwaitingSync;

  /// No description provided for @msgWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get msgWallet;

  /// No description provided for @msgRpcRequestTimedOutCheckTheUrlOr.
  ///
  /// In en, this message translates to:
  /// **'RPC request timed out. Check the URL or try another endpoint.'**
  String get msgRpcRequestTimedOutCheckTheUrlOr;

  /// No description provided for @msgRpcRequestFailedCheckTheNetworkEndpointOr.
  ///
  /// In en, this message translates to:
  /// **'RPC request failed. Check the network, endpoint or credentials.'**
  String get msgRpcRequestFailedCheckTheNetworkEndpointOr;

  /// {p0} 连接失败，可在设置中修改 RPC 或重试。
  ///
  /// In en, this message translates to:
  /// **'Could not connect to {p0}. Edit RPC settings or retry.'**
  String msgCouldNotConnectToEditRpcSettingsOr(String p0);

  /// No description provided for @msgTheAccountHasChangedReopenThisAsset.
  ///
  /// In en, this message translates to:
  /// **'The account has changed. Reopen this asset.'**
  String get msgTheAccountHasChangedReopenThisAsset;

  /// No description provided for @msgCouldNotSaveNetworkSelectionPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not save network selection. Please try again.'**
  String get msgCouldNotSaveNetworkSelectionPleaseTryAgain;

  /// No description provided for @msgPrivateKeyAccountImported.
  ///
  /// In en, this message translates to:
  /// **'Private-key account imported'**
  String get msgPrivateKeyAccountImported;

  /// No description provided for @msgTheAccountWasSavedButCouldNotBe.
  ///
  /// In en, this message translates to:
  /// **'The account was saved but could not be loaded. Reopen the wallet.'**
  String get msgTheAccountWasSavedButCouldNotBe;

  /// No description provided for @msgCannotReadThisFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot read this file.'**
  String get msgCannotReadThisFile;

  /// No description provided for @msgNoImportableRowsTheHeaderMustContainChain.
  ///
  /// In en, this message translates to:
  /// **'No importable rows. The header must contain chain and private key columns.'**
  String get msgNoImportableRowsTheHeaderMustContainChain;

  /// 成功导入 {p0} 条{p1}。
  ///
  /// In en, this message translates to:
  /// **'Imported {p0, plural, one{{p0} row} other{{p0} rows}}{p1}.'**
  String importedRowSummary(int p0, String p1);

  /// ，{p0} 条失败
  ///
  /// In en, this message translates to:
  /// **'; {p0} failed'**
  String msgFailed(String p0);

  /// No description provided for @msgChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get msgChain;

  /// 已选择 {p0}，正在连接 RPC…
  ///
  /// In en, this message translates to:
  /// **'Selected {p0}. Connecting to RPC…'**
  String msgSelectedConnectingToRpc(String p0);

  /// {p0} 网络配置已保存
  ///
  /// In en, this message translates to:
  /// **'{p0} network settings saved'**
  String msgNetworkSettingsSaved(String p0);

  /// No description provided for @msgSwapsAreNotConnectedNoOrderOrSignature.
  ///
  /// In en, this message translates to:
  /// **'Swaps are not connected. No order or signature was created.'**
  String get msgSwapsAreNotConnectedNoOrderOrSignature;

  /// No description provided for @msgUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get msgUnavailable;

  /// No description provided for @msgAddressCopied.
  ///
  /// In en, this message translates to:
  /// **'Address copied'**
  String get msgAddressCopied;

  /// No description provided for @msgSelectANetworkBeforeSending.
  ///
  /// In en, this message translates to:
  /// **'Select a network before sending.'**
  String get msgSelectANetworkBeforeSending;

  /// 交易已广播：{p0}
  ///
  /// In en, this message translates to:
  /// **'Transaction broadcast: {p0}'**
  String msgTransactionBroadcast(String p0);

  /// No description provided for @msgWalletOperationFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Wallet operation failed. Please try again.'**
  String get msgWalletOperationFailedPleaseTryAgain;

  /// No description provided for @msgMostRecentlyBroadcastTransaction.
  ///
  /// In en, this message translates to:
  /// **'Most recently broadcast transaction'**
  String get msgMostRecentlyBroadcastTransaction;

  /// No description provided for @msgEnterAValidTronAddressStartingWithT.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid TRON address starting with T and a correct checksum.'**
  String get msgEnterAValidTronAddressStartingWithT;

  /// No description provided for @msgTheTronEndpointReturnedAnErrorTryAnother.
  ///
  /// In en, this message translates to:
  /// **'The TRON endpoint returned an error. Try another endpoint or retry later.'**
  String get msgTheTronEndpointReturnedAnErrorTryAnother;

  /// No description provided for @msgTronNetworkMismatchAMainnetEndpointIsRequired.
  ///
  /// In en, this message translates to:
  /// **'TRON network mismatch. A mainnet endpoint is required.'**
  String get msgTronNetworkMismatchAMainnetEndpointIsRequired;

  /// 全部 {p0} 个 TRON 节点均不可用，请稍后重试或编辑节点列表。
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{The TRON endpoint is unavailable.} other{All {p0} TRON endpoints are unavailable.}} Try again later or edit the endpoint list.'**
  String msgAllTronEndpointsAreUnavailableTryAgainLater(int p0);

  /// No description provided for @msgTrcQueryFailedCheckTheContractAndEndpoint.
  ///
  /// In en, this message translates to:
  /// **'TRC20 query failed. Check the contract and endpoint.'**
  String get msgTrcQueryFailedCheckTheContractAndEndpoint;

  /// No description provided for @msgTheTronEndpointReturnedADifferentAccountS.
  ///
  /// In en, this message translates to:
  /// **'The TRON endpoint returned a different account’s balance.'**
  String get msgTheTronEndpointReturnedADifferentAccountS;

  /// No description provided for @msgTheTronEndpointReturnedAnInvalidBalance.
  ///
  /// In en, this message translates to:
  /// **'The TRON endpoint returned an invalid balance.'**
  String get msgTheTronEndpointReturnedAnInvalidBalance;

  /// No description provided for @msgTrxAmountIsOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'TRX amount is out of range.'**
  String get msgTrxAmountIsOutOfRange;

  /// No description provided for @msgTronReferenceBlockIsInvalidOrStaleCheck.
  ///
  /// In en, this message translates to:
  /// **'TRON reference block is invalid or stale. Check your clock and endpoint.'**
  String get msgTronReferenceBlockIsInvalidOrStaleCheck;

  /// No description provided for @msgTheTronEndpointDidNotConfirmTheBroadcast.
  ///
  /// In en, this message translates to:
  /// **'The TRON endpoint did not confirm the broadcast.'**
  String get msgTheTronEndpointDidNotConfirmTheBroadcast;

  /// No description provided for @msgCannotReadTheWalletBookCheckSecureStorage.
  ///
  /// In en, this message translates to:
  /// **'Cannot read the wallet book. Check secure storage.'**
  String get msgCannotReadTheWalletBookCheckSecureStorage;

  /// No description provided for @msgAccount.
  ///
  /// In en, this message translates to:
  /// **'Account 1'**
  String get msgAccount;

  /// 私钥账户 {p0}
  ///
  /// In en, this message translates to:
  /// **'Private-key account {p0}'**
  String msgPrivateKeyAccount(String p0);

  /// No description provided for @msgSavedPrivateKeyAccountDataIsCorrupted.
  ///
  /// In en, this message translates to:
  /// **'Saved private-key account data is corrupted.'**
  String get msgSavedPrivateKeyAccountDataIsCorrupted;

  /// 钱包 {p0}
  ///
  /// In en, this message translates to:
  /// **'Wallet {p0}'**
  String msgWalletMore(String p0);

  /// No description provided for @msgUnsupportedNetwork.
  ///
  /// In en, this message translates to:
  /// **'Unsupported network.'**
  String get msgUnsupportedNetwork;

  /// No description provided for @msgDuplicateEntrySkipped.
  ///
  /// In en, this message translates to:
  /// **'Duplicate entry skipped.'**
  String get msgDuplicateEntrySkipped;

  /// No description provided for @msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts.
  ///
  /// In en, this message translates to:
  /// **'Only recovery-phrase wallets can derive additional accounts.'**
  String get msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts;

  /// 账户 {p0}
  ///
  /// In en, this message translates to:
  /// **'Account {p0}'**
  String msgAccountMore(String p0);

  /// No description provided for @msgAccountNotFound.
  ///
  /// In en, this message translates to:
  /// **'Account not found.'**
  String get msgAccountNotFound;

  /// No description provided for @msgWalletNotFound.
  ///
  /// In en, this message translates to:
  /// **'Wallet not found.'**
  String get msgWalletNotFound;

  /// No description provided for @msgUnexpectedErrorPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Please try again.'**
  String get msgUnexpectedErrorPleaseTryAgain;

  /// No description provided for @msgSelfCustodyEvmTron.
  ///
  /// In en, this message translates to:
  /// **'Self-custody · EVM / TRON'**
  String get msgSelfCustodyEvmTron;

  /// No description provided for @portfolioOverview.
  ///
  /// In en, this message translates to:
  /// **'Address overview'**
  String get portfolioOverview;

  /// No description provided for @portfolioByCoin.
  ///
  /// In en, this message translates to:
  /// **'By coin'**
  String get portfolioByCoin;

  /// No description provided for @portfolioReferenceValue.
  ///
  /// In en, this message translates to:
  /// **'Reference value'**
  String get portfolioReferenceValue;

  /// No description provided for @portfolioValuedSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Valued subtotal'**
  String get portfolioValuedSubtotal;

  /// No description provided for @portfolioAllAddresses.
  ///
  /// In en, this message translates to:
  /// **'All linked addresses'**
  String get portfolioAllAddresses;

  /// No description provided for @portfolioAllNetworks.
  ///
  /// In en, this message translates to:
  /// **'All enabled networks'**
  String get portfolioAllNetworks;

  /// No description provided for @portfolioAllAssets.
  ///
  /// In en, this message translates to:
  /// **'All assets'**
  String get portfolioAllAssets;

  /// No description provided for @portfolioSimple.
  ///
  /// In en, this message translates to:
  /// **'Simple'**
  String get portfolioSimple;

  /// No description provided for @portfolioDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get portfolioDetailed;

  /// No description provided for @portfolioDisplaySettings.
  ///
  /// In en, this message translates to:
  /// **'Asset display'**
  String get portfolioDisplaySettings;

  /// No description provided for @portfolioDisplayMode.
  ///
  /// In en, this message translates to:
  /// **'Display mode'**
  String get portfolioDisplayMode;

  /// No description provided for @portfolioInitialCount.
  ///
  /// In en, this message translates to:
  /// **'Initial coin count'**
  String get portfolioInitialCount;

  /// No description provided for @portfolioAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get portfolioAll;

  /// No description provided for @portfolioSort.
  ///
  /// In en, this message translates to:
  /// **'Sort assets'**
  String get portfolioSort;

  /// No description provided for @portfolioSortValue.
  ///
  /// In en, this message translates to:
  /// **'Value: high to low'**
  String get portfolioSortValue;

  /// No description provided for @portfolioStableFirst.
  ///
  /// In en, this message translates to:
  /// **'Stablecoins first'**
  String get portfolioStableFirst;

  /// No description provided for @portfolioSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get portfolioSortName;

  /// No description provided for @portfolioHideZero.
  ///
  /// In en, this message translates to:
  /// **'Hide confirmed zero balances'**
  String get portfolioHideZero;

  /// No description provided for @portfolioShowSpam.
  ///
  /// In en, this message translates to:
  /// **'Show suspected spam from indexers'**
  String get portfolioShowSpam;

  /// No description provided for @portfolioExpand.
  ///
  /// In en, this message translates to:
  /// **'Show all ({p0})'**
  String portfolioExpand(String p0);

  /// No description provided for @portfolioCollapse.
  ///
  /// In en, this message translates to:
  /// **'Show fewer'**
  String get portfolioCollapse;

  /// No description provided for @portfolioSelectCoin.
  ///
  /// In en, this message translates to:
  /// **'Select a coin'**
  String get portfolioSelectCoin;

  /// No description provided for @portfolioSearch.
  ///
  /// In en, this message translates to:
  /// **'Search coins, contracts or networks'**
  String get portfolioSearch;

  /// No description provided for @portfolioChainCount.
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{{p0} chain} other{{p0} chains}}'**
  String portfolioChainCount(int p0);

  /// No description provided for @portfolioCoinCount.
  ///
  /// In en, this message translates to:
  /// **'{p0, plural, one{{p0} coin} other{{p0} coins}}'**
  String portfolioCoinCount(int p0);

  /// No description provided for @portfolioInformation.
  ///
  /// In en, this message translates to:
  /// **'Value and query details'**
  String get portfolioInformation;

  /// No description provided for @portfolioValueExplanation.
  ///
  /// In en, this message translates to:
  /// **'USDT market prices, using 1 USDT ≈ 1 USD. Includes watched and discovered assets on enabled networks only.'**
  String get portfolioValueExplanation;

  /// No description provided for @portfolioVersionExplanation.
  ///
  /// In en, this message translates to:
  /// **'USDT0 and Binance-Peg versions use the USDT reference price. Matching tickers alone never identify an asset.'**
  String get portfolioVersionExplanation;

  /// No description provided for @portfolioCoverage.
  ///
  /// In en, this message translates to:
  /// **'{p0}/{p1} holdings queried · {p2} without a price'**
  String portfolioCoverage(String p0, String p1, String p2);

  /// No description provided for @portfolioPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get portfolioPartial;

  /// No description provided for @portfolioStalePrices.
  ///
  /// In en, this message translates to:
  /// **'Cached prices · update failed'**
  String get portfolioStalePrices;

  /// No description provided for @portfolioNoPrice.
  ///
  /// In en, this message translates to:
  /// **'Price unavailable'**
  String get portfolioNoPrice;

  /// No description provided for @portfolioNoAssets.
  ///
  /// In en, this message translates to:
  /// **'No matching assets'**
  String get portfolioNoAssets;

  /// No description provided for @portfolioShowZero.
  ///
  /// In en, this message translates to:
  /// **'Show zero balances'**
  String get portfolioShowZero;

  /// No description provided for @portfolioRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh balances and prices'**
  String get portfolioRefresh;

  /// No description provided for @portfolioSourceRpc.
  ///
  /// In en, this message translates to:
  /// **'Balance from RPC'**
  String get portfolioSourceRpc;

  /// No description provided for @portfolioSourceIndexer.
  ///
  /// In en, this message translates to:
  /// **'Discovered by indexer'**
  String get portfolioSourceIndexer;

  /// No description provided for @portfolioPriceSource.
  ///
  /// In en, this message translates to:
  /// **'Prices: Binance public USDT markets'**
  String get portfolioPriceSource;

  /// No description provided for @portfolioUpdated.
  ///
  /// In en, this message translates to:
  /// **'Price time: {p0}'**
  String portfolioUpdated(String p0);

  /// No description provided for @portfolioTestnetExcluded.
  ///
  /// In en, this message translates to:
  /// **'Testnet balances are excluded from the value.'**
  String get portfolioTestnetExcluded;

  /// No description provided for @discoveryServices.
  ///
  /// In en, this message translates to:
  /// **'Asset indexers'**
  String get discoveryServices;

  /// No description provided for @discoveryConfigure.
  ///
  /// In en, this message translates to:
  /// **'Configure auto-discovery'**
  String get discoveryConfigure;

  /// No description provided for @discoveryNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Auto-discovery not configured'**
  String get discoveryNotConfigured;

  /// No description provided for @discoveryQuerying.
  ///
  /// In en, this message translates to:
  /// **'Discovering assets…'**
  String get discoveryQuerying;

  /// No description provided for @discoveryPartial.
  ///
  /// In en, this message translates to:
  /// **'Discovery is incomplete'**
  String get discoveryPartial;

  /// No description provided for @discoveryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Auto-discovery unavailable'**
  String get discoveryUnavailable;

  /// No description provided for @discoveryLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Continue discovery'**
  String get discoveryLoadMore;

  /// No description provided for @discoveryConfigureProvider.
  ///
  /// In en, this message translates to:
  /// **'Configure {p0}'**
  String discoveryConfigureProvider(String p0);

  /// No description provided for @discoveryGetKey.
  ///
  /// In en, this message translates to:
  /// **'Get an API key'**
  String get discoveryGetKey;

  /// No description provided for @discoveryDocs.
  ///
  /// In en, this message translates to:
  /// **'Official guide'**
  String get discoveryDocs;

  /// No description provided for @discoveryPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans and quotas'**
  String get discoveryPlans;

  /// No description provided for @discoveryApiKey.
  ///
  /// In en, this message translates to:
  /// **'Service API key'**
  String get discoveryApiKey;

  /// No description provided for @discoveryKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Use your own service key, not a wallet private key'**
  String get discoveryKeyHint;

  /// No description provided for @discoveryKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a service API key.'**
  String get discoveryKeyRequired;

  /// No description provided for @discoveryPrivacy.
  ///
  /// In en, this message translates to:
  /// **'When enabled, this service receives the linked public address on selected networks. Keys stay in this device’s secure storage.'**
  String get discoveryPrivacy;

  /// No description provided for @discoveryAssignments.
  ///
  /// In en, this message translates to:
  /// **'Choose networks (replaces their current indexer)'**
  String get discoveryAssignments;

  /// No description provided for @discoveryChooseNetwork.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one supported enabled network.'**
  String get discoveryChooseNetwork;

  /// No description provided for @discoveryTest.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get discoveryTest;

  /// No description provided for @discoveryConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected. Credentials and response are valid.'**
  String get discoveryConnected;

  /// No description provided for @discoverySaveEnable.
  ///
  /// In en, this message translates to:
  /// **'Save and enable'**
  String get discoverySaveEnable;

  /// No description provided for @discoveryEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get discoveryEnabled;

  /// No description provided for @discoveryDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get discoveryDisabled;

  /// No description provided for @discoveryDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get discoveryDisable;

  /// No description provided for @discoveryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete configuration'**
  String get discoveryDelete;

  /// No description provided for @discoveryEdit.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get discoveryEdit;

  /// No description provided for @discoveryUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Service key rejected. Check the key and plan permissions.'**
  String get discoveryUnauthorized;

  /// No description provided for @discoveryLimited.
  ///
  /// In en, this message translates to:
  /// **'Indexer quota or rate limit reached. Retry later.'**
  String get discoveryLimited;

  /// No description provided for @discoveryResponseInvalid.
  ///
  /// In en, this message translates to:
  /// **'The indexer returned invalid asset data.'**
  String get discoveryResponseInvalid;

  /// No description provided for @discoveryRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to the indexer. Watched assets remain available.'**
  String get discoveryRequestFailed;

  /// No description provided for @discoverySettingsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read indexer settings. Existing records have been kept.'**
  String get discoverySettingsUnreadable;

  /// No description provided for @discoverySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save indexer settings. Please retry.'**
  String get discoverySaveFailed;

  /// No description provided for @discoveryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This indexer does not support the selected network in this app.'**
  String get discoveryUnsupported;

  /// No description provided for @discoveryWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch this token'**
  String get discoveryWatch;

  /// No description provided for @discoveryWatched.
  ///
  /// In en, this message translates to:
  /// **'Token added to watched assets'**
  String get discoveryWatched;

  /// No description provided for @discoveryMoralisGuide.
  ///
  /// In en, this message translates to:
  /// **'Create a Moralis account → copy the Web3 API key → choose Ethereum, Polygon or BNB Chain. View current quotas on the plans page.'**
  String get discoveryMoralisGuide;

  /// No description provided for @discoveryAlchemyGuide.
  ///
  /// In en, this message translates to:
  /// **'Create an Alchemy app → enable Ethereum or Polygon → copy its API key. This app uses the Token API.'**
  String get discoveryAlchemyGuide;

  /// No description provided for @discoveryTronGridGuide.
  ///
  /// In en, this message translates to:
  /// **'Sign in to TronGrid → create an API key → enable TRON Mainnet. This app discovers TRC20 holdings.'**
  String get discoveryTronGridGuide;

  /// No description provided for @discoveryLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser. The link has been copied.'**
  String get discoveryLinkCopied;

  /// No description provided for @discoveryNoEnabledNetworks.
  ///
  /// In en, this message translates to:
  /// **'Enable a supported network before configuring discovery.'**
  String get discoveryNoEnabledNetworks;

  /// No description provided for @portfolioAddressDetails.
  ///
  /// In en, this message translates to:
  /// **'Linked addresses'**
  String get portfolioAddressDetails;

  /// No description provided for @portfolioBalanceStatus.
  ///
  /// In en, this message translates to:
  /// **'Balance status'**
  String get portfolioBalanceStatus;

  /// No description provided for @portfolioSpam.
  ///
  /// In en, this message translates to:
  /// **'Suspected spam'**
  String get portfolioSpam;

  /// No description provided for @portfolioNoCoin.
  ///
  /// In en, this message translates to:
  /// **'No coins in this selection'**
  String get portfolioNoCoin;

  /// No description provided for @discoveryNotConfiguredShort.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get discoveryNotConfiguredShort;

  /// No description provided for @settingsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search settings'**
  String get settingsSearch;

  /// No description provided for @settingsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Language, display mode, RPC…'**
  String get settingsSearchHint;

  /// No description provided for @settingsQuickLinks.
  ///
  /// In en, this message translates to:
  /// **'Quick settings'**
  String get settingsQuickLinks;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'All settings'**
  String get settingsCategories;

  /// No description provided for @settingsWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets and accounts'**
  String get settingsWallets;

  /// No description provided for @settingsWalletsHint.
  ///
  /// In en, this message translates to:
  /// **'Manage, create and import'**
  String get settingsWalletsHint;

  /// No description provided for @settingsAssetsHint.
  ///
  /// In en, this message translates to:
  /// **'Display preferences and watched tokens'**
  String get settingsAssetsHint;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Networks and data'**
  String get settingsData;

  /// No description provided for @settingsDataHint.
  ///
  /// In en, this message translates to:
  /// **'Network RPC and asset indexers'**
  String get settingsDataHint;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security and backup'**
  String get settingsSecurity;

  /// No description provided for @settingsSecurityHint.
  ///
  /// In en, this message translates to:
  /// **'Account security and backup guidance'**
  String get settingsSecurityHint;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsGeneralHint.
  ///
  /// In en, this message translates to:
  /// **'Language and appearance'**
  String get settingsGeneralHint;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsWatchedTokens.
  ///
  /// In en, this message translates to:
  /// **'Watched tokens'**
  String get settingsWatchedTokens;

  /// No description provided for @settingsNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching settings'**
  String get settingsNoResults;

  /// No description provided for @settingsClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get settingsClearSearch;

  /// No description provided for @settingsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get settingsUnavailable;

  /// No description provided for @settingsNetworkDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get settingsNetworkDisabled;

  /// No description provided for @settingsNetworkEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settingsNetworkEnabled;

  /// No description provided for @settingsNetworkState.
  ///
  /// In en, this message translates to:
  /// **'Enable network'**
  String get settingsNetworkState;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'Keep recovery credentials safely offline. Cloud backup is not available yet.'**
  String get settingsBackupHint;

  /// No description provided for @settingsMatchedOption.
  ///
  /// In en, this message translates to:
  /// **'Setting located'**
  String get settingsMatchedOption;

  /// No description provided for @omniImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview OmniVault import'**
  String get omniImportTitle;

  /// No description provided for @omniImportResult.
  ///
  /// In en, this message translates to:
  /// **'OmniVault import results'**
  String get omniImportResult;

  /// No description provided for @omniReading.
  ///
  /// In en, this message translates to:
  /// **'Checking {count} rows…'**
  String omniReading(int count);

  /// No description provided for @omniConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm import'**
  String get omniConfirm;

  /// No description provided for @omniNewWallet.
  ///
  /// In en, this message translates to:
  /// **'New wallets'**
  String get omniNewWallet;

  /// No description provided for @omniAliasesAdded.
  ///
  /// In en, this message translates to:
  /// **'New aliases'**
  String get omniAliasesAdded;

  /// No description provided for @omniDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Duplicates'**
  String get omniDuplicates;

  /// No description provided for @omniSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get omniSkipped;

  /// No description provided for @omniFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get omniFailed;

  /// No description provided for @omniAllRows.
  ///
  /// In en, this message translates to:
  /// **'All rows'**
  String get omniAllRows;

  /// No description provided for @omniNoRows.
  ///
  /// In en, this message translates to:
  /// **'No rows in this category'**
  String get omniNoRows;

  /// No description provided for @omniLine.
  ///
  /// In en, this message translates to:
  /// **'Line {line}'**
  String omniLine(int line);

  /// No description provided for @omniPreviousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get omniPreviousPage;

  /// No description provided for @omniNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get omniNextPage;

  /// No description provided for @omniWalletAliases.
  ///
  /// In en, this message translates to:
  /// **'Wallet aliases'**
  String get omniWalletAliases;

  /// No description provided for @omniHeader.
  ///
  /// In en, this message translates to:
  /// **'The OmniVault CSV must include all seven required columns without duplicate headers.'**
  String get omniHeader;

  /// No description provided for @omniInvalidEncoding.
  ///
  /// In en, this message translates to:
  /// **'The file must use UTF-8 encoding.'**
  String get omniInvalidEncoding;

  /// No description provided for @omniMalformedCsv.
  ///
  /// In en, this message translates to:
  /// **'Invalid CSV quoting at line {line}.'**
  String omniMalformedCsv(int line);

  /// No description provided for @omniColumnCount.
  ///
  /// In en, this message translates to:
  /// **'The number of columns does not match the header.'**
  String get omniColumnCount;

  /// No description provided for @omniInvalidStatus.
  ///
  /// In en, this message translates to:
  /// **'Unrecognized private-key export status.'**
  String get omniInvalidStatus;

  /// No description provided for @omniInvalidIdentity.
  ///
  /// In en, this message translates to:
  /// **'Platform and UID must each contain 1–256 characters without control characters.'**
  String get omniInvalidIdentity;

  /// No description provided for @omniInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'The source address is invalid for this chain.'**
  String get omniInvalidAddress;

  /// No description provided for @omniAddressMismatch.
  ///
  /// In en, this message translates to:
  /// **'The private key derives a different address.'**
  String get omniAddressMismatch;

  /// No description provided for @omniWalletChanged.
  ///
  /// In en, this message translates to:
  /// **'The wallet book changed. Reopen the file and check it again.'**
  String get omniWalletChanged;

  /// No description provided for @omniStorageError.
  ///
  /// In en, this message translates to:
  /// **'The encrypted wallet database could not complete this operation.'**
  String get omniStorageError;

  /// No description provided for @omniRecordTooLarge.
  ///
  /// In en, this message translates to:
  /// **'A CSV record exceeds the supported size.'**
  String get omniRecordTooLarge;

  /// No description provided for @omniSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search wallet, platform, UID, or address prefix'**
  String get omniSearchHint;

  /// No description provided for @omniFileHint.
  ///
  /// In en, this message translates to:
  /// **'OmniVault CSV or a chain and private key CSV/TSV'**
  String get omniFileHint;

  /// No description provided for @transferChooseAsset.
  ///
  /// In en, this message translates to:
  /// **'Choose an asset to send'**
  String get transferChooseAsset;

  /// No description provided for @transferReview.
  ///
  /// In en, this message translates to:
  /// **'Review transfer'**
  String get transferReview;

  /// No description provided for @transferEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit transfer'**
  String get transferEdit;

  /// No description provided for @transferSender.
  ///
  /// In en, this message translates to:
  /// **'From address'**
  String get transferSender;

  /// No description provided for @transferContract.
  ///
  /// In en, this message translates to:
  /// **'Token contract'**
  String get transferContract;

  /// No description provided for @transferFee.
  ///
  /// In en, this message translates to:
  /// **'Estimated network fee'**
  String get transferFee;

  /// No description provided for @transferTronFeeNote.
  ///
  /// In en, this message translates to:
  /// **'The TRX cost may change with available Energy and Bandwidth.'**
  String get transferTronFeeNote;

  /// No description provided for @transferViewTransaction.
  ///
  /// In en, this message translates to:
  /// **'View transaction'**
  String get transferViewTransaction;

  /// No description provided for @transferInvalidRecipient.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid recipient address for this network.'**
  String get transferInvalidRecipient;

  /// No description provided for @transferAmountTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The amount is too large for this network.'**
  String get transferAmountTooLarge;

  /// No description provided for @transferSimulationFailed.
  ///
  /// In en, this message translates to:
  /// **'The network rejected the transfer simulation. Check the amount and recipient.'**
  String get transferSimulationFailed;

  /// No description provided for @transferTokenDecimalsChanged.
  ///
  /// In en, this message translates to:
  /// **'The token contract reports a different precision. Refresh its details before sending.'**
  String get transferTokenDecimalsChanged;

  /// No description provided for @transferFeeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The network fee could not be estimated. Try again or check the RPC endpoint.'**
  String get transferFeeUnavailable;

  /// No description provided for @transferInsufficientFee.
  ///
  /// In en, this message translates to:
  /// **'The native balance is too low to cover this transfer and its network fee.'**
  String get transferInsufficientFee;

  /// No description provided for @transferReviewExpired.
  ///
  /// In en, this message translates to:
  /// **'Review the transfer again before signing.'**
  String get transferReviewExpired;

  /// No description provided for @walletBalancesTitle.
  ///
  /// In en, this message translates to:
  /// **'All wallet balances'**
  String get walletBalancesTitle;

  /// No description provided for @walletBalancesStarted.
  ///
  /// In en, this message translates to:
  /// **'Scan started {time}'**
  String walletBalancesStarted(String time);

  /// No description provided for @walletBalancesChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get walletBalancesChecking;

  /// No description provided for @walletBalancesPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get walletBalancesPaused;

  /// No description provided for @walletBalancesFinished.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get walletBalancesFinished;

  /// No description provided for @walletBalancesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Wallet list could not be loaded'**
  String get walletBalancesLoadFailed;

  /// No description provided for @walletBalancesProgress.
  ///
  /// In en, this message translates to:
  /// **'{state} · {checked} / {total} accounts'**
  String walletBalancesProgress(String state, int checked, int total);

  /// No description provided for @walletBalancesScope.
  ///
  /// In en, this message translates to:
  /// **'Ranked by estimated USD value. Chain-specific wallets use their source chain. Other wallets use enabled networks. Checks native coins, built-in and watched tokens, and configured token discovery. Testnet assets are excluded from USD totals.'**
  String get walletBalancesScope;

  /// No description provided for @walletBalancesIncompleteCount.
  ///
  /// In en, this message translates to:
  /// **'{count} accounts with incomplete results'**
  String walletBalancesIncompleteCount(int count);

  /// No description provided for @walletBalancesPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get walletBalancesPause;

  /// No description provided for @walletBalancesResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get walletBalancesResume;

  /// No description provided for @walletBalancesBackground.
  ///
  /// In en, this message translates to:
  /// **'Continue in background'**
  String get walletBalancesBackground;

  /// No description provided for @walletBalancesNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'No networks to check'**
  String get walletBalancesNoNetwork;

  /// No description provided for @walletBalancesQueryIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Balance or token discovery incomplete'**
  String get walletBalancesQueryIncomplete;

  /// No description provided for @walletBalancesTokenListError.
  ///
  /// In en, this message translates to:
  /// **'Saved token list unavailable'**
  String get walletBalancesTokenListError;

  /// No description provided for @walletBalancesMissingPrices.
  ///
  /// In en, this message translates to:
  /// **'Prices missing'**
  String get walletBalancesMissingPrices;

  /// No description provided for @walletBalancesNoHoldings.
  ///
  /// In en, this message translates to:
  /// **'No balances in the checked assets.'**
  String get walletBalancesNoHoldings;

  /// No description provided for @walletBalancesWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the first result…'**
  String get walletBalancesWaiting;

  /// No description provided for @walletBalancesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No wallets to check.'**
  String get walletBalancesEmpty;

  /// No description provided for @omniPoolTitle.
  ///
  /// In en, this message translates to:
  /// **'OmniVault address pools'**
  String get omniPoolTitle;

  /// No description provided for @omniPoolSetupHelp.
  ///
  /// In en, this message translates to:
  /// **'Register this device in OmniVault under Address pools → Inventory and devices, then grant access to its platforms. Check the server fingerprint through a separate trusted channel.'**
  String get omniPoolSetupHelp;

  /// No description provided for @omniPoolDevice.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get omniPoolDevice;

  /// No description provided for @omniPoolFingerprint.
  ///
  /// In en, this message translates to:
  /// **'SHA-256 fingerprint'**
  String get omniPoolFingerprint;

  /// No description provided for @omniPoolCopyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy device public key'**
  String get omniPoolCopyPublicKey;

  /// No description provided for @omniPoolServerKey.
  ///
  /// In en, this message translates to:
  /// **'Server public key (PEM)'**
  String get omniPoolServerKey;

  /// No description provided for @omniPoolConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get omniPoolConnect;

  /// No description provided for @omniPoolConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection settings'**
  String get omniPoolConnection;

  /// No description provided for @omniPoolNoPlatforms.
  ///
  /// In en, this message translates to:
  /// **'This device has no platform grants.'**
  String get omniPoolNoPlatforms;

  /// No description provided for @omniPoolRefreshPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Refresh platforms'**
  String get omniPoolRefreshPlatforms;

  /// No description provided for @omniPoolCreate.
  ///
  /// In en, this message translates to:
  /// **'Create platform recovery phrase'**
  String get omniPoolCreate;

  /// No description provided for @omniPoolWriteWords.
  ///
  /// In en, this message translates to:
  /// **'Keep these words offline and enter words 3 and 18 to continue.'**
  String get omniPoolWriteWords;

  /// No description provided for @omniPoolWord.
  ///
  /// In en, this message translates to:
  /// **'Word {index}'**
  String omniPoolWord(int index);

  /// No description provided for @omniPoolCount.
  ///
  /// In en, this message translates to:
  /// **'Count (1–1,000)'**
  String get omniPoolCount;

  /// No description provided for @omniPoolGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate addresses'**
  String get omniPoolGenerate;

  /// No description provided for @omniPoolUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get omniPoolUpload;

  /// No description provided for @omniPoolUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get omniPoolUploaded;

  /// No description provided for @omniPoolReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to upload'**
  String get omniPoolReady;

  /// No description provided for @omniPoolBatches.
  ///
  /// In en, this message translates to:
  /// **'Local batches'**
  String get omniPoolBatches;

  /// No description provided for @omniPoolNeedsBackup.
  ///
  /// In en, this message translates to:
  /// **'Verified backup required'**
  String get omniPoolNeedsBackup;

  /// No description provided for @omniPoolBackup.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted backup'**
  String get omniPoolBackup;

  /// No description provided for @omniPoolRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore encrypted backup'**
  String get omniPoolRestore;

  /// No description provided for @omniPoolPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase (12+ characters)'**
  String get omniPoolPassphrase;

  /// No description provided for @omniPoolConfirmPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Confirm backup passphrase'**
  String get omniPoolConfirmPassphrase;

  /// No description provided for @omniPoolContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get omniPoolContinue;

  /// No description provided for @omniPoolSync.
  ///
  /// In en, this message translates to:
  /// **'Sync inventory and addresses'**
  String get omniPoolSync;

  /// No description provided for @omniPoolAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get omniPoolAvailable;

  /// No description provided for @omniPoolAllocated.
  ///
  /// In en, this message translates to:
  /// **'Allocated'**
  String get omniPoolAllocated;

  /// No description provided for @omniPoolDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get omniPoolDisabled;

  /// No description provided for @omniPoolThreshold.
  ///
  /// In en, this message translates to:
  /// **'Alert threshold'**
  String get omniPoolThreshold;

  /// No description provided for @omniPoolOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get omniPoolOrder;

  /// No description provided for @omniPoolRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get omniPoolRetry;

  /// No description provided for @omniPoolConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Check the HTTPS address, public key and verified fingerprint.'**
  String get omniPoolConnectionError;

  /// No description provided for @omniPoolAccessError.
  ///
  /// In en, this message translates to:
  /// **'Check the device registration and platform grant in OmniVault.'**
  String get omniPoolAccessError;

  /// No description provided for @omniPoolNetworkError.
  ///
  /// In en, this message translates to:
  /// **'OmniVault could not be reached. Try again.'**
  String get omniPoolNetworkError;

  /// No description provided for @omniPoolVerificationError.
  ///
  /// In en, this message translates to:
  /// **'OmniVault data could not be verified. The saved records are intact.'**
  String get omniPoolVerificationError;

  /// No description provided for @omniPoolBackupError.
  ///
  /// In en, this message translates to:
  /// **'Backup verification failed. Check the file, passphrase and selected platform.'**
  String get omniPoolBackupError;

  /// No description provided for @omniPoolInputError.
  ///
  /// In en, this message translates to:
  /// **'Check the recovery phrase or enter a count from 1 to 1,000.'**
  String get omniPoolInputError;

  /// No description provided for @omniPoolError.
  ///
  /// In en, this message translates to:
  /// **'The address pool operation failed. Check the connection or local storage and retry.'**
  String get omniPoolError;

  /// No description provided for @omniPoolPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get omniPoolPlatform;

  /// No description provided for @omniPoolChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get omniPoolChain;

  /// No description provided for @omniPoolAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get omniPoolAddresses;

  /// No description provided for @omniPoolAllChains.
  ///
  /// In en, this message translates to:
  /// **'All chains'**
  String get omniPoolAllChains;

  /// No description provided for @omniPoolSearchAddress.
  ///
  /// In en, this message translates to:
  /// **'Search address, UID or order'**
  String get omniPoolSearchAddress;

  /// No description provided for @invalidDerivationPath.
  ///
  /// In en, this message translates to:
  /// **'Enter a full path such as m/44\'/60\'/0\'/0/1. Each index must be between 0 and 2147483647, with at most 255 levels.'**
  String get invalidDerivationPath;

  /// No description provided for @duplicateDerivationPath.
  ///
  /// In en, this message translates to:
  /// **'An account in this wallet already uses one of these derivation paths. Choose unused paths for both chains.'**
  String get duplicateDerivationPath;

  /// No description provided for @derivedAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the full derivation path for each chain. EVM networks share the EVM path. The new account will use these paths to derive addresses and sign transactions.'**
  String get derivedAccountHint;

  /// No description provided for @evmDerivationPath.
  ///
  /// In en, this message translates to:
  /// **'EVM derivation path'**
  String get evmDerivationPath;

  /// No description provided for @tronDerivationPath.
  ///
  /// In en, this message translates to:
  /// **'TRON derivation path'**
  String get tronDerivationPath;

  /// No description provided for @legacyAddressMode.
  ///
  /// In en, this message translates to:
  /// **'OmniVault legacy address mode (view only)'**
  String get legacyAddressMode;

  /// No description provided for @legacyAddressWarning.
  ///
  /// In en, this message translates to:
  /// **'Reproduces the old address hash that included 0x04. Matching an old address does not recover control of its funds. These accounts can only display balances; sending, receiving requests and key export are unavailable.'**
  String get legacyAddressWarning;

  /// No description provided for @legacyAddressBadge.
  ///
  /// In en, this message translates to:
  /// **'Legacy hash error · view only'**
  String get legacyAddressBadge;

  /// No description provided for @legacyAddressCannotSign.
  ///
  /// In en, this message translates to:
  /// **'This address uses the old incorrect hash. The derived key controls a different standard address. Transfers and payment requests are unavailable.'**
  String get legacyAddressCannotSign;

  /// No description provided for @legacyStandardAddresses.
  ///
  /// In en, this message translates to:
  /// **'Standard addresses controlled by the derived keys'**
  String get legacyStandardAddresses;

  /// No description provided for @legacyCheckAddress.
  ///
  /// In en, this message translates to:
  /// **'Old address to check (optional)'**
  String get legacyCheckAddress;

  /// No description provided for @legacyCheck.
  ///
  /// In en, this message translates to:
  /// **'Check old address and paths'**
  String get legacyCheck;

  /// No description provided for @legacyMatchStandard.
  ///
  /// In en, this message translates to:
  /// **'A standard address matches. Use the matched path with legacy mode off to add the normal account.'**
  String get legacyMatchStandard;

  /// No description provided for @legacyMatchHash.
  ///
  /// In en, this message translates to:
  /// **'The old hash matches. This confirms the address-generation bug, not control of this address.'**
  String get legacyMatchHash;

  /// No description provided for @legacyMatchNone.
  ///
  /// In en, this message translates to:
  /// **'No match in the supplied path or the three known historical branches. Verify the original phrase and xPub path.'**
  String get legacyMatchNone;

  /// No description provided for @legacyMatchedPath.
  ///
  /// In en, this message translates to:
  /// **'Matched path'**
  String get legacyMatchedPath;

  /// No description provided for @legacyUseMatchedPath.
  ///
  /// In en, this message translates to:
  /// **'Use matched path'**
  String get legacyUseMatchedPath;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
