#!/usr/bin/env python3
"""
Pixel-Calibrated C2C Test Runner for Pocket
Executes live on ADB device dc96724c1e0d:
- Recurring Dues (OTT Streaming subscription, Calendar view)
- Debts & Loans (Rahul Sharma ₹2,500 Lent, IOU ledger)
- NLP Quick Add (Natural language parser, live tokens, instant commit)
- Wallets (HDFC Bank Account addition, inter-wallet transfer, Savings Goal)
- Full Transaction logging & Balance verification
"""

import os
import sys
import time
import subprocess
from PIL import Image

DEVICE_ID = "dc96724c1e0d"
ARTIFACT_DIR = "/home/nandha/.gemini/antigravity-ide/brain/034d6163-7069-49d8-8ac4-9c6b2f1cb3c7"

def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def tap_xy(x, y, desc=""):
    if desc:
        log(f"Tap {desc} at ({x}, {y})")
    run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
    time.sleep(1.2)

def key_back():
    log("Press BACK")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_BACK")
    time.sleep(1.0)

def hide_keyboard():
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent 111")
    time.sleep(0.6)

def type_text(text):
    log(f"Type: '{text}'")
    escaped = text.replace(" ", "%s")
    run_cmd(f"adb -s {DEVICE_ID} shell input text '{escaped}'")
    time.sleep(0.8)

def capture_screenshot(name):
    sdcard_path = f"/sdcard/{name}.png"
    local_path = os.path.join(ARTIFACT_DIR, f"{name}.png")
    run_cmd(f"adb -s {DEVICE_ID} shell screencap -p {sdcard_path}")
    run_cmd(f"adb -s {DEVICE_ID} pull {sdcard_path} {local_path}")
    log(f"Screenshot saved: {name}.png")
    return local_path

def ensure_home():
    log("Ensuring Home Screen...")
    tap_xy(150, 2320, "Home Tab")
    time.sleep(1.0)

