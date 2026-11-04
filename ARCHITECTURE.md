# Pocket App - Complete Logic Architecture

## Overview
Pocket is a privacy-first, offline-only financial management app built with Flutter & Dart. The architecture follows a **Domain-Split Riverpod State Management** pattern with strict separation of concerns across layers.

---

## Layer Architecture

### 1. **Presentation Layer** (UI/Screens)
**Location**: `lib/screens/`

Handles user interaction and displays UI. Uses Riverpod providers for reactive state management.

```
screens/
├── home/
│   └── home_screen.dart (Main dashboard: balance, today's spend, quick stats)
├── transactions/
│   ├── transactions_list_screen.dart (List all transactions with filters)
│   ├── add_transaction_screen.dart (Detailed transaction creation)
│   ├── edit_transaction_screen.dart (Edit existing transaction)
│   ├── quick_add_dialog_screen.dart (Quick add via dialog)
│   └── transaction_detail_screen.dart (Transaction view)
├── wallets/
│   └── wallets_screen.dart (Manage bank accounts, UPI, cash, cards)
├── analytics/
│   └── analytics_screen.dart (Charts, trends, spending analysis)
├── debts/
│   └── debts_screen.dart (Borrowed/Lent money tracking)
├── settings/
│   ├── settings_screen.dart (Main settings hub)
│   ├── data_management_screen.dart (Backup, restore, export JSON/CSV/PDF)
│   ├── recurring_rules_screen.dart (Recurring transaction rules)
│   ├── widgets_customizer_screen.dart (Android widget configuration)
│   └── auto_import_studio_screen.dart (SMS/Receipt auto-import setup)
├── onboarding/
│   └── onboarding_screen.dart (First-time setup)
├── notifications/
│   └── notification_center_screen.dart (Budget alerts, reminders)
└── splash/
    └── splash_screen.dart (App startup splash)
```

**Key Pattern**: Screens are `ConsumerStatefulWidget` or `ConsumerWidget` that watch Riverpod providers.

---

### 2. **State Management Layer** (Providers)
**Location**: `lib/providers/`

Uses **Riverpod 2.6** with domain-split architecture. Each provider file manages one domain entity.

```
providers/
├── core_providers.dart
│   └── Exports: storageServiceProvider, backupServiceProvider, autoImportServiceProvider
├── settings_provider.dart
│   ├── settingsProvider (StateNotifier: UserSettings)
│   └── Computed: effectiveThemeModeProvider, activePaletteProvider, activeDarkThemeProvider
├── transactions_provider.dart
│   ├── transactionsProvider (StateNotifier: List<TransactionModel>)
│   └── Methods: addTransaction(), updateTransaction(), deleteTransaction()
├── wallets_provider.dart
│   ├── walletsProvider (StateNotifier: List<WalletModel>)
│   ├── walletsWithBalancesProvider (Computed: List<WalletModel> with currentBalance)
│   └── totalBalanceProvider (Computed: double)
├── categories_provider.dart
│   ├── categoriesProvider (StateNotifier: List<CategoryModel>)
│   └── currentMonthCategorySpendingProvider (Computed: Map<String, double>)
├── recurring_rules_provider.dart
│   ├── recurringRulesProvider (StateNotifier: List<RecurringRuleModel>)
│   └── Methods: addRule(), updateRule(), deleteRule()
├── budgets_provider.dart
│   ├── budgetsProvider (StateNotifier: List<BudgetModel>)
│   ├── categoryBudgetsProvider (Computed: Map<String, double>)
│   └── effectiveCategoryBudgetsProvider (Computed: with cycle awareness)
├── debts_provider.dart
│   ├── debtsProvider (StateNotifier: List<DebtModel>)
│   └── Methods: addDebt(), settleDebt(), updateDebt()
├── goals_provider.dart
│   ├── goalsProvider (StateNotifier: List<GoalModel>)
│   └── totalSavedInGoalsProvider (Computed: double)
├── notifications_provider.dart
│   ├── notificationsProvider (StateNotifier: List<NotificationModel>)
│   └── Methods: markAsRead(), deleteNotification()
├── pending_transactions_provider.dart
│   ├── pendingTransactionsProvider (StateNotifier: List<PendingTransactionModel>)
│   └── Methods for SMS/UPI parsing
├── derived_providers.dart
│   ├── monthlyStatsProvider (Computed: MonthlyStats)
│   ├── netWorthSummaryProvider (Computed: NetWorthSummary)
│   ├── spendingComparisonProvider (Computed: Month-over-month)
│   ├── monthSpendForecastProvider (Computed: AI forecast)
│   ├── financialHealthReportProvider (Computed: Health score)
│   ├── totalBudgetRemainingProvider (Computed: double)
│   └── subscriptionCandidatesProvider (Computed: List<SubscriptionCandidate>)
└── app_providers.dart
    └── Central barrel export of all providers
```

