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
#   ./bootstrap.sh --yes           Answer every prompt with its default (no questions)
#
# Anything that varies between machines is asked as a question here rather than
# left as a manual step, and the answers are written to untracked files:
#   ~/.gitconfig.local             This machine's git identity, prompted for below. Everything
#                                  outside ~/dotfiles uses it; ~/dotfiles always commits as the
#                                  personal identity in config/git/personal.
#   ~/.gitconfig.scoped            Written only if that identity is restricted to one directory.
#   ~/.zshrc.local                 Shell config specific to this machine. Still manual.
#
# Prompts are skipped when there's no terminal or when --yes is passed, so a
# piped or CI run completes with defaults instead of dying on a question.

REPO_DIR="$HOME/dotfiles"

usage() {
  cat <<USAGE
Usage:
  ./bootstrap.sh [--no-nvim] [--no-shell] [--no-git] [--no-ssh] [--yes]

Flags:
  --no-nvim   Skip linking LazyVim config
  --no-shell  Skip linking shell dotfiles (.zshrc/.zshenv/.bash*)
  --no-git    Skip linking gitconfig
  --no-ssh    Skip deploy key generation, ssh config link, and remote setup
  --yes, -y   Take the default for every prompt instead of asking
USAGE
}

DO_NVIM=1
DO_SHELL=1
DO_GIT=1
DO_SSH=1
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --no-nvim)  DO_NVIM=0 ;;
    --no-shell) DO_SHELL=0 ;;
    --no-git)   DO_GIT=0 ;;
    --no-ssh)   DO_SSH=0 ;;
    --yes|-y)   ASSUME_YES=1 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

# --- Prompt helpers ---
#
# Every question goes through these, so a run without a terminal (piped
# installer, CI, --yes) can't hang or die partway. A bare `read` returns
# non-zero at EOF and `set -e` turns that into an abort — which used to kill
# this script at the first prompt on any non-interactive run, before it had
# linked anything.

can_prompt() { [ "$ASSUME_YES" -eq 0 ] && [ -t 0 ]; }

# confirm <prompt> [default:y|n] — true for yes
confirm() {
  local prompt="$1" default="${2:-n}" reply="" hint="[y/N]"
  [ "$default" = "y" ] && hint="[Y/n]"
  if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
  if ! can_prompt; then [ "$default" = "y" ]; return; fi
  read -r -p "$prompt $hint " reply || reply=""
  [[ "${reply:-$default}" =~ ^[Yy]$ ]]
}

# ask <varname> <prompt> [default] — answer lands in <varname>
ask() {
  local __var="$1" __prompt="$2" __default="${3:-}" __reply=""
  if can_prompt; then
    if [ -n "$__default" ]; then
      read -r -p "$__prompt [$__default]: " __reply || __reply=""
    else
      read -r -p "$__prompt: " __reply || __reply=""
    fi
  fi
  printf -v "$__var" '%s' "${__reply:-$__default}"
}

if [ ! -d "$REPO_DIR/.git" ]; then
  echo "Error: expected repo at $REPO_DIR" >&2
  echo "Clone first: git clone https://github.com/eshaan-mehta/dotfiles.git $REPO_DIR" >&2
  exit 1
fi

cd "$REPO_DIR"

if command -v brew &>/dev/null; then
    if brew bundle check --file="$REPO_DIR/Brewfile" &>/dev/null; then
        echo "Brewfile: all dependencies already installed"
    else
        echo "Brewfile: missing —"
        brew bundle check --file="$REPO_DIR/Brewfile" --verbose 2>/dev/null \
            | grep -Ev '^(==>|✔)' | sed 's/^/  /' || true
        if confirm "Install them?" y; then
            brew bundle --file="$REPO_DIR/Brewfile"
        fi
    fi
else
    echo "Warning: homebrew not found, skipping Brewfile install" >&2
fi

# --- Optional installs (prompt only when not already present) ---

if command -v claude &>/dev/null; then
    _v=$(claude --version 2>/dev/null | head -1 || true)
    if confirm "Claude Code is already installed${_v:+ ($_v)}. Reinstall over it?"; then
        curl -fsSL https://claude.ai/install.sh | bash
    fi
elif confirm "Claude Code is not installed. Install it?" y; then
    curl -fsSL https://claude.ai/install.sh | bash
fi

if command -v ollama &>/dev/null; then
    if ollama list 2>/dev/null | grep -q "dotfiles-commit"; then
        if confirm "Ollama model 'dotfiles-commit' already exists. Rebuild it from config/ollama/Modelfile?"; then
            ollama create dotfiles-commit -f "$REPO_DIR/config/ollama/Modelfile"
        fi
    elif confirm "Ollama model 'dotfiles-commit' is missing; auto-sync uses it to write commit messages. Create it?" y; then
        ollama create dotfiles-commit -f "$REPO_DIR/config/ollama/Modelfile"
    fi
fi

sync_plist="$HOME/Library/LaunchAgents/com.user.dotfiles-sync.plist"
if [ -f "$sync_plist" ]; then
    if confirm "Auto-sync agent is already installed. Reinstall and reload it?"; then
        bash "$REPO_DIR/install.sh"
    fi