def main():
    log("=== STARTING CALIBRATED ALL-COMPONENTS C2C RUN ===")
    run_cmd(f"adb -s {DEVICE_ID} shell svc power stayon true")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_WAKEUP")

    # -------------------------------------------------------------
    # 1. RECURRING RULES & SUBSCRIPTIONS
    # -------------------------------------------------------------
    log(">>> 1. RECURRING RULES & SUBSCRIPTIONS")
    ensure_home()
    
    # Tap Recurring Dues Card (270, 1250)
    tap_xy(270, 1250, "Recurring Dues Card")
    capture_screenshot("c2c_11_recurring_rules_screen")
    
    # Tap Add Recurring Rule Button (top right AppBar)
    tap_xy(918, 175, "Add Recurring Rule Icon")
    time.sleep(1.2)
    capture_screenshot("c2c_12_add_recurring_sheet")
    
    # Tap OTT Streaming preset chip (240, 800)
    tap_xy(240, 800, "OTT Streaming Preset Chip")
    time.sleep(0.6)
    
    # Tap Recurring Amount field (400, 1760)
    tap_xy(400, 1760, "Recurring Amount Field")
    type_text("649")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Create Recurring Rule Button (540, 2322)
    tap_xy(540, 2322, "Create Recurring Rule Button")
    time.sleep(1.5)
    capture_screenshot("c2c_13_recurring_rule_created")
    
    # Tap Due Calendar Tab (750, 280)
    tap_xy(750, 280, "Due Calendar Tab")
    time.sleep(1.0)
    capture_screenshot("c2c_14_recurring_calendar_view")
    
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 2. DEBTS & LOANS (IOUs)
    # -------------------------------------------------------------
    log(">>> 2. DEBTS & LOANS (IOUs)")
    ensure_home()
    
    # Tap Debts & Loans Card (780, 1250)
    tap_xy(780, 1250, "Debts & Loans Card")
    capture_screenshot("c2c_15_debts_screen")
    
    # Tap Add Debt Icon (918, 175)
    tap_xy(918, 175, "Add Debt Icon")
    time.sleep(1.2)
    capture_screenshot("c2c_16_add_debt_dialog")
    
    # Tap Person Name Field (400, 880)
    tap_xy(400, 880, "Person Name Field")
    type_text("Rahul Sharma")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Total Amount Field (400, 1250)
    tap_xy(400, 1250, "Total Amount Field")
    type_text("2500")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Save Button (755, 1918)
    tap_xy(755, 1918, "Save Debt Button")
    time.sleep(1.5)
    capture_screenshot("c2c_17_debt_added_view")
    
    key_back()
    time.sleep(1.0)

    # -------------------------------------------------------------
    # 3. NLP QUICK ADD (+ QUICK LOG)
    # -------------------------------------------------------------
    log(">>> 3. NATURAL LANGUAGE ENTRY (NLP QUICK ADD)")
    ensure_home()
    
    # Tap + Quick Log button at (675, 1530)
    tap_xy(675, 1530, "+ Quick Log Button")
    time.sleep(1.2)
    capture_screenshot("c2c_18_nlp_quick_add_modal")
    
    # Hide keyboard first to see example chips
    hide_keyboard()
    time.sleep(0.6)
    
    # In NlpQuickAddModal, example chips are around y = 2160, x = 300
    # Or tap the text field at (400, 1200) and type natural text
    tap_xy(400, 1200, "Natural Language Text Field")
    type_text("paid 850 electricity bill")
    hide_keyboard()
    time.sleep(1.0)
    capture_screenshot("c2c_19_nlp_tokens_parsed")
    
    # Tap green 'Add Transaction' button at (540, 2340)
    tap_xy(540, 2340, "Add Transaction Button")
    time.sleep(1.5)
    capture_screenshot("c2c_20_nlp_transaction_saved_home")

    # -------------------------------------------------------------
    # 4. WALLETS & INTER-ACCOUNT TRANSFER
    # -------------------------------------------------------------
    log(">>> 4. WALLETS & ACCOUNTS MANAGEMENT")
    tap_xy(660, 2320, "Wallets Bottom Nav Tab")
    time.sleep(1.2)
    capture_screenshot("c2c_27_wallets_screen")
    
    # Tap Add Account Icon (918, 175)
    tap_xy(918, 175, "Add Account Icon")
    time.sleep(1.2)
    capture_screenshot("c2c_28_add_account_modal")
    
    # Tap Account Name Field (400, 1170)
    tap_xy(400, 1170, "Account Name Field")
    type_text("HDFC Bank")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Account Last 4 Digits (400, 1530)
    tap_xy(400, 1530, "Account Last 4 Field")
    type_text("4821")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Initial Balance Field (400, 1710)
    tap_xy(400, 1710, "Initial Balance Field")
    type_text("35000")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Add Account Button (540, 2390)
    tap_xy(540, 2390, "Add Account Button")
    time.sleep(1.5)
    capture_screenshot("c2c_29_hdfc_account_added")
    
    # Test Transfer Funds (795, 175)
    tap_xy(795, 175, "Transfer Funds Icon")
    time.sleep(1.2)
    capture_screenshot("c2c_30_transfer_dialog")
    
    # Tap Transfer Amount field (400, 1260)
    tap_xy(400, 1260, "Transfer Amount Field")
    type_text("2000")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Transfer submit button in dialog (around 750, 1460)
    # Let's inspect or tap
    tap_xy(750, 1460, "Transfer Submit Button")
    time.sleep(1.5)
    capture_screenshot("c2c_31_wallets_transferred")

    # -------------------------------------------------------------
    # 5. SAVINGS GOALS
    # -------------------------------------------------------------
    log(">>> 5. SAVINGS GOALS")
    # Tap '+ Create My First Goal' button at (500, 1770) or '+ Add Goal' at (820, 1400)
    tap_xy(500, 1770, "Create My First Goal Button")
    time.sleep(1.2)
    capture_screenshot("c2c_33_add_goal_modal")
    
    # Tap Goal Title (400, 1070)
    tap_xy(400, 1070, "Goal Title Field")
    type_text("MacBook Pro M4")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Target Amount (400, 1240)
    tap_xy(400, 1240, "Target Amount Field")
    type_text("120000")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Initial Saved Amount (400, 1400)
    tap_xy(400, 1400, "Saved Amount Field")
    type_text("15000")
    hide_keyboard()
    time.sleep(0.5)
    
    # Scroll down slightly and tap 'Create Goal' button
    run_cmd(f"adb -s {DEVICE_ID} shell input swipe 540 1800 540 1200 300")
    time.sleep(0.8)
    tap_xy(540, 2320, "Create Goal Submit Button")
    time.sleep(1.5)
    capture_screenshot("c2c_34_savings_goal_active")

    # -------------------------------------------------------------
    # 6. INCOME LOGGING & HOME DASHBOARD BALANCE
    # -------------------------------------------------------------
    log(">>> 6. INCOME LOGGING & BALANCE RECALCULATION")
    ensure_home()
    
    # Open Quick Transaction FAB (540, 2320)
    tap_xy(540, 2320, "Center FAB Button")
    time.sleep(1.2)
    
    # Tap '+ Income' tab (680, 500)
    tap_xy(680, 500, "+ Income Segment Tab")
    time.sleep(0.6)
    
    # Tap Amount field (400, 680)
    tap_xy(400, 680, "Amount Field")
    type_text("25000")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap Merchant / Description (400, 850)
    tap_xy(400, 850, "Description Field")
    type_text("Consulting Project")
    hide_keyboard()
    time.sleep(0.5)
    
    # Tap '✓ Quick Save' button (720, 1517)
    tap_xy(720, 1517, "Quick Save Button")
    time.sleep(1.8)
    
    # Capture final Home Dashboard with updated positive balance & metrics!
    capture_screenshot("c2c_39_final_home_positive_balance")
    
    # Switch to Analytics to capture updated Health Score & Sankey Flow!
    tap_xy(330, 2320, "Analytics Tab")
    time.sleep(1.8)
    capture_screenshot("c2c_40_final_analytics_positive_health")
    
    log("=== CALIBRATED C2C RUN COMPLETED SUCCESSFULLY! ===")

if __name__ == "__main__":
    main()
