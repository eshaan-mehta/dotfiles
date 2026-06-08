#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for this dotfiles repo.
# - Symlinks selected files into $HOME
# - Links LazyVim: ~/.config/nvim -> ~/dotfiles/config/nvim
# - Optionally installs Claude Code, the auto-sync agent, and its Ollama model
#
# Safe to rerun — symlinks are idempotent, optional installs only prompt when not yet installed.
#
# COMMON USAGE:
#   ./bootstrap.sh                 Standard setup, prompts for optional installs
#   ./bootstrap.sh --no-git        Skip gitconfig link (keep machine's existing git identity)
#
# MACHINE-SPECIFIC OVERRIDES (create these manually after bootstrap — not tracked in dotfiles):
#   ~/.gitconfig.local             Git identity (name + email) for this machine. Required — git
#                                  commits will fail without it. Example:
#                                    [user]
#                                      email = you@example.com
#                                      name  = Your Name
#   ~/.zshrc.local                 Shell config specific to this machine (work tools, aliases, etc.)

REPO_DIR="$HOME/dotfiles"

usage() {
  cat <<USAGE
Usage:
  ./bootstrap.sh [--no-nvim] [--no-shell] [--no-git]

Flags:
  --no-nvim   Skip linking LazyVim config
  --no-shell  Skip linking shell dotfiles (.zshrc/.zshenv/.bash*)
  --no-git    Skip linking gitconfig
USAGE
}

DO_NVIM=1
DO_SHELL=1
DO_GIT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-nvim)  DO_NVIM=0 ;;
    --no-shell) DO_SHELL=0 ;;
    --no-git)   DO_GIT=0 ;;
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

ghostty_dir="$HOME/Library/Application Support/com.mitchellh.ghostty"
if [ -e "$REPO_DIR/config/ghostty/config.ghostty" ]; then
  mkdir -p "$ghostty_dir"
  link_file "$REPO_DIR/config/ghostty/config.ghostty" "$ghostty_dir/config.ghostty"
fi

echo "Done."
