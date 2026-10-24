# Architectural Decisions - Pocket Mobile

## D-001: Live Wallet Balances Provider (`walletsWithBalancesProvider`)
- **Context:** `walletsProvider` exposes static Hive model entries which only hold `initialBalance`. Components that need to display real-time balances after income, expense, debt settlement, or transfer events must watch `walletsWithBalancesProvider`.
- **Decision:** All consumer screens (`sankey_flow_diagram.dart`, `add_transaction_screen.dart`, `quick_add_transaction_dialog.dart`, `wallets_screen.dart`) must explicitly watch `walletsWithBalancesProvider` rather than raw `walletsProvider`.
- **Date:** 2026-10-24

## D-002: Three-Stage Sankey Node Weight by Actual Flow Volume
- **Context:** The Sankey Flow Diagram accounts hub (Stage 2) previously mapped each account's static initial balance, displaying incorrect or stagnant nodes (e.g. ₹1.00).
- **Decision:** Compute Stage 2 accounts hub weight by actual chronological monthly flow volume through that account (`monthFlow = inflow + outflow`), falling back to `currentBalance.abs()` only when flow is zero.
- **Date:** 2026-10-24

## D-003: Attached TextEditingController for Search Fields
- **Context:** `TextField` without an explicit `controller` fails to clear on `suffixIcon` tap even when state variable is reset, leaving stale text in the native input widget.
- **Decision:** Always pair search `TextField`s with a `late final TextEditingController`, disposing it cleanly in `dispose()`.
- **Date:** 2026-10-24
