# Pocket — Transaction Tracking App

A Flutter mobile app for tracking income and expenses with balance management, analytics, and a premium Material 3 design.

---

## Design Decisions Summary

| Decision | Choice |
|---|---|
| **Platform** | Flutter mobile (iOS & Android) |
| **Transactions** | Income + Expenses with balance tracking |
| **Storage** | Local-first (Isar DB), Firebase sync in phase 2 |
| **Categories** | Predefined + custom + hierarchical + tag-based, auto-suggest from history |
| **Currency** | Single currency, set during onboarding |
| **Wallets** | Multiple (Cash, Bank, UPI, etc.), customizable in settings |
| **State Management** | Riverpod |
| **Database** | Isar |
| **Routing** | go_router |
| **Design** | Material 3 (default), minimal & glassmorphism options in settings |
| **Theme** | Auto dark/light by time of day (default), pure black AMOLED option |
| **Navigation** | Bottom nav bar (5 tabs), no floating button, Material Design |
| **Add Transaction** | Calculator numpad → title/category auto-suggest → auto-save |
| **Search** | Full-text search + filters (date, category, wallet, amount, type) |
| **Security** | Biometric (fingerprint/face) + PIN fallback |
| **Home Screen** | Balance card + today's transactions + daily spend stats |
| **Gestures** | Swipe left=delete, right=edit, tap=view, long-press=menu (customizable) |
| **Onboarding** | Name → Currency → Wallets + feature tour slides |
| **App Name** | Pocket |

---

## Phase 1 vs Phase 2

