# Pocket App — UI Generation Prompts

> Detailed prompts for generating UI mockups of every screen in the Pocket transaction tracking app.
> Use these prompts with Google's image generation tools (Imagen, etc.)

---

## 🎨 Design System Reference

Use these specs consistently across ALL prompts:

| Property | Value |
|---|---|
| **Primary Color** | Forest Green `#2E7D32` / `#4CAF50` |
| **Accent Color** | Warm Orange `#FF9800` / `#FFB74D` |
| **Dark Background** | Pure Black `#000000` |
| **Dark Surface** | `#121212` / `#1E1E1E` |
| **Light Background** | `#FAFAFA` |
| **Light Surface** | `#FFFFFF` |
| **Income Color** | Green `#4CAF50` |
| **Expense Color** | `#EF5350` (soft red) |
| **Font** | Google Sans / Inter |
| **Style** | Material 3, rounded corners (16dp), subtle shadows |
| **Aspect Ratio** | 9:16 (mobile portrait) |
| **Frame** | No device frame, just the raw UI screen |

---

## 📱 Screen 1: Onboarding — Welcome / Feature Tour

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app onboarding welcome screen. Material 3 design language.

Center of screen: A large, elegant illustration of a green wallet with golden coins and a small bar chart rising upward, rendered in a modern flat illustration style with subtle gradients. The illustration uses forest green (#2E7D32), warm orange (#FF9800), and gold tones against the black background.

Below the illustration: Large bold white text "Welcome to Pocket" in Google Sans font, 28sp. Below that, muted gray (#9E9E9E) subtitle text "Track every rupee. Master your money." in 16sp.

At the bottom: A row of 4 small dot indicators, the first dot is filled green (#4CAF50), the other 3 are outline gray (#424242). Below the dots: A wide rounded pill-shaped button (border-radius 28dp) with green (#4CAF50) background and white bold text "Get Started". Below the button: Small gray text "Skip" that is tappable.

The overall feel is premium, minimal, and inviting. Clean spacing, no clutter. Status bar at top shows white icons on black.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app onboarding welcome screen. Material 3 design language.

Center of screen: A large, elegant illustration of a green wallet with golden coins and a small bar chart rising upward, rendered in a modern flat illustration style with subtle gradients. The illustration uses forest green (#2E7D32), warm orange (#FF9800), and gold tones against the light background.

Below the illustration: Large bold dark text (#1B1B1B) "Welcome to Pocket" in Google Sans font, 28sp. Below that, muted gray (#757575) subtitle text "Track every rupee. Master your money." in 16sp.

At the bottom: A row of 4 small dot indicators, the first dot is filled green (#4CAF50), the other 3 are outline light gray (#E0E0E0). Below the dots: A wide rounded pill-shaped button (border-radius 28dp) with green (#4CAF50) background and white bold text "Get Started". Below the button: Small gray text "Skip".

The overall feel is premium, clean, and fresh. Bright and airy. Status bar at top shows dark icons on white.
```

---

## 📱 Screen 2: Onboarding — Feature Tour Slide (Spending Insights)

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app onboarding feature tour slide. Material 3 design.

Top half: A beautiful illustration showing a stylized line chart trending upward with green (#4CAF50) gradient fill underneath, small orange (#FF9800) data points on the line, and subtle floating rupee (₹) symbols. Modern flat vector art style with soft glows.

Bottom half: Bold white text "Smart Spending Insights" in 24sp Google Sans. Below: Gray (#9E9E9E) body text "See where your money goes with beautiful charts and daily trend analysis." in 15sp, centered, max 2 lines.

Bottom: Row of 4 dot indicators, second dot filled green, others outline gray. Wide green (#4CAF50) rounded pill button "Next". Small "Skip" text below.

Premium, sleek, dark aesthetic.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app onboarding feature tour slide. Material 3 design.

Top half: A beautiful illustration showing a stylized line chart trending upward with green (#4CAF50) gradient fill underneath, small orange (#FF9800) data points on the line, and subtle floating rupee (₹) symbols. Modern flat vector art style with soft shadows.

Bottom half: Bold dark (#1B1B1B) text "Smart Spending Insights" in 24sp Google Sans. Below: Gray (#757575) body text "See where your money goes with beautiful charts and daily trend analysis." in 15sp, centered.

Bottom: Row of 4 dot indicators, second dot filled green, others outline light gray. Wide green pill button "Next". Small gray "Skip" text below.

Clean, bright, premium aesthetic.
```

---

## 📱 Screen 3: Onboarding — Name & Currency Setup

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app onboarding setup screen. Material 3 design.

Top: Back arrow icon (white) on the left. Centered title "Set Up Your Profile" in white, 20sp, bold.

Main content area with generous padding (24dp):

First section: Label "Your Name" in green (#4CAF50) 13sp above a Material 3 outlined text field with rounded corners (12dp), white border on dark surface (#1E1E1E), placeholder text "Enter your name" in gray (#616161). The text field has a subtle green focus indicator.

Second section (below, 32dp gap): Label "Currency" in green (#4CAF50) 13sp. Below it, a horizontal scrollable row of currency chips/cards. Each chip is a rounded rectangle (border-radius 12dp) with dark surface (#1E1E1E) background showing the currency symbol large (₹, $, €, £, ¥) and the code below (INR, USD, EUR, GBP, JPY). The selected chip (₹ INR) has a green (#4CAF50) border and subtle green tint background (#1B3A1B). Unselected chips have gray (#333333) borders.

Bottom: Wide green (#4CAF50) rounded pill button "Continue" with white bold text. Disabled state if name is empty.

Sleek, minimal, premium dark interface.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app onboarding setup screen. Material 3 design.

Top: Back arrow icon (dark) on the left. Centered title "Set Up Your Profile" in dark (#1B1B1B), 20sp, bold.

Main content area with generous padding (24dp):

First section: Label "Your Name" in green (#2E7D32) 13sp above a Material 3 outlined text field with rounded corners (12dp), gray border on white surface, placeholder text "Enter your name" in light gray (#BDBDBD).

Second section: Label "Currency" in green (#2E7D32) 13sp. Horizontal scrollable row of currency chips. Each chip is a rounded rectangle on white (#FFFFFF) with subtle shadow, showing currency symbol (₹, $, €, £, ¥) and code. Selected chip (₹ INR) has green (#4CAF50) border and light green tint (#E8F5E9). Unselected have light gray (#E0E0E0) borders.

Bottom: Wide green (#4CAF50) rounded pill button "Continue".

Clean, bright, premium light interface.
```

---

## 📱 Screen 4: Onboarding — Wallet Setup

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app onboarding wallet setup screen. Material 3 design.

Top: Back arrow (white), centered title "Set Up Your Wallets" in white 20sp bold.

Subtitle below title: Gray (#9E9E9E) text "Add the accounts you use to track spending" in 14sp.

Main content: A vertical list of wallet cards. Each card is a rounded rectangle (16dp radius) with dark surface (#1E1E1E) background, horizontal layout:
- Left: Circular colored icon (40dp) with wallet emoji/icon
- Center: Wallet name in white 16sp bold, below it gray text showing "₹0.00" balance
- Right: Green checkmark for selected, or gray circle for unselected

Pre-filled wallets shown:
1. 💵 "Cash" — green circle icon background — checked (green ✓)
2. 🏦 "Bank Account" — blue circle icon background — checked (green ✓)  
3. 💳 "Credit Card" — orange circle icon background — unchecked
4. 📱 "UPI" — purple circle icon background — unchecked

Below the list: A dashed-border rounded rectangle button with "+" icon and gray text "Add Custom Wallet" — dashed border in gray (#424242).

Bottom: Wide green (#4CAF50) rounded pill button "Finish Setup" with white bold text.

Dark, premium, clean layout with good spacing between cards (12dp).
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app onboarding wallet setup screen. Material 3 design.

Top: Back arrow (dark), centered title "Set Up Your Wallets" in dark 20sp bold.

Subtitle: Gray (#757575) text "Add the accounts you use to track spending" in 14sp.

Wallet cards on white (#FFFFFF) surface with subtle elevation shadow (2dp), rounded 16dp:
1. 💵 "Cash" — light green circle icon — checked (green ✓)
2. 🏦 "Bank Account" — light blue circle — checked (green ✓)
3. 💳 "Credit Card" — light orange circle — unchecked
4. 📱 "UPI" — light purple circle — unchecked

Dashed-border "Add Custom Wallet" button with light gray dashes.

Bottom: Wide green pill button "Finish Setup".

Bright, clean, premium look.
```

---

## 📱 Screen 5: Lock Screen (PIN + Biometric)

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app lock screen with PIN entry. Material 3 design.

Top center: Pocket app logo — a minimal geometric wallet icon in green (#4CAF50) with a subtle orange (#FF9800) accent, 64dp size. Below logo: "Pocket" text in white 22sp bold.

Middle: 4 PIN dots in a horizontal row (spaced 20dp apart). 2 dots are filled green (#4CAF50) circles (12dp), 2 are outlined gray (#424242) circles. This indicates 2 digits entered.

Below dots (24dp gap): A subtle rounded chip/button with fingerprint icon (white) and text "Use Fingerprint" in gray (#BDBDBD), 13sp. The chip has a dark surface (#1E1E1E) background with rounded corners.

Bottom half: A 3×4 numeric keypad grid on pure black background:
- Number buttons (1-9, 0) are circular (64dp), dark surface (#1E1E1E) background, white number text 24sp bold
- Bottom left: empty space
- Bottom right: backspace icon (white) on transparent background
- Numbers arranged: 1 2 3 / 4 5 6 / 7 8 9 / [empty] 0 [⌫]
- Subtle press-state ripple in green tint

Very clean, secure, minimal aesthetic. No unnecessary elements.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app lock screen with PIN entry. Material 3 design.

Top center: Pocket app logo — minimal wallet icon in green (#2E7D32), 64dp. Below: "Pocket" in dark (#1B1B1B) 22sp bold.

Middle: 4 PIN dots, 2 filled green (#4CAF50), 2 outlined light gray (#E0E0E0).

Fingerprint chip with light gray (#F5F5F5) background, dark icon and text.

Bottom: 3×4 numeric keypad, circular buttons with white (#FFFFFF) background and subtle shadow, dark number text. Backspace icon in dark gray.

Clean, bright, secure feel.
```

---

## 📱 Screen 6: Home Screen (Main Dashboard)

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app home screen / main dashboard. Material 3 design language. This is the most important screen.

TOP SECTION:
- Status bar with white icons
- App bar: Left side "Hi, Nandha 👋" in white 18sp bold. Right side: notification bell icon (white outline) and search icon (white outline).

BALANCE CARD (below app bar, 16dp margin):
A large rounded card (20dp radius) with a rich gradient background from dark green (#1B5E20) to forest green (#2E7D32), subtle noise texture overlay for premium feel. Inside the card:
- Top left: Small text "Total Balance" in light green (#A5D6A7) 12sp
- Below: Large bold white text "₹24,580.00" in 32sp Google Sans
- Bottom row of the card: Three mini stat columns separated by thin vertical dividers:
  - "Income" with up-arrow icon in green, "₹45,000" in white 14sp bold
  - "Expenses" with down-arrow icon in soft red (#EF5350), "₹20,420" in white 14sp bold  
  - "Today" with calendar icon in orange (#FFB74D), "₹1,250" in white 14sp bold

QUICK STATS ROW (below card, 16dp gap):
Two small rounded cards side by side (48% width each), dark surface (#1E1E1E), 12dp radius:
- Left card: Small orange (#FFB74D) flame icon, "Daily Average" in gray 11sp, "₹680" in white 16sp bold
- Right card: Small green (#4CAF50) trending-up icon, "This Month" in gray 11sp, "-₹20,420" in soft red 16sp bold

SECTION HEADER (16dp below):
"Today's Transactions" in white 16sp bold on the left. "See All →" in green (#4CAF50) 13sp on the right.

TRANSACTION LIST (below header):
4-5 transaction items, each is a horizontal row on pure black background with subtle separator lines (#1E1E1E):
- Left: Circular category icon (40dp) with colored background (each category has its own muted color)
  - 🍔 Food — warm red circle (#3E2723 tint)
  - 🚗 Transport — blue circle (#1A237E tint)  
  - 💰 Salary — green circle (#1B5E20 tint)
  - 🛒 Groceries — orange circle (#E65100 tint)
- Center: Transaction title "Lunch at Zomato" in white 15sp, below it gray (#9E9E9E) text "Food & Dining • Cash" 12sp
- Right: Amount — expenses in soft red "-₹250", income in green "+₹45,000", 15sp bold
- Each row has 16dp vertical padding

BOTTOM NAVIGATION BAR:
Rounded top corners (16dp), dark surface (#121212) background. 5 equally spaced items:
- 🏠 Home (active — green icon, green label "Home", green indicator pill above)
- 📋 Transactions (inactive — gray icon, gray label)
- 📊 Analytics (inactive — gray icon, gray label)
- 💳 Wallets (inactive — gray icon, gray label)
- ⚙️ Settings (inactive — gray icon, gray label)
Material 3 style with active indicator pill (green rounded rectangle behind active icon).

Overall: Premium, data-rich but not cluttered, clear visual hierarchy, dark AMOLED aesthetic.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app home screen / main dashboard. Material 3 design language.

TOP SECTION:
- Status bar with dark icons
- App bar: "Hi, Nandha 👋" in dark (#1B1B1B) 18sp bold. Right: notification bell and search icons in dark gray.

BALANCE CARD:
Large rounded card (20dp radius) with gradient from medium green (#388E3C) to light green (#4CAF50), clean look. Inside:
- "Total Balance" in light green (#C8E6C9) 12sp
- "₹24,580.00" in white 32sp bold
- Bottom row: Income (green up-arrow, ₹45,000), Expenses (red down-arrow, ₹20,420), Today (orange calendar, ₹1,250) — all white text

QUICK STATS ROW:
Two white (#FFFFFF) cards with subtle shadow (4dp elevation), rounded 12dp:
- "Daily Average ₹680" with orange icon
- "This Month -₹20,420" with green icon, amount in red

SECTION: "Today's Transactions" dark bold, "See All →" green.

TRANSACTION LIST on white background:
- Category icons with pastel colored circle backgrounds
- Title in dark text, subtitle in gray
- Amounts: red for expense, green for income
- Subtle (#F0F0F0) divider lines

BOTTOM NAV: White (#FFFFFF) surface with subtle top shadow, green active state with Material 3 indicator pill.

Bright, clean, premium, airy feel.
```

---

## 📱 Screen 7: Transactions List Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app transactions list screen. Material 3 design.

TOP:
- App bar with centered title "Transactions" in white 20sp bold
- Below app bar: A Material 3 search bar — rounded pill shape (28dp radius), dark surface (#1E1E1E), with search icon (gray) on left and placeholder "Search transactions..." in gray (#616161). Microphone icon on right.

FILTER ROW (below search, 12dp gap):
Horizontal scrollable row of filter chips, Material 3 style rounded pills:
- "All" chip — filled green (#4CAF50) background, white text (active)
- "Income" chip — outlined gray, white text
- "Expense" chip — outlined gray, white text  
- "This Week" chip — outlined gray, with calendar icon
- "Food" chip — outlined gray
- Each chip has 8dp horizontal padding between them

DATE GROUPED TRANSACTION LIST:
Section headers for dates:
- "Today, 28 Aug" in green (#4CAF50) 13sp bold, with total "-₹1,250" in gray on the right

Transaction items (same style as home screen):
- Category icon circle (40dp), title, subtitle (category • wallet), amount
- Swipe hint: very subtle left-pointing chevron on the right edge (barely visible)

Another section: "Yesterday, 27 Aug" header, with 3-4 transactions.

Another section: "26 Aug 2026" with 2-3 transactions.

The list is scrollable with smooth transitions between date groups.

BOTTOM NAV: Same as home, but "Transactions" tab is active (green icon + label + indicator pill).

Clean, organized, scannable dark interface.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app transactions list screen. Material 3 design.

Search bar: White (#FFFFFF) pill with subtle shadow, dark search icon, gray placeholder text.

Filter chips: "All" filled green with white text. Others outlined with light gray borders, dark text.

Date sections: Green date headers, light gray (#F5F5F5) subtle section background.

Transaction rows on white, with pastel category icons, dark text, subtle dividers.

Bottom nav with "Transactions" active in green.

Bright, organized, premium.
```

---

## 📱 Screen 8: Add Transaction Screen (Calculator Numpad)

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app add transaction screen with calculator-style numpad. Material 3 design. This is a critical screen for the app's core flow.

TOP:
- App bar: Back arrow (white) on left. Center: Two segmented toggle buttons "Expense" (active — filled with soft red #EF5350 background, white text) and "Income" (inactive — dark surface, gray text). The toggle is a Material 3 segmented button with rounded ends.

AMOUNT DISPLAY (large, prominent):
- Center of upper area: The rupee symbol "₹" in gray (#757575) 24sp, followed by the entered amount "1,250" in white 48sp extra-bold Google Sans. If no amount entered, show "0" in gray (#424242) 48sp.
- Below the amount: A thin horizontal line (green #4CAF50, 40% width, centered) acting as a subtle separator.

CATEGORY SUGGESTION ROW (below amount, 20dp gap):
- Small label "Category" in gray (#9E9E9E) 11sp on the left
- Horizontal scrollable row of category suggestion chips based on history:
  - First chip highlighted: "🍔 Food & Dining" with green (#1B5E20) tint background, white text — this is the auto-suggested category
  - Other chips: "🚗 Transport", "🛒 Groceries", "👕 Shopping" in dark surface (#1E1E1E) with gray text
  - Last chip: "+ More" in outlined gray

TITLE INPUT (below categories):
- A minimal text field (no border, just underline style) with placeholder "Add a note..." in gray (#616161) 14sp. When the user types a title, the category suggestions update in real-time.

WALLET SELECTOR (below title):
- Small row: wallet icon (💵) + "Cash" in white 13sp + dropdown chevron. Tappable to switch wallet.

DATE SELECTOR (next to wallet, right aligned):
- Calendar icon + "Today" in white 13sp + dropdown chevron.

CALCULATOR NUMPAD (bottom 50% of screen):
A 4×4 grid of circular buttons on pure black:
Row 1: [7] [8] [9] [⌫ backspace]
Row 2: [4] [5] [6] [+]  
Row 3: [1] [2] [3] [-]
Row 4: [.] [0] [00] [✓ green filled circle]

- Number buttons: 64dp circles, dark surface (#1E1E1E), white text 22sp bold
- Operator buttons (+, -): 64dp circles, dark surface (#1E1E1E), orange (#FFB74D) text 22sp
- Backspace: 64dp circle, dark surface, white ⌫ icon
- Confirm/save button (✓): 64dp circle, green (#4CAF50) filled, white checkmark icon — this auto-saves the transaction

Grid has 12dp spacing between buttons. The numpad feels like a premium calculator.

Overall: Focused, fast-entry interface optimized for one-handed use. Dark, premium, no distractions.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app add transaction screen with calculator-style numpad. Material 3 design.

Top: Segmented toggle — "Expense" active in soft red, "Income" inactive in light gray.

Amount: "₹1,250" in dark (#1B1B1B) 48sp extra-bold. Green underline separator.

Category chips: Auto-suggested "🍔 Food & Dining" with light green (#E8F5E9) tint, others on white with light gray borders.

Title input: Minimal underline field, gray placeholder.

Wallet and date selectors in dark text with chevrons.

Numpad: White (#FFFFFF) circular buttons with subtle shadows, dark number text. Orange operator text. Green filled confirm button with white checkmark.

Bright, focused, clean calculator interface.
```

---

## 📱 Screen 9: Transaction Detail Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app transaction detail screen. Material 3 design.

TOP:
- App bar: Back arrow (white) left, "Transaction Details" centered white 18sp, three-dot menu icon right (white).

MAIN CONTENT (centered, generous spacing):

Amount section (centered):
- Large category icon (56dp circle with colored background, e.g., 🍔 on warm red tint #3E2723) centered
- Below icon: "Lunch at Zomato" in white 20sp bold
- Below title: "Food & Dining" in green (#4CAF50) 14sp
- Below category: Large amount "-₹250.00" in soft red (#EF5350) 36sp extra-bold (or green for income)

Detail card (below, 24dp gap):
A rounded card (16dp radius) with dark surface (#1E1E1E) background. Inside, a vertical list of detail rows with subtle dividers (#2A2A2A):
- Row: Calendar icon (gray) | "Date" gray 13sp | "28 Aug 2026, 1:30 PM" white 14sp — right aligned
- Row: Wallet icon (gray) | "Wallet" gray 13sp | "💵 Cash" white 14sp — right aligned  
- Row: Tag icon (gray) | "Category" gray 13sp | "🍔 Food & Dining" white 14sp — right aligned
- Row: Type icon (gray) | "Type" gray 13sp | "Expense" in soft red 14sp — right aligned
- Row: Note icon (gray) | "Note" gray 13sp | "Team lunch" white 14sp — right aligned

Each row has 16dp vertical padding, icons are 20dp, in gray (#757575).

ACTION BUTTONS (bottom, 32dp gap):
Two buttons side by side:
- "Edit" — outlined green border, green text, rounded pill, left half width
- "Delete" — outlined red (#EF5350) border, red text, rounded pill, right half width

Clean, detailed, informative layout.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app transaction detail screen. Material 3 design.

Same layout as dark mode but:
- White surface card with subtle shadow
- Dark text for values, gray for labels
- Category icon on pastel colored circle
- Amount in dark red for expense, dark green for income
- Dividers in light gray (#F0F0F0)
- Edit button outlined green, Delete button outlined red
- Clean, bright, detailed layout
```

---

## 📱 Screen 10: Analytics Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app analytics screen with charts and monthly summary. Material 3 design.

TOP:
- App bar: "Analytics" centered white 20sp bold. Right side: export/share icon (white).

MONTH SELECTOR (below app bar):
- Horizontal row with left arrow, "August 2026" in white 16sp bold center, right arrow. Arrows are green (#4CAF50). Tappable to navigate months.

MONTHLY SUMMARY CARD:
Rounded card (16dp) with dark surface (#1E1E1E). Three columns:
- "Income" — green (#4CAF50) small dot, "₹45,000" in green 18sp bold, "↑ 12%" in small green chip
- "Expenses" — red (#EF5350) small dot, "₹20,420" in soft red 18sp bold, "↓ 5%" in small green chip (down is good)
- "Savings" — orange (#FFB74D) small dot, "₹24,580" in orange 18sp bold, "54%" in small orange chip
Columns separated by thin vertical dividers (#2A2A2A).

SPENDING TREND CHART (below, 16dp gap):
Section title: "Daily Spending" in white 15sp bold left, "Week ▾" dropdown in gray right.
A beautiful line chart using fl_chart style:
- Dark surface (#1E1E1E) rounded card background (16dp radius)
- X-axis: Days (Mon, Tue, Wed, Thu, Fri, Sat, Sun) in gray 11sp
- Y-axis: Amount values in gray 11sp (₹0, ₹500, ₹1K, ₹1.5K, ₹2K)
- Expense line: Smooth curved line in soft red (#EF5350) with gradient fill (red to transparent) below the line
- Income dots: Small green circles on income days
- Grid lines: Very subtle (#1A1A1A) horizontal dashed lines
- Interactive tooltip: One data point highlighted with a vertical dashed green line and a floating label showing "₹1,250" with date
- The chart is 200dp tall

EXPORT SECTION (below chart):
Two side-by-side rounded buttons on dark surface:
- "📄 Export CSV" — outlined gray, white text
- "📊 Export PDF" — outlined gray, white text

BOTTOM NAV: "Analytics" tab active in green.

Data-rich but clean, premium dark analytics view.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app analytics screen. Material 3 design.

Month selector with dark text, green arrows.

Summary card on white with shadow: green income, red expenses, orange savings.

Line chart on white card with shadow:
- Red expense line with light red gradient fill
- Light gray grid lines
- Dark axis labels
- Tooltip with green accent

Export buttons on white with gray outlines.

Bottom nav with "Analytics" active green.

Bright, data-rich, premium.
```

---

## 📱 Screen 11: Wallets Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app wallets screen showing all user wallets. Material 3 design.

TOP:
- App bar: "Wallets" centered white 20sp bold.

TOTAL BALANCE HEADER:
- "Total Balance" in gray (#9E9E9E) 13sp centered
- "₹24,580.00" in white 28sp extra-bold centered
- Below: Small row showing "4 wallets" in gray 12sp

WALLET CARDS (vertical list, 12dp spacing):
Each wallet is a large rounded card (20dp radius, dark surface #1E1E1E):

Card 1 — Cash:
- Left: Large circular icon (48dp) with green (#1B5E20) tint background, 💵 emoji
- Center: "Cash" in white 17sp bold, below "12 transactions" in gray 12sp
- Right: "₹8,250.00" in white 18sp bold
- Bottom of card: Thin progress bar showing percentage of total (green fill on dark track)

Card 2 — Bank Account:
- Blue (#1A237E) tint icon circle, 🏦 emoji
- "Bank Account" white bold, "8 transactions" gray
- "₹15,330.00" white bold
- Blue tinted progress bar

Card 3 — Credit Card:
- Orange (#E65100) tint icon circle, 💳 emoji  
- "Credit Card" white bold, "5 transactions" gray
- "-₹2,400.00" in soft red (negative balance/dues)
- Orange tinted progress bar

Card 4 — UPI:
- Purple (#4A148C) tint icon circle, 📱 emoji
- "UPI" white bold, "3 transactions" gray
- "₹3,400.00" white bold

ADD WALLET BUTTON (below cards):
A dashed-outline rounded card (20dp radius), gray (#424242) dashed border, centered "+" icon and "Add Wallet" text in gray (#757575).

BOTTOM NAV: "Wallets" tab active green.

Clean, card-based layout, premium feel.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Pocket app wallets screen. Material 3 design.

Same layout but:
- White cards with subtle shadow elevation
- Pastel colored icon circles (light green, light blue, light orange, light purple)
- Dark text for names and amounts
- Progress bars with matching pastel colors
- Dashed "Add Wallet" with light gray border
- Bottom nav "Wallets" active green

Bright, card-based, premium.
```

---

## 📱 Screen 12: Wallet Detail Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app wallet detail screen showing a specific wallet's info. Material 3 design.

TOP:
- App bar: Back arrow (white), "Cash" centered white 18sp bold, edit pencil icon (white) right.

WALLET BALANCE CARD:
Rounded card (20dp radius) with gradient matching wallet color (green gradient for Cash: #1B5E20 to #2E7D32):
- 💵 emoji centered (32dp)
- "Cash" in white 14sp below emoji
- "₹8,250.00" in white 32sp extra-bold centered
- Bottom row: "Income ₹12,000" (green up-arrow) | "Spent ₹3,750" (red down-arrow) — white text, separated by divider

MINI CHART:
Small sparkline chart (80dp tall) on dark surface card showing spending trend for this wallet — green line on dark background.

TRANSACTION LIST for this wallet:
Date grouped like the main transactions screen, but filtered to this wallet only.
"Today" header with 2 transactions, "Yesterday" with 3 transactions.

Same transaction row style: category icon, title, subtitle (category only, no wallet since we're in wallet detail), amount.

Clean detail view focused on one wallet.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Same layout, wallet gradient card (lighter green tones), white surface cards, dark text, pastel category icons. Clean and bright.
```

---

## 📱 Screen 13: Add/Edit Wallet Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app add wallet screen. Material 3 design. Form layout.

TOP:
- App bar: "Add Wallet" centered white 18sp bold. X close icon on left.

FORM CONTENT (vertical, 24dp padding, 20dp gaps between fields):

Icon selector:
- Centered large circle (72dp) with dark surface (#1E1E1E) and current selected emoji (💵) inside. Below: "Tap to change icon" in gray 12sp.
- Below: Horizontal row of 8 small emoji options (💵💳🏦📱💰🎯🏪✈️) in dark circles, selected one has green border.

Name field:
- "Wallet Name" label in green (#4CAF50) 13sp
- Material 3 outlined text field, rounded 12dp, white text "My Savings" entered, green border focus state

Color picker:
- "Color" label in green 13sp  
- Row of 8 small color circles (green, blue, orange, purple, red, teal, pink, amber), selected has white checkmark inside and subtle glow

Initial balance:
- "Initial Balance" label in green 13sp
- Outlined text field with "₹" prefix in gray, entered value "5,000" in white

BOTTOM:
Wide green (#4CAF50) rounded pill button "Create Wallet" with white bold text.

Clean form, dark, Material 3.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Same form layout: white surface, gray borders, dark text. Pastel color circles. Green labels. White cards with shadow for icon area. Green create button. Bright and clean.
```

---

## 📱 Screen 14: Settings Screen (Main)

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app main settings screen. Material 3 design. Well-organized grouped list.

TOP:
- App bar: "Settings" centered white 20sp bold.

USER PROFILE SECTION (top):
Rounded card (16dp) dark surface (#1E1E1E):
- Left: Circular avatar (48dp) with user initials "N" in white on green (#4CAF50) circle
- Center: "Nandha" in white 16sp bold, "₹ INR • Indian Rupee" in gray 13sp below
- Right: Chevron (>) in gray

SETTINGS GROUPS (below, separated by 24dp spacing):

Group label: "APPEARANCE" in green (#4CAF50) 11sp bold uppercase, 8dp left padding

Rows on pure black, each row has:
- Left: Material icon (24dp) in gray (#9E9E9E)
- Center: Setting name in white 15sp, subtitle in gray 12sp
- Right: Value or chevron in gray

Appearance group:
- 🎨 "Theme" / "Auto (Time-based)" → chevron
- 🖌️ "Design Style" / "Material 3" → chevron
- 🌑 "Pure Black Mode" / toggle switch (ON — green)

Group: "GENERAL"
- 📂 "Categories" / "18 categories" → chevron
- 💳 "Wallets" / "4 wallets" → chevron
- 👆 "Gestures" / "Swipe to edit/delete" → chevron
- 🧭 "Navigation Tabs" / "5 tabs" → chevron

Group: "SECURITY"
- 🔒 "App Lock" / "Biometric + PIN" → chevron
- 🔑 "Change PIN" → chevron

Group: "DATA"
- 📤 "Export Data" / "CSV, PDF" → chevron
- 🔄 "Backup & Restore" → chevron

Group: "ABOUT"
- ℹ️ "About Pocket" / "v1.0.0" → chevron

BOTTOM NAV: "Settings" tab active green.

Organized, professional settings layout.
```

### ☀️ Light Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, white (#FAFAFA) background.

Same settings layout: white surface cards with subtle shadows for groups, dark text, green group labels, green toggle states. Profile card white with shadow. Light gray dividers. Bright and clean.
```

---

## 📱 Screen 15: Category Settings Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app category management settings screen. Material 3 design.

TOP:
- App bar: Back arrow, "Categories" centered white 18sp bold, "+" add icon (green) right.

TAB BAR (below app bar):
Material 3 tab bar with two tabs:
- "Expense" (active — green underline, white text)
- "Income" (inactive — no underline, gray text)

CATEGORY LIST (vertical, drag-reorderable):
Each row has:
- Left: Drag handle icon (⠿) in gray (#424242), then category icon circle (36dp with colored tint)
- Center: Category name in white 15sp
- Right: Edit pencil icon (gray) and delete trash icon (gray)

Expense categories listed:
1. ⠿ 🍔 (warm red circle) "Food & Dining" ✏️ 🗑️
2. ⠿ 🚗 (blue circle) "Transport" ✏️ 🗑️
3. ⠿ 🏠 (teal circle) "Rent & Housing" ✏️ 🗑️
4. ⠿ 🛒 (orange circle) "Groceries" ✏️ 🗑️
5. ⠿ 💊 (pink circle) "Health & Medical" ✏️ 🗑️
6. ⠿ 🎬 (purple circle) "Entertainment" ✏️ 🗑️
7. ⠿ 👕 (indigo circle) "Shopping" ✏️ 🗑️
(more below, scrollable)

Each row on pure black with subtle (#1E1E1E) dividers, 12dp vertical padding.

ADD BUTTON (bottom):
Floating green (#4CAF50) rounded pill button at bottom: "+ Add Category"

Clean, manageable list interface.
```

### ☀️ Light Mode

```
Same layout on white (#FAFAFA) background. Pastel category icon circles. Dark text. Light gray dividers. Green active tab underline. Green add button. White surface rows.
```

---

## 📱 Screen 16: Theme Settings Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app theme settings screen. Material 3 design.

TOP:
- App bar: Back arrow, "Appearance" centered white 18sp bold.

THEME MODE SECTION:
Label "THEME MODE" in green 11sp bold uppercase.
Three selectable option cards in a vertical list, dark surface (#1E1E1E) rounded 12dp:
- ☀️ "Light Mode" — white text, gray subtitle "Classic bright theme", radio unselected (gray circle)
- 🌙 "Dark Mode" — white text, gray subtitle "Easy on the eyes", radio unselected
- 🔄 "Auto (Time-based)" — white text, gray subtitle "Switches at sunrise/sunset", radio SELECTED (green filled circle) ✓
Each card has 16dp padding, 8dp spacing between cards.

PURE BLACK TOGGLE:
A row: "Pure Black (AMOLED)" white 15sp, "Uses true #000000 black" gray 12sp, Material 3 toggle switch ON (green track, white thumb).

DESIGN STYLE SECTION (24dp below):
Label "DESIGN STYLE" in green 11sp bold uppercase.
Three cards showing mini preview thumbnails:
- Card 1: "Material 3" — mini preview showing rounded buttons and cards with green accent. SELECTED with green border and checkmark.
- Card 2: "Minimal" — mini preview showing clean, lots of whitespace, muted colors. Gray border.
- Card 3: "Glassmorphism" — mini preview showing frosted glass cards with blur. Gray border.
Each card is square-ish (100dp × 120dp), dark surface, rounded 12dp, with style name below the preview.

COLOR PALETTE SECTION (24dp below):
Label "COLOR PALETTE" in green 11sp bold uppercase.
Row of 4 color palette swatches, each a rounded square (56dp):
- 🟢🟠 Green/Orange (SELECTED — green border + checkmark) — current default
- 🔵🟡 Teal/Amber
- 🟣🩷 Purple/Pink  
- 🔵🟢 Blue/Green
Each swatch shows primary color top half, accent color bottom half.

Clean, well-organized settings.
```

### ☀️ Light Mode

```
Same layout on white (#FAFAFA). White option cards with shadows. Dark text. Green selected states. Light gray unselected borders. Same mini previews but lighter. Bright and clean.
```

---

## 📱 Screen 17: Gesture Settings Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app gesture customization settings. Material 3 design.

TOP:
- App bar: Back arrow, "Gestures" centered white 18sp bold.

PREVIEW AREA (top):
A visual demo card (dark surface #1E1E1E, rounded 16dp) showing a sample transaction row with animated arrows:
- Left arrow (orange) labeled "Swipe Right → Edit"
- Right arrow (red) labeled "← Swipe Left Delete"
- Center: The transaction row with category icon, "Sample Transaction", "₹500"
This is a visual guide showing the user how gestures work.

GESTURE CONFIGURATION LIST:

Label "SWIPE ACTIONS" in green 11sp bold uppercase.

Each row is a dark surface card with:
- Left: Gesture icon and direction description
- Right: Dropdown showing current action

Rows:
- "→ Swipe Right" | Dropdown: "Edit" (green text) ▾
- "← Swipe Left" | Dropdown: "Delete" (red text) ▾
- "Long Press" | Dropdown: "Quick Menu" (orange text) ▾
- "Tap" | Dropdown: "View Details" (white text) ▾
- "Double Tap" | Dropdown: "Duplicate" (gray text) ▾

AVAILABLE ACTIONS NOTE:
Small gray (#9E9E9E) text at bottom: "Available actions: Edit, Delete, Duplicate, View Details, Quick Menu, Mark as Recurring, None"

Reset button: "Reset to Defaults" in gray outlined pill button at bottom.

Clean, power-user settings page.
```

### ☀️ Light Mode

```
Same layout on white. White cards with shadow. Dark text. Colored action labels. Preview card with white background and subtle animations. Bright and organized.
```

---

## 📱 Screen 18: Security Settings Screen

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app security settings screen. Material 3 design.

TOP:
- App bar: Back arrow, "Security" centered white 18sp bold.

LOCK ICON (centered, top):
Large shield icon (64dp) with lock symbol inside, green (#4CAF50) color, subtle glow effect.
"Your data is protected" in green 14sp below.

SECURITY OPTIONS:

Label "APP LOCK" in green 11sp bold uppercase.

Rows on dark surface cards:
- 🔒 "Enable App Lock" | Material 3 toggle switch ON (green)
- 👆 "Biometric Authentication" / "Fingerprint or Face ID" | Toggle ON (green)
- 🔢 "PIN Lock" / "4-digit PIN as fallback" | Toggle ON (green)

Label "PIN MANAGEMENT" (16dp below):
- 🔑 "Change PIN" → chevron
- 🔄 "Reset PIN" → chevron (red tinted text for caution)

Label "LOCK BEHAVIOR" (16dp below):
- ⏱️ "Lock After" | Dropdown: "Immediately" ▾
- Options available: Immediately, 30 seconds, 1 minute, 5 minutes

Note at bottom in gray: "App will lock when you leave or switch apps."

Clean, security-focused settings.
```

### ☀️ Light Mode

```
Same layout on white. Green shield icon. White toggle cards with shadow. Dark text. Green active toggles. Bright and secure-feeling.
```

---

## 📱 Screen 19: Navigation Tab Settings

### 🌙 Dark Mode

```
Mobile app UI screen design, no device frame, 9:16 aspect ratio, pure black (#000000) background.

Pocket app navigation tab customization settings. Material 3 design.

TOP:
- App bar: Back arrow, "Navigation Tabs" centered white 18sp bold.

PREVIEW (top area):
A mini preview of the bottom navigation bar as it would appear, dark surface rounded card. Shows the current 5 tabs with icons and labels. Active tab highlighted green.

TAB LIST (main content):
Label "VISIBLE TABS" in green 11sp bold uppercase.
Toggle-able list with drag handles:
- ⠿ 🏠 "Home" | Toggle ON (green) | LOCKED (can't disable, shown as "Required")
- ⠿ 📋 "Transactions" | Toggle ON (green)
- ⠿ 📊 "Analytics" | Toggle ON (green)
- ⠿ 💳 "Wallets" | Toggle ON (green)
- ⠿ ⚙️ "Settings" | Toggle ON (green) | LOCKED "Required"

Label "AVAILABLE TABS" (below):
Additional tabs that can be added:
- 📅 "Calendar View" | Toggle OFF (gray)
- 🏷️ "Tags" | Toggle OFF (gray)

Note: "Drag to reorder. Minimum 3 tabs, maximum 5." in gray 12sp.

"Reset to Default" gray outlined button at bottom.

Clean tab management.
```

### ☀️ Light Mode

```
Same layout on white. White cards, shadows, dark text, green toggles. Mini nav preview on white. Bright and clean.
```

---

## 🎯 Prompt Tips for Best Results

> [!TIP]
> **Consistency Tips for Google Image Tools:**
> 1. Always include "Material 3 design language" and "no device frame" in every prompt
> 2. Copy-paste the color hex codes exactly to maintain consistency
> 3. For dark mode always specify "pure black (#000000) background" for AMOLED
> 4. Use "9:16 aspect ratio" for mobile portrait screens
> 5. Add "Google Sans font" or "Inter font" for typography consistency
> 6. Include "premium, modern, clean" as quality keywords
> 7. If results are too busy, add "minimal, focused, clean spacing"
> 8. If results lack detail, add "highly detailed UI mockup, pixel-perfect"

> [!TIP]
> **Batch Generation Strategy:**
> Generate in this order for best workflow:
> 1. Home Screen (dark) → establishes the design language
> 2. Home Screen (light) → validates light variant
> 3. Add Transaction → most unique/complex screen
> 4. Analytics → validates chart rendering
> 5. Then remaining screens following the established style
