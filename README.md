# Stone Wallet

Stone Wallet is a Flutter cross-platform self-custodial Web3 wallet foundation covering iOS, Android, macOS, and Windows project targets.

## Current milestone

This milestone contains the first real wallet vertical slice:

- Multiple BIP39 wallets: create or import more wallets after onboarding without replacing existing ones
- Direct single EVM private-key import from the welcome screen and Settings, with masked input, network selection, validation and duplicate detection
- BIP32 Ethereum accounts at `m/44'/60'/0'/0/i`, with named groups, account derivation, search and persistent active-account selection
- Platform-backed secure storage through Keychain, Keystore, macOS Keychain, and Windows Credential Manager
- User-selected EVM network profiles with no RPC connection until selection
- Multi-network native balance reads through JSON-RPC after the user enables one or more networks
- A current-operation network for signing, with each network's RPC pool and current working endpoint visible in Settings
- Per-network editable ordered RPC pools, built-in free public endpoints, automatic failover, custom EVM network profiles, and Chain ID checks
- Clickable native-asset rows, searchable full asset list, and asset details with refresh/send/receive actions
- Local EVM transaction signing and native-asset broadcast on the selected network
- Recovery phrase display followed by word-position verification before a newly created wallet is saved
- Chinese Home/Settings flows with inactive navigation areas removed
- Cloud backup is deliberately shown as disabled until iCloud/Google Drive integration has a secure design
- Responsive blue-accented light and dark themes with distinct desktop and phone layouts
- Receive address copy and an explicit send review form
- CSV/TSV batch import for chain + private-key rows, with validation, duplicate skipping, and secure local storage

This is not a mainnet-ready release. Token balances, swaps, WalletConnect, dApp discovery, full multi-chain adapters, fee simulation, hardware wallets, backup export, and security audit gates are not complete. Ethereum Mainnet, Ethereum Sepolia, Polygon Mainnet, and Polygon Amoy are selectable profiles; the user chooses which networks to view and when to connect.

## Run locally

```bash
flutter pub get
flutter run -d macos
```

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

## Networks and assets

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
64-character hexadecimal EVM private key (an optional `0x` prefix is accepted).
The key is saved in platform-backed secure storage; successful import activates
the account and connects to the selected network for its balance. Invalid or
duplicate imports stay in the form for correction. Existing mnemonic and imported
accounts remain available in the wallet picker as **主钱包** and **私钥账户**.
Single and batch imports share the same storage, including existing batch data.

Choose a network name in **Manage Networks** to set the operation chain; checkboxes
enable additional chains for balance viewing. Click **Save** to connect. Syncing,
success and failure are tracked independently per chain; unavailable balances show
`—`, not zero.

Use **Edit RPC** for any enabled network or **Add Custom Chain** in Settings (also
available in Manage Networks). Configure the name, Chain ID, native symbol, RPC URLs,
optional explorer URL and testnet flag. Saved profiles and RPC overrides survive
restarts and work with batch private-key imports by network name or Chain ID.
These profiles use the existing EVM signer and 18-decimal native-asset model;
Bitcoin, Solana and other non-EVM protocols need separate adapters. The RPC check
verifies `eth_chainId`, which is also checked before balance reads and signing.

### Automatic RPC failover

The defaults in `lib/wallet_core.dart` include two free, keyless public endpoints
for each built-in network:

| Network | First endpoint | Backup endpoint |
| --- | --- | --- |
| Ethereum | `https://eth.drpc.org` | `https://ethereum-rpc.publicnode.com` |
| Ethereum Sepolia | `https://ethereum-sepolia-rpc.publicnode.com` | `https://rpc.sepolia.ethpandaops.io` |
| Polygon | `https://polygon.drpc.org` | `https://polygon-bor-rpc.publicnode.com` |
| Polygon Amoy | `https://polygon-amoy.drpc.org` | `https://polygon-amoy-bor-rpc.publicnode.com` |

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
responses, JSON-RPC errors or a mismatched Chain ID. Every endpoint is checked
against the network's Chain ID before balance reads, signing preparation and
broadcast. Each chain check and operation has a five-second timeout; one pass
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

Asset rows open details, and **View All** opens a searchable list of enabled chains'
native assets. Details include refresh, receive, send and current-chain actions.
Android release includes Internet permission and allows user-configured HTTP RPCs;
iOS permits these HTTP RPC connections through its transport configuration.

## Responsive layout checks

The welcome screen splits at 1000 logical pixels. The wallet uses bottom navigation
below 760, a compact rail from 760, and a full sidebar with two-column content from
1100. macOS starts at 1200×800 with an 800×600 minimum content size.

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
To render the desktop and phone welcome/home/settings previews using a local CJK font:

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