elif confirm "Auto-sync agent is not installed; it watches ~/dotfiles and commits and pushes changes. Install it?" y; then
    bash "$REPO_DIR/install.sh"
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
  # Say what's changing. Already-correct links are silent so a re-run only
  # reports real differences; a replaced regular file is kept in $backup_dir,
  # and repointing a symlink discards nothing.
  if [ -L "$dest" ]; then
    local current
    current=$(readlink "$dest")
    [ "$current" = "$src" ] && return 0
    echo "  relink $dest: $current -> $src"
  elif [ -e "$dest" ]; then
    echo "  replace $dest (regular file, moved to $backup_dir/)"
  fi
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

  # Pin the personal identity on this clone directly. Repo-local config beats
  # anything global, so dotfiles commits stay personal even if ~/.gitconfig.local
  # sets an identity machine-wide, and even if this clone lives somewhere the
  # tracked includeIf pattern doesn't match. Values come from the tracked file
  # so there's still one source of truth.
  personal_cfg="$REPO_DIR/config/git/personal"
  if [ -e "$personal_cfg" ]; then
    git -C "$REPO_DIR" config user.name  "$(git config -f "$personal_cfg" --get user.name)"
    git -C "$REPO_DIR" config user.email "$(git config -f "$personal_cfg" --get user.email)"
  fi

  # This machine's identity, for everything outside ~/dotfiles. The tracked
  # .gitconfig sets useConfigOnly, so without this git refuses to commit rather
  # than quietly inventing an address from username@hostname.
  write_local_identity=1
  if [ -e "$HOME/.gitconfig.local" ]; then
    write_local_identity=0
    _cur=$(git config -f "$HOME/.gitconfig.local" --get user.email 2>/dev/null || true)
    if confirm "~/.gitconfig.local already exists (${_cur:-no identity set}). Overwrite it?"; then
      write_local_identity=1
    fi
  fi

  if [ "$write_local_identity" -eq 1 ]; then
    git_name=""; git_email=""; scope_dir=""
    if can_prompt; then
      echo ""
      echo "Git identity for this machine. Used everywhere except ~/dotfiles,"
      echo "which always commits as the personal identity tracked in this repo."
      echo "Leave the email blank to skip and write a stub instead."
      ask git_name  "  Name"  "$(git config --get user.name || true)"
      ask git_email "  Email"
      if [ -n "$git_email" ]; then
        ask scope_dir "  Restrict it to one directory (blank = whole machine), e.g. ~/dev"
      fi
    fi

    if [ -z "$git_email" ]; then
      cat > "$HOME/.gitconfig.local" <<'LOCALCFG'
# This machine's git identity. Included by ~/.gitconfig, and nothing here is
# tracked in dotfiles. Until a [user] block exists here, git refuses to commit
# outside ~/dotfiles rather than guessing an address (user.useConfigOnly).
#
#   [user]
#       name = Your Name
#       email = you@example.com
#
# To apply it only under one directory instead of machine-wide:
#   [includeIf "gitdir:~/some/dir/"]
#       path = ~/.gitconfig.scoped
LOCALCFG
      echo "Wrote ~/.gitconfig.local stub — add a [user] block before committing outside ~/dotfiles"
    elif [ -n "$scope_dir" ]; then
      case "$scope_dir" in */) ;; *) scope_dir="$scope_dir/" ;; esac
      cat > "$HOME/.gitconfig.scoped" <<SCOPEDCFG
[user]
	name = $git_name
	email = $git_email
SCOPEDCFG
      cat > "$HOME/.gitconfig.local" <<LOCALCFG
# This machine's git identity, scoped to one directory. Not tracked.
[includeIf "gitdir:$scope_dir"]
	path = ~/.gitconfig.scoped
LOCALCFG
      echo "Wrote ~/.gitconfig.local — $git_email applies under $scope_dir"
    else
      cat > "$HOME/.gitconfig.local" <<LOCALCFG
# This machine's git identity. Not tracked.
[user]
	name = $git_name
	email = $git_email
LOCALCFG
      echo "Wrote ~/.gitconfig.local — $git_email applies outside ~/dotfiles"
    fi
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

  if [ -f "$ssh_key" ]; then
    _fp=$(ssh-keygen -lf "$ssh_key.pub" 2>/dev/null | awk '{print $2}' || true)
    echo "Deploy key already exists: $ssh_key${_fp:+ ($_fp)}"
    if confirm "Regenerate it? Pushes fail until the old key is removed from $repo_slug and the new one added"; then
      rm -f "$ssh_key" "$ssh_key.pub"
      echo "Generating deploy key: $ssh_key"
      ssh-keygen -t ed25519 -N "" -C "$key_title" -f "$ssh_key" >/dev/null
    fi
  else
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
      echo "Deploy key \"$key_title\" is already registered on $repo_slug"
      registered=1
    elif confirm "Register the deploy key using gh? (no = print it to add by hand, which keeps the key independent of your gh token)"; then
      if gh repo deploy-key add "$ssh_key.pub" -R "$repo_slug" -w -t "$key_title" >/dev/null 2>&1; then
        echo "Registered deploy key \"$key_title\" on $repo_slug"
        registered=1
      else
        echo "gh could not add the key (not authenticated, or missing scope)" >&2
      fi
    fi
  fi

  if [ "$registered" -eq 0 ]; then
    echo "" >&2
    echo "Add this deploy key to the repo, ticking \"Allow write access\":" >&2
    echo "  https://github.com/$repo_slug/settings/keys" >&2
    echo "" >&2
    cat "$ssh_key.pub" >&2
    echo "" >&2
    echo "Until it's added, auto-sync can commit but not push." >&2
    echo "" >&2
  fi

  # Point this clone at the alias defined in .ssh/config so it uses the scoped
  # key. This lives in .git/config, which isn't tracked — hence doing it here,
  # so every machine gets it from bootstrap rather than by hand.
  desired_remote="git@github-dotfiles:$repo_slug.git"
  current_remote=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)
  if [ "$current_remote" = "$desired_remote" ]; then
    echo "origin already points at the scoped alias"
  elif confirm "Change origin from ${current_remote:-unset} to $desired_remote?" y; then
    git remote set-url origin "$desired_remote"
  fi
fi

echo "Done."
echo ""
echo "Apply shell changes: source ~/.zshrc"