**Provider Pattern**:
```dart
// StateNotifier for mutable data
final transactionsProvider = StateNotifierProvider<TransactionsNotifier, List<TransactionModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TransactionsNotifier(storage);
});

// Provider for computed/derived data (read-only)
final totalBalanceProvider = Provider<double>((ref) {
  final wallets = ref.watch(walletsWithBalancesProvider);
  return wallets.fold(0.0, (sum, w) => sum + w.currentBalance);
});
```

---

### 3. **Service Layer** (Business Logic)
**Location**: `lib/services/`

Pure business logic, no UI dependencies. Services are singleton instances.

#### Core Services

**Storage & Persistence**
```
storage_service.dart
├── Responsibility: AES-256-CBC encryption, encrypted persistence, in-memory cache
├── Methods:
│   ├── saveTransaction() / getTransactions()
│   ├── saveWallet() / getWallets()
│   ├── saveSettings() / getSettings()
│   └── processDueRecurringRules() (auto-process recurring on startup)
├── Cache Layer: 10 cached collections in memory
└── Hardware Security: Android Keystore for encryption keys
```

**AI & Analytics Services**
```
ai_forecasting_service.dart
├── Monthly spend forecast with 90% confidence intervals
├── Uses daily burn rate formula
└── Integrates upcoming recurring obligations

anomaly_detection_service.dart
├── Z-score based anomaly detection
├── Multiple-of-average threshold
└── Sample variance calculation for statistical accuracy

financial_health_service.dart
├── Composite 0-1000 Financial Health Score
├── Components: income stability, savings rate, debt ratio, budget adherence
└── Returns: FinancialHealthReport with breakdown

subscription_detector_service.dart
├── ML pattern detection for recurring transactions
├── Identifies subscription candidates from transaction history
└── Learns from user dismissals
```

**SMS & Banking Integration**
```
auto_import_service.dart
├── SMS inbox scanning for transactions
├── Signature-based deduplication
└── Native SMS permission handling

upi_screenshot_parser_service.dart
├── OCR/parsing of UPI payment screenshots
├── Merchant name extraction
└── Amount and date parsing

shared_transaction_handler.dart
├── Handles Android Intent extras for UPI/banking intents
├── Parses shared transaction data from banking apps
└── Deep linking support

system_contact_service.dart
├── Contact lookup for merchant/sender names
└── SMS contact extraction
```

**Receipt & Document Processing**
```
receipt_service.dart
├── Camera capture and image picking
├── Receipt OCR parsing
└── Amount/date extraction from receipts
```

**Notifications & Reminders**
```
notification_service.dart
├── Local push notifications (daily reminders, budget alerts)
├── Scheduled notifications
└── Notification channel setup

system_widget_service.dart
├── Android home screen app widget updates
├── Real-time widget data sync
├── Widget lifecycle management
```

**NLP & Parsing**
```
nlp_parser_service.dart
├── Natural language parsing for transactions
├── Extracts: amount, date, category, wallet, type (income/expense)
├── Supports: "1200 for dinner yesterday", "paid 4500 electricity bill"
└── Confidence scoring (0.0 - 1.0)
```

**Data & Backup**
```
backup_service.dart
├── JSON backup export/import
├── CSV transaction export
├── PDF financial report generation
└── Encrypted backup storage

bank_discovery_service.dart
├── Bank/wallet type detection
└── Account number parsing

inflation_service.dart
├── Historical inflation rates
└── Purchasing power calculations

learning_suggest_service.dart
├── ML-based category suggestions
└── Smart defaults based on history
```

**Security**
```
security_service.dart
├── Biometric authentication
├── App lock mechanism
└── PIN/password management
```

---

### 4. **Data Models** (Domain Entities)
**Location**: `lib/models/`

Immutable data classes with serialization.

