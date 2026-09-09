#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for this dotfiles repo.
# - Symlinks selected files into $HOME
# - Links LazyVim: ~/.config/nvim -> ~/dotfiles/config/nvim
# - Sets up a repo-scoped SSH deploy key so auto-sync can push unattended
# - Optionally installs Claude Code, the auto-sync agent, and its Ollama model
#
# Safe to rerun — symlinks are idempotent, optional installs only prompt when not yet installed.
#
# COMMON USAGE:
#   ./bootstrap.sh                 Standard setup, prompts for optional installs
#   ./bootstrap.sh --no-git        Skip gitconfig link (keep machine's existing git identity)
#   ./bootstrap.sh --no-ssh        Skip the deploy key / ssh config / remote setup
#
# MACHINE-SPECIFIC OVERRIDES (create these manually after bootstrap — not tracked in dotfiles):
#   ~/.gitconfig.local             Per-machine git overrides. Optional: the tracked .gitconfig
#                                  already sets a default identity, and this file is included
#                                  last so anything here wins. Use it to route a different
#                                  identity at a directory, e.g.
#                                    [includeIf "gitdir:~/some/dir/"]
#                                      path = ~/.gitconfig.other
#   ~/.zshrc.local                 Shell config specific to this machine (work tools, aliases, etc.)

REPO_DIR="$HOME/dotfiles"

usage() {
  cat <<USAGE
Usage:
  ./bootstrap.sh [--no-nvim] [--no-shell] [--no-git] [--no-ssh]

Flags:
  --no-nvim   Skip linking LazyVim config
  --no-shell  Skip linking shell dotfiles (.zshrc/.zshenv/.bash*)
  --no-git    Skip linking gitconfig
  --no-ssh    Skip deploy key generation, ssh config link, and remote setup
USAGE
}

DO_NVIM=1
DO_SHELL=1
DO_GIT=1
DO_SSH=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-nvim)  DO_NVIM=0 ;;
    --no-shell) DO_SHELL=0 ;;
    --no-git)   DO_GIT=0 ;;
    --no-ssh)   DO_SSH=0 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Error: expected repo at $REPO_DIR" >&2
  echo "Clone first: git clone https://github.com/eshaan-mehta/dotfiles.git $REPO_DIR" >&2
  exit 1
fi

cd "$REPO_DIR"

if command -v brew &>/dev/null; then
    brew bundle --file="$REPO_DIR/Brewfile"
else
    echo "Warning: homebrew not found, skipping Brewfile install" >&2
fi

# --- Optional installs (prompt only when not already present) ---

if ! command -v claude &>/dev/null; then
    read -r -p "Install Claude Code? [y/N] " _reply
    if [[ "$_reply" =~ ^[Yy]$ ]]; then
        curl -fsSL https://claude.ai/install.sh | bash
    fi
fi

if command -v ollama &>/dev/null && ! ollama list 2>/dev/null | grep -q "dotfiles-commit"; then
    read -r -p "Install dotfiles-commit Ollama model (used by auto-sync for commit messages)? [y/N] " _reply
    if [[ "$_reply" =~ ^[Yy]$ ]]; then
        ollama create dotfiles-commit -f "$REPO_DIR/config/ollama/Modelfile"
    fi
fi

if [ ! -f "$HOME/Library/LaunchAgents/com.user.dotfiles-sync.plist" ]; then
    read -r -p "Install auto-sync agent (watches ~/dotfiles, auto-commits+pushes changes)? [y/N] " _reply
    if [[ "$_reply" =~ ^[Yy]$ ]]; then
        bash "$REPO_DIR/install.sh"
    fi
fi

# --- Symlinks ---

backup_dir="$HOME/.dotfiles-backup-$(date +%F-%H%M%S)"
mkdir -p "$backup_dir"
echo "Backup dir: $backup_dir"

backup_if_needed() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    mv "$target" "$backup_dir/"
  fi
}

link_file() {
  local src="$1"
  local dest="$2"
  backup_if_needed "$dest"
  ln -sfn "$src" "$dest"
}

if [ "$DO_SHELL" -eq 1 ]; then
  for f in .zshrc .zshenv .bash_profile .bashrc; do
    if [ -e "$REPO_DIR/$f" ]; then
      link_file "$REPO_DIR/$f" "$HOME/$f"
    fi
  done
fi

