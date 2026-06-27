#!/usr/bin/env bash
# ============================================================================
# Turkey Mode - ADB Unlock Script
# ============================================================================
# Companion script to unlock Turkey Mode from a PC via ADB.
#
# Usage:
#   ./scripts/adb_unlock.sh <passphrase>
#
# Example:
#   ./scripts/adb_unlock.sh "my_secret_passphrase"
#
# The passphrase must match the one set in the Mindful app's Turkey Mode
# settings (PC Unlock Passphrase). SHA-256 validation happens on the device.
# ============================================================================

set -euo pipefail

PACKAGE="com.mindful.android"
RECEIVER="${PACKAGE}.receivers.AdbUnlockReceiver"
ACTION="com.mindful.android.action.UNLOCK_TURKEY_MODE"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <passphrase>"
    echo ""
    echo "Passphrase must match the one set in Mindful > Turkey Mode > PC Unlock Passphrase"
    exit 1
fi

PASSPHRASE="$1"

echo "Sending ADB unlock command to Turkey Mode..."
adb shell am broadcast \
    -a "$ACTION" \
    --es token "$PASSPHRASE" \
    -n "$RECEIVER"

echo ""
echo "Done. Check the device for unlock confirmation."
