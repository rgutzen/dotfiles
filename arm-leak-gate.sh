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
# TWO HOOKS, ONE SCAN.
#   pre-push    written by `leak_gate.py --arm`: scans the blobs the push sends.
#   pre-commit  written below: the index the commit will write (git's own
#               GIT_INDEX_FILE, so `commit -a` and `commit <paths>` are right)
#               becomes a throwaway commit on HEAD, and the same push scan reads
#               that delta. The object is dangling and gc removes it.
# Both are STRICT (`pazras.leak-gate strict`): a hit refuses. The way past is
# deliberate: `git -c pazras.leak-gate=warn commit|push`, or `--no-verify`.
# `pazras.visibility public` pins the answer, so a commit makes no network call.
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
for h in pre-push pre-commit; do
    if [[ -e "$hooks/$h" ]] && ! grep -q "leak_gate.py" "$hooks/$h"; then
        echo "  ✗ $hooks/$h exists and is not the leak gate; leaving it, NOT armed"
        exit 1
    fi
done

python3 "$GATE" --arm --tree "$DOTFILES" >/dev/null

cat > "$hooks/pre-commit" <<EOF
#!/usr/bin/env bash
# $MARK -- calls $GATE; regenerate, do not edit.
set -euo pipefail
tree="\$(git write-tree)"
if head="\$(git rev-parse -q --verify HEAD)"; then parent=(-p "\$head"); else head=0000000000000000000000000000000000000000; parent=(); fi
commit="\$(GIT_AUTHOR_NAME=leak-gate GIT_AUTHOR_EMAIL=leak-gate@localhost \\
    GIT_COMMITTER_NAME=leak-gate GIT_COMMITTER_EMAIL=leak-gate@localhost \\
    git commit-tree "\$tree" "\${parent[@]}" -m "leak-gate pre-commit scan")"
REPO_TREE="\$(env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_PREFIX \\
    -u GIT_COMMON_DIR git rev-parse --show-toplevel)"
url="\$(git remote get-url origin 2>/dev/null || true)"
if ! printf 'refs/heads/commit %s refs/heads/commit %s\n' "\$commit" "\$head" |
        python3 $GATE --tree "\$REPO_TREE" --url "\$url" --quiet; then
    echo "leak-gate: the COMMIT is refused (the message above says push: the same rule)." >&2
    exit 1
fi
EOF
chmod 0755 "$hooks/pre-commit"

git -C "$DOTFILES" config pazras.leak-gate strict
git -C "$DOTFILES" config pazras.visibility public
echo "  ✓ leak gate armed, strict: $hooks/pre-commit, $hooks/pre-push"