### Phase 1 (Core MVP)
- Core transaction CRUD (income/expense)
- Calculator-style numpad entry with category auto-suggestion based on previous history & auto-save with 3-second undo snackbar
- Multiple wallets management (Default: Cash & Bank Account, customizable)
- Home dashboard (Balance summary card, today's transactions, daily spending stats)
- Full transaction list with full-text search & multi-filters (date, category, wallet, amount, type)
- Monthly summary & daily/weekly spending trend line charts
- CSV/PDF report export
- Security: App lock with Biometric (fingerprint/face) + 4-digit PIN fallback
- Theming: Material 3 with Green (#2E7D32) primary / Orange (#FF9800) accent, Pure Black AMOLED dark mode & light mode with auto time-of-day switching
- 5-tab clean bottom navigation (Home, Transactions, Analytics, Wallets, Settings)
- Short onboarding flow (Name → Currency ₹ INR → Wallet setup → Quick tour)
- Standard Settings (Categories CRUD, Wallets CRUD, Currency, Theme Mode switch, Security PIN/Biometric toggles, Export data, About)

### Phase 2 (v2)
- Advanced settings customizations:
  - Custom gesture mapping (swipe actions, double tap, long-press actions)
  - Bottom navigation tab reordering & toggleable tabs
  - Multiple visual design style switchers (Glassmorphism, Minimal, etc.)
  - Color palette theme switcher (Teal/Amber, Purple/Pink, Blue/Green)
- Firebase cloud backup & sync
- Recurring/repeating transactions with reminder notifications
- Smart notifications (Daily logging reminder, weekly summaries, category budget alerts)
- Receipt/bill photo attachment with quick camera capture (Claude mobile style)
- Hierarchical sub-categories & tag-based transaction tracking
- Category budget limits & budget vs actual comparisons

---

## Proposed Changes

### Project Setup

#### [NEW] Flutter project initialization
- Create Flutter project named `pocket` in `/home/nandha/Desktop/Pocket`
- Min SDK: Flutter 3.24+, Dart 3.5+
- Package name: `com.pocket.app`

#### [NEW] `pubspec.yaml` — Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  # State Management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  # Database
  isar: ^3.1.0+1
  isar_flutter_libs: ^3.1.0+1
  # Routing
  go_router: ^14.8.1
  # UI & Design
  google_fonts: ^6.2.1
  flutter_animate: ^4.5.2
  fl_chart: ^0.70.2
  # Security
  local_auth: ^2.3.0
  # Utils
  intl: ^0.19.0
  uuid: ^4.5.1
  path_provider: ^2.1.5
  share_plus: ^10.1.4
  csv: ^6.0.0
  pdf: ^3.11.2
  printing: ^5.14.2
  shared_preferences: ^2.3.5

dev_dependencies:
  flutter_test:
    sdk: flutter
  isar_generator: ^3.1.0+1
  build_runner: ^2.4.14
  riverpod_generator: ^2.6.3
  flutter_lints: ^5.0.0
```

---

### Core Architecture (`lib/`)

#### [NEW] `lib/main.dart`
- App entry point
- Initialize Isar database
- Wrap with `ProviderScope` (Riverpod)
- Configure `MaterialApp.router` with go_router
- Apply Material 3 theme with dynamic dark/light switching

#### [NEW] `lib/app.dart`
- Root app widget with theme configuration
- Time-based theme switching logic
- Material 3 theme data (light, dark, pure black AMOLED)

---

### Data Layer (`lib/data/`)

#### [NEW] `lib/data/models/transaction.dart`
- Isar collection for transactions
- Fields: `id`, `amount`, `type` (income/expense), `categoryId`, `walletId`, `title`, `note`, `date`, `tags`, `createdAt`, `updatedAt`

#### [NEW] `lib/data/models/category.dart`
- Isar collection for categories
- Fields: `id`, `name`, `icon`, `color`, `parentId` (for hierarchy), `isDefault`, `type` (income/expense/both), `sortOrder`

#### [NEW] `lib/data/models/wallet.dart`
- Isar collection for wallets
- Fields: `id`, `name`, `icon`, `color`, `balance`, `isDefault`, `sortOrder`

#### [NEW] `lib/data/models/user_settings.dart`
- Isar collection for user preferences
- Fields: `currency`, `currencySymbol`, `userName`, `themeMode`, `designStyle`, `navTabs`, `gestureConfig`, `isOnboarded`, `pinHash`, `useBiometric`, `autoSwitchThemeByTime`

#### [NEW] `lib/data/repositories/transaction_repository.dart`
- CRUD operations for transactions
- Query methods: by date range, category, wallet, amount range, type
- Full-text search on title/note
- Auto-suggest category based on title similarity

#### [NEW] `lib/data/repositories/category_repository.dart`
- CRUD for categories with hierarchy support
- Seed default categories on first launch

#### [NEW] `lib/data/repositories/wallet_repository.dart`
- CRUD for wallets
- Balance recalculation on transaction changes

#### [NEW] `lib/data/repositories/settings_repository.dart`
- Read/write user settings
- Theme and preference management

---

### State Management (`lib/providers/`)

#### [NEW] `lib/providers/transaction_providers.dart`
- `transactionsProvider` — filtered/sorted transaction list
- `todayTransactionsProvider` — today's transactions for home
- `transactionStatsProvider` — daily/monthly spending stats
- `categorySuggestionProvider` — auto-suggest based on history

#### [NEW] `lib/providers/wallet_providers.dart`
- `walletsProvider` — all wallets
- `totalBalanceProvider` — combined balance across wallets
- `walletBalanceProvider` — per-wallet balance

#### [NEW] `lib/providers/category_providers.dart`
- `categoriesProvider` — all categories (flat + hierarchical)
- `categoryTreeProvider` — hierarchical category tree

#### [NEW] `lib/providers/settings_providers.dart`
- `settingsProvider` — user settings
- `themeProvider` — current theme mode
- `designStyleProvider` — current design style

#### [NEW] `lib/providers/search_providers.dart`
- `searchQueryProvider` — text search state
- `filterProvider` — active filters state
- `filteredTransactionsProvider` — search + filter results

---

### Routing (`lib/routing/`)

#### [NEW] `lib/routing/app_router.dart`
- go_router configuration with `ShellRoute` for bottom nav
- Routes: `/home`, `/transactions`, `/analytics`, `/wallets`, `/settings`
- Sub-routes: `/transactions/add`, `/transactions/:id`, `/wallets/:id`, `/settings/categories`, `/settings/theme`, etc.
- Auth guard for PIN/biometric on app resume

#### [NEW] `lib/routing/routes.dart`
- Named route constants

---

### UI — Screens (`lib/screens/`)

#### [NEW] `lib/screens/onboarding/`
- `onboarding_screen.dart` — Feature tour page view with slides
- `setup_name_screen.dart` — Enter user name
- `setup_currency_screen.dart` — Pick currency (₹, $, €, £, etc.)
- `setup_wallets_screen.dart` — Create initial wallets

#### [NEW] `lib/screens/auth/`
- `lock_screen.dart` — PIN entry + biometric prompt on app launch/resume

#### [NEW] `lib/screens/home/`
- `home_screen.dart` — Balance summary card, today's transactions, daily spend stat
- `widgets/balance_card.dart` — Total balance with income/expense breakdown
- `widgets/daily_stats.dart` — Today's spending summary
- `widgets/recent_transactions.dart` — Today's transaction list

#### [NEW] `lib/screens/transactions/`
- `transactions_screen.dart` — Full transaction list with search bar + filters
- `add_transaction_screen.dart` — Calculator numpad → category/title → auto-save flow
- `transaction_detail_screen.dart` — View full transaction details
- `widgets/transaction_tile.dart` — Dismissible list tile with swipe gestures
- `widgets/numpad.dart` — Calculator-style number pad
- `widgets/category_picker.dart` — Grid of category icons with auto-suggest
- `widgets/filter_sheet.dart` — Bottom sheet with filter options

#### [NEW] `lib/screens/analytics/`
- `analytics_screen.dart` — Monthly summary + charts
- `widgets/monthly_summary_card.dart` — Income, expenses, savings for month
- `widgets/spending_trend_chart.dart` — Line chart (daily/weekly trend using fl_chart)
- `widgets/export_button.dart` — CSV/PDF export trigger

#### [NEW] `lib/screens/wallets/`
- `wallets_screen.dart` — List of wallets with balances
- `wallet_detail_screen.dart` — Wallet transactions + stats
- `add_wallet_screen.dart` — Create/edit wallet form

#### [NEW] `lib/screens/settings/`
- `settings_screen.dart` — Main settings page
- `category_settings_screen.dart` — Manage categories (add, edit, reorder, hierarchy)
- `wallet_settings_screen.dart` — Manage wallets
- `theme_settings_screen.dart` — Theme mode, design style, pure black toggle
- `gesture_settings_screen.dart` — Customize swipe gestures
- `security_settings_screen.dart` — PIN/biometric toggle
- `nav_settings_screen.dart` — Customize bottom nav tabs
- `about_screen.dart` — App info, version

---

### UI — Shared (`lib/shared/`)

#### [NEW] `lib/shared/theme/`
- `app_theme.dart` — Material 3 theme data (light, dark, AMOLED black)
- `colors.dart` — Color palette constants
- `text_styles.dart` — Typography scale
- `design_styles.dart` — Minimal and glassmorphism theme variants

#### [NEW] `lib/shared/widgets/`
- `app_scaffold.dart` — Shell scaffold with bottom nav
- `animated_card.dart` — Reusable card with micro-animations
- `empty_state.dart` — Empty state illustration + message
- `loading_indicator.dart` — Branded loading spinner
- `confirm_dialog.dart` — Confirmation dialog for delete actions

#### [NEW] `lib/shared/utils/`
- `currency_formatter.dart` — Format amounts with currency symbol
- `date_formatter.dart` — Relative and absolute date formatting
- `category_suggestions.dart` — Auto-suggest algorithm (fuzzy match on title history)
- `csv_exporter.dart` — Generate CSV from transactions
- `pdf_exporter.dart` — Generate PDF report

---

### Default Categories

**Expense categories:**
| Icon | Name |
|---|---|
| 🍔 | Food & Dining |
| 🚗 | Transport |
| 🏠 | Rent & Housing |
| 🛒 | Groceries |
| 💊 | Health & Medical |
| 🎬 | Entertainment |
| 👕 | Shopping |
| 📱 | Phone & Internet |
| ⚡ | Utilities |
| 📚 | Education |
| ✈️ | Travel |
| 🎁 | Gifts |
| 💇 | Personal Care |
| 🔧 | Maintenance |
| 📦 | Other |

**Income categories:**
| Icon | Name |
|---|---|
| 💰 | Salary |
| 💼 | Freelance |
| 📈 | Investments |
| 🎁 | Gifts Received |
| 💵 | Refunds |
| 📦 | Other Income |

---

## User Review Required

> [!IMPORTANT]
> **Isar DB Note**: Isar v3 is the last stable release. The author has moved on to Isar v4 (still in development). If Isar v3 proves problematic with latest Flutter, we may need to fall back to **drift** (SQLite) as an alternative. I'll validate compatibility during setup.

> [!IMPORTANT]
> **Auto-save behavior**: When the user finishes typing the title/category in add-transaction flow, the transaction auto-saves. Should there be a brief "Saved ✓" toast/snackbar, or should it save completely silently? I recommend a subtle snackbar with an "Undo" option (3 seconds).

> [!WARNING]
> **Settings complexity**: Many features are marked as "customizable in settings" (theme, gestures, nav tabs, categories, wallets, design style). This is a significant amount of settings UI. For phase 1, I'll implement all of them, but some (like nav tab reordering) may be simplified to toggle-based rather than full drag-and-drop reorder.

## Open Questions

> [!IMPORTANT]
> **Default wallets**: What default wallets should be pre-created during onboarding? My recommendation: **Cash** and **Bank Account** as defaults, with the option to add more during onboarding setup.

> [!IMPORTANT]  
> **Transaction fields**: Beyond amount, title, category, wallet, and date — should there be a "payment mode" field (Cash, UPI, Card, Net Banking)? Or is the wallet selection sufficient for this?

---

## Verification Plan

### Automated Tests
```bash
flutter analyze
flutter test
```

### Manual Verification
- Run app on Android emulator / physical device
- Complete onboarding flow
- Add income and expense transactions via calculator numpad
- Verify auto-suggest categories
- Check balance calculations across wallets
- Test search and filter functionality
- Verify analytics charts render correctly
- Test CSV/PDF export
- Test biometric + PIN lock
- Verify dark/light auto-switch by time
- Test swipe gestures on transaction list
- Validate all settings screens

---

## Folder Structure
```
lib/
├── main.dart
├── app.dart
├── data/
│   ├── models/
│   │   ├── transaction.dart
│   │   ├── category.dart
│   │   ├── wallet.dart
│   │   └── user_settings.dart
│   └── repositories/
│       ├── transaction_repository.dart
│       ├── category_repository.dart
│       ├── wallet_repository.dart
│       └── settings_repository.dart
├── providers/
│   ├── transaction_providers.dart
│   ├── wallet_providers.dart
│   ├── category_providers.dart
│   ├── settings_providers.dart
│   └── search_providers.dart
├── routing/
│   ├── app_router.dart
│   └── routes.dart
├── screens/
│   ├── onboarding/
│   ├── auth/
│   ├── home/
│   ├── transactions/
│   ├── analytics/
│   ├── wallets/
│   └── settings/
└── shared/
    ├── theme/
    ├── widgets/
    └── utils/
```
