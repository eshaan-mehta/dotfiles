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

## END OF BITGO CONFIG




export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"
