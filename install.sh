#!/bin/bash
#
# Installs the dotfiles auto-sync launchd agent.
#
# ============================================================================
# WHAT TO DO ON A NEW MACHINE
# ============================================================================
#
# Quick path:
#   cd ~/dotfiles && ./bootstrap.sh
#
#
# 1. Clone this repo to ~/dotfiles:
#      git clone https://github.com/eshaan-mehta/dotfiles ~/dotfiles
#
# 2. Symlink the dotfiles you want active. THIS SCRIPT DOES NOT DO THIS.
#    Example:
#      ln -s ~/dotfiles/.gitconfig ~/.gitconfig
#      ln -s ~/dotfiles/.zshrc    ~/.zshrc
#      # ...etc for each file you want live
#
# 3. Make sure `git push` works WITHOUT prompting. Auto-sync runs in the
#    background and cannot type a password or touch a Yubikey.
#      - HTTPS (recommended for auto-sync, since SSH/Yubikey can fail):
#          git -C ~/dotfiles remote set-url origin https://github.com/eshaan-mehta/dotfiles.git
#          git config --global credential.helper osxkeychain
#          # Do one manual `git push` to cache the GitHub token in Keychain.
#      - GPG signing is bypassed inside auto-sync.sh via -c commit.gpgsign=false,
#        so the Yubikey is not needed for commits made by the agent.
#
# 4. Run this script:
#      cd ~/dotfiles && ./install.sh
#
# 5. Verify the agent is loaded:
#      launchctl list | grep dotfiles-sync
#
# 6. Tail the log to confirm it's running cleanly:
#      tail -f ~/dotfiles/.auto-sync.log
#
# ============================================================================
# TO UNINSTALL
# ============================================================================
#
#   launchctl unload ~/Library/LaunchAgents/com.user.dotfiles-sync.plist
#   rm ~/Library/LaunchAgents/com.user.dotfiles-sync.plist
#
# ============================================================================

set -euo pipefail

REPO_DIR="$HOME/dotfiles"
PLIST_NAME="com.user.dotfiles-sync.plist"
PLIST_SRC="$REPO_DIR/launchd/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

if [ ! -f "$PLIST_SRC" ]; then
    echo "Error: $PLIST_SRC not found. Are you running this from inside ~/dotfiles?" >&2
    exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents"

# Render the plist by substituting __HOME__ with the real $HOME.
sed "s|__HOME__|$HOME|g" "$PLIST_SRC" > "$PLIST_DEST"

chmod +x "$REPO_DIR/bin/auto-sync.sh"

# Unload first so re-running install.sh is idempotent.
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"

echo "Installed: $PLIST_DEST"
echo "Logs:      $REPO_DIR/.auto-sync.log"
echo "Verify:    launchctl list | grep dotfiles-sync"
