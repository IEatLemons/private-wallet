part of '../main.dart';

String tr(
  BuildContext context,
  MessageCode code, [
  List<Object?> arguments = const [],
]) {
  final strings = AppLocalizations.of(context);
  return switch (code) {
    MessageCode.msgSyncing => strings.msgSyncing,
    MessageCode.msgRefreshAssets => strings.msgRefreshAssets,
    MessageCode.msgManageNetworks => strings.msgManageNetworks,
    MessageCode.msgStablecoins => strings.msgStablecoins,
    MessageCode.msgOtherCoins => strings.msgOtherCoins,
    MessageCode.msgAddTokens => strings.msgAddTokens,
    MessageCode.msgSearchAssetsOrNetworks => strings.msgSearchAssetsOrNetworks,
    MessageCode.msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear =>
      strings.msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear,
    MessageCode.msgTokensAreIdentifiedByNetworkAndContractMatching =>
      strings.msgTokensAreIdentifiedByNetworkAndContractMatching,
    MessageCode.msgNoMatchingAssets => strings.msgNoMatchingAssets,
    MessageCode.msgAssetDetails => strings.msgAssetDetails(
      localized(context, arguments[0]),
    ),
    MessageCode.msgSend => strings.msgSend,
    MessageCode.msgReceive => strings.msgReceive,
    MessageCode.msgUseThisNetwork => strings.msgUseThisNetwork,
    MessageCode.msgRefreshBalance => strings.msgRefreshBalance,
    MessageCode.msgNetwork => strings.msgNetwork,
    MessageCode.msgWalletAddress => strings.msgWalletAddress,
    MessageCode.msgRpcUrl => strings.msgRpcUrl,
    MessageCode.msgBlockExplorer => strings.msgBlockExplorer,
    MessageCode.msgExplorerLinkCopied => strings.msgExplorerLinkCopied,
    MessageCode.msgCopyExplorerLink => strings.msgCopyExplorerLink,
    MessageCode.msgSystemDefault => strings.msgSystemDefault,
    MessageCode.languageSimplifiedChinese => strings.languageSimplifiedChinese,
    MessageCode.languageTraditionalChinese =>
      strings.languageTraditionalChinese,
    MessageCode.msgLanguage => strings.msgLanguage,
    MessageCode.msgPreferencesCouldNotBeSavedPreviousSettingsMay =>
      strings.msgPreferencesCouldNotBeSavedPreviousSettingsMay,
    MessageCode.msgYourKeysYourWallet => strings.msgYourKeysYourWallet,
    MessageCode.msgManageYourOnchainAssetsCreateAWalletOr =>
      strings.msgManageYourOnchainAssetsCreateAWalletOr,
    MessageCode.msgSelfCustodyWallet => strings.msgSelfCustodyWallet,
    MessageCode.msgTransactionsAreSignedOnThisDeviceYouControl =>
      strings.msgTransactionsAreSignedOnThisDeviceYouControl,
    MessageCode.msgSecureDeviceStorage => strings.msgSecureDeviceStorage,
    MessageCode.msgRecoveryCredentialsStayInThisDeviceSSecure =>
      strings.msgRecoveryCredentialsStayInThisDeviceSSecure,
    MessageCode.msgChooseYourNetworks => strings.msgChooseYourNetworks,
    MessageCode.msgRpcConnectionsStartOnlyAfterYouEnableA =>
      strings.msgRpcConnectionsStartOnlyAfterYouEnableA,
    MessageCode.msgGetStartedWithWallet => strings.msgGetStartedWithWallet,
    MessageCode.msgChooseHowToGetStarted => strings.msgChooseHowToGetStarted,
    MessageCode.msgCreateWallet => strings.msgCreateWallet,
    MessageCode.msgImportRecoveryPhrase => strings.msgImportRecoveryPhrase,
    MessageCode.msgImportPrivateKey => strings.msgImportPrivateKey,
    MessageCode.msgImportPrivateKeyFile => strings.msgImportPrivateKeyFile,
    MessageCode.msgCsvTsvColumnsChainPrivateKey =>
      strings.msgCsvTsvColumnsChainPrivateKey,
    MessageCode.msgKeepYourRecoveryPhraseAndPrivateKeysSafe =>
      strings.msgKeepYourRecoveryPhraseAndPrivateKeysSafe,
    MessageCode.msgNetworksAndRpc => strings.msgNetworksAndRpc,
    MessageCode.msgNoNetworkSelectedEnableANetworkToQuery =>
      strings.msgNoNetworkSelectedEnableANetworkToQuery,
    MessageCode.msgTransactionNetwork => strings.msgTransactionNetwork,
    MessageCode.msgTestnet => strings.msgTestnet,
    MessageCode.msgMainnet => strings.msgMainnet,
    MessageCode.endpointCount => strings.endpointCount(arguments[0] as int),
    MessageCode.msgActiveEndpoint => strings.msgActiveEndpoint,
    MessageCode.msgSyncingMore => strings.msgSyncingMore,
    MessageCode.msgRpcConnected => strings.msgRpcConnected,
    MessageCode.msgNotSynced => strings.msgNotSynced,
    MessageCode.msgEditRpc => strings.msgEditRpc,
    MessageCode.msgAddCustomNetwork => strings.msgAddCustomNetwork,
    MessageCode.msgWalletSecurity => strings.msgWalletSecurity,
    MessageCode.msgAccountSource => strings.msgAccountSource,
    MessageCode.msgDerivationPath => strings.msgDerivationPath,
    MessageCode.msgPrivateKeyImport => strings.msgPrivateKeyImport,
    MessageCode.msgRecoveryPhrasesAndPrivateKeysRemainInSecure =>
      strings.msgRecoveryPhrasesAndPrivateKeysRemainInSecure,
    MessageCode.msgWalletManagement => strings.msgWalletManagement,
    MessageCode.walletAndAccountSummary => strings.walletAndAccountSummary(
      arguments[0] as int,
      arguments[1] as int,
    ),
    MessageCode.msgManageWalletsAndAccounts =>
      strings.msgManageWalletsAndAccounts,
    MessageCode.msgChooseFileToImport => strings.msgChooseFileToImport,
    MessageCode.msgBackup => strings.msgBackup,
    MessageCode.msgIcloudGoogleDriveBackupNotConnected =>
      strings.msgIcloudGoogleDriveBackupNotConnected,
    MessageCode.msgKeepYourRecoveryCredentialsInASecureOffline =>
      strings.msgKeepYourRecoveryCredentialsInASecureOffline,
    MessageCode.msgOnchainAssets => strings.msgOnchainAssets,
    MessageCode.msgViewAll => strings.msgViewAll,
    MessageCode.msgAssets => strings.msgAssets,
    MessageCode.msgBalance => strings.msgBalance,
    MessageCode.msgStatus => strings.msgStatus,
    MessageCode.msgSynced => strings.msgSynced,
    MessageCode.msgNetworksQueried => strings.msgNetworksQueried(
      localized(context, arguments[0]),
      arguments[1] as int,
    ),
    MessageCode.msgQueriedBalanceDistribution =>
      strings.msgQueriedBalanceDistribution,
    MessageCode.msgStablecoinOverview => strings.msgStablecoinOverview,
    MessageCode.msgRefreshStablecoins => strings.msgRefreshStablecoins,
    MessageCode.msgCurrentAccount => strings.msgCurrentAccount(
      localized(context, arguments[0]),
    ),
    MessageCode.msgTrackedTotal => strings.msgTrackedTotal(
      localized(context, arguments[0]),
    ),
    MessageCode.msgQueriedSubtotal => strings.msgQueriedSubtotal,
    MessageCode.msgNetworksQueriedMore => strings.msgNetworksQueriedMore(
      localized(context, arguments[0]),
      arguments[1] as int,
      localized(context, arguments[2]),
    ),
    MessageCode.msgFullySynced => strings.msgFullySynced,
    MessageCode.msgCoverageIsIncomplete => strings.msgCoverageIsIncomplete,
    MessageCode.msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities =>
      strings.msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities,
    MessageCode.msgOnlyAddedCircleUsdcContractsAreCountedBy =>
      strings.msgOnlyAddedCircleUsdcContractsAreCountedBy,
    MessageCode.msgViewNetworkDistribution =>
      strings.msgViewNetworkDistribution,
    MessageCode.msgByNetwork => strings.msgByNetwork(
      localized(context, arguments[0]),
    ),
    MessageCode.msgEnableQueryNetworks => strings.msgEnableQueryNetworks,
    MessageCode.msgNoAddedYet => strings.msgNoAddedYet(
      localized(context, arguments[0]),
    ),
    MessageCode.msgAddTokensToViewTheirNetworkDistribution =>
      strings.msgAddTokensToViewTheirNetworkDistribution,
    MessageCode.msgEnableStablecoinNetworks =>
      strings.msgEnableStablecoinNetworks,
    MessageCode.msgOfQueriedBalances => strings.msgOfQueriedBalances(
      localized(context, arguments[0]),
    ),
    MessageCode.msgZeroBalance => strings.msgZeroBalance,
    MessageCode.msgAwaitingOnchainBalance => strings.msgAwaitingOnchainBalance,
    MessageCode.msgCopyReceiveAddress => strings.msgCopyReceiveAddress,
    MessageCode.msgQuerying => strings.msgQuerying,
    MessageCode.msgCurrentAccountReceiveAddress =>
      strings.msgCurrentAccountReceiveAddress,
    MessageCode.msgTokenContractDecimals => strings.msgTokenContractDecimals(
      arguments[0] as int,
    ),
    MessageCode.msgCheckTheNetworkAndContractBeforeReceivingToken =>
      strings.msgCheckTheNetworkAndContractBeforeReceivingToken,
    MessageCode.msgCannotReadThisTokenCheckTheNetworkContract =>
      strings.msgCannotReadThisTokenCheckTheNetworkContract,
    MessageCode.msgAddingATokenChangesItsDisplayOnlyIt =>
      strings.msgAddingATokenChangesItsDisplayOnlyIt,
    MessageCode.msgCommonStablecoins => strings.msgCommonStablecoins,
    MessageCode.msgAddedCustomTokens => strings.msgAddedCustomTokens,
    MessageCode.msgHideToken => strings.msgHideToken,
    MessageCode.msgAddCustomToken => strings.msgAddCustomToken,
    MessageCode.msgTokenContractAddress => strings.msgTokenContractAddress,
    MessageCode.msgProcessing => strings.msgProcessing,
    MessageCode.msgReadTokenInfo => strings.msgReadTokenInfo,
    MessageCode.msgDecimals => strings.msgDecimals(
      localized(context, arguments[0]),
      arguments[1] as int,
    ),
    MessageCode.msgCustomTokensWithMatchingTickersAreNotAutomatically =>
      strings.msgCustomTokensWithMatchingTickersAreNotAutomatically,
    MessageCode.msgMatchesAPresetContractItWillBeIncluded =>
      strings.msgMatchesAPresetContractItWillBeIncluded(
        localized(context, arguments[0]),
      ),
    MessageCode.msgAdded => strings.msgAdded,
    MessageCode.msgConfirmAddition => strings.msgConfirmAddition,
    MessageCode.msgSwitchTheme => strings.msgSwitchTheme,
    MessageCode.msgClose => strings.msgClose,
    MessageCode.msgSelectWallet => strings.msgSelectWallet,
    MessageCode.msgRecoveryPhraseWallet => strings.msgRecoveryPhraseWallet,
    MessageCode.msgSwap => strings.msgSwap,
    MessageCode.msgMakeSureTheReceivingNetworkMatchesTheNetwork =>
      strings.msgMakeSureTheReceivingNetworkMatchesTheNetwork,
    MessageCode.msgEnableMultipleNetworksToViewBalancesOnlySelected =>
      strings.msgEnableMultipleNetworksToViewBalancesOnlySelected,
    MessageCode.msgDisconnectAllNetworks => strings.msgDisconnectAllNetworks,
    MessageCode.msgSaveNetworkSelection => strings.msgSaveNetworkSelection,
    MessageCode.msgTapANetworkNameToUseItFor =>
      strings.msgTapANetworkNameToUseItFor,
    MessageCode.msgUseForTransactions => strings.msgUseForTransactions,
    MessageCode.msgRecoveryPhraseVerificationFailedCheckWordsAnd =>
      strings.msgRecoveryPhraseVerificationFailedCheckWordsAnd,
    MessageCode.msgVerifyRecoveryPhrase => strings.msgVerifyRecoveryPhrase,
    MessageCode.msgWriteDownRecoveryPhrase =>
      strings.msgWriteDownRecoveryPhrase,
    MessageCode.msgVerifyAndOpenWallet => strings.msgVerifyAndOpenWallet,
    MessageCode.msgIWroteItDownVerify => strings.msgIWroteItDownVerify,
    MessageCode.msgWrittenVerify => strings.msgWrittenVerify,
    MessageCode.msgWriteDownVerify => strings.msgWriteDownVerify,
    MessageCode.msgEnterTheRequestedWordsToFinishCreatingYour =>
      strings.msgEnterTheRequestedWordsToFinishCreatingYour,
    MessageCode.msgWriteDownTheseWordsInOrderAndKeep =>
      strings.msgWriteDownTheseWordsInOrderAndKeep,
    MessageCode.msgWord => strings.msgWord(localized(context, arguments[0])),
    MessageCode.msgDoNotScreenshotCopyOrSendYourRecovery =>
      strings.msgDoNotScreenshotCopyOrSendYourRecovery,
    MessageCode.msgImportWallet => strings.msgImportWallet,
    MessageCode.msgEnterYourExistingRecoveryPhraseSeparatingWordsWith =>
      strings.msgEnterYourExistingRecoveryPhraseSeparatingWordsWith,
    MessageCode.msgImport => strings.msgImport,
    MessageCode.msgEnterYourOrWordRecoveryPhrase =>
      strings.msgEnterYourOrWordRecoveryPhrase,
    MessageCode.msgChooseANetworkToViewAfterImporting =>
      strings.msgChooseANetworkToViewAfterImporting,
    MessageCode.msgPrivateKeyImportFailedPleaseTryAgain =>
      strings.msgPrivateKeyImportFailedPleaseTryAgain,
    MessageCode.msgRestoreAnAccountWithAnEvmTronHexadecimal =>
      strings.msgRestoreAnAccountWithAnEvmTronHexadecimal,
    MessageCode.msgImporting => strings.msgImporting,
    MessageCode.msgImportAndOpenWallet => strings.msgImportAndOpenWallet,
    MessageCode.msgSelectANetwork => strings.msgSelectANetwork,
    MessageCode.msgPrivateKey => strings.msgPrivateKey,
    MessageCode.msgHexadecimalCharactersOptionallyPrefixedWithX =>
      strings.msgHexadecimalCharactersOptionallyPrefixedWithX,
    MessageCode.msgShowPrivateKey => strings.msgShowPrivateKey,
    MessageCode.msgHidePrivateKey => strings.msgHidePrivateKey,
    MessageCode.msgPrivateKeysStayInSecureDeviceStorageAfter =>
      strings.msgPrivateKeysStayInSecureDeviceStorageAfter,
    MessageCode.msgImportResults => strings.msgImportResults,
    MessageCode.msgDone => strings.msgDone,
    MessageCode.msgImportedSkippedOrFailed =>
      strings.msgImportedSkippedOrFailed(
        localized(context, arguments[0]),
        localized(context, arguments[1]),
      ),
    MessageCode.msgRow => strings.msgRow(
      localized(context, arguments[0]),
      localized(context, arguments[1]),
    ),
    MessageCode.msgAmountMustBeGreaterThanZero =>
      strings.msgAmountMustBeGreaterThanZero,
    MessageCode.msgAmountExceedsTheAvailableBalance =>
      strings.msgAmountExceedsTheAvailableBalance,
    MessageCode.msgSendMore => strings.msgSendMore(
      localized(context, arguments[0]),
    ),
    MessageCode.msgSignedOnThisDevice => strings.msgSignedOnThisDevice(
      localized(context, arguments[0]),
      localized(context, arguments[1]),
    ),
    MessageCode.msgCheckTheTransactionStatusFirst =>
      strings.msgCheckTheTransactionStatusFirst,
    MessageCode.msgSignAndBroadcast => strings.msgSignAndBroadcast,
    MessageCode.msgRecipientAddress => strings.msgRecipientAddress,
    MessageCode.msgAmount => strings.msgAmount(
      localized(context, arguments[0]),
    ),
    MessageCode.msgAvailable => strings.msgAvailable(
      localized(context, arguments[0]),
      localized(context, arguments[1]),
      localized(context, arguments[2]),
    ),
    MessageCode.msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay =>
      strings.msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay,
    MessageCode.msgGasFeesAreChargedSeparately =>
      strings.msgGasFeesAreChargedSeparately,
    MessageCode.msgTransactionHash => strings.msgTransactionHash(
      localized(context, arguments[0]),
    ),
    MessageCode.msgSettings => strings.msgSettings,
    MessageCode.msgYourKeysStayWithYouTransactionsAreSigned =>
      strings.msgYourKeysStayWithYouTransactionsAreSigned,
    MessageCode.msgHome => strings.msgHome,
    MessageCode.msgChooseNetwork => strings.msgChooseNetwork,
    MessageCode.msgChainIdMustBeAValidPositiveInteger =>
      strings.msgChainIdMustBeAValidPositiveInteger,
    MessageCode.msgThisChainIdAlreadyExistsEditItsRpc =>
      strings.msgThisChainIdAlreadyExistsEditItsRpc,
    MessageCode.msgConfigureAtLeastOneRpcUrl =>
      strings.msgConfigureAtLeastOneRpcUrl,
    MessageCode.msgTronHttpApiIsAvailableTheMainnetGenesis =>
      strings.msgTronHttpApiIsAvailableTheMainnetGenesis,
    MessageCode.msgRpcIsAvailableAndItsChainIdMatches =>
      strings.msgRpcIsAvailableAndItsChainIdMatches,
    MessageCode.msgConnectionCheckFailedCheckTheRpcUrlNetwork =>
      strings.msgConnectionCheckFailedCheckTheRpcUrlNetwork,
    MessageCode.msgCouldNotSaveNetworkSettingsPleaseTryAgain =>
      strings.msgCouldNotSaveNetworkSettingsPleaseTryAgain,
    MessageCode.msgAddCustomEvmNetwork => strings.msgAddCustomEvmNetwork,
    MessageCode.msgEditNetworkAndRpc => strings.msgEditNetworkAndRpc,
    MessageCode.msgEnterOneRpcUrlPerLineInPriority =>
      strings.msgEnterOneRpcUrlPerLineInPriority,
    MessageCode.msgSaving => strings.msgSaving,
    MessageCode.msgSaveNetworkSettings => strings.msgSaveNetworkSettings,
    MessageCode.msgNetworkName => strings.msgNetworkName,
    MessageCode.msgForExampleBase => strings.msgForExampleBase,
    MessageCode.msgForExample => strings.msgForExample,
    MessageCode.msgNativeCurrencySymbol => strings.msgNativeCurrencySymbol,
    MessageCode.msgForExampleEth => strings.msgForExampleEth,
    MessageCode.msgHttpsPrimaryEndpointHttpsBackupEndpoint =>
      strings.msgHttpsPrimaryEndpointHttpsBackupEndpoint,
    MessageCode.msgOneUrlPerLineOrderSetsPriorityDuplicates =>
      strings.msgOneUrlPerLineOrderSetsPriorityDuplicates,
    MessageCode.msgRestoreBuiltInFreeEndpoints =>
      strings.msgRestoreBuiltInFreeEndpoints,
    MessageCode.msgBlockExplorerUrlOptional =>
      strings.msgBlockExplorerUrlOptional,
    MessageCode.msgChecking => strings.msgChecking,
    MessageCode.msgCheckRpcConnection => strings.msgCheckRpcConnection,
    MessageCode.msgOperationFailedPleaseTryAgain =>
      strings.msgOperationFailedPleaseTryAgain,
    MessageCode.msgRenameAccount => strings.msgRenameAccount,
    MessageCode.msgRenameWallet => strings.msgRenameWallet,
    MessageCode.walletAccountCount => strings.walletAccountCount(
      localized(context, arguments[0]),
      arguments[1] as int,
    ),
    MessageCode.msgPrivateKeyWallet => strings.msgPrivateKeyWallet,
    MessageCode.msgCopyAccountAddress => strings.msgCopyAccountAddress,
    MessageCode.msgAddAccount => strings.msgAddAccount,
    MessageCode.walletAndAccountCount => strings.walletAndAccountCount(
      arguments[0] as int,
      arguments[1] as int,
    ),
    MessageCode.msgARecoveryPhraseWalletCanHaveMultipleAccounts =>
      strings.msgARecoveryPhraseWalletCanHaveMultipleAccounts,
    MessageCode.msgSearchWalletsAccountsOrAddresses =>
      strings.msgSearchWalletsAccountsOrAddresses,
    MessageCode.msgNoMatchingWalletsOrAccounts =>
      strings.msgNoMatchingWalletsOrAccounts,
    MessageCode.msgExistingWalletsAreKeptYouCanSwitchAt =>
      strings.msgExistingWalletsAreKeptYouCanSwitchAt,
    MessageCode.msgRestoreAWalletAndAddDerivedAccounts =>
      strings.msgRestoreAWalletAndAddDerivedAccounts,
    MessageCode.msgImportOneEvmTronAccount =>
      strings.msgImportOneEvmTronAccount,
    MessageCode.msgImportMultipleAccountsFromCsvTsv =>
      strings.msgImportMultipleAccountsFromCsvTsv,
    MessageCode.msgNamesMustContainCharacters =>
      strings.msgNamesMustContainCharacters,
    MessageCode.msgSaveName => strings.msgSaveName,
    MessageCode.msgName => strings.msgName,
    MessageCode.msgCustomToken => strings.msgCustomToken,
    MessageCode.msgInvalidTokenInformationReadTheContractAgain =>
      strings.msgInvalidTokenInformationReadTheContractAgain,
    MessageCode.msgTokenSymbolContainsInvalidCharacters =>
      strings.msgTokenSymbolContainsInvalidCharacters,
    MessageCode.msgTheTokenContractReturnedAnInvalidValue =>
      strings.msgTheTokenContractReturnedAnInvalidValue,
    MessageCode.msgInvalidTokenSymbol => strings.msgInvalidTokenSymbol,
    MessageCode.msgOnlyTokensWithDecimalsAreSupported =>
      strings.msgOnlyTokensWithDecimalsAreSupported,
    MessageCode.msgCannotReadTheTokenSymbol =>
      strings.msgCannotReadTheTokenSymbol,
    MessageCode.msgInvalidTokenSymbolEncoding =>
      strings.msgInvalidTokenSymbolEncoding,
    MessageCode.msgInvalidTokenSymbolLength =>
      strings.msgInvalidTokenSymbolLength,
    MessageCode.msgCannotReadTheSavedTokenListExistingRecords =>
      strings.msgCannotReadTheSavedTokenListExistingRecords,
    MessageCode.msgThisTokenHasAlreadyBeenAddedOnThis =>
      strings.msgThisTokenHasAlreadyBeenAddedOnThis,
    MessageCode.msgNetworkDisabled => strings.msgNetworkDisabled,
    MessageCode.msgQueryingMore => strings.msgQueryingMore,
    MessageCode.msgQueryFailed => strings.msgQueryFailed,
    MessageCode.msgTronMainnetIdentifierDoesNotMatchTheProtocol =>
      strings.msgTronMainnetIdentifierDoesNotMatchTheProtocol,
    MessageCode.msgEnterTheNetworkNameAndNativeCurrencySymbol =>
      strings.msgEnterTheNetworkNameAndNativeCurrencySymbol,
    MessageCode.msgEnterAValidHttpHttpsUrl =>
      strings.msgEnterAValidHttpHttpsUrl,
    MessageCode.msgCannotAccessKeychainQuitRebuildAndRunThe =>
      strings.msgCannotAccessKeychainQuitRebuildAndRunThe,
    MessageCode.msgCannotAccessSecureDeviceStorageCheckThatKeychain =>
      strings.msgCannotAccessSecureDeviceStorageCheckThatKeychain,
    MessageCode.msgCannotReadSavedNetworkSettingsCheckTheStored =>
      strings.msgCannotReadSavedNetworkSettingsCheckTheStored,
    MessageCode.msgAccountIndexIsOutOfRange =>
      strings.msgAccountIndexIsOutOfRange,
    MessageCode.msgInvalidRecoveryPhraseCheckTheWordsAndTheir =>
      strings.msgInvalidRecoveryPhraseCheckTheWordsAndTheir,
    MessageCode.msgCannotDeriveTheEvmPrivateKey =>
      strings.msgCannotDeriveTheEvmPrivateKey,
    MessageCode.msgInvalidPrivateKeyEnterHexadecimalCharacters =>
      strings.msgInvalidPrivateKeyEnterHexadecimalCharacters,
    MessageCode.msgPrivateKeyValueIsOutOfRange =>
      strings.msgPrivateKeyValueIsOutOfRange,
    MessageCode.msgInvalidPrivateKeyCannotCreateAnAccount =>
      strings.msgInvalidPrivateKeyCannotCreateAnAccount,
    MessageCode.msgBinance => strings.msgBinance,
    MessageCode.msgTron => strings.msgTron,
    MessageCode.msgRpcNetworkMismatchExpectedReceived =>
      strings.msgRpcNetworkMismatchExpectedReceived(
        localized(context, arguments[0]),
        localized(context, arguments[1]),
      ),
    MessageCode.msgAllRpcEndpointsAreUnavailableTryAgainLater =>
      strings.msgAllRpcEndpointsAreUnavailableTryAgainLater(
        arguments[0] as int,
      ),
    MessageCode.msgTheTokenAndNetworkDoNotMatch =>
      strings.msgTheTokenAndNetworkDoNotMatch,
    MessageCode.msgTheRpcReturnedADifferentTransactionHash =>
      strings.msgTheRpcReturnedADifferentTransactionHash,
    MessageCode.msgBroadcastStatusIsUncertainCheckTheTransactionHash =>
      strings.msgBroadcastStatusIsUncertainCheckTheTransactionHash,
    MessageCode.msgEnterAValidAmountWithAtMostDecimal =>
      strings.msgEnterAValidAmountWithAtMostDecimal(arguments[0] as int),
    MessageCode.msgMainWallet => strings.msgMainWallet,
    MessageCode.msgNoNetworkSelected => strings.msgNoNetworkSelected,
    MessageCode.msgChooseANetworkToView => strings.msgChooseANetworkToView,
    MessageCode.msgRpcNotConnected => strings.msgRpcNotConnected,
    MessageCode.msgNativeAsset => strings.msgNativeAsset,
    MessageCode.msgConnectionFailed => strings.msgConnectionFailed,
    MessageCode.msgAwaitingSync => strings.msgAwaitingSync,
    MessageCode.msgWallet => strings.msgWallet,
    MessageCode.msgRpcRequestTimedOutCheckTheUrlOr =>
      strings.msgRpcRequestTimedOutCheckTheUrlOr,
    MessageCode.msgRpcRequestFailedCheckTheNetworkEndpointOr =>
      strings.msgRpcRequestFailedCheckTheNetworkEndpointOr,
    MessageCode.msgCouldNotConnectToEditRpcSettingsOr =>
      strings.msgCouldNotConnectToEditRpcSettingsOr(
        localized(context, arguments[0]),
      ),
    MessageCode.msgTheAccountHasChangedReopenThisAsset =>
      strings.msgTheAccountHasChangedReopenThisAsset,
    MessageCode.msgCouldNotSaveNetworkSelectionPleaseTryAgain =>
      strings.msgCouldNotSaveNetworkSelectionPleaseTryAgain,
    MessageCode.msgPrivateKeyAccountImported =>
      strings.msgPrivateKeyAccountImported,
    MessageCode.msgTheAccountWasSavedButCouldNotBe =>
      strings.msgTheAccountWasSavedButCouldNotBe,
    MessageCode.msgCannotReadThisFile => strings.msgCannotReadThisFile,
    MessageCode.msgNoImportableRowsTheHeaderMustContainChain =>
      strings.msgNoImportableRowsTheHeaderMustContainChain,
    MessageCode.importedRowSummary => strings.importedRowSummary(
      arguments[0] as int,
      localized(context, arguments[1]),
    ),
    MessageCode.msgFailed => strings.msgFailed(
      localized(context, arguments[0]),
    ),
    MessageCode.msgChain => strings.msgChain,
    MessageCode.msgSelectedConnectingToRpc =>
      strings.msgSelectedConnectingToRpc(localized(context, arguments[0])),
    MessageCode.msgNetworkSettingsSaved => strings.msgNetworkSettingsSaved(
      localized(context, arguments[0]),
    ),
    MessageCode.msgSwapsAreNotConnectedNoOrderOrSignature =>
      strings.msgSwapsAreNotConnectedNoOrderOrSignature,
    MessageCode.msgUnavailable => strings.msgUnavailable,
    MessageCode.msgAddressCopied => strings.msgAddressCopied,
    MessageCode.msgSelectANetworkBeforeSending =>
      strings.msgSelectANetworkBeforeSending,
    MessageCode.msgTransactionBroadcast => strings.msgTransactionBroadcast(
      localized(context, arguments[0]),
    ),
    MessageCode.msgWalletOperationFailedPleaseTryAgain =>
      strings.msgWalletOperationFailedPleaseTryAgain,
    MessageCode.msgMostRecentlyBroadcastTransaction =>
      strings.msgMostRecentlyBroadcastTransaction,
    MessageCode.msgEnterAValidTronAddressStartingWithT =>
      strings.msgEnterAValidTronAddressStartingWithT,
    MessageCode.msgTheTronEndpointReturnedAnErrorTryAnother =>
      strings.msgTheTronEndpointReturnedAnErrorTryAnother,
    MessageCode.msgTronNetworkMismatchAMainnetEndpointIsRequired =>
      strings.msgTronNetworkMismatchAMainnetEndpointIsRequired,
    MessageCode.msgAllTronEndpointsAreUnavailableTryAgainLater =>
      strings.msgAllTronEndpointsAreUnavailableTryAgainLater(
        arguments[0] as int,
      ),
    MessageCode.msgTrcQueryFailedCheckTheContractAndEndpoint =>
      strings.msgTrcQueryFailedCheckTheContractAndEndpoint,
    MessageCode.msgTheTronEndpointReturnedADifferentAccountS =>
      strings.msgTheTronEndpointReturnedADifferentAccountS,
    MessageCode.msgTheTronEndpointReturnedAnInvalidBalance =>
      strings.msgTheTronEndpointReturnedAnInvalidBalance,
    MessageCode.msgTrxAmountIsOutOfRange => strings.msgTrxAmountIsOutOfRange,
    MessageCode.msgTronReferenceBlockIsInvalidOrStaleCheck =>
      strings.msgTronReferenceBlockIsInvalidOrStaleCheck,
    MessageCode.msgTheTronEndpointDidNotConfirmTheBroadcast =>
      strings.msgTheTronEndpointDidNotConfirmTheBroadcast,
    MessageCode.msgCannotReadTheWalletBookCheckSecureStorage =>
      strings.msgCannotReadTheWalletBookCheckSecureStorage,
    MessageCode.msgAccount => strings.msgAccount,
    MessageCode.msgPrivateKeyAccount => strings.msgPrivateKeyAccount(
      localized(context, arguments[0]),
    ),
    MessageCode.msgSavedPrivateKeyAccountDataIsCorrupted =>
      strings.msgSavedPrivateKeyAccountDataIsCorrupted,
    MessageCode.msgWalletMore => strings.msgWalletMore(
      localized(context, arguments[0]),
    ),
    MessageCode.msgUnsupportedNetwork => strings.msgUnsupportedNetwork,
    MessageCode.msgDuplicateEntrySkipped => strings.msgDuplicateEntrySkipped,
    MessageCode.msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts =>
      strings.msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts,
    MessageCode.msgAccountMore => strings.msgAccountMore(
      localized(context, arguments[0]),
    ),
    MessageCode.msgAccountNotFound => strings.msgAccountNotFound,
    MessageCode.msgWalletNotFound => strings.msgWalletNotFound,
    MessageCode.msgUnexpectedErrorPleaseTryAgain =>
      strings.msgUnexpectedErrorPleaseTryAgain,
    MessageCode.msgSelfCustodyEvmTron => strings.msgSelfCustodyEvmTron,
    MessageCode.portfolioOverview => strings.portfolioOverview,
    MessageCode.portfolioByCoin => strings.portfolioByCoin,
    MessageCode.portfolioReferenceValue => strings.portfolioReferenceValue,
    MessageCode.portfolioValuedSubtotal => strings.portfolioValuedSubtotal,
    MessageCode.portfolioAllAddresses => strings.portfolioAllAddresses,
    MessageCode.portfolioAllNetworks => strings.portfolioAllNetworks,
    MessageCode.portfolioAllAssets => strings.portfolioAllAssets,
    MessageCode.portfolioSimple => strings.portfolioSimple,
    MessageCode.portfolioDetailed => strings.portfolioDetailed,
    MessageCode.portfolioDisplaySettings => strings.portfolioDisplaySettings,
    MessageCode.portfolioDisplayMode => strings.portfolioDisplayMode,
    MessageCode.portfolioInitialCount => strings.portfolioInitialCount,
    MessageCode.portfolioAll => strings.portfolioAll,
    MessageCode.portfolioSort => strings.portfolioSort,
    MessageCode.portfolioSortValue => strings.portfolioSortValue,
    MessageCode.portfolioStableFirst => strings.portfolioStableFirst,
    MessageCode.portfolioSortName => strings.portfolioSortName,
    MessageCode.portfolioHideZero => strings.portfolioHideZero,
    MessageCode.portfolioShowSpam => strings.portfolioShowSpam,
    MessageCode.portfolioExpand => strings.portfolioExpand(
      localized(context, arguments[0]),
    ),
    MessageCode.portfolioCollapse => strings.portfolioCollapse,
    MessageCode.portfolioSelectCoin => strings.portfolioSelectCoin,
    MessageCode.portfolioSearch => strings.portfolioSearch,
    MessageCode.portfolioChainCount => strings.portfolioChainCount(
      arguments[0] as int,
    ),
    MessageCode.portfolioCoinCount => strings.portfolioCoinCount(
      arguments[0] as int,
    ),
    MessageCode.portfolioInformation => strings.portfolioInformation,
    MessageCode.portfolioValueExplanation => strings.portfolioValueExplanation,
    MessageCode.portfolioVersionExplanation =>
      strings.portfolioVersionExplanation,
    MessageCode.portfolioCoverage => strings.portfolioCoverage(
      localized(context, arguments[0]),
      localized(context, arguments[1]),
      localized(context, arguments[2]),
    ),
    MessageCode.portfolioPartial => strings.portfolioPartial,
    MessageCode.portfolioStalePrices => strings.portfolioStalePrices,
    MessageCode.portfolioNoPrice => strings.portfolioNoPrice,
    MessageCode.portfolioNoAssets => strings.portfolioNoAssets,
    MessageCode.portfolioShowZero => strings.portfolioShowZero,
    MessageCode.portfolioRefresh => strings.portfolioRefresh,
    MessageCode.portfolioSourceRpc => strings.portfolioSourceRpc,
    MessageCode.portfolioSourceIndexer => strings.portfolioSourceIndexer,
    MessageCode.portfolioPriceSource => strings.portfolioPriceSource,
    MessageCode.portfolioUpdated => strings.portfolioUpdated(
      localized(context, arguments[0]),
    ),
    MessageCode.portfolioTestnetExcluded => strings.portfolioTestnetExcluded,
    MessageCode.discoveryServices => strings.discoveryServices,
    MessageCode.discoveryConfigure => strings.discoveryConfigure,
    MessageCode.discoveryNotConfigured => strings.discoveryNotConfigured,
    MessageCode.discoveryQuerying => strings.discoveryQuerying,
    MessageCode.discoveryPartial => strings.discoveryPartial,
    MessageCode.discoveryUnavailable => strings.discoveryUnavailable,
    MessageCode.discoveryLoadMore => strings.discoveryLoadMore,
    MessageCode.discoveryConfigureProvider =>
      strings.discoveryConfigureProvider(localized(context, arguments[0])),
    MessageCode.discoveryGetKey => strings.discoveryGetKey,
    MessageCode.discoveryDocs => strings.discoveryDocs,
    MessageCode.discoveryPlans => strings.discoveryPlans,
    MessageCode.discoveryApiKey => strings.discoveryApiKey,
    MessageCode.discoveryKeyHint => strings.discoveryKeyHint,
    MessageCode.discoveryKeyRequired => strings.discoveryKeyRequired,
    MessageCode.discoveryPrivacy => strings.discoveryPrivacy,
    MessageCode.discoveryAssignments => strings.discoveryAssignments,
    MessageCode.discoveryChooseNetwork => strings.discoveryChooseNetwork,
    MessageCode.discoveryTest => strings.discoveryTest,
    MessageCode.discoveryConnected => strings.discoveryConnected,
    MessageCode.discoverySaveEnable => strings.discoverySaveEnable,
    MessageCode.discoveryEnabled => strings.discoveryEnabled,
    MessageCode.discoveryDisabled => strings.discoveryDisabled,
    MessageCode.discoveryDisable => strings.discoveryDisable,
    MessageCode.discoveryDelete => strings.discoveryDelete,
    MessageCode.discoveryEdit => strings.discoveryEdit,
    MessageCode.discoveryUnauthorized => strings.discoveryUnauthorized,
    MessageCode.discoveryLimited => strings.discoveryLimited,
    MessageCode.discoveryResponseInvalid => strings.discoveryResponseInvalid,
    MessageCode.discoveryRequestFailed => strings.discoveryRequestFailed,
    MessageCode.discoverySettingsUnreadable =>
      strings.discoverySettingsUnreadable,
    MessageCode.discoverySaveFailed => strings.discoverySaveFailed,
    MessageCode.discoveryUnsupported => strings.discoveryUnsupported,
    MessageCode.discoveryWatch => strings.discoveryWatch,
    MessageCode.discoveryWatched => strings.discoveryWatched,
    MessageCode.discoveryMoralisGuide => strings.discoveryMoralisGuide,
    MessageCode.discoveryAlchemyGuide => strings.discoveryAlchemyGuide,
    MessageCode.discoveryTronGridGuide => strings.discoveryTronGridGuide,
    MessageCode.discoveryLinkCopied => strings.discoveryLinkCopied,
    MessageCode.discoveryNoEnabledNetworks =>
      strings.discoveryNoEnabledNetworks,
    MessageCode.portfolioAddressDetails => strings.portfolioAddressDetails,
    MessageCode.portfolioBalanceStatus => strings.portfolioBalanceStatus,
    MessageCode.portfolioSpam => strings.portfolioSpam,
    MessageCode.portfolioNoCoin => strings.portfolioNoCoin,
    MessageCode.omniHeader => strings.omniHeader,
    MessageCode.omniInvalidEncoding => strings.omniInvalidEncoding,
    MessageCode.omniMalformedCsv => strings.omniMalformedCsv(
      arguments[0] as int,
    ),
    MessageCode.omniColumnCount => strings.omniColumnCount,
    MessageCode.omniInvalidStatus => strings.omniInvalidStatus,
    MessageCode.omniInvalidIdentity => strings.omniInvalidIdentity,
    MessageCode.omniInvalidAddress => strings.omniInvalidAddress,
    MessageCode.omniAddressMismatch => strings.omniAddressMismatch,
    MessageCode.omniWalletChanged => strings.omniWalletChanged,
    MessageCode.omniStorageError => strings.omniStorageError,
    MessageCode.omniRecordTooLarge => strings.omniRecordTooLarge,
    MessageCode.transferInvalidRecipient => strings.transferInvalidRecipient,
    MessageCode.transferAmountTooLarge => strings.transferAmountTooLarge,
    MessageCode.transferSimulationFailed => strings.transferSimulationFailed,
    MessageCode.transferTokenDecimalsChanged =>
      strings.transferTokenDecimalsChanged,
    MessageCode.transferFeeUnavailable => strings.transferFeeUnavailable,
    MessageCode.transferInsufficientFee => strings.transferInsufficientFee,
    MessageCode.transferReviewExpired => strings.transferReviewExpired,
    MessageCode.manageWalletChanged => strings.manageWalletChanged,
    MessageCode.discoveryNotConfiguredShort =>
      strings.discoveryNotConfiguredShort,
  };
}

String localized(BuildContext context, Object? value) {
  if (value is WalletMessage) return tr(context, value.code, value.arguments);
  if (value is WalletInputException) return localized(context, value.message);
  if (value is Exception || value is Error) {
    return tr(context, MessageCode.msgUnexpectedErrorPleaseTryAgain);
  }
  if (value is int) {
    return NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);
  }
  return value?.toString() ?? '';
}

WalletMessage walletMessage(Object error) => error is WalletInputException
    ? error.message
    : const WalletMessage(MessageCode.msgUnexpectedErrorPleaseTryAgain);

String displayQuantity(BuildContext context, String value) {
  // Supported locales share Latin digits, decimal dots and comma grouping.
  // Work on strings: never round a BigInt amount through double/NumberFormat.
  final match = RegExp(r'^(< )?(\d+)(\.\d+)?(.*)$').firstMatch(value);
  if (match == null) return value;
  final grouped = match[2]!.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '${match[1] ?? ''}$grouped${match[3] ?? ''}${match[4] ?? ''}';
}

String tokenRepresentation(BuildContext context, TokenDefinition token) =>
    token.trustedFamily == null
    ? tr(context, MessageCode.msgCustomToken)
    : token.representation;
