import subprocess
import time
import sys
import threading

def run_e2e_test():
    print("[E2E] Granting SMS permissions via ADB...")
    subprocess.run(["adb", "shell", "pm", "grant", "com.pocket.pocket", "android.permission.RECEIVE_SMS"], check=False)
    subprocess.run(["adb", "shell", "pm", "grant", "com.pocket.pocket", "android.permission.READ_SMS"], check=False)

    print("[E2E] Starting Flutter integration test on Android...")
    process = subprocess.Popen(
        ["flutter", "test", "integration_test/sms_auto_import_test.dart", "-d", "dc96724c1e0d"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    def inject_sms():
        # Wait for the app to compile, deploy and reach the pumpAndSettle stage
        # 35 seconds is usually enough for flutter test to build and launch on device
        time.sleep(35)
        print("\n[E2E] ===> INJECTING SIMULATED SMS VIA ADB <===")
        subprocess.run([
            "adb", "shell", "am", "broadcast", 
            "-a", "com.pocket.pocket.TEST_SMS", 
            "--es", "sender", "TESTBANK", 
            "--es", "body", "Spent $50.00 at Starbucks on your credit card."
        ])

    injector_thread = threading.Thread(target=inject_sms)
    injector_thread.start()

    # Stream output
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()

    process.wait()
    injector_thread.join()
    
    if process.returncode == 0:
        print("[E2E] Integration Test completed SUCCESSFULLY!")
    else:
        print(f"[E2E] Integration Test FAILED with code {process.returncode}")
        sys.exit(process.returncode)

if __name__ == "__main__":
    run_e2e_test()