```dart
transaction_model.dart
├── TransactionModel
│   ├── id, amount, title, note
│   ├── type: TransactionType (income/expense)
│   ├── categoryId, walletId
│   ├── date, createdAt, updatedAt
│   ├── receiptImagePath, senderName, receiverName
│   ├── refId (UPI reference), counterpartyLast4 (bank details)
│   └── signature (for deduplication)
└── Methods: toJson(), fromJson(), copyWith()

wallet_model.dart
├── WalletModel
│   ├── id, name, description
│   ├── walletType: WalletType (bank, upi, creditCard, cash, savings, loan)
│   ├── currentBalance, minBalance, maxBalance
│   ├── accountNumber, cardNumber, ifsc, upiId
│   ├── isActive, color, icon
│   └── createdAt, updatedAt
└── Computed: currentBalance (calculated from transactions)

category_model.dart
├── CategoryModel
│   ├── id, name, icon, color
│   ├── type: CategoryType (expense, income)
│   └── isActive
└── Hardcoded defaults: Food, Transport, Bills, etc.

recurring_model.dart
├── RecurringRuleModel
│   ├── id, title, amount, categoryId, walletId
│   ├── frequency: RecurringFrequency (daily, weekly, biweekly, monthly)
│   ├── nextDueDate, lastProcessedDate
│   ├── isActive, endDate (optional)
│   └── createdAt, updatedAt
└── Auto-processing on app startup

budget_model.dart
├── BudgetModel
│   ├── id, categoryId, amount, cycle
│   ├── cycle: BudgetCycle (monthly, quarterly, yearly)
│   └── Alert thresholds
└── Real-time tracking against spending

goal_model.dart
├── GoalModel
│   ├── id, name, targetAmount, currentAmount
│   ├── dueDate, icon, color
│   ├── priority, notes
│   └── createdAt, updatedAt
└── Net worth calculation inclusion

debt_model.dart
├── DebtModel
│   ├── id, personName, amount, type
│   ├── type: DebtType (lent, borrowed)
│   ├── dueDate, notes, isSettled
│   └── createdAt, updatedAt
└── Net worth liability tracking

settings_model.dart
├── UserSettingsModel
│   ├── User: userName, phoneNumber, currencySymbol, currencyCode
│   ├── Theme: themeMode, manualThemeStyle, themePreset, customAccentColor
│   ├── Notifications: budgetAlerts, dailyReminders, monthlySummary
│   ├── Widget: customization, theme, visibility flags
│   ├── SMS Auto-Log: autoSaveSms, autoReadSmsEnabled
│   ├── Security: biometricLockEnabled
│   ├── Persistence: deletedTransactionSignatures, processedMessageIds
│   └── Methods: formatCurrency(), formatCompact(), copyWith(), toJson(), fromJson()

notification_model.dart
├── NotificationModel
│   ├── id, title, body, type
│   ├── type: NotificationType (budgetAlert, reminder, info)
│   ├── timestamp, isRead, data
│   └── actionUri (for deep linking)
```

---

### 5. **Navigation Layer**
**Location**: `lib/navigation/`

Uses **GoRouter** for type-safe, deep-linkable navigation.

```dart
app_router.dart
├── Route Tree:
│   ├── / (home screen)
│   ├── /onboarding (onboarding flow)
│   ├── /transactions (list, add, edit, detail)
│   ├── /wallets
│   ├── /analytics
│   ├── /debts
│   ├── /settings (settings, data-management, widgets, recurring)
│   └── /notifications
├── Deep Linking Support:
│   ├── pocket://quick-add (quick add dialog)
│   ├── pocket://scan (camera receipt scan)
│   ├── pocket://voice (NLP quick add)
│   └── pocket://budget (budgets route)
└── GoRouter Configuration: error handling, redirects, transitions

app_scaffold.dart
├── Bottom navigation bar routing
├── Persistent app shell
└── Layout wrapper for screens
```

---

### 6. **UI/Widget Layer**
**Location**: `lib/widgets/`

Reusable UI components.

```
widgets/
├── balance_card.dart (Total balance display)
├── transaction_tile.dart (List tile for transaction)
├── quick_add_transaction_dialog.dart (Quick add modal)
├── nlp_quick_add_modal.dart (Voice/NLP input)
├── spend_forecast_card.dart (AI forecast visualization)
├── financial_health_gauge.dart (Health score gauge)
├── inflation_calculator_card.dart (Inflation adjustment)
├── sankey_flow_diagram.dart (Money flow visualization)
├── subscription_candidate_card.dart (Recurring detection)
├── pending_transactions_capsule.dart (SMS pending indicator)
├── sms_inbox_scanner_sheet.dart (SMS scan UI)
├── app_lock_gate.dart (Biometric authentication gate)
├── auto_import_guide_modal.dart (SMS setup guide)
├── numpad.dart (Custom numeric keypad)
├── user_avatar_widget.dart (Profile avatar)
├── blurred_dialog_utils.dart (Blur effect utility)
├── top_capsule_toast.dart (Toast notifications)
└── waving_hand_emoji.dart (Animated emoji)
```

