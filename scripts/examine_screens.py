#!/usr/bin/env python3
import os
import sys
import time
import subprocess

def get_default_device():
    if os.environ.get("DEVICE_ID"):
        return os.environ["DEVICE_ID"]
    res = subprocess.run("adb devices", shell=True, capture_output=True, text=True)
    devs = [line.split()[0] for line in res.stdout.strip().split("\n")[1:] if "\tdevice" in line]
    return devs[0] if devs else "dc96724c1e0d"

DEVICE_ID = get_default_device()
ARTIFACT_DIR = os.environ.get("ARTIFACT_DIR", os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "test_screenshots"))
os.makedirs(ARTIFACT_DIR, exist_ok=True)


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.stdout.strip()

def tap(x, y, desc=""):
    if desc:
        log(f"Tap {desc} @ ({x}, {y})")
    run_cmd(f"adb -s {DEVICE_ID} shell input tap {x} {y}")
    time.sleep(1.2)

def key_back():
    log("Press BACK")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_BACK")
    time.sleep(1.0)

def hide_keyboard():
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent 111")
    time.sleep(0.5)

def capture(name):
    sdpath = f"/sdcard/screen_{name}.png"
    localpath = os.path.join(ARTIFACT_DIR, f"{name}.png")
    run_cmd(f"adb -s {DEVICE_ID} shell screencap -p {sdpath}")
    run_cmd(f"adb -s {DEVICE_ID} pull {sdpath} {localpath}")
    log(f"Captured: {localpath}")
    return localpath

def launch_pocket():
    log("Launching Pocket MainActivity...")
    run_cmd(f"adb -s {DEVICE_ID} shell am start -n com.pocket.pocket/.MainActivity")
    time.sleep(2.0)

def main():
    log("=== SCREEN EXAMINATION SUITE FOR POCKET ===")
    run_cmd(f"adb -s {DEVICE_ID} shell input keyevent KEYCODE_WAKEUP")
    launch_pocket()

    # 1. Home Screen (Dashboard)
    log("--- Screen 1: Home Dashboard ---")
    tap(150, 2320, "Home Tab")
    time.sleep(0.8)
    capture("01_home_screen")

    # 2. Analytics Screen
    log("--- Screen 2: Analytics ---")
    tap(330, 2320, "Analytics Tab")
    time.sleep(1.5)
    capture("02_analytics_screen")

    # 3. Wallets Screen
    log("--- Screen 3: Wallets & Accounts ---")
    tap(660, 2320, "Wallets Tab")
    time.sleep(1.5)
    capture("03_wallets_screen")

    # 4. Settings Screen
    log("--- Screen 4: Settings ---")
    tap(880, 2320, "Settings Tab")
    time.sleep(1.5)
    capture("04_settings_screen")

    # From Settings: Data Management
    log("--- Screen 5: Data Management (from Settings) ---")
    # In settings, find Data Management
    # Let's see where Data Management is located on Settings screen, or scroll if needed
    # Usually around y=1200 or y=1400. Let's capture settings first or tap
    # Let's go back to Home first to explore top bar and cards
    tap(150, 2320, "Home Tab")
    time.sleep(1.0)

    # 5. Quick Add Modal / Dialog (center FAB)
    log("--- Screen 5: Quick Add / Transaction Modal ---")
    tap(500, 2320, "Center FAB (+)")
    time.sleep(1.5)
    capture("05_quick_add_modal")
    # Close modal or go back
    key_back()

    # 6. Recurring Dues Screen
    log("--- Screen 6: Recurring Dues ---")
    tap(270, 450, "Recurring Dues Card")
    time.sleep(1.5)
    capture("06_recurring_dues_screen")
    # Tap Add Recurring Rule icon at top right
    tap(950, 80, "Add Recurring Rule Icon")
    time.sleep(1.2)
    capture("06b_add_recurring_sheet")
    key_back()
    time.sleep(0.6)
    key_back() # Back to Home
    time.sleep(0.8)

    # 7. Savings Goals Screen
    log("--- Screen 7: Savings Goals ---")
    tap(730, 450, "Savings Goals Card")
    time.sleep(1.5)
    capture("07_savings_goals_screen")
    key_back()
    time.sleep(0.8)

    # 8. Transactions List Screen
    log("--- Screen 8: Transactions List ---")
    tap(860, 510, "See All Transactions")
    time.sleep(1.5)
    capture("08_transactions_list_screen")
    
    # 9. Transaction Detail Screen
    log("--- Screen 9: Transaction Detail ---")
    tap(500, 400, "First Transaction Item")
    time.sleep(1.5)
    capture("09_transaction_detail_screen")
    key_back()
    time.sleep(0.8)
    key_back() # Back to Home
    time.sleep(0.8)

    # 10. Notification Center Screen
    log("--- Screen 10: Notification Center ---")
    tap(920, 75, "Notification Bell")
    time.sleep(1.5)
    capture("10_notification_center_screen")
    key_back()
    time.sleep(0.8)

    # 11. Auto-Import Studio Screen
    log("--- Screen 11: Auto-Import Studio ---")
    tap(800, 75, "Auto-Import Studio Wand")
    time.sleep(1.5)
    capture("11_auto_import_studio_screen")
    key_back()
    time.sleep(0.8)

    # 12. Profile / Avatar Modal
    log("--- Screen 12: Profile / Avatar Settings ---")
    tap(90, 75, "User Avatar")
    time.sleep(1.5)
    capture("12_avatar_modal")
    key_back()
    time.sleep(0.8)

    # 13. Settings Sub-screens: Go to Settings Tab
    log("--- Screen 13: Settings Navigation to Sub-screens ---")
    tap(880, 2320, "Settings Tab")
    time.sleep(1.2)
    
    # In Settings, let's look for Widgets Customizer, Data Management, Debts & Loans
    # Let's inspect where items are or scroll down
    run_cmd(f"adb -s {DEVICE_ID} shell input swipe 540 1800 540 800 300")
    time.sleep(1.0)
    capture("13_settings_scrolled")

    log("=== SCRIPT FINISHED ===")

if __name__ == "__main__":
    main()
