#!/usr/bin/env bash
set -euo pipefail

# One-shot setup for this dotfiles repo.
# - Symlinks selected files into $HOME
# - Links LazyVim: ~/.config/nvim -> ~/dotfiles/config/nvim
# - Installs/loads the auto-sync LaunchAgent

REPO_DIR="$HOME/dotfiles"

usage() {
  cat <<USAGE
Usage:
  ./bootstrap.sh [--no-sync] [--no-nvim] [--no-shell] [--no-git]

Flags:
  --no-sync   Skip installing launchd auto-sync
  --no-nvim   Skip linking LazyVim config
  --no-shell  Skip linking shell dotfiles (.zshrc/.zshenv/.bash*)
  --no-git    Skip linking gitconfig
USAGE
}

DO_SYNC=1
DO_NVIM=1
DO_SHELL=1
DO_GIT=1

while [ $# -gt 0 ]; do
  case "$1" in
    --no-sync) DO_SYNC=0 ;;
    --no-nvim) DO_NVIM=0 ;;
    --no-shell) DO_SHELL=0 ;;
    --no-git) DO_GIT=0 ;;
    -h|--help) usage; exit 0 ;;
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
  for f in .zshrc .zshenv .bash_profile .bashrc .direnvrc; do
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

if [ "$DO_SYNC" -eq 1 ]; then
  bash "$REPO_DIR/install.sh"
fi

echo "Done."