---

### 7. **Theme & Styling**
**Location**: `lib/theme/`

```dart
app_theme.dart
├── Material 3 design system
├── Light & Dark themes
├── Dynamic color palette
├── Custom theme presets:
│   ├── Emerald
│   ├── Cyberpunk
│   ├── Sapphire
│   ├── Sunset
│   └── Rose
├── Pure black AMOLED support
└── Theme switching (manual / auto time-based)
```

---

### 8. **Utils & Helpers**
**Location**: `lib/utils/`

```dart
currency_formatter.dart
├── Indian numbering (₹1,20,000.00)
├── International numbering ($120,000.00)
└── Compact format (₹1.2L)

cycle_utils.dart
├── Billing cycle calculations
├── Month start day awareness
└── Date range utilities
```

---

## Data Flow

### Transaction Creation Flow
```
User Input
    ↓
NlpQuickAddModal / QuickAddDialog
    ↓
NlpTransactionParser.parse() / Manual Input
    ↓
TransactionsNotifier.addTransaction()
    ↓
StorageService.saveTransaction()
    ↓
AES-256 Encryption + Android Keystore
    ↓
Encrypted Local Storage (encrypted_shared_preferences)
    ↓
In-Memory Cache Update
    ↓
Riverpod State Mutation
    ↓
Reactive UI Update (Consumer Widgets)
    ↓
SystemWidgetService.updateWidgetData()
    ↓
Android Home Screen Widget Refresh
```

### SMS Auto-Log Flow
```
Incoming SMS
    ↓
[Android Native Layer] PocketAccessibilityService
    ↓
SharedTransactionHandler.onTransactionReceived()
    ↓
UpiScreenshotParserService.parse()
    ↓
PendingTransactionsProvider.addPendingTransaction()
    ↓
User Review in Pending Sheet
    ↓
User Confirms
    ↓
TransactionsNotifier.addTransaction()
    ↓
Full persistence flow (see above)
```

### State Refresh on App Resume
```
App Lifecycle: resumed
    ↓
didChangeAppLifecycleState(AppLifecycleState.resumed)
    ↓
Refresh All Providers:
   ├── transactionsProvider.refreshFromDisk()
   ├── walletsProvider.refreshFromDisk()
   ├── notificationsProvider.refreshFromDisk()
   ├── pendingTransactionsProvider.fetchPendingTransactions()
   ├── pendingTransactionsProvider.syncRecentSmsInbox()
    ↓
Derived Providers Auto-Compute:
   ├── monthlyStatsProvider
   ├── totalBalanceProvider
   ├── monthSpendForecastProvider
    ↓
SystemWidgetService._syncWidget()
    ↓
Android Widget Updates
```

---

## Dependency Injection

**Riverpod Providers as DI Container**:
```dart
// Core service initialization
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must override in main()');
});

// Service-derived providers
final backupServiceProvider = Provider<BackupService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BackupService(storage);
});

// In main()
ProviderScope(
  overrides: [
    storageServiceProvider.overrideWithValue(storageService),
  ],
  child: const PocketApp(),
)
```

---

## Key Architectural Patterns

### 1. **StateNotifier Pattern**
```dart
class TransactionsNotifier extends StateNotifier<List<TransactionModel>> {
  final StorageService _storage;
  
  TransactionsNotifier(this._storage) : super(_storage.getTransactions());
  
  Future<void> addTransaction(TransactionModel tx) async {
    state = [...state, tx];  // Mutate local state
    await _storage.saveTransaction(tx);  // Persist
  }
}
```

**Benefits**:
- Reactive state updates
- Predictable mutation patterns
- Easy testing

### 2. **Provider Composition**
```dart
// Derive complex state from simpler providers
final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  final txs = ref.watch(transactionsProvider);  // Watch dependency
  final settings = ref.watch(settingsProvider);
  // Compute derived value
  return _computeStats(txs, settings);
});
```

**Benefits**:
- Automatic cache invalidation
- Lazy evaluation
- No manual update tracking

### 3. **Encryption at Rest**
```dart
// All data encrypted with AES-256-CBC
final encryptedData = AesCryptography.encrypt(
  plaintext: jsonData,
  key: hardwareBackedKey,  // From Android Keystore
);
await storage.save(encryptedData);
```