if [ "$DO_GIT" -eq 1 ]; then
  if [ -e "$REPO_DIR/.gitconfig" ]; then
    link_file "$REPO_DIR/.gitconfig" "$HOME/.gitconfig"
  fi

  # Stub for per-machine git overrides. The tracked .gitconfig includes this
  # last, so anything added here beats the defaults. Not tracked (gitignored).
  if [ ! -e "$HOME/.gitconfig.local" ]; then
    cat > "$HOME/.gitconfig.local" <<'LOCALCFG'
# Per-machine git overrides. Included last by ~/.gitconfig, so settings here
# win over the tracked defaults. Nothing in this file is tracked in dotfiles.
#
# To use a different identity for repos under a given directory:
#   [includeIf "gitdir:~/some/dir/"]
#       path = ~/.gitconfig.other
LOCALCFG
    echo "Created ~/.gitconfig.local stub"
  fi
fi

if [ "$DO_NVIM" -eq 1 ]; then
  mkdir -p "$HOME/.config"
  if [ -e "$REPO_DIR/config/nvim" ]; then
    backup_if_needed "$HOME/.config/nvim"
    ln -sfn "$REPO_DIR/config/nvim" "$HOME/.config/nvim"
  else
    echo "Note: $REPO_DIR/config/nvim not found; skipping nvim link" >&2
  fi
fi

mkdir -p "$HOME/.config/git"
if [ -e "$REPO_DIR/config/git/ignore" ]; then
  link_file "$REPO_DIR/config/git/ignore" "$HOME/.config/git/ignore"
fi

ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
if [ -e "$REPO_DIR/config/ghostty/config.ghostty" ]; then
  mkdir -p "$ghostty_dir"
  link_file "$REPO_DIR/config/ghostty/config.ghostty" "$ghostty_dir/config.ghostty"
fi

# --- SSH deploy key + remote ---
#
# The auto-sync agent pushes from launchd with no tty, so it needs a credential
# that never prompts. This uses a passphrase-less key registered as a DEPLOY KEY
# on the dotfiles repo alone — it can't reach any other repo, which keeps this
# repo's automation independent of whatever account-level keys the machine uses
# for everything else.

if [ "$DO_SSH" -eq 1 ]; then
  ssh_key="$HOME/.ssh/id_dotfiles"
  repo_slug="eshaan-mehta/dotfiles"
  key_title="dotfiles-sync $(hostname -s)"

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [ -e "$REPO_DIR/.ssh/config" ]; then
    link_file "$REPO_DIR/.ssh/config" "$HOME/.ssh/config"
  fi

  if [ ! -f "$ssh_key" ]; then
    echo "Generating deploy key: $ssh_key"
    ssh-keygen -t ed25519 -N "" -C "$key_title" -f "$ssh_key" >/dev/null
  fi

  # Register the pubkey, unless this machine's key is already on the repo.
  #
  # Caveat: a deploy key added via gh is bound to the gh auth token — revoking
  # or de-authorizing that token deletes the key too, and auto-sync starts
  # failing. Adding it by hand in the web UI avoids that coupling; the manual
  # path below prints everything needed to do so.
  registered=0
  if command -v gh &>/dev/null; then
    existing=$(gh repo deploy-key list -R "$repo_slug" --json title --jq '.[].title' 2>/dev/null || true)
    if printf '%s\n' "$existing" | grep -qxF "$key_title"; then
      registered=1
    elif gh repo deploy-key add "$ssh_key.pub" -R "$repo_slug" -w -t "$key_title" >/dev/null 2>&1; then
      echo "Registered deploy key \"$key_title\" on $repo_slug"
      registered=1
    fi
  fi

  if [ "$registered" -eq 0 ]; then
    echo "" >&2
    echo "Could not register the deploy key automatically (gh missing, not" >&2
    echo "authenticated, or lacking scope). Add this key manually, ticking" >&2
    echo "\"Allow write access\":" >&2
    echo "  https://github.com/$repo_slug/settings/keys" >&2
    echo "" >&2
    cat "$ssh_key.pub" >&2
    echo "" >&2
  fi

  # Point this clone at the alias defined in .ssh/config so it uses the scoped
  # key. This lives in .git/config, which isn't tracked — hence doing it here,
  # so every machine gets it from bootstrap rather than by hand.
  git remote set-url origin "git@github-dotfiles:$repo_slug.git"
fi

echo "Done."
echo ""
echo "Apply shell changes: source ~/.zshrc"
