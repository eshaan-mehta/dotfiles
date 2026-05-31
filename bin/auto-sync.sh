#!/bin/bash
# Periodically commits and pushes changes in ~/dotfiles.
# Invoked by launchd (see ../launchd/com.user.dotfiles-sync.plist).

set -euo pipefail

REPO_DIR="$HOME/dotfiles"
cd "$REPO_DIR"

# Pull first so commits don't fail with non-fast-forward when another machine pushed.
# --autostash protects any uncommitted local edits during the rebase.
git pull --rebase --autostash origin main 2>&1 || true

# Exit quietly if nothing changed.
if [ -z "$(git status --porcelain)" ]; then
    exit 0
fi

git add -A

DIFF=$(git diff --staged)
MSG=$(echo "$DIFF" | ollama run tavernari/git-commit-message:sp_commit_mini --nowordwrap 2>/dev/null | tr '\n' ' ' | xargs || true)

if [ -z "$MSG" ]; then
    MSG="auto-sync: $(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname -s)"
fi

# -c commit.gpgsign=false bypasses Yubikey GPG signing — auto-commits run
# in the background and can't touch the Yubikey.
git -c commit.gpgsign=false commit -m "$MSG"

git push origin main
