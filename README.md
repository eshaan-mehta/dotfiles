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

### Options
- Skip auto-sync install: `./bootstrap.sh --no-sync`
- Skip LazyVim link: `./bootstrap.sh --no-nvim`
- Skip shell dotfiles: `./bootstrap.sh --no-shell`
- Skip gitconfig: `./bootstrap.sh --no-git`

## Verify
- `launchctl list | grep dotfiles-sync`
- `tail -f ~/dotfiles/.auto-sync.log`
