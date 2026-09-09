#!/bin/bash
# Periodically commits and pushes changes in ~/dotfiles.
# Invoked by launchd (see ../launchd/com.user.dotfiles-sync.plist).

set -euo pipefail

REPO_DIR="$HOME/dotfiles"
cd "$REPO_DIR"

# Pull first so commits don't fail with non-fast-forward when another machine pushed.
# --autostash protects any uncommitted local edits during the rebase.
git pull --rebase --autostash origin main 2>&1 || true

# Commit only when there's something to commit. Note this is no longer an early
# exit: even with a clean tree we still fall through to the push check below.
if [ -n "$(git status --porcelain)" ]; then
    git add -A

    DIFF=$(git diff --staged)
    MSG=$(echo "$DIFF" | ollama run dotfiles-commit --nowordwrap 2>/dev/null | tr '\n' ' ' | xargs || true)

    if [ -z "$MSG" ]; then
        MSG="auto-sync: $(date '+%Y-%m-%d %H:%M:%S %Z') on $(hostname -s)"
    fi

    # -c commit.gpgsign=false bypasses Yubikey GPG signing — auto-commits run
    # in the background and can't touch the Yubikey.
    git -c commit.gpgsign=false commit -m "$MSG"
fi

# Push whenever the branch is ahead of its upstream, not just when we committed
# above. A commit whose push failed (expired credential, no network) used to be
# stranded forever: the next run saw a clean tree, exited early, and never
# retried — so the other machines silently never received it.
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    # No upstream yet (fresh clone) — set it while pushing.
    git push -u origin main
elif [ -n "$(git rev-list '@{u}..HEAD')" ]; then
    git push
fi
