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

**An intelligent, offline-first personal financial management suite engineered with Flutter, Material 3, Supabase Cloud Sync, and AMOLED aesthetics.**

---

[![CI/CD Release](https://github.com/Myselfnandha/Pocket/actions/workflows/build_apk.yml/badge.svg)](https://github.com/Myselfnandha/Pocket/actions)
[![Latest Release](https://img.shields.io/github/v/release/Myselfnandha/Pocket?color=00E676&label=Version)](https://github.com/Myselfnandha/Pocket/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Riverpod](https://img.shields.io/badge/State-Riverpod%202.6-blueviolet)](https://riverpod.dev)
[![Database](https://img.shields.io/badge/Database-Supabase%20Cloud%20%2B%20Local-3ECF8E?logo=supabase)](https://supabase.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Theme](https://img.shields.io/badge/Theme-Material%203%20%2B%20AMOLED-000000)](https://material.io)

</div>

---

## ⚡ Feature Matrix & Key Modules

### 1. 🎨 Theme & Accent Studio (5 Luxury Presets + Custom Color Wheel)
- **5 Curated Luxury Palettes**:
  - 🟢 **Emerald Neon**: Futuristic cyber green (`#4CAF50` / `#2E7D32`)
  - 🟣 **Cyberpunk Purple**: Radiant ultraviolet & neon cyan (`#B388FF` / `#7C4DFF`)
  - 🔵 **Midnight Sapphire**: Deep oceanic electric blue (`#29B6F6` / `#0288D1`)
  - 🟡 **Sunset Gold**: Warm amber & liquid gold (`#FFB300` / `#FF8F00`)
  - 🔴 **Rose Quartz**: Vibrant cyberpunk magenta (`#FF4081` / `#C2185B`)
- **Custom Hex & Color Swatch Picker**: Pick any custom hex color with live, instant app-wide preview.
- **Display Modes**: Choose between **Pure Black AMOLED (`#000000`)**, **Dark Charcoal (`#131313`)**, **Light Paper**, or **Auto Time-Based** (Day/Night cycle).

### 2. ⚡ Transparent Floating QuickAdd HUD
- **Zero-Latency Popup**: Launches `QuickAddActivity` as a transparent floating HUD directly over the Android home screen wallpaper or app drawer.
- **Hardware-Accelerated Calculator Numpad**: Perform real-time math operations (`+`, `-`, `.`) directly inside the amount input.
- **Multi-Activity Live Sync**: Transactions logged from widgets or notifications automatically reflect on the Home screen in real-time.

### 3. 📸 Smart Screenshot OCR & Banking Intent Parser
- **Auto-Extract Metadata**:
  - 💵 **Amount & Currency** (handles all Indian comma notations, e.g. `₹1,450.00`)
  - 👤 **Sender (From)** & 👥 **Receiver (To)**
  - 📱 **Mobile / Account Last 4 Digits** (`•••• 1234`)
  - 🔢 **Bank UTR / Transaction Reference ID**
  - ⚡ **Auto Direction**: Automatically identifies Income ("Received from") vs Expense ("Paid to").
- **Clean Note Preservation**: Keeps payment reference numbers in dedicated metadata fields, ensuring the Note field remains 100% clean for personal user notes.
- **Dedicated Transfer Details Card**: Displays sender, receiver, account, and reference details inside `TransactionDetailScreen`.

### 4. ☁️ Supabase Free Cloud Database Sync
- **Free PostgreSQL Cloud Backend**: Connect your free Supabase project in 1 tap with project URL and public key.
- **1-Tap Cloud Backup & Restore**: Upload and download complete database state (transactions, wallets, categories, debts, budgets) across multiple devices.
- **Zero Lock-In**: Works completely offline-first with local encrypted persistence; cloud sync is entirely optional and free.

### 5. 📊 Next-Gen Analytics & Financial Projections
- **"Daily Avg Spend" Calculator**: Interactive metric calculating daily burning rate (`Total Spend ÷ Days Elapsed`) and projected month-end spend.
- **Top Category Spending Hero**: Visualizes the top category outflow with percentage allocation.
- **Day-of-Week Burning Rate Matrix**: Mon–Sun cash outflow bar chart highlighting peak spending days.
- **Export Reports**: Generate branded PDF financial statements and raw CSV spreadsheets.

### 6. 🎯 Category Budgets & Spending Caps
- **Proactive Threshold Alerts**: Real-time heads-up notifications trigger at **80% (approaching limit)** and **100% (exceeded limit)**.
- **Category Progress Bars**: Visual health indicators for each expense category.

### 7. 🤝 Lend & Borrow / Debt Ledger
- **Visual Ledger**: Clear separation between **"You are owed" (Lent - Green)** and **"You owe" (Borrowed - Red)**.
- **Partial Repayments & Full Settlement**: Record repayments with progress tracking and optional automatic wallet balance adjustment.

### 8. 🔄 Autonomous Recurring Expenses Engine
- **Automated Startup Evaluation**: Automatically processes due bills, rent, EMIs, and subscriptions when the app opens.
- **Preset Templates**: Rent (`🏠`), Loan EMI (`💳`), OTT Subscriptions (`🎬`), Electricity (`⚡`), Phone Bill (`📱`), Insurance (`🛡️`), and Subscriptions (`📦`).

### 9. 📱 Android Home Screen App Widget
- **Live Glances**: Glanceable real-time balance, today's total spending, and quick transaction buttons directly on the phone home screen.

### 10. 🔒 Sandboxed Private Receipt Storage
- **Gallery-Isolated (`.nomedia`)**: All camera snaps and receipt attachments are securely sandboxed inside the app's internal storage without polluting the system gallery.
- **Pinch-to-Zoom Viewer**: Inspect receipts with multi-touch `InteractiveViewer`.

---

## 🛠️ Architecture & System Design

```
                       ┌─────────────────────────────────────────┐
                       │            Flutter UI Layer             │
                       │   (Material 3 + Theme & Accent Studio)  │
                       └────────────────────┬────────────────────┘
                                            │
                       ┌────────────────────▼────────────────────┐
                       │         Riverpod 2.6 State Engine       │
                       │ (Reactive Notifiers & Derived Selectors)│
                       └────────────────────┬────────────────────┘
                                            │
         ┌──────────────────┬──────────────┼──────────────┬──────────────────┐
         │                  │              │              │                  │
┌────────▼────────┐┌────────▼────────┐┌────▼─────┐┌───────▼────────┐┌────────▼────────┐
│ Recurring Engine││ Notification Hub││  OCR &   ││   Debt Ledger  ││  Supabase Sync  │
│ (Auto Executor) ││(System & In-App)││ Intent   ││ (Lend & Borrow)││  (Cloud DB)     │
└────────┬────────┘└────────┬────────┘└────┬─────┘└───────┬────────┘└────────┬────────┘
         │                  │              │              │                  │
         └──────────────────┴──────────────┼──────────────┴──────────────────┘
                                           │
                      ┌────────────────────▼────────────────────┐
                      │    Local Encrypted Storage (SharedPreferences) │
                      └─────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
Pocket/
├── android/                   # Native Android wrapper, Manifest, Widgets & QuickAddActivity
│   ├── app/src/main/kotlin/   # Kotlin OCR parser, QuickAddActivity, ShareReceiverActivity
│   └── app/src/main/res/      # Material 3 launcher icons, styles, and widget layouts
├── lib/
│   ├── models/                # Immutable data models (Transaction, Wallet, Category, Settings, etc.)
│   ├── navigation/            # GoRouter configuration & AppScaffold navigation bar
│   ├── providers/             # Riverpod StateNotifiers, Derived Selectors & Palette providers
│   ├── screens/
│   │   ├── analytics/         # Analytics, Daily Avg Spend dialog, and PDF/CSV export
│   │   ├── debts/             # Lend & Borrow debt ledger
│   │   ├── home/              # Hero balance card, waving greeting, and recent activity
│   │   ├── settings/          # Theme Studio, Data Management & Supabase Sync
│   │   ├── splash/            # 800ms fast glowing splash screen
│   │   ├── transactions/      # Transaction list, details, and QuickAdd dialog
│   │   └── wallets/           # Multi-wallet manager and transfers
│   ├── services/              # StorageService, SupabaseSyncService, NotificationService, OCR parser
│   ├── theme/                 # AppTheme, AppThemePalette, and dynamic Material 3 color schemes
│   └── widgets/               # Reusable BalanceCard, TransactionTile, WavingHandEmoji, Numpad
├── test/                      # Unit and widget test suite (21+ automated tests)
└── pubspec.yaml               # Flutter package configuration & dependencies
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- Android Studio / VS Code with Flutter extensions
- Android Device or Emulator (API 26+ recommended)

### Installation & Build

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Myselfnandha/Pocket.git
   cd Pocket
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run unit & widget tests:**
   ```bash
   flutter test
   ```

4. **Launch the development build:**
   ```bash
   flutter run
   ```

5. **Build Release APK:**
   ```bash
   flutter build apk --release
   ```

---

## 🔒 Privacy & Security

- **100% User Ownership**: All financial records, receipts, and personal debts are stored locally on your device by default.
- **Zero Third-Party Telemetry**: No trackers, no advertisements, and no data harvesting.
- **Optional Cloud Sync**: Cloud synchronization is opt-in via your own free Supabase PostgreSQL database.

---

## 📄 License

Pocket is open-source software licensed under the [MIT License](LICENSE).
