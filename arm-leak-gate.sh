#!/usr/bin/env bash
# arm-leak-gate.sh — arm 06_SYSTEM's leak gate in this checkout, strict.
#
#   ./arm-leak-gate.sh            # write both hooks and the git config; idempotent
#   ./arm-leak-gate.sh --check    # say whether the gate is armed
#
# WHY. This repository is PUBLIC, and agents commit and push to it. Protection
# against a leaked key or a private name rests on automatic checks, not on an
# agent following prose (ruled by the user, 2026-11-01). The gate is
# ~/06_SYSTEM/engine/checks/leak_gate.py: the built-in credential shapes plus
# the private register of names that must not travel. Neither is copied here,
# because the register is the very thing that must stay private.
#
# ONE HOOK, ON PUSH ONLY (ruled by the user, 2026-11-24). pre-push, written by
# `leak_gate.py --arm`, scans the blobs a push sends. There is no pre-commit
# gate: a commit may hold a name that must not travel (a local-only settings
# edit), and only the push, the moment it becomes public, is refused. A
# pre-commit hook this script wrote earlier is removed. It is STRICT
# (`pazras.leak-gate strict`): a hit refuses. The way past is deliberate:
# `git -c pazras.leak-gate=warn push`, or `--no-verify`.
# `pazras.visibility public` pins the answer, so no network call is made.
#
# What is already public is declared, file by file and pattern by pattern, in
# .pazras/leak-allow.txt, so an edit of such a file is not refused for what it
# already published. A declaration covers (path, pattern), not a count: a new
# hit of the same pattern in the same file passes. Remove a row to re-arm it.
#
# Hooks and git config are not tracked, so bootstrap.sh runs this on every
# install. Without 06_SYSTEM there is no gate, and this says so and exits 0.

set -euo pipefail
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE="${PAZRAS_LEAK_GATE:-$HOME/06_SYSTEM/engine/checks/leak_gate.py}"
MARK="written by dotfiles/arm-leak-gate.sh"

if [[ ! -f "$GATE" ]]; then
    echo "  ! $GATE not found — the leak gate is NOT armed (is 06_SYSTEM checked out?)"
    exit 0
fi
if [[ "${1:-}" == "--check" ]]; then
    exec python3 "$GATE" --check --tree "$DOTFILES"
fi

hooks="$(git -C "$DOTFILES" rev-parse --path-format=absolute --git-path hooks)"
mkdir -p "$hooks"
# Never overwrite a hook someone else wrote.
for h in pre-push; do
    if [[ -e "$hooks/$h" ]] && ! grep -q "leak_gate.py" "$hooks/$h"; then
        echo "  ✗ $hooks/$h exists and is not the leak gate; leaving it, NOT armed"
        exit 1
    fi
done

python3 "$GATE" --arm --tree "$DOTFILES" >/dev/null

# Retire the pre-commit hook this script used to write; leave any other.
if [[ -e "$hooks/pre-commit" ]] && grep -q "$MARK" "$hooks/pre-commit"; then
    rm -f "$hooks/pre-commit"
fi

git -C "$DOTFILES" config pazras.leak-gate strict
git -C "$DOTFILES" config pazras.visibility public
echo "  ✓ leak gate armed, strict, on push only: $hooks/pre-push"
