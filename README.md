# Asterkeel Wallet · 星舟钱包

Asterkeel Wallet is a Flutter cross-platform self-custodial Web3 wallet foundation covering iOS, Android, macOS, and Windows project targets.

## Current milestone

This milestone contains the first real wallet vertical slice:

- Multiple BIP39 wallets: create or import more wallets after onboarding without replacing existing ones
- Direct single EVM/TRON private-key import from the welcome screen and Settings, with masked input, network selection, validation and duplicate detection
- BIP32 EVM accounts at `m/44'/60'/0'/0/i` and TRON accounts at `m/44'/195'/0'/0/i`, with named groups, account derivation, search and persistent active-account selection
- Platform-backed secure storage through Keychain, Keystore, macOS Keychain, and Windows Credential Manager
- User-selected EVM and TRON network profiles with no RPC connection until selection
- Multi-network native balance reads through JSON-RPC after the user enables one or more networks
- A current-operation network for signing, with each network's RPC pool and current working endpoint visible in Settings
- Per-network editable ordered RPC pools, built-in free public endpoints, automatic failover, custom EVM network profiles, and Chain ID checks
- Clickable native-asset rows, searchable full asset list, and asset details with refresh/send/receive actions
- Local EVM/TRON signing and broadcast for native coins and ERC20, BEP20 and TRC20 tokens
- Recovery phrase display followed by word-position verification before a newly created wallet is saved
- Address-first asset home: linked EVM/TRON addresses, cross-chain coin totals, compact lists and USDT-based reference USD values
- Optional Moralis / Alchemy / TronGrid asset discovery with user-supplied keys and setup guides
- Simplified Chinese, Traditional Chinese and English, with system matching and persistent language selection
- Cloud backup is deliberately shown as disabled until iCloud/Google Drive integration has a secure design
- Responsive blue-accented light and dark themes with distinct desktop and phone layouts
- Receive address copy and an explicit send review form
- CSV/TSV batch import for chain + private-key rows, with validation, duplicate skipping, and secure local storage

This is not a mainnet-ready release. Swaps, WalletConnect, dApp discovery, full multi-chain adapters, hardware wallets, backup export, and security audit gates are not complete. Ethereum Mainnet, Ethereum Sepolia, Polygon Mainnet, Polygon Amoy, BNB Smart Chain Mainnet, and TRON Mainnet are selectable profiles; the user chooses which networks to view and when to connect.

## Run locally

```bash
flutter pub get
flutter run -d macos
```

### 使用构建脚本（macOS 主机）

项目根目录提供 `build.sh`，从任何目录调用都会在本项目内构建：

```bash
# 编译并运行 iOS 模拟器应用（优先已启动的 iPhone，否则自动启动一个）
./build.sh ios-sim run

# 查看可用模拟器；使用名称或 UUID 指定设备
./build.sh ios-sim devices
./build.sh ios-sim run --device "iPhone 18 Pro"

# 只编译，不启动；无参数也执行此操作
./build.sh ios-sim build

# iPhone / iPad 真机调试（先完成下方的首次配置）
./build.sh ios devices
./build.sh ios run
./build.sh ios run --device IPHONE_DEVICE_ID
./build.sh ios build

# macOS 编译、运行及发布模式
./build.sh macos build --mode release
./build.sh macos run

# 将其他参数透传给 Flutter
./build.sh ios-sim run -- --dart-define=APP_ENV=dev
./build.sh --help
```

模拟器构建产物位于 `build/ios/iphonesimulator/Runner.app`，不能安装到
真实 iPhone；模拟器仅支持 Debug 模式。`run` 包含编译、安装及启动，并保留
Flutter 调试终端：`r` 热更新、`R` 重启、`q` 退出、`d` 脱离并保持应用运行。
同名模拟器存在多个时，用 `devices` 输出中的 UUID 指定。

需要完整 Xcode、已安装的 iOS Simulator runtime，以及 PATH 中的 Flutter
（也会尝试 `$HOME/develop/flutter/bin/flutter`）。可通过
`FLUTTER_BIN=/path/to/flutter ./build.sh ios-sim run` 指定 SDK。
脚本自动补充 Homebrew 的命令搜索目录，以查找 CocoaPods。

