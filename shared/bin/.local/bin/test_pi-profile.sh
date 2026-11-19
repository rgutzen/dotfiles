#!/usr/bin/env bash
# Regression test for pi-profile Defect 1: jq parse error
# This test verifies that the fix (adding --json flag) is present in the script
set -euo pipefail

echo "Running pi-profile regression test..."
echo ""

PI_PROFILE_SCRIPT="${HOME}/02_AREAS/B_Tech/dotfiles/shared/bin/.local/bin/pi-profile"

# Test: Verify the script uses --json flag with omarchy agent account list
if grep -q "omarchy agent account list --json" "$PI_PROFILE_SCRIPT"; then
    echo "PASS: pi-profile uses --json flag with omarchy agent account list"
    echo ""
    echo "This fixes the 'jq: parse error: Invalid numeric literal at line 1, column 7' error."
    echo "The error occurred because omarchy agent account list outputs plain text by default,"
    echo "and jq cannot parse plain text as JSON. The --json flag ensures JSON output."
else
    echo "FAIL: pi-profile does not use --json flag with omarchy agent account list"
    exit 1
fi

echo ""
echo "Test passed!"
