export PATH="${HOMEBREW_PREFIX}/opt/openssl/bin:$PATH"

cai() {
    claude --dangerously-skip-permissions
}
export PATH="$HOME/.local/bin:$PATH"

# Git aliases
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

# bun
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Machine-specific config (GPG/Yubikey, nvm, work aliases, etc.) — not tracked in dotfiles
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
