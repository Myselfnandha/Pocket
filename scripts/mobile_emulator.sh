#!/usr/bin/env bash
export SCRCPY_SERVER_PATH="${SCRCPY_SERVER_PATH:-/home/nandha/.local/share/scrcpy/scrcpy-server}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/home/nandha/Android/Sdk}"
export ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-/home/nandha/.config/.android/avd}"
export PATH="$HOME/.local/bin:$HOME/Android/Sdk/emulator:$HOME/Android/Sdk/platform-tools:$PATH"

# Parse arguments
MODE="auto"
EXTRA_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --avd|--virtual)
            MODE="avd"
            ;;
        --mirror|--device|--live)
            MODE="mirror"
            ;;
        *)
            EXTRA_ARGS+=("$arg")
            ;;
    esac
done

launch_avd() {
    AVD_NAME="${1:-Pocket_Emulator}"
    echo "======================================================="
    echo " Starting Android Virtual Device: $AVD_NAME"
    echo " KVM Acceleration: Active"
    echo "======================================================="
    exec /home/nandha/Android/Sdk/emulator/emulator -avd "$AVD_NAME" -gpu host -netdelay none -netspeed full "${EXTRA_ARGS[@]}"
}

launch_mirror() {
    DEVICE="$1"
    echo "======================================================="
    echo " Launching Live Device Screen Mirror for: $DEVICE"
    echo " Keyboard, Mouse, and High-Speed Touch Controls Active"
    echo "======================================================="
    exec scrcpy -s "$DEVICE" --window-title "Pocket Mobile Device ($DEVICE)" --always-on-top "${EXTRA_ARGS[@]}"
}

DEVICES=$(adb devices | grep -w "device" | awk '{print $1}')
FIRST_DEV=$(echo "$DEVICES" | head -n 1)

if [ "$MODE" = "avd" ]; then
    launch_avd "Pocket_Emulator"
elif [ "$MODE" = "mirror" ]; then
    if [ -n "$FIRST_DEV" ]; then
        launch_mirror "$FIRST_DEV"
    else
        echo "Error: No live USB/Wi-Fi Android device connected via ADB."
        exit 1
    fi
else
    # Auto mode:
    if [ -n "$FIRST_DEV" ]; then
        launch_mirror "$FIRST_DEV"
    else
        launch_avd "Pocket_Emulator"
    fi
fi

