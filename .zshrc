## START OF BITGO CONFIG
# Put python packages in $PATH
PATH=$HOME/Library/Python/3.9/bin:$PATH

# Setup gpg-agent for ssh use
ENVFILE="$HOME/.gnupg/gpg-agent.env"

if ( [[ ! -e "$HOME/.gnupg/S.gpg-agent" ]] && \
     [[ ! -e "/var/run/user/$(id -u)/gnupg/S.gpg-agent" ]] ) ||
   ( [[ ! -s "$ENVFILE" ]] );
then
  if [[ ! -d "$HOME/.gnupg" ]]; then
    echo 'Create ~/.gnupg directory'
    mkdir -m 700 "$HOME/.gnupg"
  fi
  if [[ ! -f "$HOME/.gnupg/gpg-agent.conf" ]]; then
    echo 'Set pinentry-mac to default gpg pinentry in ~/.gnupg/gpg-agent.conf'
    echo "pinentry-program /opt/homebrew/bin/pinentry-mac" > "$HOME/.gnupg/gpg-agent.conf"
  fi

  echo "Reloading scdaemon and gpg-agent, creating .env file: $ENVFILE"
  killall pinentry > /dev/null 2>&1
  gpgconf --reload scdaemon > /dev/null 2>&1
  killall -9 gpg-agent > /dev/null 2>&1
  gpg-agent --daemon --enable-ssh-support > "$ENVFILE"
fi

# Wake up smartcard to avoid races
gpg --card-status > /dev/null 2>&1

source "$ENVFILE"

# Setup nvm
if [[ ! -d "$HOME/.nvm" ]]; then
  mkdir ~/.nvm
fi
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"

# add alias to use git from Homebrew
alias git="/opt/homebrew/bin/git"

eval "$(direnv hook zsh)"

## END OF BITGO CONFIG

export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"

  cai() {                                           
	claude --dangerously-skip-permissions
  }
export PATH="$HOME/.local/bin:$PATH"

# Git alias
alias g="git"
alias lg="lazygit"
alias bi="brew install"

# Creates cdd command with autocomplete
autoload -Uz compinit && compinit

cdd() {
    local DEV="$HOME/dev"
    local DEV2="$HOME/dev2"
    if [ -d "$DEV/$1" ]; then
        cd "$DEV/$1"
    elif [ -d "$DEV2/$1" ]; then
        cd "$DEV2/$1"
    else
        echo "Repo '$1' not found in $DEV or $DEV2"
    fi
}

_cdd_completions() {
    local DEV="$HOME/dev"
    local DEV2="$HOME/dev2"
    local repos=()
    for dir in "$DEV"/*/; do
        repos+=("$(basename "$dir")")
    done
    for dir in "$DEV2"/*/; do
        repos+=("$(basename "$dir")")
    done
    compadd "$@" -- "${repos[@]}"
}

compdef _cdd_completions cdd

# bun completions
[ -s "/Users/eshaanmehta/.bun/_bun" ] && source "/Users/eshaanmehta/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
