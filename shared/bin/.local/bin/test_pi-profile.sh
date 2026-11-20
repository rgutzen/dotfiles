#!/usr/bin/env bash
# pi-profile binds a profile to its own login, ~/.claude-<profile>, the path
# 06_SYSTEM's profiles.yaml declares; an Omarchy account of the same name is
# ignored (2026-11-20: two logins of one account drifted apart).
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
ln -s "$dir/pi-profile" "$tmp/pi-example"
got=$("$tmp/pi-example" status 2>/dev/null | awk '/^claude home/ {print $3}')
if [[ "$got" == "$HOME/.claude-example" ]]; then
    echo "PASS: pi-example uses $got"
else
    echo "FAIL: pi-example uses '${got}', expected $HOME/.claude-example"; exit 1
fi
if grep -q "omarchy agent account" "$dir/pi-profile"; then
    echo "FAIL: pi-profile still consults Omarchy accounts"; exit 1
fi
echo "PASS: no Omarchy account lookup"
