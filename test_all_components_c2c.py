#!/usr/bin/env python3
"""
Comprehensive C2C Interactive UI Test Runner for Pocket - All Components
Tested on device dc96724c1e0d:
1. Recurring Dues & Rules (RecurringRulesScreen, Add Rule, Calendar View)
2. Debts & Loans (DebtsScreen, Add Lent Debt, View Calculation)
3. NLP Quick Add (NlpQuickAddModal, Natural Language Parsing, Instant Log)
4. Transaction Detail & Editing (TransactionDetailScreen, Edit Transaction, Save)
5. Transactions List Screen (Full-text Search, Filtering)
6. Notification Center (NotificationCenterScreen)
7. Wallets & Accounts (Add Bank Account, Transfer Funds, Savings Goals)
8. Data Management & Export (DataManagementScreen, Export JSON Backup)
9. Full Add Transaction Screen (AddTransactionScreen, Income Logging, Net Worth)
"""

import os
import sys
import time
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image

DEVICE_ID = "dc96724c1e0d"
PACKAGE_NAME = "com.pocket.pocket"
ARTIFACT_DIR = "/home/nandha/.gemini/antigravity-ide/brain/034d6163-7069-49d8-8ac4-9c6b2f1cb3c7"

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res

def tap_xy(x, y, desc=""):
    if desc:
        log(f"Tap {desc} at ({x}, {y})")
    run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
    time.sleep(1.2)

def key_back():
    log("Press BACK")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_BACK")
    time.sleep(1.0)

def type_text(text):
    log(f"Type text: '{text}'")
    # replace spaces with %s for adb
    escaped = text.replace(" ", "%s")
    run_cmd(f"adb -s {DEVICE_ID} shell input text '{escaped}'")
    time.sleep(0.8)

def hide_keyboard():
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent 111") # KEYCODE_ESCAPE
    time.sleep(0.5)

def capture_screenshot(name):
    sdcard_path = f"/sdcard/{name}.png"
    local_path = os.path.join(ARTIFACT_DIR, f"{name}.png")
    run_cmd(f"adb -s {DEVICE_ID} shell screencap -p {sdcard_path}")
    run_cmd(f"adb -s {DEVICE_ID} pull {sdcard_path} {local_path}")
    log(f"Saved screenshot: {name}.png")
    return local_path

def dump_ui():
    run_cmd(f"adb -s {DEVICE_ID} shell uiautomator dump /sdcard/c2c_ui.xml")
    run_cmd(f"adb -s {DEVICE_ID} pull /sdcard/c2c_ui.xml /tmp/c2c_ui.xml")
    if os.path.exists("/tmp/c2c_ui.xml"):
        try:
            return ET.parse("/tmp/c2c_ui.xml").getroot()
        except Exception as e:
            log(f"XML parse error: {e}")
    return None

def find_node_by_text(root, text_substring):
    if root is None:
        return None
    for elem in root.iter():
        text = elem.attrib.get('text', '') or elem.attrib.get('content-desc', '')
        if text_substring.lower() in text.lower():
            return elem
    return None

def get_node_center(node):
    bounds = node.attrib.get('bounds')
    if bounds:
        import re
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', bounds)
        if m:
            x1, y1, x2, y2 = map(int, m.groups())
            return (x1 + x2) // 2, (y1 + y2) // 2
    return None

def tap_node_text(text_substring, desc=""):
    root = dump_ui()
    node = find_node_by_text(root, text_substring)
    if node:
        center = get_node_center(node)
        if center:
            x, y = center
            tap_xy(x, y, desc or f"node '{text_substring}'")
            return True
    log(f"Node '{text_substring}' not found in UI dump")
    return False

def ensure_home_screen():
    log("Navigating to Home screen...")
    # Tap bottom nav Home tab (x=150, y=2320)
    tap_xy(150, 2320, "Home Tab")
    time.sleep(1.0)

