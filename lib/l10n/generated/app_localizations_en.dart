// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get msgSyncing => 'Syncing…';

  @override
  String get msgRefreshAssets => 'Refresh assets';

  @override
  String get msgManageNetworks => 'Manage networks';

  @override
  String get msgStablecoins => 'Stablecoins';

  @override
  String get msgOtherCoins => 'Other coins';

  @override
  String get msgAddTokens => 'Add tokens';

  @override
  String get msgSearchAssetsOrNetworks => 'Search assets or networks';

  @override
  String get msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear =>
      'Native coins pay network fees. Unsynced balances appear as —.';

  @override
  String get msgTokensAreIdentifiedByNetworkAndContractMatching =>
      'Tokens are identified by network and contract. Matching tickers are not automatically combined.';

  @override
  String get msgNoMatchingAssets => 'No matching assets.';

  @override
  String msgAssetDetails(String p0) {
    return '$p0 asset details';
  }

  @override
  String get msgSend => 'Send';

  @override
  String get msgReceive => 'Receive';

  @override
  String get msgUseThisNetwork => 'Use this network';

  @override
  String get msgRefreshBalance => 'Refresh balance';

  @override
  String get msgNetwork => 'Network';

  @override
  String get msgWalletAddress => 'Wallet address';

  @override
  String get msgRpcUrl => 'RPC URL';

  @override
  String get msgBlockExplorer => 'Block explorer';

  @override
  String get msgExplorerLinkCopied => 'Explorer link copied';

  @override
  String get msgCopyExplorerLink => 'Copy explorer link';

  @override
  String get msgSystemDefault => 'System default';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get msgLanguage => 'Language';

  @override
  String get msgPreferencesCouldNotBeSavedPreviousSettingsMay =>
      'Preferences could not be saved. Previous settings may return after restarting.';

  @override
  String get msgYourKeysYourWallet => 'Your keys,\nyour wallet.';

  @override
  String get msgManageYourOnchainAssetsCreateAWalletOr =>
      'Manage your onchain assets.\nCreate a wallet or import an existing account to start.';

  @override
  String get msgSelfCustodyWallet => 'Self-custody wallet';

  @override
  String get msgTransactionsAreSignedOnThisDeviceYouControl =>
      'Transactions are signed on this device. You control your keys.';

  @override
  String get msgSecureDeviceStorage => 'Secure device storage';

  @override
  String get msgRecoveryCredentialsStayInThisDeviceSSecure =>
      'Recovery credentials stay in this device’s secure storage.';

  @override
  String get msgChooseYourNetworks => 'Choose your networks';

  @override
  String get msgRpcConnectionsStartOnlyAfterYouEnableA =>
      'RPC connections start only after you enable a network.';

  @override
  String get msgGetStartedWithStoneWallet => 'Get started with Stone Wallet';

  @override
  String get msgChooseHowToGetStarted => 'Choose how to get started';

  @override
  String get msgCreateWallet => 'Create wallet';

  @override
  String get msgImportRecoveryPhrase => 'Import recovery phrase';

  @override
  String get msgImportPrivateKey => 'Import private key';

  @override
  String get msgImportPrivateKeyFile => 'Import private-key file';

  @override
  String get msgCsvTsvColumnsChainPrivateKey =>
      'CSV / TSV · Columns: chain, private key';

  @override
  String get msgKeepYourRecoveryPhraseAndPrivateKeysSafe =>
      'Keep your recovery phrase and private keys safe. They restore access to your wallet.';

  @override
  String get msgNetworksAndRpc => 'Networks and RPC';

  @override
  String get msgNoNetworkSelectedEnableANetworkToQuery =>
      'No network selected. Enable a network to query balances.';

  @override
  String get msgTransactionNetwork => 'Transaction network';

  @override
  String get msgTestnet => 'Testnet';

  @override
  String get msgMainnet => 'Mainnet';

  @override
  String endpointCount(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 endpoints · Automatic failover',
      one: '$p0 endpoint · Automatic failover',
    );
    return '$_temp0';
  }

  @override
  String get msgActiveEndpoint => 'Active endpoint';

  @override
  String get msgSyncingMore => '○ Syncing…';

  @override
  String get msgRpcConnected => '● RPC connected';

  @override
  String get msgNotSynced => '○ Not synced';

  @override
  String get msgEditRpc => 'Edit RPC';

  @override
  String get msgAddCustomNetwork => 'Add custom network';

  @override
  String get msgWalletSecurity => 'Wallet security';

  @override
  String get msgAccountSource => 'Account source';

  @override
  String get msgDerivationPath => 'Derivation path';

  @override
  String get msgPrivateKeyImport => 'Private-key import';

  @override
  String get msgRecoveryPhrasesAndPrivateKeysRemainInSecure =>
      'Recovery phrases and private keys remain in secure device storage. Keep an offline backup.';

  @override
  String get msgWalletManagement => 'Wallet management';

  @override
  String walletAndAccountSummary(int p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 wallets',
      one: '$p0 wallet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 accounts',
      one: '$p1 account',
    );
    return '$_temp0 · $_temp1\nCreate or import wallets, or add accounts to a recovery-phrase wallet.';
  }

  @override
  String get msgManageWalletsAndAccounts => 'Manage wallets and accounts';

  @override
  String get msgChooseFileToImport => 'Choose file to import';

  @override
  String get msgBackup => 'Backup';

  @override
  String get msgIcloudGoogleDriveBackupNotConnected =>
      'iCloud / Google Drive backup (not connected)';

  @override
  String get msgKeepYourRecoveryCredentialsInASecureOffline =>
      'Keep your recovery credentials in a secure offline location.';

  @override
  String get msgOnchainAssets => 'Onchain assets';

  @override
  String get msgViewAll => 'View all';

  @override
  String get msgAssets => 'Assets';

  @override
  String get msgBalance => 'Balance';

  @override
  String get msgStatus => 'Status';

  @override
  String get msgSynced => 'Synced';

  @override
  String msgNetworksQueried(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: 'networks queried',
      one: 'network queried',
    );
    return '$p0/$p1\n$_temp0';
  }

  @override
  String get msgQueriedBalanceDistribution => 'Queried balance distribution';

  @override
  String get msgStablecoinOverview => 'Stablecoin overview';

  @override
  String get msgRefreshStablecoins => 'Refresh stablecoins';

  @override
  String msgCurrentAccount(String p0) {
    return 'Current account · $p0';
  }

  @override
  String msgTrackedTotal(String p0) {
    return 'Tracked $p0 total';
  }

  @override
  String get msgQueriedSubtotal => 'Queried subtotal';

  @override
  String msgNetworksQueriedMore(String p0, int p1, String p2) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: 'networks queried',
      one: 'network queried',
    );
    return '$p0/$p1 $_temp0$p2';
  }

  @override
  String get msgFullySynced => ' · Fully synced';

  @override
  String get msgCoverageIsIncomplete => ' · Coverage is incomplete';

  @override
  String get msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities =>
      'Includes tracked USDT0 / Binance-Peg versions. Token quantities only, not a USD valuation.';

  @override
  String get msgOnlyAddedCircleUsdcContractsAreCountedBy =>
      'Only added Circle USDC contracts are counted, by token quantity.';

  @override
  String get msgViewNetworkDistribution => 'View network distribution →';

  @override
  String msgByNetwork(String p0) {
    return '$p0 by network';
  }

  @override
  String get msgEnableQueryNetworks => 'Enable query networks';

  @override
  String msgNoAddedYet(String p0) {
    return 'No $p0 added yet';
  }

  @override
  String get msgAddTokensToViewTheirNetworkDistribution =>
      'Add tokens to view their network distribution.';

  @override
  String get msgEnableStablecoinNetworks => 'Enable stablecoin networks';

  @override
  String msgOfQueriedBalances(String p0) {
    return '$p0% of queried balances';
  }

  @override
  String get msgZeroBalance => 'Zero balance';

  @override
  String get msgAwaitingOnchainBalance => 'Awaiting onchain balance';

  @override
  String get msgCopyReceiveAddress => 'Copy receive address';

  @override
  String get msgQuerying => 'Querying…';

  @override
  String get msgCurrentAccountReceiveAddress =>
      'Current account receive address';

  @override
  String msgTokenContractDecimals(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 decimals',
      one: '$p0 decimal',
    );
    return 'Token contract · $_temp0';
  }

  @override
  String get msgCheckTheNetworkAndContractBeforeReceivingToken =>
      'Check the network and contract before receiving. Token transfers are not available here yet.';

  @override
  String get msgCannotReadThisTokenCheckTheNetworkContract =>
      'Cannot read this token. Check the network, contract and endpoint.';

  @override
  String get msgAddingATokenChangesItsDisplayOnlyIt =>
      'Adding a token changes its display only. It does not approve or send a transaction.';

  @override
  String get msgCommonStablecoins => 'Common stablecoins';

  @override
  String get msgAddedCustomTokens => 'Added custom tokens';

  @override
  String get msgHideToken => 'Hide token';

  @override
  String get msgAddCustomToken => 'Add custom token';

  @override
  String get msgTokenContractAddress => 'Token contract address';

  @override
  String get msgProcessing => 'Processing…';

  @override
  String get msgReadTokenInfo => 'Read token info';

  @override
  String msgDecimals(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 decimals',
      one: '$p1 decimal',
    );
    return '$p0 · $_temp0';
  }

  @override
  String get msgCustomTokensWithMatchingTickersAreNotAutomatically =>
      'Custom tokens with matching tickers are not automatically included in USDT / USDC totals.';

  @override
  String msgMatchesAPresetContractItWillBeIncluded(String p0) {
    return 'Matches a preset contract. It will be included in the $p0 total.';
  }

  @override
  String get msgAdded => 'Added';

  @override
  String get msgConfirmAddition => 'Confirm addition';

  @override
  String get msgSwitchTheme => 'Switch theme';

  @override
  String get msgClose => 'Close';

  @override
  String get msgSelectWallet => 'Select wallet';

  @override
  String get msgRecoveryPhraseWallet => 'Recovery-phrase wallet';

  @override
  String get msgSwap => 'Swap';

  @override
  String get msgMakeSureTheReceivingNetworkMatchesTheNetwork =>
      'Make sure the receiving network matches the network you selected.';

  @override
  String get msgEnableMultipleNetworksToViewBalancesOnlySelected =>
      'Enable multiple networks to view balances. Only selected networks connect to RPC after you save.';

  @override
  String get msgDisconnectAllNetworks => 'Disconnect all networks';

  @override
  String get msgSaveNetworkSelection => 'Save network selection';

  @override
  String get msgTapANetworkNameToUseItFor =>
      'Tap a network name to use it for transactions. Checkboxes enable additional networks for balance queries.';

  @override
  String get msgUseForTransactions => 'Use for transactions';

  @override
  String get msgRecoveryPhraseVerificationFailedCheckWordsAnd =>
      'Recovery phrase verification failed. Check words 2, 6 and 10.';

  @override
  String get msgVerifyRecoveryPhrase => 'Verify recovery phrase';

  @override
  String get msgWriteDownRecoveryPhrase => 'Write down recovery phrase';

  @override
  String get msgVerifyAndOpenWallet => 'Verify and open wallet';

  @override
  String get msgIWroteItDownVerify => 'I wrote it down — verify';

  @override
  String get msgWrittenVerify => 'Written ✓     →     ② Verify';

  @override
  String get msgWriteDownVerify => '① Write down     →     ② Verify';

  @override
  String get msgEnterTheRequestedWordsToFinishCreatingYour =>
      'Enter the requested words to finish creating your wallet.';

  @override
  String get msgWriteDownTheseWordsInOrderAndKeep =>
      'Write down these words in order and keep them in a secure offline location.';

  @override
  String msgWord(String p0) {
    return 'Word $p0';
  }

  @override
  String get msgDoNotScreenshotCopyOrSendYourRecovery =>
      'Do not screenshot, copy or send your recovery phrase. Verification happens on this device.';

  @override
  String get msgImportWallet => 'Import wallet';

  @override
  String get msgEnterYourExistingRecoveryPhraseSeparatingWordsWith =>
      'Enter your existing recovery phrase, separating words with spaces.';

  @override
  String get msgImport => 'Import';

  @override
  String get msgEnterYourOrWordRecoveryPhrase =>
      'Enter your 12- or 24-word recovery phrase';

  @override
  String get msgChooseANetworkToViewAfterImporting =>
      'Choose a network to view after importing.';

  @override
  String get msgPrivateKeyImportFailedPleaseTryAgain =>
      'Private-key import failed. Please try again.';

  @override
  String get msgRestoreAnAccountWithAnEvmTronHexadecimal =>
      'Restore an account with an EVM / TRON hexadecimal private key. No recovery phrase is required.';

  @override
  String get msgImporting => 'Importing…';

  @override
  String get msgImportAndOpenWallet => 'Import and open wallet';

  @override
  String get msgSelectANetwork => 'Select a network';

  @override
  String get msgPrivateKey => 'Private key';

  @override
  String get msgHexadecimalCharactersOptionallyPrefixedWithX =>
      '64 hexadecimal characters, optionally prefixed with 0x';

  @override
  String get msgShowPrivateKey => 'Show private key';

  @override
  String get msgHidePrivateKey => 'Hide private key';

  @override
  String get msgPrivateKeysStayInSecureDeviceStorageAfter =>
      'Private keys stay in secure device storage. After import, the selected network is queried for balances. Private keys are never sent to RPC.';

  @override
  String get msgImportResults => 'Import results';

  @override
  String get msgDone => 'Done';

  @override
  String msgImportedSkippedOrFailed(String p0, String p1) {
    return '$p0 imported · $p1 skipped or failed';
  }

  @override
  String msgRow(String p0, String p1) {
    return 'Row $p0: $p1';
  }

  @override
  String get msgAmountMustBeGreaterThanZero =>
      'Amount must be greater than zero.';

  @override
  String get msgAmountExceedsTheAvailableBalance =>
      'Amount exceeds the available balance.';

  @override
  String msgSendMore(String p0) {
    return 'Send $p0';
  }

  @override
  String msgSignedOnThisDevice(String p0, String p1) {
    return '$p0 · $p1 · Signed on this device';
  }

  @override
  String get msgCheckTheTransactionStatusFirst =>
      'Check the transaction status first';

  @override
  String get msgSignAndBroadcast => 'Sign and broadcast';

  @override
  String get msgRecipientAddress => 'Recipient address';

  @override
  String msgAmount(String p0) {
    return 'Amount ($p0)';
  }

  @override
  String msgAvailable(String p0, String p1, String p2) {
    return 'Available: $p0 $p1 · $p2';
  }

  @override
  String get msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay =>
      'Insufficient bandwidth consumes TRX. An unactivated recipient may incur extra fees.';

  @override
  String get msgGasFeesAreChargedSeparately =>
      'Gas fees are charged separately';

  @override
  String msgTransactionHash(String p0) {
    return 'Transaction hash: $p0';
  }

  @override
  String get msgSettings => 'Settings';

  @override
  String get msgYourKeysStayWithYouTransactionsAreSigned =>
      'Your keys stay with you\nTransactions are signed on this device';

  @override
  String get msgHome => 'Home';

  @override
  String get msgChooseNetwork => 'Choose network';

  @override
  String get msgChainIdMustBeAValidPositiveInteger =>
      'Chain ID must be a valid positive integer.';

  @override
  String get msgThisChainIdAlreadyExistsEditItsRpc =>
      'This Chain ID already exists. Edit its RPC settings instead.';

  @override
  String get msgConfigureAtLeastOneRpcUrl => 'Configure at least one RPC URL.';

  @override
  String get msgTronHttpApiIsAvailableTheMainnetGenesis =>
      'TRON HTTP API is available. The mainnet genesis block was verified.';

  @override
  String get msgRpcIsAvailableAndItsChainIdMatches =>
      'RPC is available and its Chain ID matches the network.';

  @override
  String get msgConnectionCheckFailedCheckTheRpcUrlNetwork =>
      'Connection check failed. Check the RPC URL, network or credentials.';

  @override
  String get msgCouldNotSaveNetworkSettingsPleaseTryAgain =>
      'Could not save network settings. Please try again.';

  @override
  String get msgAddCustomEvmNetwork => 'Add custom EVM network';

  @override
  String get msgEditNetworkAndRpc => 'Edit network and RPC';

  @override
  String get msgEnterOneRpcUrlPerLineInPriority =>
      'Enter one RPC URL per line in priority order. Failed endpoints are skipped and working ones are preferred.';

  @override
  String get msgSaving => 'Saving…';

  @override
  String get msgSaveNetworkSettings => 'Save network settings';

  @override
  String get msgNetworkName => 'Network name';

  @override
  String get msgForExampleBase => 'For example: Base';

  @override
  String get msgForExample => 'For example: 8453';

  @override
  String get msgNativeCurrencySymbol => 'Native currency symbol';

  @override
  String get msgForExampleEth => 'For example: ETH';

  @override
  String get msgHttpsPrimaryEndpointHttpsBackupEndpoint =>
      'https://primary-endpoint\nhttps://backup-endpoint';

  @override
  String get msgOneUrlPerLineOrderSetsPriorityDuplicates =>
      'One URL per line. Order sets priority. Duplicates are removed.';

  @override
  String get msgRestoreBuiltInFreeEndpoints =>
      'Restore built-in free endpoints';

  @override
  String get msgBlockExplorerUrlOptional => 'Block explorer URL (optional)';

  @override
  String get msgChecking => 'Checking…';

  @override
  String get msgCheckRpcConnection => 'Check RPC connection';

  @override
  String get msgOperationFailedPleaseTryAgain =>
      'Operation failed. Please try again.';

  @override
  String get msgRenameAccount => 'Rename account';

  @override
  String get msgRenameWallet => 'Rename wallet';

  @override
  String walletAccountCount(String p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 accounts',
      one: '$p1 account',
    );
    return '$p0 · $_temp0';
  }

  @override
  String get msgPrivateKeyWallet => 'Private-key wallet';

  @override
  String get msgCopyAccountAddress => 'Copy account address';

  @override
  String get msgAddAccount => 'Add account';

  @override
  String walletAndAccountCount(int p0, int p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 wallets',
      one: '$p0 wallet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      p1,
      locale: localeName,
      other: '$p1 accounts',
      one: '$p1 account',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get msgARecoveryPhraseWalletCanHaveMultipleAccounts =>
      'A recovery-phrase wallet can have multiple accounts. A different recovery phrase or private key creates a separate wallet.';

  @override
  String get msgSearchWalletsAccountsOrAddresses =>
      'Search wallets, accounts or addresses';

  @override
  String get msgNoMatchingWalletsOrAccounts =>
      'No matching wallets or accounts';

  @override
  String get msgExistingWalletsAreKeptYouCanSwitchAt =>
      'Existing wallets are kept. You can switch at any time.';

  @override
  String get msgRestoreAWalletAndAddDerivedAccounts =>
      'Restore a wallet and add derived accounts';

  @override
  String get msgImportOneEvmTronAccount => 'Import one EVM / TRON account';

  @override
  String get msgImportMultipleAccountsFromCsvTsv =>
      'Import multiple accounts from CSV / TSV';

  @override
  String get msgNamesMustContainCharacters =>
      'Names must contain 1–64 characters.';

  @override
  String get msgSaveName => 'Save name';

  @override
  String get msgName => 'Name';

  @override
  String get msgCustomToken => 'Custom token';

  @override
  String get msgInvalidTokenInformationReadTheContractAgain =>
      'Invalid token information. Read the contract again.';

  @override
  String get msgTokenSymbolContainsInvalidCharacters =>
      'Token symbol contains invalid characters.';

  @override
  String get msgTheTokenContractReturnedAnInvalidValue =>
      'The token contract returned an invalid value.';

  @override
  String get msgInvalidTokenSymbol => 'Invalid token symbol.';

  @override
  String get msgOnlyTokensWithDecimalsAreSupported =>
      'Only tokens with 0–36 decimals are supported.';

  @override
  String get msgCannotReadTheTokenSymbol => 'Cannot read the token symbol.';

  @override
  String get msgInvalidTokenSymbolEncoding => 'Invalid token symbol encoding.';

  @override
  String get msgInvalidTokenSymbolLength => 'Invalid token symbol length.';

  @override
  String get msgCannotReadTheSavedTokenListExistingRecords =>
      'Cannot read the saved token list. Existing records were not overwritten.';

  @override
  String get msgThisTokenHasAlreadyBeenAddedOnThis =>
      'This token has already been added on this network.';

  @override
  String get msgNetworkDisabled => 'Network disabled';

  @override
  String get msgQueryingMore => 'Querying';

  @override
  String get msgQueryFailed => 'Query failed';

  @override
  String get msgTronMainnetIdentifierDoesNotMatchTheProtocol =>
      'TRON mainnet identifier does not match the protocol.';

  @override
  String get msgEnterTheNetworkNameAndNativeCurrencySymbol =>
      'Enter the network name and native currency symbol.';

  @override
  String get msgEnterAValidHttpHttpsUrl => 'Enter a valid HTTP / HTTPS URL.';

  @override
  String get msgCannotAccessKeychainQuitRebuildAndRunThe =>
      'Cannot access Keychain (-34018). Quit, rebuild and run the app. Hot reload cannot update native signing permissions.';

  @override
  String get msgCannotAccessSecureDeviceStorageCheckThatKeychain =>
      'Cannot access secure device storage. Check that Keychain is unlocked and access is allowed.';

  @override
  String get msgCannotReadSavedNetworkSettingsCheckTheStored =>
      'Cannot read saved network settings. Check the stored configuration.';

  @override
  String get msgAccountIndexIsOutOfRange => 'Account index is out of range.';

  @override
  String get msgInvalidRecoveryPhraseCheckTheWordsAndTheir =>
      'Invalid recovery phrase. Check the words and their order.';

  @override
  String get msgCannotDeriveTheEvmPrivateKey =>
      'Cannot derive the EVM private key.';

  @override
  String get msgInvalidPrivateKeyEnterHexadecimalCharacters =>
      'Invalid private key. Enter 64 hexadecimal characters.';

  @override
  String get msgPrivateKeyValueIsOutOfRange =>
      'Private key value is out of range.';

  @override
  String get msgInvalidPrivateKeyCannotCreateAnAccount =>
      'Invalid private key. Cannot create an account.';

  @override
  String get msgBinance => 'Binance';

  @override
  String get msgTron => 'TRON';

  @override
  String msgRpcNetworkMismatchExpectedReceived(String p0, String p1) {
    return 'RPC network mismatch: expected $p0, received $p1.';
  }

  @override
  String msgAllRpcEndpointsAreUnavailableTryAgainLater(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: 'All $p0 RPC endpoints are unavailable.',
      one: 'The RPC endpoint is unavailable.',
    );
    return '$_temp0 Try again later or edit the endpoint list.';
  }

  @override
  String get msgTheTokenAndNetworkDoNotMatch =>
      'The token and network do not match.';

  @override
  String get msgTheRpcReturnedADifferentTransactionHash =>
      'The RPC returned a different transaction hash.';

  @override
  String get msgBroadcastStatusIsUncertainCheckTheTransactionHash =>
      'Broadcast status is uncertain. Check the transaction hash before trying again to avoid duplicate transfers.';

  @override
  String msgEnterAValidAmountWithAtMostDecimal(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 decimal places',
      one: '$p0 decimal place',
    );
    return 'Enter a valid amount with at most $_temp0.';
  }

  @override
  String get msgMainWallet => 'Main wallet';

  @override
  String get msgNoNetworkSelected => 'No network selected';

  @override
  String get msgChooseANetworkToView => 'Choose a network to view';

  @override
  String get msgRpcNotConnected => 'RPC not connected';

  @override
  String get msgNativeAsset => 'Native asset';

  @override
  String get msgConnectionFailed => 'Connection failed';

  @override
  String get msgAwaitingSync => 'Awaiting sync';

  @override
  String get msgWallet => 'Wallet';

  @override
  String get msgRpcRequestTimedOutCheckTheUrlOr =>
      'RPC request timed out. Check the URL or try another endpoint.';

  @override
  String get msgRpcRequestFailedCheckTheNetworkEndpointOr =>
      'RPC request failed. Check the network, endpoint or credentials.';

  @override
  String msgCouldNotConnectToEditRpcSettingsOr(String p0) {
    return 'Could not connect to $p0. Edit RPC settings or retry.';
  }

  @override
  String get msgTheAccountHasChangedReopenThisAsset =>
      'The account has changed. Reopen this asset.';

  @override
  String get msgCouldNotSaveNetworkSelectionPleaseTryAgain =>
      'Could not save network selection. Please try again.';

  @override
  String get msgPrivateKeyAccountImported => 'Private-key account imported';

  @override
  String get msgTheAccountWasSavedButCouldNotBe =>
      'The account was saved but could not be loaded. Reopen the wallet.';

  @override
  String get msgCannotReadThisFile => 'Cannot read this file.';

  @override
  String get msgNoImportableRowsTheHeaderMustContainChain =>
      'No importable rows. The header must contain chain and private key columns.';

  @override
  String importedRowSummary(int p0, String p1) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 rows',
      one: '$p0 row',
    );
    return 'Imported $_temp0$p1.';
  }

  @override
  String msgFailed(String p0) {
    return '; $p0 failed';
  }

  @override
  String get msgChain => 'Chain';

  @override
  String msgSelectedConnectingToRpc(String p0) {
    return 'Selected $p0. Connecting to RPC…';
  }

  @override
  String msgNetworkSettingsSaved(String p0) {
    return '$p0 network settings saved';
  }

  @override
  String get msgSwapsAreNotConnectedNoOrderOrSignature =>
      'Swaps are not connected. No order or signature was created.';

  @override
  String get msgUnavailable => 'Unavailable';

  @override
  String get msgAddressCopied => 'Address copied';

  @override
  String get msgSelectANetworkBeforeSending =>
      'Select a network before sending.';

  @override
  String msgTransactionBroadcast(String p0) {
    return 'Transaction broadcast: $p0';
  }

  @override
  String get msgWalletOperationFailedPleaseTryAgain =>
      'Wallet operation failed. Please try again.';

  @override
  String get msgMostRecentlyBroadcastTransaction =>
      'Most recently broadcast transaction';

  @override
  String get msgEnterAValidTronAddressStartingWithT =>
      'Enter a valid TRON address starting with T and a correct checksum.';

  @override
  String get msgTheTronEndpointReturnedAnErrorTryAnother =>
      'The TRON endpoint returned an error. Try another endpoint or retry later.';

  @override
  String get msgTronNetworkMismatchAMainnetEndpointIsRequired =>
      'TRON network mismatch. A mainnet endpoint is required.';

  @override
  String msgAllTronEndpointsAreUnavailableTryAgainLater(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: 'All $p0 TRON endpoints are unavailable.',
      one: 'The TRON endpoint is unavailable.',
    );
    return '$_temp0 Try again later or edit the endpoint list.';
  }

  @override
  String get msgTrcQueryFailedCheckTheContractAndEndpoint =>
      'TRC20 query failed. Check the contract and endpoint.';

  @override
  String get msgTheTronEndpointReturnedADifferentAccountS =>
      'The TRON endpoint returned a different account’s balance.';

  @override
  String get msgTheTronEndpointReturnedAnInvalidBalance =>
      'The TRON endpoint returned an invalid balance.';

  @override
  String get msgTrxAmountIsOutOfRange => 'TRX amount is out of range.';

  @override
  String get msgTronReferenceBlockIsInvalidOrStaleCheck =>
      'TRON reference block is invalid or stale. Check your clock and endpoint.';

  @override
  String get msgTheTronEndpointDidNotConfirmTheBroadcast =>
      'The TRON endpoint did not confirm the broadcast.';

  @override
  String get msgCannotReadTheWalletBookCheckSecureStorage =>
      'Cannot read the wallet book. Check secure storage.';

  @override
  String get msgAccount => 'Account 1';

  @override
  String msgPrivateKeyAccount(String p0) {
    return 'Private-key account $p0';
  }

  @override
  String get msgSavedPrivateKeyAccountDataIsCorrupted =>
      'Saved private-key account data is corrupted.';

  @override
  String msgWalletMore(String p0) {
    return 'Wallet $p0';
  }

  @override
  String get msgUnsupportedNetwork => 'Unsupported network.';

  @override
  String get msgDuplicateEntrySkipped => 'Duplicate entry skipped.';

  @override
  String get msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts =>
      'Only recovery-phrase wallets can derive additional accounts.';

  @override
  String msgAccountMore(String p0) {
    return 'Account $p0';
  }

  @override
  String get msgAccountNotFound => 'Account not found.';

  @override
  String get msgWalletNotFound => 'Wallet not found.';

  @override
  String get msgUnexpectedErrorPleaseTryAgain =>
      'Unexpected error. Please try again.';

  @override
  String get msgSelfCustodyEvmTron => 'Self-custody · EVM / TRON';

  @override
  String get portfolioOverview => 'Address overview';

  @override
  String get portfolioByCoin => 'By coin';

  @override
  String get portfolioReferenceValue => 'Reference value';

  @override
  String get portfolioValuedSubtotal => 'Valued subtotal';

  @override
  String get portfolioAllAddresses => 'All linked addresses';

  @override
  String get portfolioAllNetworks => 'All enabled networks';

  @override
  String get portfolioAllAssets => 'All assets';

  @override
  String get portfolioSimple => 'Simple';

  @override
  String get portfolioDetailed => 'Detailed';

  @override
  String get portfolioDisplaySettings => 'Asset display';

  @override
  String get portfolioDisplayMode => 'Display mode';

  @override
  String get portfolioInitialCount => 'Initial coin count';

  @override
  String get portfolioAll => 'All';

  @override
  String get portfolioSort => 'Sort assets';

  @override
  String get portfolioSortValue => 'Value: high to low';

  @override
  String get portfolioStableFirst => 'Stablecoins first';

  @override
  String get portfolioSortName => 'Name';

  @override
  String get portfolioHideZero => 'Hide confirmed zero balances';

  @override
  String get portfolioShowSpam => 'Show suspected spam from indexers';

  @override
  String portfolioExpand(String p0) {
    return 'Show all ($p0)';
  }

  @override
  String get portfolioCollapse => 'Show fewer';

  @override
  String get portfolioSelectCoin => 'Select a coin';

  @override
  String get portfolioSearch => 'Search coins, contracts or networks';

  @override
  String portfolioChainCount(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 chains',
      one: '$p0 chain',
    );
    return '$_temp0';
  }

  @override
  String portfolioCoinCount(int p0) {
    String _temp0 = intl.Intl.pluralLogic(
      p0,
      locale: localeName,
      other: '$p0 coins',
      one: '$p0 coin',
    );
    return '$_temp0';
  }

  @override
  String get portfolioInformation => 'Value and query details';

  @override
  String get portfolioValueExplanation =>
      'USDT market prices, using 1 USDT ≈ 1 USD. Includes watched and discovered assets on enabled networks only.';

  @override
  String get portfolioVersionExplanation =>
      'USDT0 and Binance-Peg versions use the USDT reference price. Matching tickers alone never identify an asset.';

  @override
  String portfolioCoverage(String p0, String p1, String p2) {
    return '$p0/$p1 holdings queried · $p2 without a price';
  }

  @override
  String get portfolioPartial => 'Partial';

  @override
  String get portfolioStalePrices => 'Cached prices · update failed';

  @override
  String get portfolioNoPrice => 'Price unavailable';

  @override
  String get portfolioNoAssets => 'No matching assets';

  @override
  String get portfolioShowZero => 'Show zero balances';

  @override
  String get portfolioRefresh => 'Refresh balances and prices';

  @override
  String get portfolioSourceRpc => 'Balance from RPC';

  @override
  String get portfolioSourceIndexer => 'Discovered by indexer';

  @override
  String get portfolioPriceSource => 'Prices: Binance public USDT markets';

  @override
  String portfolioUpdated(String p0) {
    return 'Price time: $p0';
  }

  @override
  String get portfolioTestnetExcluded =>
      'Testnet balances are excluded from the value.';

  @override
  String get discoveryServices => 'Asset indexers';

  @override
  String get discoveryConfigure => 'Configure auto-discovery';

  @override
  String get discoveryNotConfigured => 'Auto-discovery not configured';

  @override
  String get discoveryQuerying => 'Discovering assets…';

  @override
  String get discoveryPartial => 'Discovery is incomplete';

  @override
  String get discoveryUnavailable => 'Auto-discovery unavailable';

  @override
  String get discoveryLoadMore => 'Continue discovery';

  @override
  String discoveryConfigureProvider(String p0) {
    return 'Configure $p0';
  }

  @override
  String get discoveryGetKey => 'Get an API key';

  @override
  String get discoveryDocs => 'Official guide';

  @override
  String get discoveryPlans => 'Plans and quotas';

  @override
  String get discoveryApiKey => 'Service API key';

  @override
  String get discoveryKeyHint =>
      'Use your own service key, not a wallet private key';

  @override
  String get discoveryKeyRequired => 'Enter a service API key.';

  @override
  String get discoveryPrivacy =>
      'When enabled, this service receives the linked public address on selected networks. Keys stay in this device’s secure storage.';

  @override
  String get discoveryAssignments =>
      'Choose networks (replaces their current indexer)';

  @override
  String get discoveryChooseNetwork =>
      'Choose at least one supported enabled network.';

  @override
  String get discoveryTest => 'Test connection';

  @override
  String get discoveryConnected =>
      'Connected. Credentials and response are valid.';

  @override
  String get discoverySaveEnable => 'Save and enable';

  @override
  String get discoveryEnabled => 'Enabled';

  @override
  String get discoveryDisabled => 'Disabled';

  @override
  String get discoveryDisable => 'Disable';

  @override
  String get discoveryDelete => 'Delete configuration';

  @override
  String get discoveryEdit => 'Configure';

  @override
  String get discoveryUnauthorized =>
      'Service key rejected. Check the key and plan permissions.';

  @override
  String get discoveryLimited =>
      'Indexer quota or rate limit reached. Retry later.';

  @override
  String get discoveryResponseInvalid =>
      'The indexer returned invalid asset data.';

  @override
  String get discoveryRequestFailed =>
      'Could not connect to the indexer. Watched assets remain available.';

  @override
  String get discoverySettingsUnreadable =>
      'Could not read indexer settings. Existing records have been kept.';

  @override
  String get discoverySaveFailed =>
      'Could not save indexer settings. Please retry.';

  @override
  String get discoveryUnsupported =>
      'This indexer does not support the selected network in this app.';

  @override
  String get discoveryWatch => 'Watch this token';

  @override
  String get discoveryWatched => 'Token added to watched assets';

  @override
  String get discoveryMoralisGuide =>
      'Create a Moralis account → copy the Web3 API key → choose Ethereum, Polygon or BNB Chain. View current quotas on the plans page.';

  @override
  String get discoveryAlchemyGuide =>
      'Create an Alchemy app → enable Ethereum or Polygon → copy its API key. This app uses the Token API.';

  @override
  String get discoveryTronGridGuide =>
      'Sign in to TronGrid → create an API key → enable TRON Mainnet. This app discovers TRC20 holdings.';

  @override
  String get discoveryLinkCopied =>
      'Could not open the browser. The link has been copied.';

  @override
  String get discoveryNoEnabledNetworks =>
      'Enable a supported network before configuring discovery.';

  @override
  String get portfolioAddressDetails => 'Linked addresses';

  @override
  String get portfolioBalanceStatus => 'Balance status';

  @override
  String get portfolioSpam => 'Suspected spam';

  @override
  String get portfolioNoCoin => 'No coins in this selection';

  @override
  String get discoveryNotConfiguredShort => 'Not configured';

  @override
  String get settingsSearch => 'Search settings';

  @override
  String get settingsSearchHint => 'Language, display mode, RPC…';

  @override
  String get settingsQuickLinks => 'Quick settings';

  @override
  String get settingsCategories => 'All settings';

  @override
  String get settingsWallets => 'Wallets and accounts';

  @override
  String get settingsWalletsHint => 'Manage, create and import';

  @override
  String get settingsAssetsHint => 'Display preferences and watched tokens';

  @override
  String get settingsData => 'Networks and data';

  @override
  String get settingsDataHint => 'Network RPC and asset indexers';

  @override
  String get settingsSecurity => 'Security and backup';

  @override
  String get settingsSecurityHint => 'Account security and backup guidance';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsGeneralHint => 'Language and appearance';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsWatchedTokens => 'Watched tokens';

  @override
  String get settingsNoResults => 'No matching settings';

  @override
  String get settingsClearSearch => 'Clear search';

  @override
  String get settingsUnavailable => 'Not available yet';

  @override
  String get settingsNetworkDisabled => 'Not enabled';

  @override
  String get settingsNetworkEnabled => 'Enabled';

  @override
  String get settingsNetworkState => 'Enable network';

  @override
  String get settingsBackupHint =>
      'Keep recovery credentials safely offline. Cloud backup is not available yet.';

  @override
  String get settingsMatchedOption => 'Setting located';
}
