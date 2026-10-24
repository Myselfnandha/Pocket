# Architecture Decisions & Invariants

This document records durable architectural decisions, system invariants, and interface contracts for this project.

---

## Active Invariants

### 1. Dual-Layer Codebase Analysis Engine
- **Decision**: Codebase freshness is checked via `analyze.py --check --auto-heal --inject-ki` at the start of every session.
- **Rationale**: Prevents stale context without blocking user conversations, storing SQLite cache in `.agents/cache/codebase.db`.

### 2. Multi-Tier Security & Verification Gates
- **Decision**: All modified files and business logic must pass AAA unit test standards and Skylos SAST / AI hallucination verification.
- **Rationale**: Eliminates phantom imports, hallucinated package versions, and insecure sinks before commit.

### 3. Native MCP Server Protocol
- **Decision**: External tool integrations use the official Model Context Protocol (MCP) in `.agents/mcp_config.json`.

### 4. Startup Permission Self-Healing & Contextual Banners
- **Decision**: Missing critical Android runtime permissions (SMS and Notification) are actively checked on startup in `HomeScreen` and upon onboarding completion, with a non-blocking fallback banner that links to app settings if permanently denied.
- **Rationale**: Financial auto-logging requires SMS permissions; prompting on startup ensures zero-configuration onboarding and immediate transaction detection.

### 5. Inter-Wallet Transfer (`cat_transfer`) Accounting Isolation
- **Decision**: Transactions tagged with `categoryId == 'cat_transfer'` are strictly isolated from monthly income, monthly expense, budget category calculations, spending comparisons, and anomaly detection.
- **Rationale**: Inter-wallet transfers reallocate assets between internal accounts and do not constitute net economic gain or loss.

### 6. Enum Deserialization Crash Immunization
- **Decision**: All model `.fromJson` factories must use `Enum.values.asNameMap()[json[key]] ?? fallback` instead of `Enum.values.byName()`.
- **Rationale**: Unhandled `ArgumentError` from unknown, malformed, or version-skewed enum strings crashes startup and prevents backup restoration.

### 7. Full Backup Parity Across All Domain Entities
- **Decision**: `BackupService` JSON export and restore must encompass all nine domain entities: `transactions`, `categories`, `wallets`, `settings`, `recurringRules`, `notifications`, `debts`, `categoryBudgets`, and `goals`.
- **Rationale**: Prevents data loss for savings goals during device migration or backup/restore operations.

### 8. Strict Financial Precision & Negative Zero Elimination
- **Decision**: All transaction amounts and running balance accumulations must round via `(value * 100).round() / 100.0` with `.abs() < 0.0001 ? 0.0 : rounded` guards.
- **Rationale**: Eliminates IEEE 754 floating-point drift and `-₹0.00` display artifacts.

### 9. Explicit Account Matching Guard for Zero-Confirmation Auto-Save
- **Decision**: SMS permissions grant automatically enables zero-confirmation direct auto-saving only when an incoming transaction matches an explicit account (by last 4 digits or recognized bank keyword). Unmatched transactions are retained in the Pending Transactions review queue.
- **Rationale**: Prevents phantom transactions from being attributed to incorrect accounts while providing a frictionless experience for verified banking alerts.

### 10. Home Screen Widget Privacy Peek & Live Customization Suite
- **Decision**: Home screen widgets support tap-to-peek privacy reveals with haptic feedback, an auto-masking timer (`widgetPeekDurationSeconds`), customizable visual themes (`glassFrost`, `oledBlack`, `midnightNavy`), and configurable action buttons.
- **Rationale**: Balances glanceable desktop convenience with public privacy protection without requiring the app to be opened.

### 11. Widget Isolated Tap Space & Global Customization Master Toggle
- **Decision**: Android home screen widgets isolate the balance peek trigger to a dedicated pill button container (`btn_toggle_balance` / `txt_toggle_icon`) to prevent accidental mistouches from launching `MainActivity`. A global `isWidgetCustomizationEnabled` master toggle allows users to switch between customized widget parameters and default automatic sync across all accounts.
- **Rationale**: Android widget root click listeners intercept taps that fall outside tight text bounds; a dedicated pill container prevents unwanted app launches. The master switch allows users to revert easily to zero-configuration global balance tracking.

### 12. Explicit Wallet Selection & Overpayment Bounds in Debt Settlements
- **Decision**: All partial and full debt settlements (`_showPartialPaymentDialog`, `_showSettleUpDialog`) must provide an explicit account/wallet dropdown selector and validate that the repayment amount never exceeds `debt.remainingAmount`.
- **Rationale**: Blindly deducting from `wallets.first` corrupts multi-account ledger accuracy when repayments occur through alternate bank accounts or cash. Overpayments break ledger parity.

### 13. Indian Financial Multipliers in Natural Language Processing
- **Decision**: In addition to `k` (thousands), the NLP parser explicitly supports Indian financial denomination suffixes: Lakh (`L`, `lac`, `lakh`, `lakhs` $\times 100,000$) and Crore (`cr`, `crore`, `crores` $\times 10,000,000$).
- **Rationale**: Eliminates false parser drops and manual decimal typing when users input large asset purchases, business loans, or investments in native shorthand.

### 14. Dynamic Macro Inflation Horizon & Baseline Neutrality
- **Decision**: Macro purchasing power depreciation calculates time horizons dynamically relative to `DateTime.now().year`, with `_pastYear == currentYear` returning a 0.0% loss with a dedicated emerald `"🌱 100% Real Value • Present Baseline"` badge.
- **Rationale**: Prevents hardcoded static years from going stale in future years and prevents same-year anchor calculations from displaying false purchasing power depreciation.

### 15. Transfer Liquidity Exclusion in Sankey Flow Visualizations
- **Decision**: The Sankey 3-stage cashflow diagram strictly filters out `cat_transfer` transactions from the monthly calculation set.
- **Rationale**: Transfers between internal wallets do not represent net exogenous inflow or outflow; including them creates artificial cashflow inflation.

