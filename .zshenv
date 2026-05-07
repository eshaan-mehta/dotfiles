export PATH="/usr/local/bin:$PATH"
envfile="$HOME/.gnupg/gpg-agent.env"
if ( [[ ! -e "$HOME/.gnupg/S.gpg-agent" ]] && \
     [[ ! -e "/var/run/user/$(id -u)/gnupg/S.gpg-agent" ]] );
then
  killall pinentry > /dev/null 2>&1
  gpgconf --reload scdaemon > /dev/null 2>&1
  pkill -x -INT gpg-agent > /dev/null 2>&1
  gpg-agent --daemon --enable-ssh-support > $envfile
fi

# Wake up smartcard to avoid races
gpg --card-status > /dev/null 2>&1

source "$envfile"
export GH_TOKEN="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"
export GITHUB_TOKEN="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"
export NIX_CONFIG="access-tokens = github.com=$GITHUB_TOKEN"

eval "$(direnv hook zsh)"
