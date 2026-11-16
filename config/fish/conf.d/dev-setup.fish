# Managed by dev-setup: copied to ~/.config/fish/conf.d/ (the old file is backed up).
# Machine-specific or private settings go in ~/.config/fish/conf.d/local.fish,
# which this repo never touches.

# PATH. -g keeps it per session (no universal fish_user_paths); existing entries are
# kept, duplicates are dropped and directories that don't exist are skipped.
# Homebrew lives in /opt/homebrew on Apple Silicon and /usr/local on Intel.
set -gx BUN_INSTALL ~/.bun
set -gx PNPM_HOME ~/Library/pnpm
fish_add_path -g /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/local/sbin
fish_add_path -g ~/.local/bin ~/.pi/agent/bin $BUN_INSTALL/bin $PNPM_HOME $PNPM_HOME/bin

if type -q nvim
    set -q EDITOR; or set -gx EDITOR nvim
    set -q VISUAL; or set -gx VISUAL nvim
end

# Interactive only: scripts keep the normal cd and ls.
if status is-interactive
    type -q zoxide; and zoxide init fish --cmd cd | source
    type -q eza; and alias ls eza
    type -q nvim; and alias vim nvim
    type -q zellij; and alias ze zellij
    type -q bat; and alias cat bat
    type -q lazygit; and alias lgit lazygit
    type -q atuin; and atuin init fish | source
    alias dns-reset 'sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1'
    abbr --add .. 'cd ..'
    abbr --add ... 'cd ../..'
    abbr --add .... 'cd ../../..'
    abbr --add cd.. 'cd ..'
    abbr --add cd. 'cd ..'

    # UNSAFE, opt-in: Claude Code without any permission prompt. Enable it on a
    # machine with `set -Ux DEV_SETUP_UNSAFE_CLY 1` (disable: `set -e DEV_SETUP_UNSAFE_CLY`).
    set -q DEV_SETUP_UNSAFE_CLY; and alias cly 'claude --dangerously-skip-permissions'
end