### iPhone / iPad 真机首次配置

1. 用数据线连接并解锁设备，在 iPhone 上确认“信任此电脑”；首次建议使用 USB。
2. 在 iPhone 的 **设置 → 隐私与安全性 → 开发者模式** 中开启，按提示重启并确认。
   如果找不到此选项，先在 Xcode 的设备管理窗口中完成连接和配对。
3. 用 Xcode 打开 **ios/Runner.xcworkspace**，在 **Xcode → Settings → Apple Accounts**
   登录 Apple 账号。选择 **Runner target → Signing & Capabilities**，启用
   **Automatically manage signing**，Team 选择自己的开发团队或 Personal Team。
   如果 Bundle Identifier 注册冲突，把 `com.example.stoneWallet` 改成自己唯一的标识。
   项目已有 Team 配置；脚本保留它，首次使用仍需确认是当前账号可使用的团队。
4. 在 Xcode 选择已连接的真机，等待设备准备完成；若出现证书信任提示，在手机的
   **设置 → 通用 → VPN 与设备管理** 中信任对应开发者。如果弹出“本地网络”权限，
   允许用于 Flutter 调试连接。
5. 运行 `./build.sh ios devices`，随后执行 `./build.sh ios run`。
   只有一台可用真机时自动选择，多台时通过 `--device` 指定 ID 或完整名称。
   脚本仅选择 Flutter 识别到的可用 iOS 真机，不会选中模拟器。

