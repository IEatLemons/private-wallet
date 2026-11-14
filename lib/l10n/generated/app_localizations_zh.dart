// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '星舟钱包';

  @override
  String get msgSyncing => '同步中…';

  @override
  String get msgRefreshAssets => '刷新资产';

  @override
  String get msgManageNetworks => '管理网络';

  @override
  String get msgStablecoins => '稳定币';

  @override
  String get msgOtherCoins => '其他币种';

  @override
  String get msgAddTokens => '添加币种';

  @override
  String get msgSearchAssetsOrNetworks => '搜索资产或网络';

  @override
  String get msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear =>
      '原生币用于支付网络费用。未同步余额显示为 —。';

  @override
  String get msgTokensAreIdentifiedByNetworkAndContractMatching =>
      '按网络与合约区分代币；同名代币不会自动合并。';

  @override
  String get msgNoMatchingAssets => '没有匹配的资产。';

  @override
  String msgAssetDetails(String p0) {
    return '$p0 资产详情';
  }

  @override
  String get msgSend => '发送';

  @override
  String get msgReceive => '接收';

  @override
  String get msgUseThisNetwork => '设为当前链';

  @override
  String get msgRefreshBalance => '刷新余额';

  @override
  String get msgNetwork => '网络';

  @override
  String get msgWalletAddress => '钱包地址';

  @override
  String get msgRpcUrl => 'RPC 地址';

  @override
  String get msgBlockExplorer => '区块浏览器';

  @override
  String get msgExplorerLinkCopied => '浏览器链接已复制';

  @override
  String get msgCopyExplorerLink => '复制浏览器链接';

  @override
  String get msgSystemDefault => '跟随系统';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get msgLanguage => '语言';

  @override
  String get msgPreferencesCouldNotBeSavedPreviousSettingsMay =>
      '偏好未能保存，重启后可能恢复旧设置。';

  @override
  String get msgYourKeysYourWallet => '你的密钥，\n你的钱包。';

  @override
  String get msgManageYourOnchainAssetsCreateAWalletOr =>
      '轻松管理你的链上资产。\n创建钱包，或导入已有账户，即可开始。';

  @override
  String get msgSelfCustodyWallet => '自托管钱包';

  @override
  String get msgTransactionsAreSignedOnThisDeviceYouControl =>
      '交易在本机签名，密钥由你掌握。';

  @override
  String get msgSecureDeviceStorage => '系统安全存储';

  @override
  String get msgRecoveryCredentialsStayInThisDeviceSSecure =>
      '恢复凭证保存在本机系统安全存储中。';

  @override
  String get msgChooseYourNetworks => '网络由你选择';

  @override
  String get msgRpcConnectionsStartOnlyAfterYouEnableA => '启用网络后，才会连接对应的 RPC。';

  @override
  String get msgGetStartedWithWallet => '开始使用星舟钱包';

  @override
  String get msgChooseHowToGetStarted => '选择适合你的方式';

  @override
  String get msgCreateWallet => '创建新钱包';

  @override
  String get msgImportRecoveryPhrase => '导入助记词';

  @override
  String get msgImportPrivateKey => '导入私钥';

  @override
  String get msgImportPrivateKeyFile => '批量导入私钥表格';

  @override
  String get msgCsvTsvColumnsChainPrivateKey => 'CSV / TSV · 包含「链」「私钥」两列';

  @override
  String get msgKeepYourRecoveryPhraseAndPrivateKeysSafe =>
      '请妥善保管助记词与私钥，它们是恢复钱包的凭证。';

  @override
  String get msgNetworksAndRpc => '网络与 RPC';

  @override
  String get msgNoNetworkSelectedEnableANetworkToQuery => '尚未选择网络。启用网络后才会查询余额。';

  @override
  String get msgTransactionNetwork => '当前操作链';

  @override
  String get msgTestnet => '测试网';

  @override
  String get msgMainnet => '主网';

  @override
  String endpointCount(int p0) {
    return '$p0 个节点 · 失败自动切换';
  }

  @override
  String get msgActiveEndpoint => '当前可用节点';

  @override
  String get msgSyncingMore => '○ 同步中…';

  @override
  String get msgRpcConnected => '● RPC 已连接';

  @override
  String get msgNotSynced => '○ 尚未同步';

  @override
  String get msgEditRpc => '编辑 RPC';

  @override
  String get msgAddCustomNetwork => '添加自定义链';

  @override
  String get msgWalletSecurity => '钱包安全';

  @override
  String get msgAccountSource => '账户来源';

  @override
  String get msgDerivationPath => '派生路径';

  @override
  String get msgPrivateKeyImport => '私钥导入';

  @override
  String get msgRecoveryPhrasesAndPrivateKeysRemainInSecure =>
      '助记词与私钥仅保存在本机安全存储中，请自行保管恢复凭证。';

  @override
  String get msgWalletManagement => '钱包管理';

  @override
  String walletAndAccountSummary(int p0, int p1) {
    return '$p0 个钱包 · $p1 个账户\n创建、导入更多钱包，或在助记词钱包下继续添加账户。';
  }

  @override
  String get msgManageWalletsAndAccounts => '管理钱包与账户';

  @override
  String get msgChooseFileToImport => '选择表格导入';

  @override
  String get msgBackup => '备份';

  @override
  String get msgIcloudGoogleDriveBackupNotConnected =>
      'iCloud / Google Drive 云备份（暂未接入）';

  @override
  String get msgKeepYourRecoveryCredentialsInASecureOffline =>
      '请将恢复凭证妥善保存在离线安全位置。';

  @override
  String get msgOnchainAssets => '链上资产';

  @override
  String get msgViewAll => '查看全部';

  @override
  String get msgAssets => '资产';

  @override
  String get msgBalance => '余额';

  @override
  String get msgStatus => '状态';

  @override
  String get msgSynced => '已同步';

  @override
  String msgNetworksQueried(String p0, int p1) {
    return '$p0/$p1\n链已查询';
  }

  @override
  String get msgQueriedBalanceDistribution => '已查询余额分布';

  @override
  String get msgStablecoinOverview => '稳定币总览';

  @override
  String get msgRefreshStablecoins => '刷新稳定币';

  @override
  String msgCurrentAccount(String p0) {
    return '当前账户 · $p0';
  }

  @override
  String msgTrackedTotal(String p0) {
    return '已展示 $p0 总量';
  }

  @override
  String get msgQueriedSubtotal => '已查询合计';

  @override
  String msgNetworksQueriedMore(String p0, int p1, String p2) {
    return '$p0/$p1 条链已查询$p2';
  }

  @override
  String get msgFullySynced => ' · 已完整同步';

  @override
  String get msgCoverageIsIncomplete => ' · 余额可能尚未完整';

  @override
  String get msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities =>
      '含已展示的 USDT0 / Binance-Peg 版本；仅按代币数量汇总，不是美元估值。';

  @override
  String get msgOnlyAddedCircleUsdcContractsAreCountedBy =>
      '仅汇总已添加的 Circle USDC 合约，按代币数量统计。';

  @override
  String get msgViewNetworkDistribution => '查看各链分布 →';

  @override
  String msgByNetwork(String p0) {
    return '各链 $p0';
  }

  @override
  String get msgEnableQueryNetworks => '启用查询网络';

  @override
  String msgNoAddedYet(String p0) {
    return '尚未添加 $p0';
  }

  @override
  String get msgAddTokensToViewTheirNetworkDistribution => '添加币种后即可查看跨链分布。';

  @override
  String get msgEnableStablecoinNetworks => '启用稳定币查询网络';

  @override
  String msgOfQueriedBalances(String p0) {
    return '占已查询余额 $p0%';
  }

  @override
  String get msgZeroBalance => '余额为 0';

  @override
  String get msgAwaitingOnchainBalance => '等待链上余额';

  @override
  String get msgCopyReceiveAddress => '复制收款地址';

  @override
  String get msgQuerying => '查询中…';

  @override
  String get msgCurrentAccountReceiveAddress => '当前账户收款地址';

  @override
  String msgTokenContractDecimals(int p0) {
    return '合约地址 · $p0 位精度';
  }

  @override
  String get msgCheckTheNetworkAndContractBeforeReceivingToken =>
      '请核对收款网络和合约。此处用于查看与收款，暂不提供代币转账。';

  @override
  String get msgCannotReadThisTokenCheckTheNetworkContract =>
      '无法读取代币，请检查网络、合约与节点。';

  @override
  String get msgAddingATokenChangesItsDisplayOnlyIt => '添加仅改变资产展示，不会发起授权或交易。';

  @override
  String get msgCommonStablecoins => '常用稳定币';

  @override
  String get msgAddedCustomTokens => '已添加的自定义代币';

  @override
  String get msgHideToken => '隐藏代币';

  @override
  String get msgAddCustomToken => '添加自定义代币';

  @override
  String get msgTokenContractAddress => '代币合约地址';

  @override
  String get msgProcessing => '处理中…';

  @override
  String get msgReadTokenInfo => '读取代币信息';

  @override
  String msgDecimals(String p0, int p1) {
    return '$p0 · $p1 位精度';
  }

  @override
  String get msgCustomTokensWithMatchingTickersAreNotAutomatically =>
      '自定义同名代币不会自动计入 USDT / USDC 汇总。';

  @override
  String msgMatchesAPresetContractItWillBeIncluded(String p0) {
    return '已匹配预置合约，将计入 $p0 汇总。';
  }

  @override
  String get msgAdded => '已添加';

  @override
  String get msgConfirmAddition => '确认添加';

  @override
  String get msgSwitchTheme => '切换主题';

  @override
  String get msgClose => '关闭';

  @override
  String get msgSelectWallet => '选择钱包';

  @override
  String get msgRecoveryPhraseWallet => '助记词钱包';

  @override
  String get msgSwap => '兑换';

  @override
  String get msgMakeSureTheReceivingNetworkMatchesTheNetwork =>
      '请确认接收资产的网络与你选择的网络一致。';

  @override
  String get msgEnableMultipleNetworksToViewBalancesOnlySelected =>
      '可同时启用多条链查看余额。只有点击保存后，选中的网络才会访问 RPC。';

  @override
  String get msgDisconnectAllNetworks => '断开所有网络';

  @override
  String get msgSaveNetworkSelection => '保存网络选择';

  @override
  String get msgTapANetworkNameToUseItFor => '点击网络名称可切换当前链；勾选框用于同时启用多条链。';

  @override
  String get msgUseForTransactions => '设为当前操作链';

  @override
  String get msgRecoveryPhraseVerificationFailedCheckWordsAnd =>
      '助记词校验不正确，请重新核对第 2、6、10 个单词。';

  @override
  String get msgVerifyRecoveryPhrase => '验证恢复助记词';

  @override
  String get msgWriteDownRecoveryPhrase => '记录恢复助记词';

  @override
  String get msgVerifyAndOpenWallet => '验证并进入钱包';

  @override
  String get msgIWroteItDownVerify => '我已记录，继续验证';

  @override
  String get msgWrittenVerify => '记录  ✓     →     ② 验证';

  @override
  String get msgWriteDownVerify => '① 记录     →     ② 验证';

  @override
  String get msgEnterTheRequestedWordsToFinishCreatingYour =>
      '请输入指定位置的单词，验证后完成创建。';

  @override
  String get msgWriteDownTheseWordsInOrderAndKeep => '请按顺序记录以下单词，保存在离线安全位置。';

  @override
  String msgWord(String p0) {
    return '第 $p0 个单词';
  }

  @override
  String get msgDoNotScreenshotCopyOrSendYourRecovery =>
      '不要截图、复制或发送助记词。校验在本机完成。';

  @override
  String get msgImportWallet => '导入钱包';

  @override
  String get msgEnterYourExistingRecoveryPhraseSeparatingWordsWith =>
      '输入已有钱包的助记词，单词之间用空格分隔。';

  @override
  String get msgImport => '导入';

  @override
  String get msgEnterYourOrWordRecoveryPhrase => '请输入 12 或 24 个助记词单词';

  @override
  String get msgChooseANetworkToViewAfterImporting => '请选择导入后要查看的网络。';

  @override
  String get msgPrivateKeyImportFailedPleaseTryAgain => '私钥导入失败，请重试。';

  @override
  String get msgRestoreAnAccountWithAnEvmTronHexadecimal =>
      '使用已有的 EVM / TRON 十六进制私钥恢复账户，无需助记词。';

  @override
  String get msgImporting => '导入中…';

  @override
  String get msgImportAndOpenWallet => '导入并进入钱包';

  @override
  String get msgSelectANetwork => '请选择网络';

  @override
  String get msgPrivateKey => '私钥';

  @override
  String get msgHexadecimalCharactersOptionallyPrefixedWithX =>
      '64 位十六进制，可带 0x 前缀';

  @override
  String get msgShowPrivateKey => '显示私钥';

  @override
  String get msgHidePrivateKey => '隐藏私钥';

  @override
  String get msgPrivateKeysStayInSecureDeviceStorageAfter =>
      '私钥仅保存在本机系统安全存储中。导入成功后，将连接所选网络查询余额；私钥不会发送给 RPC。';

  @override
  String get msgImportResults => '导入结果';

  @override
  String get msgDone => '知道了';

  @override
  String msgImportedSkippedOrFailed(String p0, String p1) {
    return '成功 $p0 条 · 跳过或失败 $p1 条';
  }

  @override
  String msgRow(String p0, String p1) {
    return '第 $p0 条：$p1';
  }

  @override
  String get msgAmountMustBeGreaterThanZero => '金额必须大于 0。';

  @override
  String get msgAmountExceedsTheAvailableBalance => '金额超过当前余额。';

  @override
  String msgSendMore(String p0) {
    return '发送 $p0';
  }

  @override
  String msgSignedOnThisDevice(String p0, String p1) {
    return '$p0 · $p1 · 在本机完成签名';
  }

  @override
  String get msgCheckTheTransactionStatusFirst => '请先确认交易状态';

  @override
  String get msgSignAndBroadcast => '签名并广播';

  @override
  String get msgRecipientAddress => '收款地址';

  @override
  String msgAmount(String p0) {
    return '金额（$p0）';
  }

  @override
  String msgAvailable(String p0, String p1, String p2) {
    return '可用余额：$p0 $p1 · $p2';
  }

  @override
  String get msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay =>
      '带宽不足时消耗 TRX，接收方未激活可能另收费用';

  @override
  String get msgGasFeesAreChargedSeparately => 'Gas 费另行扣除';

  @override
  String msgTransactionHash(String p0) {
    return '交易哈希：$p0';
  }

  @override
  String get msgSettings => '设置';

  @override
  String get msgYourKeysStayWithYouTransactionsAreSigned => '密钥由你掌握\n签名在本机完成';

  @override
  String get msgHome => '首页';

  @override
  String get msgChooseNetwork => '选择网络';

  @override
  String get msgChainIdMustBeAValidPositiveInteger => 'Chain ID 必须是有效的正整数。';

  @override
  String get msgThisChainIdAlreadyExistsEditItsRpc =>
      '该 Chain ID 已存在，请编辑现有网络的 RPC。';

  @override
  String get msgConfigureAtLeastOneRpcUrl => '请至少配置一个 RPC 地址。';

  @override
  String get msgTronHttpApiIsAvailableTheMainnetGenesis =>
      'TRON HTTP API 可用，已验证主网创世区块。';

  @override
  String get msgRpcIsAvailableAndItsChainIdMatches =>
      'RPC 可用，Chain ID 与网络配置一致。';

  @override
  String get msgConnectionCheckFailedCheckTheRpcUrlNetwork =>
      '检测失败，请检查 RPC 地址、网络或访问凭证。';

  @override
  String get msgCouldNotSaveNetworkSettingsPleaseTryAgain => '网络配置保存失败，请重试。';

  @override
  String get msgAddCustomEvmNetwork => '添加自定义 EVM 链';

  @override
  String get msgEditNetworkAndRpc => '编辑网络与 RPC';

  @override
  String get msgEnterOneRpcUrlPerLineInPriority =>
      '每行填写一个 RPC 地址，按顺序尝试；失败后自动切换，后续优先使用可用节点。';

  @override
  String get msgSaving => '保存中…';

  @override
  String get msgSaveNetworkSettings => '保存网络配置';

  @override
  String get msgNetworkName => '网络名称';

  @override
  String get msgForExampleBase => '例如：Base';

  @override
  String get msgForExample => '例如：8453';

  @override
  String get msgNativeCurrencySymbol => '原生代币符号';

  @override
  String get msgForExampleEth => '例如：ETH';

  @override
  String get msgHttpsPrimaryEndpointHttpsBackupEndpoint =>
      'https://第一个节点\nhttps://备用节点';

  @override
  String get msgOneUrlPerLineOrderSetsPriorityDuplicates => '每行一个；顺序即优先级，自动去重。';

  @override
  String get msgRestoreBuiltInFreeEndpoints => '恢复内置免费节点';

  @override
  String get msgBlockExplorerUrlOptional => '区块浏览器地址（可选）';

  @override
  String get msgChecking => '检测中…';

  @override
  String get msgCheckRpcConnection => '检测 RPC 连接';

  @override
  String get msgOperationFailedPleaseTryAgain => '操作失败，请重试。';

  @override
  String get msgRenameAccount => '重命名账户';

  @override
  String get msgRenameWallet => '重命名钱包';

  @override
  String walletAccountCount(String p0, int p1) {
    return '$p0 · $p1 个账户';
  }

  @override
  String get msgPrivateKeyWallet => '私钥钱包';

  @override
  String get msgCopyAccountAddress => '复制账户地址';

  @override
  String get msgAddAccount => '添加账户';

  @override
  String walletAndAccountCount(int p0, int p1) {
    return '$p0 个钱包 · $p1 个账户';
  }

  @override
  String get msgARecoveryPhraseWalletCanHaveMultipleAccounts =>
      '一个助记词钱包可添加多个账户；新的助记词或私钥会保存为独立钱包。';

  @override
  String get msgSearchWalletsAccountsOrAddresses => '搜索钱包、账户或地址';

  @override
  String get msgNoMatchingWalletsOrAccounts => '没有匹配的钱包或账户';

  @override
  String get msgExistingWalletsAreKeptYouCanSwitchAt => '已有的钱包会保留，可随时切换。';

  @override
  String get msgRestoreAWalletAndAddDerivedAccounts => '恢复钱包，并继续添加派生账户';

  @override
  String get msgImportOneEvmTronAccount => '导入已有的单个 EVM / TRON 账户';

  @override
  String get msgImportMultipleAccountsFromCsvTsv => '从 CSV / TSV 导入多个账户';

  @override
  String get msgNamesMustContainCharacters => '名称需要包含 1 至 64 个字符。';

  @override
  String get msgSaveName => '保存名称';

  @override
  String get msgName => '名称';

  @override
  String get msgCustomToken => '自定义代币';

  @override
  String get msgInvalidTokenInformationReadTheContractAgain =>
      '代币信息无效，请重新读取合约。';

  @override
  String get msgTokenSymbolContainsInvalidCharacters => '代币符号包含无效字符。';

  @override
  String get msgTheTokenContractReturnedAnInvalidValue => '代币合约返回值无效。';

  @override
  String get msgInvalidTokenSymbol => '代币符号无效。';

  @override
  String get msgOnlyTokensWithDecimalsAreSupported => '仅支持 0–36 位精度的代币。';

  @override
  String get msgCannotReadTheTokenSymbol => '无法读取代币符号。';

  @override
  String get msgInvalidTokenSymbolEncoding => '代币符号编码无效。';

  @override
  String get msgInvalidTokenSymbolLength => '代币符号长度无效。';

  @override
  String get msgCannotReadTheSavedTokenListExistingRecords =>
      '本机代币列表无法读取，未覆盖原有记录。';

  @override
  String get msgThisTokenHasAlreadyBeenAddedOnThis => '该链上的代币已添加。';

  @override
  String get msgNetworkDisabled => '未启用网络';

  @override
  String get msgQueryingMore => '查询中';

  @override
  String get msgQueryFailed => '查询失败';

  @override
  String get msgTronMainnetIdentifierDoesNotMatchTheProtocol =>
      'TRON 主网标识与协议不匹配。';

  @override
  String get msgEnterTheNetworkNameAndNativeCurrencySymbol => '请填写网络名称和原生代币符号。';

  @override
  String get msgEnterAValidHttpHttpsUrl => '请输入有效的 HTTP / HTTPS 地址。';

  @override
  String get msgCannotAccessKeychainQuitRebuildAndRunThe =>
      '无法访问系统钥匙串（-34018）。请退出应用并重新编译运行；热重载无法更新原生签名权限。';

  @override
  String get msgCannotAccessSecureDeviceStorageCheckThatKeychain =>
      '无法访问本机安全存储，请检查系统钥匙串是否已解锁及访问是否被允许。';

  @override
  String get msgCannotReadSavedNetworkSettingsCheckTheStored =>
      '本机网络配置无法读取，请检查保存的数据。';

  @override
  String get msgAccountIndexIsOutOfRange => '账户序号超出有效范围。';

  @override
  String get msgInvalidRecoveryPhraseCheckTheWordsAndTheir => '助记词无效，请检查单词和顺序。';

  @override
  String get msgCannotDeriveTheEvmPrivateKey => '无法派生 EVM 私钥。';

  @override
  String get msgInvalidPrivateKeyEnterHexadecimalCharacters =>
      '私钥无效，应为 64 位十六进制字符串。';

  @override
  String get msgPrivateKeyValueIsOutOfRange => '私钥无效，数值超出有效范围。';

  @override
  String get msgInvalidPrivateKeyCannotCreateAnAccount => '私钥无效，无法创建账户。';

  @override
  String get msgBinance => '币安';

  @override
  String get msgTron => '波场';

  @override
  String msgRpcNetworkMismatchExpectedReceived(String p0, String p1) {
    return 'RPC 链不匹配：预期 $p0，实际 $p1。';
  }

  @override
  String msgAllRpcEndpointsAreUnavailableTryAgainLater(int p0) {
    return '全部 $p0 个 RPC 节点均不可用，请稍后重试或编辑节点列表。';
  }

  @override
  String get msgTheTokenAndNetworkDoNotMatch => '代币与网络不匹配。';

  @override
  String get msgTheRpcReturnedADifferentTransactionHash => 'RPC 返回的交易哈希不匹配。';

  @override
  String get msgBroadcastStatusIsUncertainCheckTheTransactionHash =>
      '无法确认交易是否已广播。请先按交易哈希查询确认状态，避免再次发起转账。';

  @override
  String msgEnterAValidAmountWithAtMostDecimal(int p0) {
    return '请输入有效金额，最多支持 $p0 位小数。';
  }

  @override
  String get msgMainWallet => '主钱包';

  @override
  String get msgNoNetworkSelected => '未选择网络';

  @override
  String get msgChooseANetworkToView => '请先选择要查看的链';

  @override
  String get msgRpcNotConnected => '未连接 RPC';

  @override
  String get msgNativeAsset => '原生资产';

  @override
  String get msgConnectionFailed => '连接失败';

  @override
  String get msgAwaitingSync => '待同步';

  @override
  String get msgWallet => '钱包';

  @override
  String get msgRpcRequestTimedOutCheckTheUrlOr => 'RPC 请求超时，请检查地址或更换节点。';

  @override
  String get msgRpcRequestFailedCheckTheNetworkEndpointOr =>
      'RPC 请求失败，请检查网络、节点地址或访问凭证。';

  @override
  String msgCouldNotConnectToEditRpcSettingsOr(String p0) {
    return '$p0 连接失败，可在设置中修改 RPC 或重试。';
  }

  @override
  String get msgTheAccountHasChangedReopenThisAsset => '账户已切换，请重新打开资产。';

  @override
  String get msgCouldNotSaveNetworkSelectionPleaseTryAgain => '网络选择保存失败，请重试。';

  @override
  String get msgPrivateKeyAccountImported => '私钥账户已导入';

  @override
  String get msgTheAccountWasSavedButCouldNotBe => '账户已保存，加载失败，请重新打开钱包。';

  @override
  String get msgCannotReadThisFile => '无法读取表格文件。';

  @override
  String get msgNoImportableRowsTheHeaderMustContainChain =>
      '表格没有可导入的数据。首行为：链,私钥';

  @override
  String importedRowSummary(int p0, String p1) {
    return '成功导入 $p0 条$p1。';
  }

  @override
  String msgFailed(String p0) {
    return '，$p0 条失败';
  }

  @override
  String get msgChain => '链';

  @override
  String msgSelectedConnectingToRpc(String p0) {
    return '已选择 $p0，正在连接 RPC…';
  }

  @override
  String msgNetworkSettingsSaved(String p0) {
    return '$p0 网络配置已保存';
  }

  @override
  String get msgSwapsAreNotConnectedNoOrderOrSignature => '兑换功能尚未接入，没有创建订单或签名。';

  @override
  String get msgUnavailable => '暂不可用';

  @override
  String get msgAddressCopied => '地址已复制';

  @override
  String get msgSelectANetworkBeforeSending => '发送前请先选择网络。';

  @override
  String msgTransactionBroadcast(String p0) {
    return '交易已广播：$p0';
  }

  @override
  String get msgWalletOperationFailedPleaseTryAgain => '钱包操作失败，请重试。';

  @override
  String get msgMostRecentlyBroadcastTransaction => '最近广播的交易';

  @override
  String get msgEnterAValidTronAddressStartingWithT =>
      '请输入有效的 TRON 地址（T 开头，含正确校验码）。';

  @override
  String get msgTheTronEndpointReturnedAnErrorTryAnother =>
      'TRON 节点返回错误，请更换节点或稍后重试。';

  @override
  String get msgTronNetworkMismatchAMainnetEndpointIsRequired =>
      'TRON 节点网络不匹配：需要 TRON 主网。';

  @override
  String msgAllTronEndpointsAreUnavailableTryAgainLater(int p0) {
    return '全部 $p0 个 TRON 节点均不可用，请稍后重试或编辑节点列表。';
  }

  @override
  String get msgTrcQueryFailedCheckTheContractAndEndpoint =>
      'TRC20 合约查询失败，请检查合约和节点。';

  @override
  String get msgTheTronEndpointReturnedADifferentAccountS =>
      'TRON 节点返回了不同账户的余额。';

  @override
  String get msgTheTronEndpointReturnedAnInvalidBalance => 'TRON 节点返回的余额无效。';

  @override
  String get msgTrxAmountIsOutOfRange => 'TRX 金额超出有效范围。';

  @override
  String get msgTronReferenceBlockIsInvalidOrStaleCheck =>
      'TRON 参考区块无效或已过期，请检查本机时间和节点。';

  @override
  String get msgTheTronEndpointDidNotConfirmTheBroadcast => 'TRON 节点未确认交易广播。';

  @override
  String get msgCannotReadTheWalletBookCheckSecureStorage =>
      '本机钱包簿无法读取，请检查安全存储。';

  @override
  String get msgAccount => '账户 1';

  @override
  String msgPrivateKeyAccount(String p0) {
    return '私钥账户 $p0';
  }

  @override
  String get msgSavedPrivateKeyAccountDataIsCorrupted => '本机保存的私钥账户数据已损坏。';

  @override
  String msgWalletMore(String p0) {
    return '钱包 $p0';
  }

  @override
  String get msgUnsupportedNetwork => '不支持的链。';

  @override
  String get msgDuplicateEntrySkipped => '重复记录，已跳过。';

  @override
  String get msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts =>
      '只有助记词钱包可以派生新账户。';

  @override
  String msgAccountMore(String p0) {
    return '账户 $p0';
  }

  @override
  String get msgAccountNotFound => '找不到此账户。';

  @override
  String get msgWalletNotFound => '找不到此钱包。';

  @override
  String get msgUnexpectedErrorPleaseTryAgain => '未知错误，请稍后重试。';

  @override
  String get msgSelfCustodyEvmTron => '自托管 · EVM / TRON';

  @override
  String get portfolioOverview => '地址总览';

  @override
  String get portfolioByCoin => '按币种';

  @override
  String get portfolioReferenceValue => '参考资产估值';

  @override
  String get portfolioValuedSubtotal => '已估值合计';

  @override
  String get portfolioAllAddresses => '全部关联地址';

  @override
  String get portfolioAllNetworks => '全部启用网络';

  @override
  String get portfolioAllAssets => '全部资产';

  @override
  String get portfolioSimple => '简洁';

  @override
  String get portfolioDetailed => '详细';

  @override
  String get portfolioDisplaySettings => '资产展示';

  @override
  String get portfolioDisplayMode => '展示模式';

  @override
  String get portfolioInitialCount => '首屏币种数量';

  @override
  String get portfolioAll => '全部';

  @override
  String get portfolioSort => '资产排序';

  @override
  String get portfolioSortValue => '估值从高到低';

  @override
  String get portfolioStableFirst => '稳定币优先';

  @override
  String get portfolioSortName => '名称';

  @override
  String get portfolioHideZero => '隐藏已确认的零余额';

  @override
  String get portfolioShowSpam => '显示索引服务标记的疑似垃圾资产';

  @override
  String portfolioExpand(String p0) {
    return '展开全部（$p0）';
  }

  @override
  String get portfolioCollapse => '收起';

  @override
  String get portfolioSelectCoin => '选择币种';

  @override
  String get portfolioSearch => '搜索币种、合约或网络';

  @override
  String portfolioChainCount(int p0) {
    return '$p0 条链';
  }

  @override
  String portfolioCoinCount(int p0) {
    return '$p0 个币种';
  }

  @override
  String get portfolioInformation => '估值与查询详情';

  @override
  String get portfolioValueExplanation =>
      '按 USDT 市价估算，1 USDT≈1 USD；仅包含已启用网络下已添加和已发现的资产。';

  @override
  String get portfolioVersionExplanation =>
      'USDT0、Binance-Peg 版本使用 USDT 参考价；同名符号不会自动归并或匹配行情。';

  @override
  String portfolioCoverage(String p0, String p1, String p2) {
    return '$p0/$p1 项持仓已查询 · $p2 项未定价';
  }

  @override
  String get portfolioPartial => '部分结果';

  @override
  String get portfolioStalePrices => '行情已过期，使用近期缓存';

  @override
  String get portfolioNoPrice => '暂无参考价格';

  @override
  String get portfolioNoAssets => '没有符合条件的资产';

  @override
  String get portfolioShowZero => '查看零余额资产';

  @override
  String get portfolioRefresh => '刷新余额与行情';

  @override
  String get portfolioSourceRpc => '余额来自 RPC';

  @override
  String get portfolioSourceIndexer => '索引服务发现';

  @override
  String get portfolioPriceSource => '行情：Binance 公开 USDT 交易对';

  @override
  String portfolioUpdated(String p0) {
    return '行情时间：$p0';
  }

  @override
  String get portfolioTestnetExcluded => '测试网资产不计入估值。';

  @override
  String get discoveryServices => '资产索引服务';

  @override
  String get discoveryConfigure => '配置自动发现';

  @override
  String get discoveryNotConfigured => '自动发现未配置';

  @override
  String get discoveryQuerying => '正在发现资产…';

  @override
  String get discoveryPartial => '资产发现尚未完成';

  @override
  String get discoveryUnavailable => '自动发现暂不可用';

  @override
  String get discoveryLoadMore => '继续加载资产';

  @override
  String discoveryConfigureProvider(String p0) {
    return '配置 $p0';
  }

  @override
  String get discoveryGetKey => '获取 API Key';

  @override
  String get discoveryDocs => '官方文档';

  @override
  String get discoveryPlans => '套餐与额度';

  @override
  String get discoveryApiKey => '服务 API Key';

  @override
  String get discoveryKeyHint => '填写自己的服务密钥，不是钱包私钥';

  @override
  String get discoveryKeyRequired => '请填写服务 API Key。';

  @override
  String get discoveryPrivacy => '启用后，所选服务商会收到对应网络的关联公开地址。服务密钥保存在本机安全存储中。';

  @override
  String get discoveryAssignments => '选择网络（将替换该网络的现有索引服务）';

  @override
  String get discoveryChooseNetwork => '请至少选择一个受支持的已启用网络。';

  @override
  String get discoveryTest => '测试连接';

  @override
  String get discoveryConnected => '连接成功，密钥与响应有效。';

  @override
  String get discoverySaveEnable => '保存并启用';

  @override
  String get discoveryEnabled => '已启用';

  @override
  String get discoveryDisabled => '已停用';

  @override
  String get discoveryDisable => '停用';

  @override
  String get discoveryDelete => '删除配置';

  @override
  String get discoveryEdit => '配置';

  @override
  String get discoveryUnauthorized => '服务密钥无效或权限不足，请检查密钥和套餐权限。';

  @override
  String get discoveryLimited => '索引服务额度不足或触发限流，请稍后重试。';

  @override
  String get discoveryResponseInvalid => '索引服务返回了无效的资产数据。';

  @override
  String get discoveryRequestFailed => '索引服务连接失败，已关注资产仍可查看。';

  @override
  String get discoverySettingsUnreadable => '无法读取索引服务配置，原记录已保留。';

  @override
  String get discoverySaveFailed => '索引服务配置保存失败，请重试。';

  @override
  String get discoveryUnsupported => '本应用尚未接入该服务在此网络的资产发现。';

  @override
  String get discoveryWatch => '加入关注';

  @override
  String get discoveryWatched => '已加入关注资产';

  @override
  String get discoveryMoralisGuide =>
      '注册 Moralis → 获取 Web3 API Key → 选择 Ethereum、Polygon 或 BNB Chain。额度以套餐页为准。';

  @override
  String get discoveryAlchemyGuide =>
      '创建 Alchemy App → 启用 Ethereum 或 Polygon → 复制 API Key。本应用使用 Token API。';

  @override
  String get discoveryTronGridGuide =>
      '登录 TronGrid → 创建 API Key → 启用 TRON 主网。本应用发现 TRC20 持仓。';

  @override
  String get discoveryLinkCopied => '浏览器未能打开，链接已复制。';

  @override
  String get discoveryNoEnabledNetworks => '请先启用一个受支持网络，再配置自动发现。';

  @override
  String get portfolioAddressDetails => '关联地址';

  @override
  String get portfolioBalanceStatus => '余额状态';

  @override
  String get portfolioSpam => '疑似垃圾资产';

  @override
  String get portfolioNoCoin => '当前筛选下没有币种';

  @override
  String get discoveryNotConfiguredShort => '未配置';

  @override
  String get settingsSearch => '搜索设置';

  @override
  String get settingsSearchHint => '语言、显示模式、RPC…';

  @override
  String get settingsQuickLinks => '常用设置';

  @override
  String get settingsCategories => '全部设置';

  @override
  String get settingsWallets => '钱包与账户';

  @override
  String get settingsWalletsHint => '管理、创建与导入';

  @override
  String get settingsAssetsHint => '展示偏好与关注币种';

  @override
  String get settingsData => '网络与数据';

  @override
  String get settingsDataHint => '网络 RPC 与资产索引服务';

  @override
  String get settingsSecurity => '安全与备份';

  @override
  String get settingsSecurityHint => '账户安全信息与备份说明';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsGeneralHint => '语言与外观主题';

  @override
  String get settingsAppearance => '外观主题';

  @override
  String get settingsLight => '浅色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsWatchedTokens => '关注币种管理';

  @override
  String get settingsNoResults => '没有找到相关设置';

  @override
  String get settingsClearSearch => '清空搜索';

  @override
  String get settingsUnavailable => '暂未接入';

  @override
  String get settingsNetworkDisabled => '未启用';

  @override
  String get settingsNetworkEnabled => '已启用';

  @override
  String get settingsNetworkState => '启用网络';

  @override
  String get settingsBackupHint => '恢复凭证请妥善离线保管。云备份暂未接入。';

  @override
  String get settingsMatchedOption => '已定位此设置';

  @override
  String get omniImportTitle => '预览 OmniVault 导入';

  @override
  String get omniImportResult => 'OmniVault 导入结果';

  @override
  String omniReading(int count) {
    return '正在校验，已处理 $count 行…';
  }

  @override
  String get omniConfirm => '确认导入';

  @override
  String get omniNewWallet => '新钱包';

  @override
  String get omniAliasesAdded => '新增别名';

  @override
  String get omniDuplicates => '重复';

  @override
  String get omniSkipped => '跳过';

  @override
  String get omniFailed => '失败';

  @override
  String get omniAllRows => '全部记录';

  @override
  String get omniNoRows => '此类别没有记录';

  @override
  String omniLine(int line) {
    return '第 $line 行';
  }

  @override
  String get omniPreviousPage => '上一页';

  @override
  String get omniNextPage => '下一页';

  @override
  String get omniWalletAliases => '钱包别名';

  @override
  String get omniHeader => 'OmniVault CSV 必须包含七个必需列，且表头不能重复。';

  @override
  String get omniInvalidEncoding => '文件必须使用 UTF-8 编码。';

  @override
  String omniMalformedCsv(int line) {
    return '第 $line 行的 CSV 引号格式无效。';
  }

  @override
  String get omniColumnCount => '此行列数与表头不一致。';

  @override
  String get omniInvalidStatus => '无法识别私钥导出状态。';

  @override
  String get omniInvalidIdentity => '平台和 UID 各需 1 至 256 个字符，且不能包含控制字符。';

  @override
  String get omniInvalidAddress => '原地址在该链上的格式无效。';

  @override
  String get omniAddressMismatch => '私钥派生地址与原地址不一致。';

  @override
  String get omniWalletChanged => '钱包簿已有变更，请重新打开文件进行校验。';

  @override
  String get omniStorageError => '加密钱包数据库未能完成此操作。';

  @override
  String get omniRecordTooLarge => 'CSV 中有一条记录超过支持的大小。';

  @override
  String get omniSearchHint => '搜索钱包名、平台、UID 或地址前缀';

  @override
  String get omniFileHint => '支持 OmniVault CSV 或包含链和私钥的 CSV/TSV';

  @override
  String get transferChooseAsset => '选择要发送的资产';

  @override
  String get transferReview => '核对转账';

  @override
  String get transferEdit => '修改转账';

  @override
  String get transferSender => '转出地址';

  @override
  String get transferContract => '代币合约';

  @override
  String get transferFee => '预计网络手续费';

  @override
  String get transferTronFeeNote => 'TRX 手续费会随可用能量和带宽变化。';

  @override
  String get transferViewTransaction => '查看链上交易';

  @override
  String get transferInvalidRecipient => '请输入该网络的有效收款地址。';

  @override
  String get transferAmountTooLarge => '金额超过该网络支持的范围。';

  @override
  String get transferSimulationFailed => '网络未通过转账模拟，请检查金额和收款地址。';

  @override
  String get transferTokenDecimalsChanged => '代币合约返回的精度不同，请刷新代币信息后再发送。';

  @override
  String get transferFeeUnavailable => '无法估算手续费，请重试或检查 RPC 节点。';

  @override
  String get transferInsufficientFee => '原生币余额不足，无法支付本次转账及其网络手续费。';

  @override
  String get transferReviewExpired => '请重新核对转账后再签名。';

  @override
  String get walletBalancesTitle => '全部钱包余额';

  @override
  String walletBalancesStarted(String time) {
    return '$time 开始查询';
  }

  @override
  String get walletBalancesChecking => '查询中';

  @override
  String get walletBalancesPaused => '已暂停';

  @override
  String get walletBalancesFinished => '查询完成';

  @override
  String get walletBalancesLoadFailed => '钱包列表读取失败';

  @override
  String walletBalancesProgress(String state, int checked, int total) {
    return '$state · $checked / $total 个账户';
  }

  @override
  String get walletBalancesScope =>
      '按美元估值从高到低排列。指定链的钱包查来源链，其余钱包查已启用网络。涵盖原生币、内置和关注的代币，以及已配置的代币发现。测试网资产不计入估值。';

  @override
  String walletBalancesIncompleteCount(int count) {
    return '$count 个账户结果不完整';
  }

  @override
  String get walletBalancesPause => '暂停查询';

  @override
  String get walletBalancesResume => '继续查询';

  @override
  String get walletBalancesBackground => '转到后台查询';

  @override
  String get walletBalancesNoNetwork => '无可查询网络';

  @override
  String get walletBalancesQueryIncomplete => '余额或代币发现不完整';

  @override
  String get walletBalancesTokenListError => '无法读取关注代币';

  @override
  String get walletBalancesMissingPrices => '部分资产缺少报价';

  @override
  String get walletBalancesNoHoldings => '查询范围内余额为零。';

  @override
  String get walletBalancesWaiting => '正在等待首批结果…';

  @override
  String get walletBalancesEmpty => '没有可查询的钱包。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appName => '星舟錢包';

  @override
  String get msgSyncing => '同步中…';

  @override
  String get msgRefreshAssets => '刷新資產';

  @override
  String get msgManageNetworks => '管理網路';

  @override
  String get msgStablecoins => '穩定幣';

  @override
  String get msgOtherCoins => '其他幣種';

  @override
  String get msgAddTokens => '添加幣種';

  @override
  String get msgSearchAssetsOrNetworks => '搜索資產或網路';

  @override
  String get msgNativeCoinsPayNetworkFeesUnsyncedBalancesAppear =>
      '原生幣用於支付網路費用。未同步餘額顯示為 —。';

  @override
  String get msgTokensAreIdentifiedByNetworkAndContractMatching =>
      '按網路與合約區分代幣；同名代幣不會自動合併。';

  @override
  String get msgNoMatchingAssets => '沒有匹配的資產。';

  @override
  String msgAssetDetails(String p0) {
    return '$p0 資產詳情';
  }

  @override
  String get msgSend => '發送';

  @override
  String get msgReceive => '接收';

  @override
  String get msgUseThisNetwork => '設為當前鏈';

  @override
  String get msgRefreshBalance => '刷新餘額';

  @override
  String get msgNetwork => '網路';

  @override
  String get msgWalletAddress => '錢包地址';

  @override
  String get msgRpcUrl => 'RPC 地址';

  @override
  String get msgBlockExplorer => '區塊瀏覽器';

  @override
  String get msgExplorerLinkCopied => '瀏覽器鏈接已複製';

  @override
  String get msgCopyExplorerLink => '複製瀏覽器鏈接';

  @override
  String get msgSystemDefault => '跟隨系統';

  @override
  String get languageSimplifiedChinese => '簡體中文';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get msgLanguage => '語言';

  @override
  String get msgPreferencesCouldNotBeSavedPreviousSettingsMay =>
      '偏好未能保存，重啓後可能恢復舊設置。';

  @override
  String get msgYourKeysYourWallet => '你的密鑰，\n你的錢包。';

  @override
  String get msgManageYourOnchainAssetsCreateAWalletOr =>
      '輕鬆管理你的鏈上資產。\n創建錢包，或導入已有帳戶，即可開始。';

  @override
  String get msgSelfCustodyWallet => '自托管錢包';

  @override
  String get msgTransactionsAreSignedOnThisDeviceYouControl =>
      '交易在本機簽名，密鑰由你掌握。';

  @override
  String get msgSecureDeviceStorage => '系統安全存儲';

  @override
  String get msgRecoveryCredentialsStayInThisDeviceSSecure =>
      '恢復憑證保存在本機系統安全存儲中。';

  @override
  String get msgChooseYourNetworks => '網路由你選擇';

  @override
  String get msgRpcConnectionsStartOnlyAfterYouEnableA => '啓用網路後，才會連接對應的 RPC。';

  @override
  String get msgGetStartedWithWallet => '開始使用星舟錢包';

  @override
  String get msgChooseHowToGetStarted => '選擇適合你的方式';

  @override
  String get msgCreateWallet => '創建新錢包';

  @override
  String get msgImportRecoveryPhrase => '導入助記詞';

  @override
  String get msgImportPrivateKey => '導入私鑰';

  @override
  String get msgImportPrivateKeyFile => '批量導入私鑰表格';

  @override
  String get msgCsvTsvColumnsChainPrivateKey => 'CSV / TSV · 包含「鏈」「私鑰」兩列';

  @override
  String get msgKeepYourRecoveryPhraseAndPrivateKeysSafe =>
      '請妥善保管助記詞與私鑰，它們是恢復錢包的憑證。';

  @override
  String get msgNetworksAndRpc => '網路與 RPC';

  @override
  String get msgNoNetworkSelectedEnableANetworkToQuery => '尚未選擇網路。啓用網路後才會查詢餘額。';

  @override
  String get msgTransactionNetwork => '當前操作鏈';

  @override
  String get msgTestnet => '測試網';

  @override
  String get msgMainnet => '主網';

  @override
  String endpointCount(int p0) {
    return '$p0 個節點 · 失敗自動切換';
  }

  @override
  String get msgActiveEndpoint => '當前可用節點';

  @override
  String get msgSyncingMore => '○ 同步中…';

  @override
  String get msgRpcConnected => '● RPC 已連接';

  @override
  String get msgNotSynced => '○ 尚未同步';

  @override
  String get msgEditRpc => '編輯 RPC';

  @override
  String get msgAddCustomNetwork => '添加自定義鏈';

  @override
  String get msgWalletSecurity => '錢包安全';

  @override
  String get msgAccountSource => '帳戶來源';

  @override
  String get msgDerivationPath => '派生路徑';

  @override
  String get msgPrivateKeyImport => '私鑰導入';

  @override
  String get msgRecoveryPhrasesAndPrivateKeysRemainInSecure =>
      '助記詞與私鑰僅保存在本機安全存儲中，請自行保管恢復憑證。';

  @override
  String get msgWalletManagement => '錢包管理';

  @override
  String walletAndAccountSummary(int p0, int p1) {
    return '$p0 個錢包 · $p1 個帳戶\n創建、導入更多錢包，或在助記詞錢包下繼續添加帳戶。';
  }

  @override
  String get msgManageWalletsAndAccounts => '管理錢包與帳戶';

  @override
  String get msgChooseFileToImport => '選擇表格導入';

  @override
  String get msgBackup => '備份';

  @override
  String get msgIcloudGoogleDriveBackupNotConnected =>
      'iCloud / Google Drive 雲備份（暫未接入）';

  @override
  String get msgKeepYourRecoveryCredentialsInASecureOffline =>
      '請將恢復憑證妥善保存在離線安全位置。';

  @override
  String get msgOnchainAssets => '鏈上資產';

  @override
  String get msgViewAll => '查看全部';

  @override
  String get msgAssets => '資產';

  @override
  String get msgBalance => '餘額';

  @override
  String get msgStatus => '狀態';

  @override
  String get msgSynced => '已同步';

  @override
  String msgNetworksQueried(String p0, int p1) {
    return '$p0/$p1\n鏈已查詢';
  }

  @override
  String get msgQueriedBalanceDistribution => '已查詢餘額分布';

  @override
  String get msgStablecoinOverview => '穩定幣總覽';

  @override
  String get msgRefreshStablecoins => '刷新穩定幣';

  @override
  String msgCurrentAccount(String p0) {
    return '當前帳戶 · $p0';
  }

  @override
  String msgTrackedTotal(String p0) {
    return '已展示 $p0 總量';
  }

  @override
  String get msgQueriedSubtotal => '已查詢合計';

  @override
  String msgNetworksQueriedMore(String p0, int p1, String p2) {
    return '$p0/$p1 條鏈已查詢$p2';
  }

  @override
  String get msgFullySynced => ' · 已完整同步';

  @override
  String get msgCoverageIsIncomplete => ' · 餘額可能尚未完整';

  @override
  String get msgIncludesTrackedUsdtBinancePegVersionsTokenQuantities =>
      '含已展示的 USDT0 / Binance-Peg 版本；僅按代幣數量匯總，不是美元估值。';

  @override
  String get msgOnlyAddedCircleUsdcContractsAreCountedBy =>
      '僅匯總已添加的 Circle USDC 合約，按代幣數量統計。';

  @override
  String get msgViewNetworkDistribution => '查看各鏈分布 →';

  @override
  String msgByNetwork(String p0) {
    return '各鏈 $p0';
  }

  @override
  String get msgEnableQueryNetworks => '啓用查詢網路';

  @override
  String msgNoAddedYet(String p0) {
    return '尚未添加 $p0';
  }

  @override
  String get msgAddTokensToViewTheirNetworkDistribution => '添加幣種後即可查看跨鏈分布。';

  @override
  String get msgEnableStablecoinNetworks => '啓用穩定幣查詢網路';

  @override
  String msgOfQueriedBalances(String p0) {
    return '佔已查詢餘額 $p0%';
  }

  @override
  String get msgZeroBalance => '餘額為 0';

  @override
  String get msgAwaitingOnchainBalance => '等待鏈上餘額';

  @override
  String get msgCopyReceiveAddress => '複製收款地址';

  @override
  String get msgQuerying => '查詢中…';

  @override
  String get msgCurrentAccountReceiveAddress => '當前帳戶收款地址';

  @override
  String msgTokenContractDecimals(int p0) {
    return '合約地址 · $p0 位精度';
  }

  @override
  String get msgCheckTheNetworkAndContractBeforeReceivingToken =>
      '請核對收款網路和合約。此處用於查看與收款，暫不提供代幣轉賬。';

  @override
  String get msgCannotReadThisTokenCheckTheNetworkContract =>
      '無法讀取代幣，請檢查網路、合約與節點。';

  @override
  String get msgAddingATokenChangesItsDisplayOnlyIt => '添加僅改變資產展示，不會發起授權或交易。';

  @override
  String get msgCommonStablecoins => '常用穩定幣';

  @override
  String get msgAddedCustomTokens => '已添加的自定義代幣';

  @override
  String get msgHideToken => '隱藏代幣';

  @override
  String get msgAddCustomToken => '添加自定義代幣';

  @override
  String get msgTokenContractAddress => '代幣合約地址';

  @override
  String get msgProcessing => '處理中…';

  @override
  String get msgReadTokenInfo => '讀取代幣信息';

  @override
  String msgDecimals(String p0, int p1) {
    return '$p0 · $p1 位精度';
  }

  @override
  String get msgCustomTokensWithMatchingTickersAreNotAutomatically =>
      '自定義同名代幣不會自動計入 USDT / USDC 匯總。';

  @override
  String msgMatchesAPresetContractItWillBeIncluded(String p0) {
    return '已匹配預置合約，將計入 $p0 匯總。';
  }

  @override
  String get msgAdded => '已添加';

  @override
  String get msgConfirmAddition => '確認添加';

  @override
  String get msgSwitchTheme => '切換主題';

  @override
  String get msgClose => '關閉';

  @override
  String get msgSelectWallet => '選擇錢包';

  @override
  String get msgRecoveryPhraseWallet => '助記詞錢包';

  @override
  String get msgSwap => '兌換';

  @override
  String get msgMakeSureTheReceivingNetworkMatchesTheNetwork =>
      '請確認接收資產的網路與你選擇的網路一致。';

  @override
  String get msgEnableMultipleNetworksToViewBalancesOnlySelected =>
      '可同時啓用多條鏈查看餘額。只有點擊保存後，選中的網路才會訪問 RPC。';

  @override
  String get msgDisconnectAllNetworks => '斷開所有網路';

  @override
  String get msgSaveNetworkSelection => '保存網路選擇';

  @override
  String get msgTapANetworkNameToUseItFor => '點擊網路名稱可切換當前鏈；勾選框用於同時啓用多條鏈。';

  @override
  String get msgUseForTransactions => '設為當前操作鏈';

  @override
  String get msgRecoveryPhraseVerificationFailedCheckWordsAnd =>
      '助記詞校驗不正確，請重新核對第 2、6、10 個單詞。';

  @override
  String get msgVerifyRecoveryPhrase => '驗證恢復助記詞';

  @override
  String get msgWriteDownRecoveryPhrase => '記錄恢復助記詞';

  @override
  String get msgVerifyAndOpenWallet => '驗證並進入錢包';

  @override
  String get msgIWroteItDownVerify => '我已記錄，繼續驗證';

  @override
  String get msgWrittenVerify => '記錄  ✓     →     ② 驗證';

  @override
  String get msgWriteDownVerify => '① 記錄     →     ② 驗證';

  @override
  String get msgEnterTheRequestedWordsToFinishCreatingYour =>
      '請輸入指定位置的單詞，驗證後完成創建。';

  @override
  String get msgWriteDownTheseWordsInOrderAndKeep => '請按順序記錄以下單詞，保存在離線安全位置。';

  @override
  String msgWord(String p0) {
    return '第 $p0 個單詞';
  }

  @override
  String get msgDoNotScreenshotCopyOrSendYourRecovery =>
      '不要截圖、複製或發送助記詞。校驗在本機完成。';

  @override
  String get msgImportWallet => '導入錢包';

  @override
  String get msgEnterYourExistingRecoveryPhraseSeparatingWordsWith =>
      '輸入已有錢包的助記詞，單詞之間用空格分隔。';

  @override
  String get msgImport => '導入';

  @override
  String get msgEnterYourOrWordRecoveryPhrase => '請輸入 12 或 24 個助記詞單詞';

  @override
  String get msgChooseANetworkToViewAfterImporting => '請選擇導入後要查看的網路。';

  @override
  String get msgPrivateKeyImportFailedPleaseTryAgain => '私鑰導入失敗，請重試。';

  @override
  String get msgRestoreAnAccountWithAnEvmTronHexadecimal =>
      '使用已有的 EVM / TRON 十六進制私鑰恢復帳戶，無需助記詞。';

  @override
  String get msgImporting => '導入中…';

  @override
  String get msgImportAndOpenWallet => '導入並進入錢包';

  @override
  String get msgSelectANetwork => '請選擇網路';

  @override
  String get msgPrivateKey => '私鑰';

  @override
  String get msgHexadecimalCharactersOptionallyPrefixedWithX =>
      '64 位十六進制，可帶 0x 前綴';

  @override
  String get msgShowPrivateKey => '顯示私鑰';

  @override
  String get msgHidePrivateKey => '隱藏私鑰';

  @override
  String get msgPrivateKeysStayInSecureDeviceStorageAfter =>
      '私鑰僅保存在本機系統安全存儲中。導入成功後，將連接所選網路查詢餘額；私鑰不會發送給 RPC。';

  @override
  String get msgImportResults => '導入結果';

  @override
  String get msgDone => '知道了';

  @override
  String msgImportedSkippedOrFailed(String p0, String p1) {
    return '成功 $p0 條 · 跳過或失敗 $p1 條';
  }

  @override
  String msgRow(String p0, String p1) {
    return '第 $p0 條：$p1';
  }

  @override
  String get msgAmountMustBeGreaterThanZero => '金額必須大於 0。';

  @override
  String get msgAmountExceedsTheAvailableBalance => '金額超過當前餘額。';

  @override
  String msgSendMore(String p0) {
    return '發送 $p0';
  }

  @override
  String msgSignedOnThisDevice(String p0, String p1) {
    return '$p0 · $p1 · 在本機完成簽名';
  }

  @override
  String get msgCheckTheTransactionStatusFirst => '請先確認交易狀態';

  @override
  String get msgSignAndBroadcast => '簽名並廣播';

  @override
  String get msgRecipientAddress => '收款地址';

  @override
  String msgAmount(String p0) {
    return '金額（$p0）';
  }

  @override
  String msgAvailable(String p0, String p1, String p2) {
    return '可用餘額：$p0 $p1 · $p2';
  }

  @override
  String get msgInsufficientBandwidthConsumesTrxAnUnactivatedRecipientMay =>
      '帶寬不足時消耗 TRX，接收方未激活可能另收費用';

  @override
  String get msgGasFeesAreChargedSeparately => 'Gas 費另行扣除';

  @override
  String msgTransactionHash(String p0) {
    return '交易哈希：$p0';
  }

  @override
  String get msgSettings => '設置';

  @override
  String get msgYourKeysStayWithYouTransactionsAreSigned => '密鑰由你掌握\n簽名在本機完成';

  @override
  String get msgHome => '首頁';

  @override
  String get msgChooseNetwork => '選擇網路';

  @override
  String get msgChainIdMustBeAValidPositiveInteger => 'Chain ID 必須是有效的正整數。';

  @override
  String get msgThisChainIdAlreadyExistsEditItsRpc =>
      '該 Chain ID 已存在，請編輯現有網路的 RPC。';

  @override
  String get msgConfigureAtLeastOneRpcUrl => '請至少配置一個 RPC 地址。';

  @override
  String get msgTronHttpApiIsAvailableTheMainnetGenesis =>
      'TRON HTTP API 可用，已驗證主網創世區塊。';

  @override
  String get msgRpcIsAvailableAndItsChainIdMatches =>
      'RPC 可用，Chain ID 與網路配置一致。';

  @override
  String get msgConnectionCheckFailedCheckTheRpcUrlNetwork =>
      '檢測失敗，請檢查 RPC 地址、網路或訪問憑證。';

  @override
  String get msgCouldNotSaveNetworkSettingsPleaseTryAgain => '網路配置保存失敗，請重試。';

  @override
  String get msgAddCustomEvmNetwork => '添加自定義 EVM 鏈';

  @override
  String get msgEditNetworkAndRpc => '編輯網路與 RPC';

  @override
  String get msgEnterOneRpcUrlPerLineInPriority =>
      '每行填寫一個 RPC 地址，按順序嘗試；失敗後自動切換，後續優先使用可用節點。';

  @override
  String get msgSaving => '保存中…';

  @override
  String get msgSaveNetworkSettings => '保存網路配置';

  @override
  String get msgNetworkName => '網路名稱';

  @override
  String get msgForExampleBase => '例如：Base';

  @override
  String get msgForExample => '例如：8453';

  @override
  String get msgNativeCurrencySymbol => '原生代幣符號';

  @override
  String get msgForExampleEth => '例如：ETH';

  @override
  String get msgHttpsPrimaryEndpointHttpsBackupEndpoint =>
      'https://第一個節點\nhttps://備用節點';

  @override
  String get msgOneUrlPerLineOrderSetsPriorityDuplicates => '每行一個；順序即優先級，自動去重。';

  @override
  String get msgRestoreBuiltInFreeEndpoints => '恢復內置免費節點';

  @override
  String get msgBlockExplorerUrlOptional => '區塊瀏覽器地址（可選）';

  @override
  String get msgChecking => '檢測中…';

  @override
  String get msgCheckRpcConnection => '檢測 RPC 連接';

  @override
  String get msgOperationFailedPleaseTryAgain => '操作失敗，請重試。';

  @override
  String get msgRenameAccount => '重命名帳戶';

  @override
  String get msgRenameWallet => '重命名錢包';

  @override
  String walletAccountCount(String p0, int p1) {
    return '$p0 · $p1 個帳戶';
  }

  @override
  String get msgPrivateKeyWallet => '私鑰錢包';

  @override
  String get msgCopyAccountAddress => '複製帳戶地址';

  @override
  String get msgAddAccount => '添加帳戶';

  @override
  String walletAndAccountCount(int p0, int p1) {
    return '$p0 個錢包 · $p1 個帳戶';
  }

  @override
  String get msgARecoveryPhraseWalletCanHaveMultipleAccounts =>
      '一個助記詞錢包可添加多個帳戶；新的助記詞或私鑰會保存為獨立錢包。';

  @override
  String get msgSearchWalletsAccountsOrAddresses => '搜索錢包、帳戶或地址';

  @override
  String get msgNoMatchingWalletsOrAccounts => '沒有匹配的錢包或帳戶';

  @override
  String get msgExistingWalletsAreKeptYouCanSwitchAt => '已有的錢包會保留，可隨時切換。';

  @override
  String get msgRestoreAWalletAndAddDerivedAccounts => '恢復錢包，並繼續添加派生帳戶';

  @override
  String get msgImportOneEvmTronAccount => '導入已有的單個 EVM / TRON 帳戶';

  @override
  String get msgImportMultipleAccountsFromCsvTsv => '從 CSV / TSV 導入多個帳戶';

  @override
  String get msgNamesMustContainCharacters => '名稱需要包含 1 至 64 個字符。';

  @override
  String get msgSaveName => '保存名稱';

  @override
  String get msgName => '名稱';

  @override
  String get msgCustomToken => '自定義代幣';

  @override
  String get msgInvalidTokenInformationReadTheContractAgain =>
      '代幣信息無效，請重新讀取合約。';

  @override
  String get msgTokenSymbolContainsInvalidCharacters => '代幣符號包含無效字符。';

  @override
  String get msgTheTokenContractReturnedAnInvalidValue => '代幣合約返回值無效。';

  @override
  String get msgInvalidTokenSymbol => '代幣符號無效。';

  @override
  String get msgOnlyTokensWithDecimalsAreSupported => '僅支持 0–36 位精度的代幣。';

  @override
  String get msgCannotReadTheTokenSymbol => '無法讀取代幣符號。';

  @override
  String get msgInvalidTokenSymbolEncoding => '代幣符號編碼無效。';

  @override
  String get msgInvalidTokenSymbolLength => '代幣符號長度無效。';

  @override
  String get msgCannotReadTheSavedTokenListExistingRecords =>
      '本機代幣列表無法讀取，未覆蓋原有記錄。';

  @override
  String get msgThisTokenHasAlreadyBeenAddedOnThis => '該鏈上的代幣已添加。';

  @override
  String get msgNetworkDisabled => '未啓用網路';

  @override
  String get msgQueryingMore => '查詢中';

  @override
  String get msgQueryFailed => '查詢失敗';

  @override
  String get msgTronMainnetIdentifierDoesNotMatchTheProtocol =>
      'TRON 主網標識與協議不匹配。';

  @override
  String get msgEnterTheNetworkNameAndNativeCurrencySymbol => '請填寫網路名稱和原生代幣符號。';

  @override
  String get msgEnterAValidHttpHttpsUrl => '請輸入有效的 HTTP / HTTPS 地址。';

  @override
  String get msgCannotAccessKeychainQuitRebuildAndRunThe =>
      '無法訪問系統鑰匙串（-34018）。請退出應用並重新編譯運行；熱重載無法更新原生簽名權限。';

  @override
  String get msgCannotAccessSecureDeviceStorageCheckThatKeychain =>
      '無法訪問本機安全存儲，請檢查系統鑰匙串是否已解鎖及訪問是否被允許。';

  @override
  String get msgCannotReadSavedNetworkSettingsCheckTheStored =>
      '本機網路配置無法讀取，請檢查保存的數據。';

  @override
  String get msgAccountIndexIsOutOfRange => '帳戶序號超出有效範圍。';

  @override
  String get msgInvalidRecoveryPhraseCheckTheWordsAndTheir => '助記詞無效，請檢查單詞和順序。';

  @override
  String get msgCannotDeriveTheEvmPrivateKey => '無法派生 EVM 私鑰。';

  @override
  String get msgInvalidPrivateKeyEnterHexadecimalCharacters =>
      '私鑰無效，應為 64 位十六進制字符串。';

  @override
  String get msgPrivateKeyValueIsOutOfRange => '私鑰無效，數值超出有效範圍。';

  @override
  String get msgInvalidPrivateKeyCannotCreateAnAccount => '私鑰無效，無法創建帳戶。';

  @override
  String get msgBinance => '幣安';

  @override
  String get msgTron => '波場';

  @override
  String msgRpcNetworkMismatchExpectedReceived(String p0, String p1) {
    return 'RPC 鏈不匹配：預期 $p0，實際 $p1。';
  }

  @override
  String msgAllRpcEndpointsAreUnavailableTryAgainLater(int p0) {
    return '全部 $p0 個 RPC 節點均不可用，請稍後重試或編輯節點列表。';
  }

  @override
  String get msgTheTokenAndNetworkDoNotMatch => '代幣與網路不匹配。';

  @override
  String get msgTheRpcReturnedADifferentTransactionHash => 'RPC 返回的交易哈希不匹配。';

  @override
  String get msgBroadcastStatusIsUncertainCheckTheTransactionHash =>
      '無法確認交易是否已廣播。請先按交易哈希查詢確認狀態，避免再次發起轉賬。';

  @override
  String msgEnterAValidAmountWithAtMostDecimal(int p0) {
    return '請輸入有效金額，最多支持 $p0 位小數。';
  }

  @override
  String get msgMainWallet => '主錢包';

  @override
  String get msgNoNetworkSelected => '未選擇網路';

  @override
  String get msgChooseANetworkToView => '請先選擇要查看的鏈';

  @override
  String get msgRpcNotConnected => '未連接 RPC';

  @override
  String get msgNativeAsset => '原生資產';

  @override
  String get msgConnectionFailed => '連接失敗';

  @override
  String get msgAwaitingSync => '待同步';

  @override
  String get msgWallet => '錢包';

  @override
  String get msgRpcRequestTimedOutCheckTheUrlOr => 'RPC 請求超時，請檢查地址或更換節點。';

  @override
  String get msgRpcRequestFailedCheckTheNetworkEndpointOr =>
      'RPC 請求失敗，請檢查網路、節點地址或訪問憑證。';

  @override
  String msgCouldNotConnectToEditRpcSettingsOr(String p0) {
    return '$p0 連接失敗，可在設置中修改 RPC 或重試。';
  }

  @override
  String get msgTheAccountHasChangedReopenThisAsset => '帳戶已切換，請重新打開資產。';

  @override
  String get msgCouldNotSaveNetworkSelectionPleaseTryAgain => '網路選擇保存失敗，請重試。';

  @override
  String get msgPrivateKeyAccountImported => '私鑰帳戶已導入';

  @override
  String get msgTheAccountWasSavedButCouldNotBe => '帳戶已保存，加載失敗，請重新打開錢包。';

  @override
  String get msgCannotReadThisFile => '無法讀取表格文件。';

  @override
  String get msgNoImportableRowsTheHeaderMustContainChain =>
      '表格沒有可導入的數據。首行為：鏈,私鑰';

  @override
  String importedRowSummary(int p0, String p1) {
    return '成功導入 $p0 條$p1。';
  }

  @override
  String msgFailed(String p0) {
    return '，$p0 條失敗';
  }

  @override
  String get msgChain => '鏈';

  @override
  String msgSelectedConnectingToRpc(String p0) {
    return '已選擇 $p0，正在連接 RPC…';
  }

  @override
  String msgNetworkSettingsSaved(String p0) {
    return '$p0 網路配置已保存';
  }

  @override
  String get msgSwapsAreNotConnectedNoOrderOrSignature => '兌換功能尚未接入，沒有創建訂單或簽名。';

  @override
  String get msgUnavailable => '暫不可用';

  @override
  String get msgAddressCopied => '地址已複製';

  @override
  String get msgSelectANetworkBeforeSending => '發送前請先選擇網路。';

  @override
  String msgTransactionBroadcast(String p0) {
    return '交易已廣播：$p0';
  }

  @override
  String get msgWalletOperationFailedPleaseTryAgain => '錢包操作失敗，請重試。';

  @override
  String get msgMostRecentlyBroadcastTransaction => '最近廣播的交易';

  @override
  String get msgEnterAValidTronAddressStartingWithT =>
      '請輸入有效的 TRON 地址（T 開頭，含正確校驗碼）。';

  @override
  String get msgTheTronEndpointReturnedAnErrorTryAnother =>
      'TRON 節點返回錯誤，請更換節點或稍後重試。';

  @override
  String get msgTronNetworkMismatchAMainnetEndpointIsRequired =>
      'TRON 節點網路不匹配：需要 TRON 主網。';

  @override
  String msgAllTronEndpointsAreUnavailableTryAgainLater(int p0) {
    return '全部 $p0 個 TRON 節點均不可用，請稍後重試或編輯節點列表。';
  }

  @override
  String get msgTrcQueryFailedCheckTheContractAndEndpoint =>
      'TRC20 合約查詢失敗，請檢查合約和節點。';

  @override
  String get msgTheTronEndpointReturnedADifferentAccountS =>
      'TRON 節點返回了不同帳戶的餘額。';

  @override
  String get msgTheTronEndpointReturnedAnInvalidBalance => 'TRON 節點返回的餘額無效。';

  @override
  String get msgTrxAmountIsOutOfRange => 'TRX 金額超出有效範圍。';

  @override
  String get msgTronReferenceBlockIsInvalidOrStaleCheck =>
      'TRON 參考區塊無效或已過期，請檢查本機時間和節點。';

  @override
  String get msgTheTronEndpointDidNotConfirmTheBroadcast => 'TRON 節點未確認交易廣播。';

  @override
  String get msgCannotReadTheWalletBookCheckSecureStorage =>
      '本機錢包簿無法讀取，請檢查安全存儲。';

  @override
  String get msgAccount => '帳戶 1';

  @override
  String msgPrivateKeyAccount(String p0) {
    return '私鑰帳戶 $p0';
  }

  @override
  String get msgSavedPrivateKeyAccountDataIsCorrupted => '本機保存的私鑰帳戶數據已損壞。';

  @override
  String msgWalletMore(String p0) {
    return '錢包 $p0';
  }

  @override
  String get msgUnsupportedNetwork => '不支持的鏈。';

  @override
  String get msgDuplicateEntrySkipped => '重復記錄，已跳過。';

  @override
  String get msgOnlyRecoveryPhraseWalletsCanDeriveAdditionalAccounts =>
      '只有助記詞錢包可以派生新帳戶。';

  @override
  String msgAccountMore(String p0) {
    return '帳戶 $p0';
  }

  @override
  String get msgAccountNotFound => '找不到此帳戶。';

  @override
  String get msgWalletNotFound => '找不到此錢包。';

  @override
  String get msgUnexpectedErrorPleaseTryAgain => '未知錯誤，請稍後重試。';

  @override
  String get msgSelfCustodyEvmTron => '自托管 · EVM / TRON';

  @override
  String get portfolioOverview => '地址總覽';

  @override
  String get portfolioByCoin => '按幣種';

  @override
  String get portfolioReferenceValue => '參考資產估值';

  @override
  String get portfolioValuedSubtotal => '已估值合計';

  @override
  String get portfolioAllAddresses => '全部關聯地址';

  @override
  String get portfolioAllNetworks => '全部啟用網路';

  @override
  String get portfolioAllAssets => '全部資產';

  @override
  String get portfolioSimple => '簡潔';

  @override
  String get portfolioDetailed => '詳細';

  @override
  String get portfolioDisplaySettings => '資產顯示';

  @override
  String get portfolioDisplayMode => '顯示模式';

  @override
  String get portfolioInitialCount => '首屏幣種數量';

  @override
  String get portfolioAll => '全部';

  @override
  String get portfolioSort => '資產排序';

  @override
  String get portfolioSortValue => '估值由高至低';

  @override
  String get portfolioStableFirst => '穩定幣優先';

  @override
  String get portfolioSortName => '名稱';

  @override
  String get portfolioHideZero => '隱藏已確認的零餘額';

  @override
  String get portfolioShowSpam => '顯示索引服務標記的疑似垃圾資產';

  @override
  String portfolioExpand(String p0) {
    return '展開全部（$p0）';
  }

  @override
  String get portfolioCollapse => '收起';

  @override
  String get portfolioSelectCoin => '選擇幣種';

  @override
  String get portfolioSearch => '搜尋幣種、合約或網路';

  @override
  String portfolioChainCount(int p0) {
    return '$p0 條鏈';
  }

  @override
  String portfolioCoinCount(int p0) {
    return '$p0 個幣種';
  }

  @override
  String get portfolioInformation => '估值與查詢詳情';

  @override
  String get portfolioValueExplanation =>
      '按 USDT 市價估算，1 USDT≈1 USD；僅包含已啟用網路下已新增和已發現的資產。';

  @override
  String get portfolioVersionExplanation =>
      'USDT0、Binance-Peg 版本使用 USDT 參考價；同名符號不會自動歸併或匹配行情。';

  @override
  String portfolioCoverage(String p0, String p1, String p2) {
    return '$p0/$p1 項持倉已查詢 · $p2 項未定價';
  }

  @override
  String get portfolioPartial => '部分結果';

  @override
  String get portfolioStalePrices => '行情已過期，使用近期快取';

  @override
  String get portfolioNoPrice => '暫無參考價格';

  @override
  String get portfolioNoAssets => '沒有符合條件的資產';

  @override
  String get portfolioShowZero => '查看零餘額資產';

  @override
  String get portfolioRefresh => '重新整理餘額與行情';

  @override
  String get portfolioSourceRpc => '餘額來自 RPC';

  @override
  String get portfolioSourceIndexer => '索引服務發現';

  @override
  String get portfolioPriceSource => '行情：Binance 公開 USDT 交易對';

  @override
  String portfolioUpdated(String p0) {
    return '行情時間：$p0';
  }

  @override
  String get portfolioTestnetExcluded => '測試網資產不計入估值。';

  @override
  String get discoveryServices => '資產索引服務';

  @override
  String get discoveryConfigure => '設定自動發現';

  @override
  String get discoveryNotConfigured => '自動發現未設定';

  @override
  String get discoveryQuerying => '正在發現資產…';

  @override
  String get discoveryPartial => '資產發現尚未完成';

  @override
  String get discoveryUnavailable => '自動發現暫不可用';

  @override
  String get discoveryLoadMore => '繼續載入資產';

  @override
  String discoveryConfigureProvider(String p0) {
    return '設定 $p0';
  }

  @override
  String get discoveryGetKey => '取得 API Key';

  @override
  String get discoveryDocs => '官方文件';

  @override
  String get discoveryPlans => '方案與額度';

  @override
  String get discoveryApiKey => '服務 API Key';

  @override
  String get discoveryKeyHint => '填入自己的服務金鑰，並非錢包私鑰';

  @override
  String get discoveryKeyRequired => '請填寫服務 API Key。';

  @override
  String get discoveryPrivacy => '啟用後，所選服務商會收到對應網路的關聯公開地址。服務金鑰保存在本機安全儲存中。';

  @override
  String get discoveryAssignments => '選擇網路（將取代該網路的現有索引服務）';

  @override
  String get discoveryChooseNetwork => '請至少選擇一個受支援的已啟用網路。';

  @override
  String get discoveryTest => '測試連線';

  @override
  String get discoveryConnected => '連線成功，金鑰與回應有效。';

  @override
  String get discoverySaveEnable => '儲存並啟用';

  @override
  String get discoveryEnabled => '已啟用';

  @override
  String get discoveryDisabled => '已停用';

  @override
  String get discoveryDisable => '停用';

  @override
  String get discoveryDelete => '刪除設定';

  @override
  String get discoveryEdit => '設定';

  @override
  String get discoveryUnauthorized => '服務金鑰無效或權限不足，請檢查金鑰和方案權限。';

  @override
  String get discoveryLimited => '索引服務額度不足或觸發限流，請稍後重試。';

  @override
  String get discoveryResponseInvalid => '索引服務回傳了無效的資產資料。';

  @override
  String get discoveryRequestFailed => '索引服務連線失敗，已關注資產仍可查看。';

  @override
  String get discoverySettingsUnreadable => '無法讀取索引服務設定，原記錄已保留。';

  @override
  String get discoverySaveFailed => '索引服務設定儲存失敗，請重試。';

  @override
  String get discoveryUnsupported => '本應用尚未接入該服務在此網路的資產發現。';

  @override
  String get discoveryWatch => '加入關注';

  @override
  String get discoveryWatched => '已加入關注資產';

  @override
  String get discoveryMoralisGuide =>
      '註冊 Moralis → 取得 Web3 API Key → 選擇 Ethereum、Polygon 或 BNB Chain。額度以方案頁為準。';

  @override
  String get discoveryAlchemyGuide =>
      '建立 Alchemy App → 啟用 Ethereum 或 Polygon → 複製 API Key。本應用使用 Token API。';

  @override
  String get discoveryTronGridGuide =>
      '登入 TronGrid → 建立 API Key → 啟用 TRON 主網。本應用發現 TRC20 持倉。';

  @override
  String get discoveryLinkCopied => '瀏覽器未能開啟，連結已複製。';

  @override
  String get discoveryNoEnabledNetworks => '請先啟用一個受支援網路，再設定自動發現。';

  @override
  String get portfolioAddressDetails => '關聯地址';

  @override
  String get portfolioBalanceStatus => '餘額狀態';

  @override
  String get portfolioSpam => '疑似垃圾資產';

  @override
  String get portfolioNoCoin => '目前篩選下沒有幣種';

  @override
  String get discoveryNotConfiguredShort => '未設定';

  @override
  String get settingsSearch => '搜尋設定';

  @override
  String get settingsSearchHint => '語言、顯示模式、RPC…';

  @override
  String get settingsQuickLinks => '常用設定';

  @override
  String get settingsCategories => '全部設定';

  @override
  String get settingsWallets => '錢包與帳戶';

  @override
  String get settingsWalletsHint => '管理、建立與匯入';

  @override
  String get settingsAssetsHint => '顯示偏好與關注幣種';

  @override
  String get settingsData => '網路與資料';

  @override
  String get settingsDataHint => '網路 RPC 與資產索引服務';

  @override
  String get settingsSecurity => '安全與備份';

  @override
  String get settingsSecurityHint => '帳戶安全資訊與備份說明';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsGeneralHint => '語言與外觀主題';

  @override
  String get settingsAppearance => '外觀主題';

  @override
  String get settingsLight => '淺色';

  @override
  String get settingsDark => '深色';

  @override
  String get settingsWatchedTokens => '關注幣種管理';

  @override
  String get settingsNoResults => '找不到相關設定';

  @override
  String get settingsClearSearch => '清除搜尋';

  @override
  String get settingsUnavailable => '暫未接入';

  @override
  String get settingsNetworkDisabled => '未啟用';

  @override
  String get settingsNetworkEnabled => '已啟用';

  @override
  String get settingsNetworkState => '啟用網路';

  @override
  String get settingsBackupHint => '請妥善離線保管復原憑證。雲端備份暫未接入。';

  @override
  String get settingsMatchedOption => '已定位此設定';

  @override
  String get omniImportTitle => '預覽 OmniVault 匯入';

  @override
  String get omniImportResult => 'OmniVault 匯入結果';

  @override
  String omniReading(int count) {
    return '正在驗證，已處理 $count 列…';
  }

  @override
  String get omniConfirm => '確認匯入';

  @override
  String get omniNewWallet => '新錢包';

  @override
  String get omniAliasesAdded => '新增別名';

  @override
  String get omniDuplicates => '重複';

  @override
  String get omniSkipped => '略過';

  @override
  String get omniFailed => '失敗';

  @override
  String get omniAllRows => '全部記錄';

  @override
  String get omniNoRows => '此類別沒有記錄';

  @override
  String omniLine(int line) {
    return '第 $line 列';
  }

  @override
  String get omniPreviousPage => '上一頁';

  @override
  String get omniNextPage => '下一頁';

  @override
  String get omniWalletAliases => '錢包別名';

  @override
  String get omniHeader => 'OmniVault CSV 必須包含七個必要欄位，且表頭不能重複。';

  @override
  String get omniInvalidEncoding => '檔案必須使用 UTF-8 編碼。';

  @override
  String omniMalformedCsv(int line) {
    return '第 $line 列的 CSV 引號格式無效。';
  }

  @override
  String get omniColumnCount => '此列欄位數與表頭不一致。';

  @override
  String get omniInvalidStatus => '無法識別私鑰匯出狀態。';

  @override
  String get omniInvalidIdentity => '平台和 UID 各需 1 至 256 個字元，且不能包含控制字元。';

  @override
  String get omniInvalidAddress => '原地址在該鏈上的格式無效。';

  @override
  String get omniAddressMismatch => '私鑰衍生地址與原地址不一致。';

  @override
  String get omniWalletChanged => '錢包簿已有變更，請重新開啟檔案驗證。';

  @override
  String get omniStorageError => '加密錢包資料庫未能完成此操作。';

  @override
  String get omniRecordTooLarge => 'CSV 中有一筆記錄超過支援的大小。';

  @override
  String get omniSearchHint => '搜尋錢包名稱、平台、UID 或地址前綴';

  @override
  String get omniFileHint => '支援 OmniVault CSV 或包含鏈和私鑰的 CSV/TSV';

  @override
  String get transferChooseAsset => '選擇要發送的資產';

  @override
  String get transferReview => '核對轉帳';

  @override
  String get transferEdit => '修改轉帳';

  @override
  String get transferSender => '轉出地址';

  @override
  String get transferContract => '代幣合約';

  @override
  String get transferFee => '預計網路手續費';

  @override
  String get transferTronFeeNote => 'TRX 手續費會隨可用能量和頻寬變化。';

  @override
  String get transferViewTransaction => '查看鏈上交易';

  @override
  String get transferInvalidRecipient => '請輸入該網路的有效收款地址。';

  @override
  String get transferAmountTooLarge => '金額超過該網路支援的範圍。';

  @override
  String get transferSimulationFailed => '網路未通過轉帳模擬，請檢查金額和收款地址。';

  @override
  String get transferTokenDecimalsChanged => '代幣合約回傳的精度不同，請重新整理代幣資訊後再發送。';

  @override
  String get transferFeeUnavailable => '無法估算手續費，請重試或檢查 RPC 節點。';

  @override
  String get transferInsufficientFee => '原生幣餘額不足，無法支付本次轉帳及其網路手續費。';

  @override
  String get transferReviewExpired => '請重新核對轉帳後再簽名。';

  @override
  String get walletBalancesTitle => '全部錢包餘額';

  @override
  String walletBalancesStarted(String time) {
    return '$time 開始查詢';
  }

  @override
  String get walletBalancesChecking => '查詢中';

  @override
  String get walletBalancesPaused => '已暫停';

  @override
  String get walletBalancesFinished => '查詢完成';

  @override
  String get walletBalancesLoadFailed => '錢包列表讀取失敗';

  @override
  String walletBalancesProgress(String state, int checked, int total) {
    return '$state · $checked / $total 個帳戶';
  }

  @override
  String get walletBalancesScope =>
      '按美元估值從高到低排列。指定鏈的錢包查來源鏈，其餘錢包查已啟用網路。涵蓋原生幣、內建和關注的代幣，以及已設定的代幣探索。測試網資產不計入估值。';

  @override
  String walletBalancesIncompleteCount(int count) {
    return '$count 個帳戶結果不完整';
  }

  @override
  String get walletBalancesPause => '暫停查詢';

  @override
  String get walletBalancesResume => '繼續查詢';

  @override
  String get walletBalancesBackground => '轉到背景查詢';

  @override
  String get walletBalancesNoNetwork => '無可查詢網路';

  @override
  String get walletBalancesQueryIncomplete => '餘額或代幣探索不完整';

  @override
  String get walletBalancesTokenListError => '無法讀取關注代幣';

  @override
  String get walletBalancesMissingPrices => '部分資產缺少報價';

  @override
  String get walletBalancesNoHoldings => '查詢範圍內餘額為零。';

  @override
  String get walletBalancesWaiting => '正在等待首批結果…';

  @override
  String get walletBalancesEmpty => '沒有可查詢的錢包。';
}
