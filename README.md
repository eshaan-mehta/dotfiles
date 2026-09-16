# dotfiles

## One-shot setup (new machine)

1) Clone:
- `git clone https://github.com/eshaan-mehta/dotfiles.git ~/dotfiles`

2) Bootstrap (symlinks + LazyVim + auto-sync):
- `cd ~/dotfiles && ./bootstrap.sh`

This will:
- Symlink shell + git dotfiles into `~`
- Symlink LazyVim config: `~/.config/nvim -> ~/dotfiles/config/nvim`
- Install/load the dotfiles auto-sync LaunchAgent (runs `install.sh`)
- Offer optional installs: Ghostty, cmux, Claude Code, and the Ollama commit-message model

## Verify
- `launchctl list | grep dotfiles-sync`
- `tail -f ~/dotfiles/.auto-sync.log`