个人 Apple 账号可用于本机真机测试，无需先购买付费会员。后续可在 Xcode 配对设备后
配置无线调试；日常排查连接问题时先使用 USB。
详见 [Flutter 官方 iOS 真机配置说明](https://docs.flutter.dev/platform-integration/ios/setup)。

真机的 `build` 默认也为 Debug；可通过 `--mode release` 构建 Release，后者不支持热更新。
`build` 仅生成应用；`run` 执行编译、安装和调试。真机需要有效开发签名，模拟器产物不能
直接安装到 iPhone。`./build.sh ios build -- --no-codesign` 可仅验证未签名的真机编译，
生成的应用不能直接安装调试。

For iOS or Android, first start a simulator/emulator or connect a physical device,
then run `flutter devices`. Use the actual device ID from its output with
`flutter run -d DEVICE_ID` (replace `DEVICE_ID`); `ios` and `android` are platform
names, not device selectors. If no iOS simulator runtime is installed, download it
with `xcodebuild -downloadPlatform iOS`, then open Xcode's Simulator/Device Hub and
boot an iPhone simulator before listing devices again. Windows desktop builds run
on a Windows host with `flutter run -d windows`.

For a quick local check:

```bash
flutter analyze
flutter test
```

## 资产首页与语言

创建或导入完成后直接进入资产页。手机不再显示底部导航，固定顶部提供账户切换和
设置齿轮；桌面侧栏仅保留“资产 / 设置”。设置作为独立 `/settings` 页面打开，
返回保留视图、币种选择、筛选、搜索内容及滚动位置。外观设置支持跟随系统、浅色、深色，默认跟随系统并记住选择；系统深浅色变化会即时生效。

设置采用独立导航栈，分为钱包与账户、资产、网络与数据、安全与备份、通用五个分类。
首页顶部固定搜索入口，提供语言、资产展示、网络 RPC 快捷入口；详细配置逐级进入。
宽屏（≥1100）左侧显示设置目录、右侧显示当前页面，窄屏逐页返回；窗口缩放、语言
与主题切换保留当前配置页面和表单。网络列表与索引服务列表仅显示名称和状态，进入
详情后再编辑节点、查看申请指引或配置密钥。资产页的展示设置直接进入对应子页。

设置搜索在本地匹配简体中文、繁體中文、英语名称及 RPC、节点、API Key 等别名。
结果显示所属路径和非敏感当前值，点击直达并定位具体选项；返回保留本次关键词与
结果位置。搜索不索引地址、节点 URL、凭证或用户数据，不持久保存搜索历史。


资产页提供“地址总览 / 按币种”两种视图：以当前账户的关联 EVM、TRON 地址为范围，
按地址类型和已启用网络筛选。首次默认总览、简洁模式、前 5 个币种；简洁列表展示数量，
详细模式增加约合 USD。菜单可添加币种、管理网络、搜索完整列表或筛选稳定币 / 其他币种。
设置中的“资产展示”管理 3 / 5 / 10 / 全部、估值 / 稳定币优先 / 名称排序、隐藏零余额、
显示疑似垃圾资产。展开全部和搜索不改变估值合计。旧语言与 USDT/USDC 选择保留；
旧主分类默认进入新总览。NFT / RWA 仅保留类型，不查询持仓或显示空栏目。

多语言采用 [Flutter 官方方案](https://docs.flutter.dev/ui/internationalization)：
`flutter_localizations`、`lib/l10n/*.arb` 和 `flutter gen-l10n`。
设置与首次欢迎页均可选择跟随系统、简体中文、繁體中文或 English。首次默认跟随系统；
中文 Hant 脚本或 TW/HK/MO 地区使用繁体，其他中文使用简体；未支持的语言回退英语。
切换立即生效，保留当前页面、表单、账户及交易提交状态。已有钱包、账户名称保持原样，
新建默认名称使用创建时的语言；助记词、私钥、地址、合约、哈希及符号均不翻译。

偏好单独保存在 `stone_wallet.v1.app_preferences`（version 1），字段为
语言、外观模式、视图、显示模式、条数、排序、资产 / 地址 / 网络筛选及选中币种；旧 `category / family`
字段保留兼容。通过串行队列保存，避免快速操作覆盖其他偏好。
无效字段按项回退，读取失败不会阻止钱包加载；保存失败显示提示。此改动不迁移或改写
钱包密钥、账户名称、代币列表及网络记录。

核心错误通过 `MessageCode` 和参数传到界面后翻译；余额状态由枚举表示。
金额继续使用 BigInt 精确计算，展示分组在字符串上完成。广播结果不确定时保留交易
哈希并禁用再次提交，语言切换不解除此状态。所有测试使用公开测试助记词和模拟 RPC，
不进行真实转账。

```bash
flutter gen-l10n
flutter analyze
flutter test
./build.sh ios build -- --no-codesign

# 生成三种语言的手机、桌面、深浅色和 1.3 倍字体预览（macOS）
flutter test test/preferences_localization_test.dart \
  --dart-define=RENDER_LOCALES=true --plain-name='preview and all messages'
# 输出：build/locale-previews/
```

## Networks and assets

### Address overview, per-coin view and valuation

The default overview groups assets across the current account's linked addresses,
not every account in a mnemonic wallet. Its compact reference-value header replaces
the old gradient hero and distribution ring. Lists default to five coins and can be
expanded or searched; tapping a coin opens its per-chain view, and tapping a chain
opens the existing native or token details. Zero balances can be revealed in display
settings; failed and pending balances are never treated as zero.

`PortfolioHolding` carries the chain, actual address, raw units, asset identity,
state and RPC/indexer source. Known coin identities can aggregate across chains;
unrecognized tokens retain chain/contract identities even when their tickers match.

`BinanceQuoteService` reads public USDT spot markets without an API key. ETH, BNB,
POL, TRX and USDC use their explicit market mapping; canonical USDT-family contracts
use a reference price of 1. Values use **1 USDT ≈ 1 USD**, not a separately sourced
fiat rate. Quotes cache for 60 seconds; a failed refresh can retain a marked stale
quote for up to five minutes, after which it is excluded. Unmapped assets keep their
quantities and show no price. Partial coverage is labeled **已估值合计**; testnet
balances are excluded. Market requests contain only symbols, never account addresses.
All multiplication and sums use BigInt-backed exact decimals; rounding is for display.
See [Binance's market-data-only API](https://developers.binance.com/en/docs/products/spot/faqs/market_data_only).

The default catalog contains Ethereum USDT, TRON USDT, BNB Chain Binance-Peg
BSC-USD (shown as USDT), and Polygon USDT0. The latter two versions are labeled
explicitly. USDT-family quantities are summed with exact BigInt arithmetic across
6- and 18-decimal units. Coin quantities and reference USD values are separate; the latter use the USDT
market assumptions described above. Only registered chain/contract pairs enter
stablecoin totals; a custom token named USDT cannot inflate them. Testnet tokens
are excluded from the aggregate.

Click **添加币种** to show/hide the presets or add Circle USDC on Ethereum/Polygon.
**添加自定义代币** accepts a network and contract, reads its symbol and decimals
from that chain, then requires **确认添加**. ERC20/BEP20 and TRC20 queries are
read-only while querying balances and adding tokens. Token
preferences persist locally under `stone_wallet.v1.watched_tokens`, separately
from wallet secrets. Corrupt preference records are reported rather than silently
replaced. Wallet keys and existing network settings are preserved.

RPC queries run only on enabled networks. Reading metadata for a custom contract is
an explicit connection check. Unknown or failed values remain `—`; errors and
reference assumptions live in the compact information sheet. Switching accounts or
changing networks discards old responses. Adding or hiding watched tokens refreshes
their RPC balances.

### Optional asset indexers

In **设置 → 资产索引服务**, each provider has setup steps, key signup, official docs,
plans, connection testing and secure key entry. Nothing is queried until the user
saves and enables a configuration for an enabled supported network.

| Provider | Integrated networks | Guide |
|---|---|---|
| Moralis | Ethereum, Polygon, BNB Chain | [Token balances](https://docs.moralis.com/data-api/evm/wallet/token-balances) |
| Alchemy | Ethereum, Polygon | [Token API](https://www.alchemy.com/docs/reference/token-api-quickstart) |
| TronGrid | TRON TRC20 | [Indexed balances](https://developers.tron.network/reference/get-trc20-token-balances-by-address) |

One provider is assigned per chain; saving a replacement updates that assignment.
Service keys are stored separately in platform secure storage under
`stone_wallet.v1.asset_indexer_configs`. Enablement sends that chain's linked public
address to the selected provider. Keys can be changed, disabled or deleted. Provider
plan limits remain linked to their current pricing pages rather than hard-coded quotas.

Discovery fetches up to five 100-item pages per chain initially. Remaining cursors
show **继续加载资产** and incomplete coverage; repeated cursors and invalid records
remain explicitly incomplete. Results are deduplicated by address/chain/contract,
with watched RPC holdings taking precedence. Discovered tokens can be added to the
watched catalog from details. Only identity-mapped tokens receive market prices;
indexer-provided USD values and matching ticker names are not used to guess prices.
Explicit spam flags are hidden by default, with a setting to reveal them.

Discovery caches are in memory for the current account and are cleared on account,
network or credential changes; late replies are discarded. Indexer outages never
remove the watched-asset RPC path or affect the native signer. Tests use synthetic
responses for authentication, pagination, duplicate holdings, malformed metadata,
quota errors, account races, exact valuation, stale quotes and setup flows.

Token details show the exact contract, chain, decimals, account address and receive
QR. Choose **发送** on the asset home or in asset details to transfer native coins
and ERC20, BEP20 or TRC20 tokens, including USDT on BNB Smart Chain and TRON.
The review displays the sender, recipient, chain, amount, token contract and
estimated native fee. Signing and broadcast start after confirmation. Use the
returned hash to check chain inclusion and execution in the explorer.

Sources: [Tether's contract registry](https://tether.to/en/supported-protocols/),
[BNB Chain token mapping](https://explorer.bnbchain.org/asset/USDT-6D8),
[USDT0 Polygon](https://usdt0.to/ecosystem/polygon),
[Circle USDC registry](https://developers.circle.com/stablecoins/usdc-contract-addresses),
[TRON read-only contract calls](https://developers.tron.network/docs/smart-contract-interaction).

`flutter test test/stablecoin_test.dart` checks amount aggregation, spoofed symbols,
preferences, ABI calls, failover, account-response races and the add-token flows.
To render synthetic-data previews on macOS:

```bash
flutter test test/stablecoin_test.dart --dart-define=RENDER_STABLECOINS=true
# Output: build/stablecoin-previews/
```

### BNB Smart Chain and TRON

Enable **BNB Smart Chain** or **TRON** in the network selector. BSC uses Chain ID
56, BNB and the existing EVM account address. TRON uses the standard
`m/44'/195'/0'/0/i` derivation path and a Base58Check `T…` address, distinct from
that mnemonic account's EVM address. Existing mnemonic wallets automatically have
both addresses; adding accounts advances the same account index on both paths.
Private-key imports accept TRON in single and batch imports and derive its address
from the exact imported key. The header, receive QR, copy action, wallet manager,
asset details and Settings follow the current network's address and path.

TRX balances and transfers use SUN (1 TRX = 1,000,000 SUN). TRON validates the
mainnet genesis block for every endpoint, handles unactivated accounts as zero,
and rejects malformed replies rather than reporting a zero balance. Native TRX
transfers are encoded locally as `TransferContract` protobuf, SHA256-hashed and
signed on-device with secp256k1. No private key or mnemonic is sent to an API.
Retries reuse the identical signed transaction; uncertain broadcasts retain their
hash and block resubmission. Stale reference blocks are rejected. TRON API errors,
rate limits and network mismatches trigger the next configured endpoint.

TRX transfers may consume TRX when bandwidth is insufficient, and transferring to
an unactivated address can incur activation fees. This release supports the native
assets **BNB and TRX** and BEP20/TRC20 transfers. TRC20 uses the sender's native TRX
balance and available Energy and Bandwidth to estimate the fee. Staking and TRON
multisignature permissions are outside this transfer flow. Automated verification
uses synthetic keys and mock RPC responses.

Network references: [BNB configuration](https://docs.bnbchain.org/bnb-smart-chain/developers/wallet-configuration/),
[TRON addresses](https://developers.tron.network/docs/account),
[TRON mnemonic path](https://tronweb.network/docu/docs/5.2.0/API%20List/utils/fromMnemonic/),
[TRON protocol](https://github.com/tronprotocol/protocol/blob/master/core/Tron.proto),
[TRON networks](https://developers.tron.network/docs/networks),
[PublicNode TRON gateway](https://tron.publicnode.com/).

`flutter test test/tron_test.dart` verifies address vectors, migration compatibility,
precision, local transaction contents, recoverable signatures, failover and UI
address/amount behavior with public test credentials and mocked HTTP.

### Wallets and accounts

Click the current wallet name at the top, or **设置 → 管理钱包与账户**, to open
**钱包管理**. The model follows the wallet/account grouping described in
[OKX's wallet management guide](https://web3.okx.com/zh-hans/help/how-do-i-manage-my-wallet-app):

- A mnemonic wallet owns one recovery phrase and can derive **账户 1, 账户 2, …**
  with **添加账户**. The first address keeps the original derivation path ending
  in `/0`; additional addresses end in `/1`, `/2`, etc. A private-key wallet has
  one account and does not expose account derivation.
- **创建新钱包** generates a new recovery phrase, shows it and verifies the
  requested words before saving. Creating from an existing wallet can be
  cancelled without changing the current wallet.
- **导入钱包** offers mnemonic, single private-key and batch private-key import.
  Different mnemonic phrases create independent wallet groups; importing the
  same phrase selects its existing first account and preserves all derived
  accounts and names. Settings exposes create and import actions too.
- Rename wallets and accounts with their edit buttons, search by wallet/account
  name or address, copy public addresses and select any account. The header,
  assets, receive address and signing account follow the selection. Settings
  shows the selected account's actual derivation path. Selection survives restart.

Wallet secrets, account indices, names and selection are saved together in one
versioned platform-secure-storage record (`stone_wallet.v2.wallet_book`). Legacy
single-mnemonic and batch-private-key records are validated and migrated together;
their original secure-storage keys are retained as a recovery copy. Invalid
records or failed writes do not silently discard or replace existing wallets.
Mutations and reads are serialized to prevent concurrent derivations from reusing
an index. The original address and network configuration are preserved.

Recovery phrases restore the same deterministic addresses; account names and the
number of locally added accounts are local metadata. After restoring a phrase on
a fresh installation, use **添加账户** to recreate its additional addresses in
order. Balance/history-based account discovery, wallet removal and secret export
are not part of this change.

`flutter test test/wallet_management_test.dart` checks migration, failed writes,
duplicate imports, concurrent derivation, renaming, search, switching and restart.
`flutter test integration_test/wallet_management_test.dart -d DEVICE_ID` checks
the complete native flow with only synthetic in-memory wallet data.

To import one existing account, choose **导入私钥**, select a network and enter a
64-character hexadecimal EVM/TRON private key (an optional `0x` prefix is accepted).
The key is saved in platform-backed secure storage; successful import activates
the account and connects to the selected network for its balance. Invalid or
duplicate imports stay in the form for correction. Existing mnemonic and imported
accounts remain available in the wallet picker as **主钱包** and **私钥账户**.
Single and batch imports share the same storage, including existing batch data.

### macOS 上导入 OmniVault 私钥

在欢迎页或「设置 → 钱包 → 导入钱包」中选择「批量导入私钥表格」，打开
OmniVault 导出的 UTF-8 CSV。文件应包含 `platform`、`uid`、`chain`、
`address`、`private_key`、`key_status`、`reason`。应用会在本机核对 BSC
和 TRON 主网地址，按源文件行号显示预览，确认后保存有效记录。

新钱包以「平台 · UID」命名。同链同地址的其他来源保存为别名。在钱包管理中可按
平台或 UID 前缀搜索，改名后也可通过原别名找到钱包。点击钱包旁的别名按钮可查看完整列表。
macOS 钱包簿使用 SQLCipher 加密，数据库密钥保存在本机 Keychain。首次打开新版时会迁移已有钱包。
旧的双列 CSV/TSV 和单条私钥入口仍可使用。

macOS 构建通过 Swift Package Manager 使用 SQLCipher Community Edition，
遵循其 [BSD 许可证](https://github.com/sqlcipher/SQLCipher.swift/blob/4.20.0/LICENSE.md)。

Choose a network name in **Manage Networks** to set the operation chain; checkboxes
enable additional chains for balance viewing. Click **Save** to connect. Syncing,
success and failure are tracked independently per chain; unavailable balances show
`—`, not zero.

Use **Edit RPC** for any enabled network or **Add Custom Chain** in Settings (also
available in Manage Networks). Configure the name, Chain ID, native symbol, RPC URLs,
optional explorer URL and testnet flag. Saved profiles and RPC overrides survive
restarts and work with batch private-key imports by network name or Chain ID.
Custom profiles use the EVM signer and 18-decimal native-asset model. Built-in TRON
uses its own HTTP API, address derivation, six-decimal SUN amounts and signer;
Bitcoin, Solana and additional protocols need separate adapters. EVM RPCs verify `eth_chainId` before reads and signing; TRON HTTP APIs verify the
mainnet genesis block.

### Automatic RPC failover

The defaults in `lib/wallet_core.dart` include two free, keyless public endpoints
for each built-in network (TRON uses HTTP API roots):

| Network | First endpoint | Backup endpoint |
| --- | --- | --- |
| Ethereum | `https://eth.drpc.org` | `https://ethereum-rpc.publicnode.com` |
| Ethereum Sepolia | `https://ethereum-sepolia-rpc.publicnode.com` | `https://rpc.sepolia.ethpandaops.io` |
| Polygon | `https://polygon.drpc.org` | `https://polygon-bor-rpc.publicnode.com` |
| Polygon Amoy | `https://polygon-amoy.drpc.org` | `https://polygon-amoy-bor-rpc.publicnode.com` |
| BNB Smart Chain | `https://bsc-dataseed.bnbchain.org` | `https://bsc-rpc.publicnode.com` |
| TRON | `https://api.trongrid.io` | `https://tron-rpc.publicnode.com` |

Sources: [dRPC](https://drpc.org/docs/ethereum-api),
[PublicNode](https://www.publicnode.com),
[Polygon network docs](https://docs.polygon.technology/pos/reference/rpc-endpoints),
[Sepolia chain registry](https://github.com/ethereum-lists/chains/blob/master/_data/chains/eip155-11155111.json).
These are shared services with provider rate limits; availability depends on the
local network and the provider. They do not include a private Alchemy API key.

Enter one HTTP/HTTPS RPC per line in **编辑 RPC**. Order sets priority and duplicate
URLs are removed. **恢复内置免费节点** restores the shipped list; click Save to apply.
Each chain uses its own pool, remembers its last working endpoint for that running
service, and tries the next endpoint on timeout, HTTP/rate-limit errors, malformed
responses, JSON-RPC errors or a mismatched Chain ID. Every EVM endpoint is checked
against the network's Chain ID before balance reads, signing preparation and
broadcast; TRON endpoints instead validate the mainnet genesis block. Each EVM chain check/operation and each TRON HTTP request has a five-second timeout; one pass
through the pool is attempted, with no endless retry. All-node failures leave the
balance unavailable (`—`) and show an error. No RPCs are contacted before a chain
is enabled or the user explicitly starts a connection check.

Old single-URL settings automatically gain the built-in backups. Existing custom
URLs stay first; the retired Cloudflare/Polygon default URLs are replaced. A new
explicitly saved pool is respected, even if it contains only one URL.

Transaction preparation can fail over before signing finishes. Broadcast retries
always reuse identical signed bytes and the same transaction hash; failover does
not re-sign with a new nonce. If every broadcast attempt fails, the send panel
shows the locally calculated transaction hash and disables another signature in
that panel until the user checks the status. Successful broadcast is still not a
confirmation that the transaction has been mined.

`flutter test test/rpc_failover_test.dart` verifies failover with simulated nodes;
the following opt-in native test reads balances using synthetic public test data
and first forces a failed endpoint before trying the built-in public nodes:

```bash
flutter test integration_test/rpc_failover_test.dart -d macos
```

Coin rows open per-chain lists, whose rows open the corresponding asset details.
Native details retain refresh, receive, send and current-chain actions.
Android release includes Internet permission and allows user-configured HTTP RPCs;
iOS permits these HTTP RPC connections through its transport configuration.

## Responsive layout checks

The welcome screen splits at 1000 logical pixels. The wallet has no phone bottom navigation. It uses a compact rail from 760 and a
full two-item sidebar from 1100; the linked-account header and Settings entry remain
fixed above the asset scroller. macOS starts at 1200×800 with an 800×600 minimum content size.

`flutter test test/responsive_layout_test.dart` covers both themes, 1.3× text,
breakpoint boundaries, keyboard insets, wallet switching, and long scrolling lists.
Mobile mnemonic import opens without autofocus; tap the input to show the native
keyboard. Panel results resolve after the old route's exit transition and removal,
so callers do not replace a page while its input/selection overlays are still
mounted. Close/submit actions release input focus before popping the route.
`flutter test test/ios_lifecycle_test.dart` checks rapid close, swipe dismissal,
selection menus, keyboard insets, import completion and route disposal ordering.
`flutter test integration_test/import_lifecycle_test.dart -d DEVICE_ID` checks the
native import flow using only in-memory synthetic data.
To render the desktop and phone welcome/assets/settings previews using a local CJK font:

```bash
flutter test test/responsive_layout_test.dart \
  --dart-define=RENDER_LAYOUTS=true \
  --dart-define=LAYOUT_FONT=/absolute/path/to/cjk-font.ttf \
  --name='(1200px|390px).*scale 1.0'
```

Previews are saved under `build/layout-previews/` using synthetic test wallet data.
The macOS sandbox permits outbound RPC connections and read-only access to files
explicitly selected by the user.

macOS standalone builds use the local login Keychain through
`MacOsOptions(usesDataProtectionKeychain: false)`. This supports local ad-hoc
signing without a developer provisioning profile; it does not enable iCloud
Keychain sync or cross-app Keychain Sharing. iOS uses the plugin's default
Keychain configuration. Changing to the Data Protection Keychain for a future
provisioned release requires an explicit data migration.

To verify the actual native secure-storage path with temporary synthetic data:

```bash
flutter test integration_test/secure_storage_test.dart -d macos
```

The test only reads, writes and deletes its own uniquely named test key. Rebuild
and relaunch with `flutter run -d macos` after changing native dependencies or
signing configuration; hot reload does not rebuild the native application.

## Next production milestone

1. Move key derivation/signing into an audited native/Rust core with zeroization and hardware-backed key wrapping.
2. Add chain allowlists, nonce/fee simulation, transaction history indexing, and phishing/contract-risk checks.
3. Add token support, WalletConnect v2, multi-chain adapters, hardware wallets, recovery verification, and independent security audits before enabling mainnet.
