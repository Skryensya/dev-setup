# Managed by dev-setup. Interactive-only parts stay behind the guard so scripts
# keep the normal cd/ls.
fish_add_path ~/.local/bin ~/.pi/agent/bin ~/.bun/bin
set -gx BUN_INSTALL ~/.bun
set -gx PNPM_HOME ~/Library/pnpm
fish_add_path $PNPM_HOME/bin

if status is-interactive
    zoxide init fish --cmd cd | source
    alias ls eza
    alias vim nvim
    alias ze zellij
    alias cly 'claude --dangerously-skip-permissions'
    alias dns-reset 'sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1'
    abbr --add .. 'cd ..'
    abbr --add ... 'cd ../..'
    abbr --add .... 'cd ../../..'
    abbr --add cd.. 'cd ..'
    abbr --add cd. 'cd ..'
end