**Benefits**:
- Privacy-first design
- Hardware-backed security
- On-device only

### 4. **Signature-Based Deduplication**
```dart
// Calculate transaction signature for idempotency
String _calculateSignature(TransactionModel tx) {
  return md5.convert(
    utf8.encode('${tx.amount}|${tx.categoryId}|${tx.walletId}|${tx.date}')
  ).toString();
}

// Skip if signature already processed
if (settings.deletedTransactionSignatures.contains(signature)) {
  return;  // Skip duplicate
}
```

**Benefits**:
- Resilient to SMS duplicates
- Handles network retries gracefully
- Idempotent operations

### 5. **Deep Linking with GoRouter**
```dart
// Android Intent → Deep Link URI → Route
SystemWidgetService.registerWidgetLaunchCallback((uri) {
  if (uri.host == 'quick-add') {
    ctx.go('/quick-add?type=expense');
  }
});
```

**Benefits**:
- Seamless widget integration
- Consistent routing
- Testable navigation

---

## Database Schema (Encrypted Local Storage)

**Collections** (stored as encrypted JSON):
```
┌─ transactions/
│  ├── tx_001: {id, amount, type, categoryId, walletId, date, ...}
│  ├── tx_002: {...}
│  └── [all transaction records]
├─ wallets/
│  ├── w_001: {id, name, type, balance, ...}
│  └── [all wallet records]
├─ categories/
│  ├── cat_food: {id, name, icon, color, ...}
│  └── [all category records]
├─ budgets/
│  ├── b_001: {categoryId, amount, cycle, ...}
│  └── [all budget records]
├─ recurring_rules/
│  ├── r_001: {title, amount, frequency, nextDueDate, ...}
│  └── [all recurring rules]
├─ goals/
│  ├── g_001: {name, targetAmount, dueDate, ...}
│  └── [all goals]
├─ debts/
│  ├── d_001: {personName, amount, type, dueDate, ...}
│  └── [all debts]
├─ notifications/
│  ├── n_001: {title, body, type, timestamp, ...}
│  └── [all notifications]
└─ settings/
   └── user_settings: {userName, currency, theme, ...}
```

---

## Security Architecture

### Encryption
```
Data at Rest:
  PlainText JSON
       ↓
  AES-256-CBC Encryption
       ↓
  Encrypted Blob
       ↓
  SharedPreferences Storage

Key Management:
  Encryption Key (128 bits)
       ↓
  Android Keystore (Hardware-Backed)
       ↓
  Hardware TEE (Secure Enclave)
```

### Authentication
```
User Launch
    ↓
AppLockGate checks biometric status
    ↓
If enabled: Prompt biometric
    ↓
Local authentication (no backend)
    ↓
Grant access to encrypted data
```

---

## Testing Architecture

### Unit Testing
- Riverpod providers (mock storage)
- Business logic services
- Data models serialization

### Widget Testing
- Screen rendering with mock providers
- User interactions (taps, text input)
- Navigation flow

### Integration Testing
- Full app flow: launch → onboarding → add transaction
- State persistence across lifecycle

---

## Performance Optimizations

### 1. In-Memory Cache Layer
```dart
// StorageService maintains 10 cached collections
// Reduces file I/O and decryption overhead
final _transactionCache = <List<TransactionModel>>[];
final _walletCache = <List<WalletModel>>[];
```

### 2. Provider Caching
```dart
// Riverpod automatically caches provider results
// Only recomputes when dependencies change
final monthlyStatsProvider = Provider<MonthlyStats>((ref) {
  // This only runs if transactionsProvider or settingsProvider changes
  final txs = ref.watch(transactionsProvider);
  final settings = ref.watch(settingsProvider);
  return _computeStats(txs, settings);
});
```

### 3. Lazy Widget Updates
```dart
// Only screens watching specific providers rebuild
Consumer(
  builder: (context, ref, child) {
    final balance = ref.watch(totalBalanceProvider);
    // Only this widget rebuilds when balance changes
    return BalanceCard(balance: balance);
  },
)
```

---

## Scalability Considerations

### Current Limits
- 10,000 transactions: ~500KB encrypted
- 50 wallets: Comfortable
- 100 budgets: Comfortable
- In-memory cache: ~5MB max

### Future Scaling Options
1. **Database Migration**: SQLite for larger datasets
2. **Pagination**: Load transactions in chunks
3. **Indexing**: Category/wallet ID indexes
4. **Sync Engine**: If cloud sync re-added

---

## Development Workflow

