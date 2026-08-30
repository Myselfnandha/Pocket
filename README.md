# 💳 Pocket — Next-Gen Personal Finance & Wealth Matrix

<div align="center">

```
  ██████╗  ██████╗  ██████╗██╗  ██╗███████╗████████╗
  ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝╚══██╔══╝
  ██████╔╝██║   ██║██║     █████╔╝ █████╗     ██║   
  ██╔═══╝ ██║   ██║██║     ██╔═██╗ ██╔══╝     ██║   
  ██║     ╚██████╔╝╚██████╗██║  ██╗███████╗   ██║   
  ╚═╝      ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝   ╚═╝   
```

**An intelligent, offline-first personal financial management suite engineered with Flutter, Material 3, Hardware-Backed AES-256 Encryption, On-Device AI Intelligence, and AMOLED Pure Black aesthetics.**

---

[![CI/CD Release](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Myselfnandha/Pocket/actions)
[![Latest Release](https://img.shields.io/github/v/release/Myselfnandha/Pocket?color=00E676&label=Version)](https://github.com/Myselfnandha/Pocket/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.6%20Domain--Split-blueviolet)](https://riverpod.dev)
[![Database](https://img.shields.io/badge/Database-AES--256%20Local%20%2B%20Zero--Knowledge%20Supabase-3ECF8E?logo=supabase)](https://supabase.com)
[![Tests](https://img.shields.io/badge/Tests-32%2F32%20Passing%20(100%25)-brightgreen)](https://github.com/Myselfnandha/Pocket)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Theme](https://img.shields.io/badge/Theme-Material%203%20%2B%20AMOLED%20Pure%20Black-000000)](https://material.io)

</div>

---

## ⚡ Comprehensive Feature Suite

### 1. 🤖 On-Device AI & Predictive Intelligence (100% Offline & Private)
- **🔮 Spend Forecasting & Confidence Bands (`ai_forecasting_service.dart`)**:
  - Predicts month-end expenses and liquid balance based on current daily burn rate + scheduled recurring bills.
  - Generates statistical 90% confidence bands ($\pm 1.645\sigma$) with interactive shaded trajectory charts.
- **⚠️ Statistical Anomaly Detection (`anomaly_detection_service.dart`)**:
  - Analyzes category historical distributions (mean & standard deviation) to flag unusually large transactions ($\ge 3.5\times$ or $z \ge 3.0$) with smart, non-blocking warning banners.
- **✨ Natural-Language Transaction Entry (`nlp_parser_service.dart`)**:
  - Type or speak freeform text like `"1200 for dinner with friends yesterday"` or `"paid 4500 wifi bill via bank"`.
  - Automatically parses amount, relative dates, category heuristics, transaction direction, and wallet destination into interactive preview chips with 1-tap save.
- **🧠 Adaptive Merchant Category Auto-Suggest (`learning_suggest_service.dart`)**:
  - Self-learning algorithm remembers past user categorizations by merchant token and auto-fills categories on future entries.

---

### 2. 🌊 Cyberpunk Visual Topology & Retention Analytics
- **🌊 Animated Sankey Money Flow (`sankey_flow_diagram.dart`)**:
  - Dynamic canvas with glowing ribbons visualizing the direct flow from **Total Monthly Inflows (Left)** $\to$ **Category Drains (Middle)** $\to$ **Net Savings & Goal Reserves (Right)**.
  - Interactive node tapping shows percentage distributions and volume breakdown.
- **🏆 0–1000 Financial Health Score Dashboard (`financial_health_service.dart`)**:
  - Single trending composite credit-score-style gauge with letter grades (`A+`, `A`, `B`, `C`, `D`) evaluated across 4 pillars:
    - **Savings Rate** (0–300 pts)
    - **Budget Discipline** (0–250 pts)
    - **Debt Leverage** (0–250 pts)
    - **Emergency Cushion** (0–200 pts)
  - Delivers tailored, actionable financial recommendations.
- **⏳ Inflation Purchasing Power Time-Machine (`inflation_service.dart`)**:
  - Compares past historical money value to today's real purchasing power adjusted for compound CPI inflation with interactive year selectors and rate sliders.
- **📈 Month-over-Month Category Spending Comparison**:
  - Real-time comparison card in Analytics highlighting spend deltas and percentage changes versus the previous month.
- **💎 Net Worth Matrix (`netWorthSummaryProvider`)**:
  - Aggregates liquid wallet assets + savings goal reserves + lent receivables $-$ borrowed debt liabilities.

---

### 3. 🎯 Savings Goals, Budget Rollover & Automations
- **🎯 Dedicated Savings Goals (`goal_model.dart`, `goals_provider.dart`)**:
  - Set target amounts, deadlines, and emoji icons; deposit/withdraw directly from linked wallets with progress rings and day counters.
- **🔄 Budget Rollover Carry-Forward (`CategoryBudgetModel.calculateEffectiveLimit`)**:
  - Optional toggle carrying over unspent monthly category budget balances into the next billing cycle.
- **🔄 Recurring Rules Engine with Pause & Skip (`recurring_rules_provider.dart`)**:
  - Autonomous startup execution of due bills; supports 1-tap **Skip This Cycle** and non-destructive **Pause / Resume**.
- **📅 Bill Due-Date Monthly Calendar View**:
  - Interactive monthly calendar marking scheduled bill due dates and viewing obligations by day.
- **🔔 Proactive Debt & Due Reminders (`notification_service.dart`)**:
  - Scheduled alarms 1 day prior at 9:00 AM and on due-date mornings for lent/borrowed debts and bills.

---

### 4. 🔒 Enterprise Security, Privacy & Scalability
- **🔒 Hardware-Backed AES-256 Local Encrypted Storage (`storage_service.dart`)**:
  - Master encryption key generated and stored inside Android Keystore / iOS Keychain via `flutter_secure_storage`.
  - All local JSON blobs in `SharedPreferences` are encrypted at rest (`enc:v1:...`).
  - Automatic zero-downtime migration from legacy unencrypted blobs.
- **☁️ Supabase Zero-Knowledge Backup Encryption (`supabase_sync_service.dart`)**:
  - Encrypts entire database backup payloads client-side with AES-256 CBC before uploading to PostgreSQL cloud storage.
- **🛡️ Server-Enforced Row-Level Security (RLS)**:
  - Strict PostgreSQL RLS policies (`20260830134500_create_pocket_backups.sql`) ensuring all operations are bound strictly to `auth.uid()`.
- **⚡ In-Memory Fast Cache Layer**:
  - O(1) indexed lookups with zero lag across thousands of transactions.
- **↩️ Lossless Undo for Destructive Actions**:
  - 4-second floating SnackBar Undo restoring full models across lists and detail screens.

---

### 5. 🎨 Design Aesthetics & Platform Integrations
- **🎨 AMOLED Pure Black & Theme Studio**:
  - 5 luxury presets (**Emerald Neon**, **Cyberpunk Purple**, **Midnight Sapphire**, **Sunset Gold**, **Rose Quartz**) + custom hex color wheel.
  - True `#000000` AMOLED pixels and time-adaptive auto switching.
- **📱 Android Home-Screen App Widget with Live Forecast Sparkline**:
  - Configurable metric display (Balance + Today's Spend, Net Worth, Monthly Savings, Category Budgets, or Live Forecast Trajectory).
- **🔍 Multi-Dimensional Transaction Search & Filter**:
  - Instant search across title, notes, tags, sender, receiver, and reference numbers with category/wallet filters and custom date range pickers.
- **🏷️ Multi-Tagging & Multi-File Attachments**:
  - Support for orthogonal tags and multi-file attachments (receipts, invoices, warranty docs) with pinch-to-zoom viewers.
- **📸 Smart UPI Screenshot OCR Parser**:
  - Share payment screenshots directly to Pocket to automatically extract amount, sender, receiver, and bank UTR numbers.

---

## 🛠️ System Architecture

```
                       ┌─────────────────────────────────────────┐
                       │            Flutter UI Layer             │
                       │   (Material 3 + AMOLED Pure Black HUD)  │
                       └────────────────────┬────────────────────┘
                                            │
                       ┌────────────────────▼────────────────────┐
                       │    Riverpod 2.6 Domain-Split State      │
                       │ (Settings, Wallets, Txs, Debts, Goals)  │
                       └────────────────────┬────────────────────┘
                                            │
         ┌──────────────────┬──────────────┼──────────────┬──────────────────┐
         │                  │              │              │                  │
┌────────▼────────┐┌────────▼────────┐┌────▼─────┐┌───────▼────────┐┌────────▼────────┐
│ AI Forecasting  ││ Financial Health││  Sankey  ││  NLP Parser &  ││  Zero-Knowledge │
│ & Anomaly Engine││    Dashboard    ││ Topology ││ Merchant Learn ││  Supabase Sync  │
└────────┬────────┘└────────┬────────┘└────┬─────┘└───────┬────────┘└────────┬────────┘
         │                  │              │              │                  │
         └──────────────────┴──────────────┼──────────────┴──────────────────┘
                                           │
                       ┌───────────────────▼─────────────────────┐
                       │   StorageService In-Memory Cache Layer  │
                       │ (Hardware Keystore AES-256 Persistence) │
                       └─────────────────────────────────────────┘
```

---

## 📁 Clean Domain-Split Directory Structure

```
Pocket/
├── android/                   # Native Android wrapper, Manifest, Widgets & QuickAddActivity
├── supabase/migrations/       # PostgreSQL RLS migrations (user_id bound security)
├── lib/
│   ├── models/                # Immutable models (Transaction, Wallet, Goal, Debt, Budget, Settings)
│   ├── navigation/            # GoRouter configuration & AppScaffold bottom navigation bar
│   ├── providers/             # Domain-Split Riverpod Providers:
│   │   ├── app_providers.dart          # Barrel export maintaining 100% backward compatibility
│   │   ├── settings_provider.dart      # User settings & Theme preferences
│   │   ├── wallets_provider.dart       # Multi-account balances & transfers
│   │   ├── transactions_provider.dart  # Transaction ledger & filtering
│   │   ├── goals_provider.dart         # Savings goals & deposits/withdrawals
│   │   ├── debts_provider.dart         # Lend & Borrow debt ledger
│   │   ├── budgets_provider.dart       # Category budgets & rollover limits
│   │   ├── recurring_rules_provider.dart # Subscriptions & pause/skip cycles
│   │   ├── notifications_provider.dart # Alarms & in-app notifications
│   │   └── derived_providers.dart      # AI forecast, health score, net worth, MoM spend
│   ├── screens/
│   │   ├── analytics/         # AI Forecast, Sankey Flow, Health Gauge, Inflation, PDF/CSV
│   │   ├── debts/             # Lend & Borrow debt ledger
│   │   ├── home/              # Hero balance card, accounts carousel, NLP quick entry
│   │   ├── onboarding/        # Comprehensive 7-step onboarding personalization wizard
│   │   ├── recurring/         # Recurring rules, pause/skip engine & bill calendar
│   │   ├── settings/          # Theme Studio, Data Management, Widget Picker, Supabase Sync
│   │   ├── splash/            # Theme-adaptive glowing splash screen
│   │   ├── transactions/      # Transactions list, search, detail viewer, and QuickAdd
│   │   └── wallets/           # Wallet manager, transfers, and Savings Goals carousel
│   ├── services/
│   │   ├── ai_forecasting_service.dart      # Statistical burn rate & confidence bands
│   │   ├── anomaly_detection_service.dart   # Category spending anomaly detector
│   │   ├── nlp_parser_service.dart          # Natural language transaction parser
│   │   ├── learning_suggest_service.dart    # Adaptive merchant category learning
│   │   ├── financial_health_service.dart    # 0–1000 composite financial health index
│   │   ├── inflation_service.dart           # Historical purchasing power time machine
│   │   ├── storage_service.dart             # In-memory cache + AES-256 local encrypted storage
│   │   ├── supabase_sync_service.dart       # Client-side zero-knowledge encrypted cloud sync
│   │   ├── system_widget_service.dart       # Android home widget updater with sparklines
│   │   ├── notification_service.dart        # Local notification & alarm scheduler
│   │   └── receipt_service.dart             # Sandboxed private receipt storage (.nomedia)
│   ├── theme/                 # AppTheme, luxury palettes, and Material 3 color schemes
│   └── widgets/               # Reusable SankeyFlowDiagram, SpendForecastCard, FinancialHealthGauge, NlpQuickAddModal
├── test/
│   ├── ai_intelligence_test.dart        # AI, Forecasting, Anomaly, NLP, Health & Inflation tests
│   ├── app_test.dart                    # Data models, persistence, rollover, and encryption tests
│   ├── upi_screenshot_parser_test.dart  # OCR heuristics and intent parser tests
│   └── widget_test.dart                 # UI and widget integration tests
└── pubspec.yaml               # Flutter package configuration & dependencies
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- Android Studio / VS Code with Flutter & Dart extensions
- Android Device or Emulator (API 26+ recommended)

### Installation & Execution

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Myselfnandha/Pocket.git
   cd Pocket
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run automated test suite (32 tests):**
   ```bash
   flutter test
   ```

4. **Verify static analysis:**
   ```bash
   flutter analyze --no-fatal-infos
   ```

5. **Launch development app:**
   ```bash
   flutter run
   ```

6. **Build release APK:**
   ```bash
   flutter build apk --release
   ```

---

## 🔒 Privacy & Security Guarantees

- **100% User Ownership**: All financial records, receipts, and personal debts remain strictly on your device with hardware-backed AES-256 encryption.
- **Zero Third-Party Telemetry**: Zero trackers, zero advertisements, and zero background analytics.
- **Zero-Knowledge Cloud Sync**: Optional cloud backup encrypts all data client-side before transmission; your private master key never leaves your device.

---

## 📄 License

Pocket is open-source software licensed under the [MIT License](LICENSE).
