# Stone Wallet

Stone Wallet is a Flutter cross-platform self-custodial Web3 wallet foundation covering iOS, Android, macOS, and Windows project targets.

## Current milestone

This milestone contains the first real wallet vertical slice:

- BIP39 recovery phrase creation and import
- BIP32 Ethereum derivation at `m/44'/60'/0'/0/0`
- Platform-backed secure storage through Keychain, Keystore, macOS Keychain, and Windows Credential Manager
- User-selected EVM network profiles with no RPC connection until selection
- Multi-network native balance reads through JSON-RPC after the user enables one or more networks
- A current-operation network for signing, with every enabled network’s RPC URL visible in Settings
- Per-network editable RPC endpoints, custom EVM network profiles, and a Chain ID connection check
- Clickable native-asset rows, searchable full asset list, and asset details with refresh/send/receive actions
- Local EVM transaction signing and native-asset broadcast on the selected network
- Recovery phrase display followed by word-position verification before a newly created wallet is saved
- Chinese Home/Settings flows with inactive navigation areas removed
- Cloud backup is deliberately shown as disabled until iCloud/Google Drive integration has a secure design
- Responsive blue-accented light and dark themes with distinct desktop and phone layouts
- Receive address copy and an explicit send review form
- CSV/TSV batch import for chain + private-key rows, with validation, duplicate skipping, and secure local storage

This is not a mainnet-ready release. Token balances, swaps, WalletConnect, dApp discovery, full multi-chain adapters, fee simulation, hardware wallets, backup export, RPC failover, and security audit gates are not complete. Ethereum Mainnet, Ethereum Sepolia, Polygon Mainnet, and Polygon Amoy are selectable profiles; the user chooses which networks to view and when to connect.

## Run locally

```bash
flutter pub get
flutter run -d macos
flutter run -d ios
flutter run -d android
flutter run -d windows
```

For a quick local check:

```bash
flutter analyze
flutter test
```

## Networks and assets

Choose a network name in **Manage Networks** to set the operation chain; checkboxes
enable additional chains for balance viewing. Click **Save** to connect. Syncing,
success and failure are tracked independently per chain; unavailable balances show
`—`, not zero.

Use **Edit RPC** for any enabled network or **Add Custom Chain** in Settings (also
available in Manage Networks). Configure the name, Chain ID, native symbol, RPC URL,
optional explorer URL and testnet flag. Saved profiles and RPC overrides survive
restarts and work with batch private-key imports by network name or Chain ID.
These profiles use the existing EVM signer and 18-decimal native-asset model;
Bitcoin, Solana and other non-EVM protocols need separate adapters. The RPC check
verifies `eth_chainId`, which is also checked before balance reads and signing.

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

## Next production milestone

1. Move key derivation/signing into an audited native/Rust core with zeroization and hardware-backed key wrapping.
2. Add RPC failover, chain allowlists, nonce/fee simulation, transaction history indexing, and phishing/contract-risk checks.
3. Add token support, WalletConnect v2, multi-chain adapters, hardware wallets, recovery verification, and independent security audits before enabling mainnet.
