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
- Local EVM transaction signing and native-asset broadcast on the selected network
- Recovery phrase display followed by word-position verification before a newly created wallet is saved
- Chinese Home/Settings flows with inactive navigation areas removed
- Cloud backup is deliberately shown as disabled until iCloud/Google Drive integration has a secure design
- Responsive light Portfolio and dark Command Center UI styles
- Receive address copy and an explicit send review form

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

## Next production milestone

1. Move key derivation/signing into an audited native/Rust core with zeroization and hardware-backed key wrapping.
2. Add RPC failover, chain allowlists, nonce/fee simulation, transaction history indexing, and phishing/contract-risk checks.
3. Add token support, WalletConnect v2, multi-chain adapters, hardware wallets, recovery verification, and independent security audits before enabling mainnet.
