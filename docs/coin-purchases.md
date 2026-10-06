# Coin purchases — local implementation, not a live deployment

Updated 2026-10-06. Version remains 1.0.0+1 in source; use the next unused build number for TestFlight uploads.

The native store integration is implemented with `in_app_purchase`, platform secure storage and a separate purchase-verification backend at `C:\CODE\Arrow backend`. It replaces the normal-player disabled coin buttons **when explicitly configured**, while preserving clearly marked admin simulations.

Read the backend's `SETUP.md` for the complete Apple, Google, hosting and Codemagic checklist. Real checkout defaults OFF via `ARROW_PURCHASES_ENABLED=false`; no backend URL or store secrets are embedded. AdMob test mode remains unchanged.

Products: `coins_1500` (1,500 coins; intended India price ₹49), `coins_4000` (4,000 coins; intended India price ₹99). Actual prices are fetched from the store. The backend independently verifies the purchase and credits a transaction once before the app finishes/consumes it.

Purchased balances are server-backed; offline earned/ad coins remain local. Spending uses earned coins first, then debits the missing purchased coins with an idempotency key. Paid permanent entitlements are recoverable using a private wallet recovery key. Level progress, offline rewards and already-delivered consumable hints/revives are not cloud-synchronized. The shop states this limitation. Android auto-backup is disabled to avoid restoring unusable encrypted wallet credentials; users must keep their recovery key.

Changed code: `lib/coin_purchases.dart`, `lib/wallet_api.dart`, `lib/paid_wallet.dart`, wallet hooks in `GameController`, shop/gate/revive actions and app startup. An iOS keychain entitlement has been added without changing the existing iOS bundle identifier. StoreKit 2 purchases require iOS 15+; older devices retain gameplay but no coin checkout. Android package/signing still needs your production configuration.

New tests exercise pending/cancelled/error states, duplicate delivery, verification/finish failures, interrupted spending/restart, mixed earned/paid balances, storage errors, simultaneous taps, stale revive protection, recovery and localized price/missing-product UI. The backend also tests receipt validation rules, account isolation, idempotent credit/debit, encryption, environment separation and refunds.

The backend has no simulated-credit production endpoint. Its default local startup exposes health/config with checkout closed. No paid account, cloud host, store products or credentials have been created, and no real payment has been tested. Do not call this launch-ready until the device and deployment checklist passes.