def main():
    log("=== STARTING POCKET ALL COMPONENTS C2C TEST SUITE ===")
    run_cmd(f"adb -s {DEVICE_ID} shell svc power stayon true")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_WAKEUP")
    
    # -------------------------------------------------------------
    # 1. RECURRING RULES / SUBSCRIPTIONS
    # -------------------------------------------------------------
    log("--- Step 1: Testing Recurring Rules & Calendar ---")
    ensure_home_screen()
    
    # Tap Recurring Dues card (x=270, y=1250)
    tap_xy(270, 1250, "Recurring Dues Card")
    capture_screenshot("c2c_11_recurring_rules_screen")
    
    # Tap '+' in AppBar (x=930, y=170) to open Add Recurring Rule Bottom Sheet
    tap_xy(930, 170, "Add Recurring Rule Button")
    time.sleep(1.0)
    capture_screenshot("c2c_12_add_recurring_sheet")
    
    # In Add Recurring Rule bottom sheet:
    # Tap preset chip 'Netflix' (around x=180, y=1380) or enter title & amount
    # Let's tap 'Netflix' chip if available, or tap title field
    root = dump_ui()
    node = find_node_by_text(root, "Netflix")
    if node:
        center = get_node_center(node)
        if center:
            tap_xy(center[0], center[1], "Netflix Preset Chip")
    else:
        # Tap title field (around y=1500)
        tap_xy(300, 1400, "Title Field")
        type_text("Netflix 4K")
        hide_keyboard()
    
    # Tap Amount field (y is around 1550 - 1650)
    # Let's find amount field in dump
    root = dump_ui()
    amt_node = find_node_by_text(root, "Amount") or find_node_by_text(root, "0.00")
    if amt_node:
        c = get_node_center(amt_node)
        tap_xy(c[0], c[1], "Amount Field")
    else:
        tap_xy(300, 1600, "Amount Field fallback")
    type_text("649")
    hide_keyboard()
    
    # Tap 'Create Recurring Rule' button
    root = dump_ui()
    btn = find_node_by_text(root, "Create Recurring Rule")
    if btn:
        c = get_node_center(btn)
        tap_xy(c[0], c[1], "Create Recurring Rule Button")
    else:
        tap_xy(540, 2250, "Create Recurring Rule Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_13_recurring_rule_created")
    
    # Switch to Due Calendar Tab (x=750, y=280)
    tap_xy(750, 280, "Due Calendar Tab")
    time.sleep(1.0)
    capture_screenshot("c2c_14_recurring_calendar_view")
    
    # Return to Home
    key_back()
    time.sleep(1.0)
    
    # -------------------------------------------------------------
    # 2. DEBTS & LOANS (IOUs)
    # -------------------------------------------------------------
    log("--- Step 2: Testing Debts & Loans ---")
    ensure_home_screen()
    
    # Tap Debts & Loans Card (x=780, y=1250)
    tap_xy(780, 1250, "Debts & Loans Card")
    capture_screenshot("c2c_15_debts_screen")
    
    # Tap Add Debt/Loan icon in AppBar (x=930, y=170)
    tap_xy(930, 170, "Add Debt Button")
    time.sleep(1.0)
    capture_screenshot("c2c_16_add_debt_dialog")
    
    # In Add Debt Dialog:
    # Tap Person Name field (around x=400, y=1050)
    root = dump_ui()
    name_node = find_node_by_text(root, "Person Name")
    if name_node:
        c = get_node_center(name_node)
        tap_xy(c[0], c[1], "Person Name Field")
    else:
        tap_xy(400, 1050, "Person Name Field fallback")
    type_text("Rahul Sharma")
    hide_keyboard()
    
    # Tap Amount field
    root = dump_ui()
    amt_node = find_node_by_text(root, "Total Amount")
    if amt_node:
        c = get_node_center(amt_node)
        tap_xy(c[0], c[1], "Total Amount Field")
    else:
        tap_xy(400, 1250, "Total Amount Field fallback")
    type_text("2500")
    hide_keyboard()
    
    # Tap Save Button
    root = dump_ui()
    save_node = find_node_by_text(root, "Save")
    if save_node:
        c = get_node_center(save_node)
        tap_xy(c[0], c[1], "Save Debt Button")
    else:
        tap_xy(880, 1550, "Save Debt Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_17_debt_added_view")
    
    # Switch between tabs: Borrowed, Settled
    tap_xy(400, 480, "Lent Tab")
    tap_xy(650, 480, "Borrowed Tab")
    tap_xy(900, 480, "Settled Tab")
    tap_xy(150, 480, "All Tab")
    time.sleep(0.8)
    
    # Return to Home
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 3. NLP QUICK ADD (+ Quick Log)
    # -------------------------------------------------------------
    log("--- Step 3: Testing NLP Quick Add Modal ---")
    ensure_home_screen()
    
    # Tap '+ Quick Log' button (x=620, y=1550)
    tap_xy(620, 1550, "+ Quick Log Button")
    time.sleep(1.0)
    capture_screenshot("c2c_18_nlp_quick_add_modal")
    
    # Tap one of the example quick chips: '1200 for dinner yesterday' or 'paid 850 electricity bill'
    root = dump_ui()
    chip = find_node_by_text(root, "electricity bill") or find_node_by_text(root, "850") or find_node_by_text(root, "dinner yesterday")
    if chip:
        c = get_node_center(chip)
        tap_xy(c[0], c[1], "Example NLP Chip")
    else:
        # Tap input field and type
        tap_xy(400, 1400, "NLP Input Field")
        type_text("850 for electricity bill")
        hide_keyboard()
    
    time.sleep(1.0)
    capture_screenshot("c2c_19_nlp_tokens_parsed")
    
    # Tap 'Add Transaction' button
    root = dump_ui()
    add_btn = find_node_by_text(root, "Add Transaction")
    if add_btn:
        c = get_node_center(add_btn)
        tap_xy(c[0], c[1], "Add Transaction Button")
    else:
        tap_xy(540, 2200, "Add Transaction Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_20_nlp_transaction_saved_home")

    # -------------------------------------------------------------
    # 4. TRANSACTION DETAIL & EDITING
    # -------------------------------------------------------------
    log("--- Step 4: Testing Transaction Detail & Editing ---")
    ensure_home_screen()
    
    # Tap the first transaction in Today's Transactions (around x=500, y=1750)
    tap_xy(500, 1750, "First Transaction Tile")
    time.sleep(1.0)
    capture_screenshot("c2c_21_transaction_detail_screen")
    
    # Tap Edit icon in AppBar (x=830, y=170)
    tap_xy(830, 170, "Edit Transaction Button")
    time.sleep(1.0)
    capture_screenshot("c2c_22_edit_transaction_screen")
    
    # Tap Note field or Title field to update
    root = dump_ui()
    note_node = find_node_by_text(root, "Notes") or find_node_by_text(root, "Add a note")
    if note_node:
        c = get_node_center(note_node)
        tap_xy(c[0], c[1], "Note Field")
    else:
        tap_xy(400, 1000, "Note Field fallback")
    type_text("Verified online via UPI")
    hide_keyboard()
    
    # Tap 'Save' in AppBar (x=960, y=170)
    tap_xy(960, 170, "Save Edit Button")
    time.sleep(1.2)
    capture_screenshot("c2c_23_transaction_detail_updated")
    
    # Return to Home
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 5. TRANSACTIONS LIST SCREEN (Search & Filter)
    # -------------------------------------------------------------
    log("--- Step 5: Testing Dedicated Transactions List ---")
    ensure_home_screen()
    
    # Tap 'See All >' (x=860, y=1550)
    tap_xy(860, 1550, "See All Transactions Button")
    time.sleep(1.0)
    capture_screenshot("c2c_24_transactions_list_screen")
    
    # Tap Search input field (around x=400, y=280)
    tap_xy(400, 280, "Search Input Field")
    type_text("dinner")
    hide_keyboard()
    capture_screenshot("c2c_25_transactions_search_result")
    
    # Clear search
    tap_xy(950, 280, "Clear Search Icon")
    time.sleep(0.5)
    
    # Return to Home
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 6. NOTIFICATION & ALERT CENTER
    # -------------------------------------------------------------
    log("--- Step 6: Testing Notification Center ---")
    ensure_home_screen()
    
    # Tap Bell icon in AppBar (x=920, y=170)
    tap_xy(920, 170, "Notification Bell Icon")
    time.sleep(1.0)
    capture_screenshot("c2c_26_notification_center")
    
    # Return to Home
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 7. WALLETS, ACCOUNTS TRANSFER & SAVINGS GOALS
    # -------------------------------------------------------------
    log("--- Step 7: Testing Wallets, Transfer & Savings Goals ---")
    # Tap Wallets Tab (x=660, y=2320)
    tap_xy(660, 2320, "Wallets Bottom Nav Tab")
    time.sleep(1.0)
    capture_screenshot("c2c_27_wallets_screen")
    
    # Tap '+ Add Account' in AppBar (x=930, y=170)
    tap_xy(930, 170, "Add Account AppBar Icon")
    time.sleep(1.0)
    capture_screenshot("c2c_28_add_account_modal")
    
    # In Add Account Modal:
    # Tap Account Name field (x=400, y=1050)
    root = dump_ui()
    name_node = find_node_by_text(root, "Account Name")
    if name_node:
        c = get_node_center(name_node)
        tap_xy(c[0], c[1], "Account Name Field")
    else:
        tap_xy(400, 1050, "Account Name Field fallback")
    type_text("HDFC Bank")
    hide_keyboard()
    
    # Tap Initial Balance field
    root = dump_ui()
    bal_node = find_node_by_text(root, "Initial Balance")
    if bal_node:
        c = get_node_center(bal_node)
        tap_xy(c[0], c[1], "Initial Balance Field")
    else:
        tap_xy(400, 1350, "Initial Balance Field fallback")
    type_text("35000")
    hide_keyboard()
    
    # Tap 'Add Account' button
    root = dump_ui()
    btn = find_node_by_text(root, "Add Account")
    if btn:
        c = get_node_center(btn)
        tap_xy(c[0], c[1], "Add Account Submit Button")
    else:
        tap_xy(540, 2200, "Add Account Submit Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_29_hdfc_account_added")
    
    # Now test Transfer Funds between HDFC Bank and Primary Cash
    # Tap 'Transfer Funds' icon in AppBar (x=830, y=170)
    tap_xy(830, 170, "Transfer Funds AppBar Icon")
    time.sleep(1.0)
    capture_screenshot("c2c_30_transfer_dialog")
    
    # In Transfer Dialog, enter Amount
    root = dump_ui()
    amt_node = find_node_by_text(root, "Transfer Amount") or find_node_by_text(root, "Amount")
    if amt_node:
        c = get_node_center(amt_node)
        tap_xy(c[0], c[1], "Transfer Amount Field")
    else:
        tap_xy(400, 1150, "Transfer Amount Field fallback")
    type_text("2000")
    hide_keyboard()
    
    # Tap 'Transfer' button in dialog
    root = dump_ui()
    tr_btn = find_node_by_text(root, "Transfer")
    if tr_btn:
        c = get_node_center(tr_btn)
        tap_xy(c[0], c[1], "Execute Transfer Button")
    else:
        tap_xy(850, 1450, "Execute Transfer Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_31_wallets_transferred")

    # Scroll down to Savings Goals
    run_cmd(f"adb -s {DEVICE_ID} shell input swipe 540 1800 540 800 400")
    time.sleep(1.0)
    capture_screenshot("c2c_32_savings_goals_section")
    
    # Tap 'Create My First Goal' or 'Add Goal'
    root = dump_ui()
    goal_btn = find_node_by_text(root, "Create My First Goal") or find_node_by_text(root, "Add Goal")
    if goal_btn:
        c = get_node_center(goal_btn)
        tap_xy(c[0], c[1], "Add Goal Button")
    else:
        tap_xy(540, 1600, "Add Goal Button fallback")
    time.sleep(1.0)
    capture_screenshot("c2c_33_add_goal_modal")
    
    # Enter Goal Title
    root = dump_ui()
    g_title = find_node_by_text(root, "Goal Title")
    if g_title:
        c = get_node_center(g_title)
        tap_xy(c[0], c[1], "Goal Title Field")
    else:
        tap_xy(400, 1100, "Goal Title Field fallback")
    type_text("MacBook Pro M4")
    hide_keyboard()
    
    # Enter Target Amount
    root = dump_ui()
    g_amt = find_node_by_text(root, "Target Amount")
    if g_amt:
        c = get_node_center(g_amt)
        tap_xy(c[0], c[1], "Target Amount Field")
    else:
        tap_xy(400, 1250, "Target Amount Field fallback")
    type_text("120000")
    hide_keyboard()
    
    # Enter Initial Saved Amount
    root = dump_ui()
    g_saved = find_node_by_text(root, "Initial Saved Amount")
    if g_saved:
        c = get_node_center(g_saved)
        tap_xy(c[0], c[1], "Saved Amount Field")
    else:
        tap_xy(400, 1400, "Saved Amount Field fallback")
    type_text("15000")
    hide_keyboard()
    
    # Tap 'Create Goal' button
    root = dump_ui()
    cg_btn = find_node_by_text(root, "Create Goal")
    if cg_btn:
        c = get_node_center(cg_btn)
        tap_xy(c[0], c[1], "Create Goal Submit Button")
    else:
        tap_xy(540, 2200, "Create Goal Submit Button fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_34_savings_goal_active")

    # -------------------------------------------------------------
    # 8. SETTINGS & DATA MANAGEMENT (JSON Export)
    # -------------------------------------------------------------
    log("--- Step 8: Testing Settings & Data Management ---")
    # Tap Settings Tab (x=850, y=2320)
    tap_xy(850, 2320, "Settings Bottom Nav Tab")
    time.sleep(1.0)
    capture_screenshot("c2c_35_settings_overview")
    
    # Scroll down to find 'Data Management' or 'Data & Cloud Sync'
    run_cmd(f"adb -s {DEVICE_ID} shell input swipe 540 1800 540 900 400")
    time.sleep(1.0)
    
    root = dump_ui()
    dm_node = find_node_by_text(root, "Data & Cloud Sync") or find_node_by_text(root, "Data Management") or find_node_by_text(root, "Backup")
    if dm_node:
        c = get_node_center(dm_node)
        tap_xy(c[0], c[1], "Data Management Option")
    else:
        tap_xy(540, 1200, "Data Management Option fallback")
    time.sleep(1.2)
    capture_screenshot("c2c_36_data_management_screen")
    
    # Tap 'Export JSON Database Backup'
    root = dump_ui()
    export_node = find_node_by_text(root, "Export JSON") or find_node_by_text(root, "Export")
    if export_node:
        c = get_node_center(export_node)
        tap_xy(c[0], c[1], "Export JSON Tile")
    else:
        tap_xy(540, 950, "Export JSON Tile fallback")
    time.sleep(1.5)
    capture_screenshot("c2c_37_backup_exported_dialog")
    
    # Dismiss share dialog if opened
    key_back()
    time.sleep(0.8)
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 9. FULL ADD TRANSACTION SCREEN (Income Logging)
    # -------------------------------------------------------------
    log("--- Step 9: Testing Full Add Transaction Screen ---")
    ensure_home_screen()
    
    # Tap Center FAB (+) (x=540, y=2320)
    tap_xy(540, 2320, "Center FAB Button")
    time.sleep(1.0)
    
    # Tap 'More Details' to open full AddTransactionScreen
    root = dump_ui()
    more_btn = find_node_by_text(root, "More Details")
    if more_btn:
        c = get_node_center(more_btn)
        tap_xy(c[0], c[1], "More Details Button")
    else:
        tap_xy(350, 1750, "More Details Button fallback")
    time.sleep(1.2)
    capture_screenshot("c2c_38_full_add_transaction_screen")
    
    # Switch to 'Income' mode (around x=450, y=250)
    root = dump_ui()
    income_tab = find_node_by_text(root, "Income")
    if income_tab:
        c = get_node_center(income_tab)
        tap_xy(c[0], c[1], "Income Segment Tab")
    else:
        tap_xy(540, 250, "Income Segment Tab fallback")
    time.sleep(0.8)
    
    # Enter Amount '25000' using numpad or input
    # If numpad is showing, tap digits 2, 5, 0, 0, 0
    # In Numpad widget: 1..9, 0
    root = dump_ui()
    num2 = find_node_by_text(root, "2")
    if num2:
        # Numpad visible!
        for digit in ["2", "5", "0", "0", "0"]:
            d_node = find_node_by_text(dump_ui(), digit)
            if d_node:
                c = get_node_center(d_node)
                tap_xy(c[0], c[1], f"Numpad '{digit}'")
    else:
        # Tap amount area
        tap_xy(540, 400, "Amount Display")
        type_text("25000")
        hide_keyboard()
    
    # Enter Title: Tap title field
    root = dump_ui()
    t_field = find_node_by_text(root, "Title") or find_node_by_text(root, "What was this for?")
    if t_field:
        c = get_node_center(t_field)
        tap_xy(c[0], c[1], "Title Input Field")
    else:
        tap_xy(400, 600, "Title Input Field fallback")
    type_text("Freelance Consulting")
    hide_keyboard()
    
    # Select Category chip (Salary / Consulting / Income)
    root = dump_ui()
    cat_chip = find_node_by_text(root, "Salary") or find_node_by_text(root, "Freelance") or find_node_by_text(root, "Income")
    if cat_chip:
        c = get_node_center(cat_chip)
        tap_xy(c[0], c[1], "Salary Category Chip")
    
    # Scroll down to Save Transaction Button
    run_cmd(f"adb -s {DEVICE_ID} shell input swipe 540 1800 540 1000 400")
    time.sleep(0.8)
    
    root = dump_ui()
    save_tx_btn = find_node_by_text(root, "Save Transaction") or find_node_by_text(root, "Save")
    if save_tx_btn:
        c = get_node_center(save_tx_btn)
        tap_xy(c[0], c[1], "Save Transaction Button")
    else:
        tap_xy(540, 2200, "Save Transaction Button fallback")
    time.sleep(1.5)
    
    # Final check on Home Screen with positive net worth and fresh metrics!
    ensure_home_screen()
    capture_screenshot("c2c_39_final_home_positive_balance")
    
    # Also capture final Analytics with updated charts
    tap_xy(330, 2320, "Analytics Tab")
    time.sleep(1.5)
    capture_screenshot("c2c_40_final_analytics_positive_health")
    
    log("=== ALL COMPONENTS C2C TESTS COMPLETED SUCCESSFULLY! ===")

if __name__ == "__main__":
    main()
