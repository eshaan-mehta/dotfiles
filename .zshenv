# Minimal, safe environment for *all* zsh invocations.
# Keep this file portable across machines.

# PATH: support Apple Silicon + Intel Homebrew if present.
if [ -d "/opt/homebrew/bin" ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi
if [ -d "/usr/local/bin" ]; then
  export PATH="/usr/local/bin:$PATH"
fi

# Default editor
export EDITOR="nvim"
export VISUAL="nvim"

# Optional GPG agent env (only if GPG tooling exists on this machine)
if command -v gpg-agent >/dev/null 2>&1; then
  envfile="$HOME/.gnupg/gpg-agent.env"

  if ( [[ ! -e "$HOME/.gnupg/S.gpg-agent" ]] && \
       [[ ! -e "/var/run/user/$(id -u)/gnupg/S.gpg-agent" ]] );
  then
    killall pinentry > /dev/null 2>&1 || true
    gpgconf --reload scdaemon > /dev/null 2>&1 || true
    pkill -x -INT gpg-agent > /dev/null 2>&1 || true
    gpg-agent --daemon --enable-ssh-support > "$envfile" 2>/dev/null || true
  fi

  command -v gpg >/dev/null 2>&1 && gpg --card-status > /dev/null 2>&1 || true
  [ -f "$envfile" ] && source "$envfile"
fi

# Optional direnv
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Local-only machine secrets/overrides (NOT tracked)
[ -f "$HOME/.zshenv.local" ] && source "$HOME/.zshenv.local"