### Adding a New Feature

1. **Model** (Data layer)
   ```dart
   // lib/models/feature_model.dart
   class FeatureModel { ... }
   ```

2. **Provider** (State layer)
   ```dart
   // lib/providers/feature_provider.dart
   final featureProvider = StateNotifierProvider<...>(...);
   ```

3. **Service** (Business logic layer)
   ```dart
   // lib/services/feature_service.dart
   class FeatureService { ... }
   ```

4. **Screen** (UI layer)
   ```dart
   // lib/screens/feature/feature_screen.dart
   class FeatureScreen extends ConsumerWidget { ... }
   ```

5. **Navigation** (Router update)
   ```dart
   // lib/navigation/app_router.dart
   // Add route
   ```

---

## Architecture Decision Records (ADRs)

### ADR-1: Riverpod for State Management
- **Decision**: Use Riverpod 2.6 (not Bloc/GetX/Provider)
- **Rationale**: Compile-time safety, simpler provider composition, auto cache invalidation
- **Trade-off**: Steeper learning curve, but cleaner code

### ADR-2: AES-256-CBC Encryption
- **Decision**: All data encrypted at rest (no plaintext)
- **Rationale**: Privacy-first design, GDPR compliance, hardware-backed security
- **Trade-off**: Slight performance overhead (~5-10ms per operation)

### ADR-3: Local-Only Architecture (No Cloud Sync)
- **Decision**: 100% offline-first, no cloud dependencies
- **Rationale**: Security, privacy, no backend costs, works offline
- **Trade-off**: Multi-device sync requires future implementation

### ADR-4: GoRouter for Navigation
- **Decision**: Type-safe routing with deep linking
- **Rationale**: Cleaner URL handling, Android Intent integration, error handling
- **Trade-off**: More configuration than Navigator 2.0

---

## Files & Components Summary

| Component | File Count | Purpose |
|-----------|-----------|---------|
| Screens | 12 | User interfaces |
| Providers | 13 | State management |
| Services | 18 | Business logic |
| Models | 11 | Data entities |
| Widgets | 16 | Reusable components |
| Navigation | 2 | Routing |
| Theme | 1 | UI styling |
| Utils | 2 | Helper functions |

**Total**: ~75 Dart files, ~15K+ LOC

---

## Key Metrics

- **State Providers**: 50+
- **Screens**: 12
- **Services**: 18
- **Models**: 11
- **Widgets**: 16
- **Dependencies**: 25 packages (Flutter, Riverpod, GoRouter, etc.)
- **Encryption**: AES-256-CBC
- **Storage**: Local encrypted SQLite (via shared_preferences)
- **Platform**: Android (native Kotlin for SMS, widgets, accessibility)
- **Min Dart Version**: 3.0+
- **Min Flutter Version**: 3.10+

---

## Architecture Strengths

✅ **Type-Safe**: Riverpod compile-time safety, GoRouter typed routes
✅ **Reactive**: UI automatically syncs with state changes
✅ **Modular**: Clear separation of concerns across layers
✅ **Testable**: Providers can be mocked easily
✅ **Scalable**: Domain-split architecture supports feature growth
✅ **Offline-First**: No backend dependencies
✅ **Secure**: AES-256-CBC encryption, hardware-backed keys
✅ **Performance**: In-memory caching, lazy provider evaluation

---

## Architecture Weaknesses & Improvements

⚠️ **Single Device**: No multi-device sync (need cloud layer)
⚠️ **Riverpod Complexity**: Steep learning curve for new developers
⚠️ **State Mutations**: Direct state mutation (`.copyWith()` pattern) can be error-prone
⚠️ **Limited Scalability**: 10K transaction limit in memory

### Recommended Improvements

1. **Add Cloud Sync** (with encryption):
   - Firebase Firestore (end-to-end encryption)
   - Sync engine for conflict resolution
   - Change tracking and delta sync

2. **Migrate to Clean Architecture**:
   - Entity layer (pure Dart, no dependencies)
   - Use case layer (business logic)
   - Repository pattern (data abstraction)
   - Cleaner separation

3. **Add Event Sourcing**:
   - Immutable event log
   - Replay-able state
   - Audit trail

4. **Database Upgrade**:
   - Replace encrypted_shared_preferences with SQLite
   - Pagination support
   - Query optimization

5. **Testing Infrastructure**:
   - Golden tests for widgets
   - Integration test suite
   - Performance benchmarks

---

**Last Updated**: 2026-11-03
**Version**: 1.0
**Status**: Production

