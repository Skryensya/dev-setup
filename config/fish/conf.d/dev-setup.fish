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
    # Theme: Catppuccin Mocha (same as zellij and fzf). Global, so it follows this file; override
    # in local.fish.
    set -g fish_color_normal cdd6f4
    set -g fish_color_command 89b4fa
    set -g fish_color_param f2cdcd
    set -g fish_color_keyword f38ba8
    set -g fish_color_quote a6e3a1
    set -g fish_color_redirection f5c2e7
    set -g fish_color_end fab387
    set -g fish_color_error f38ba8
    set -g fish_color_option a6e3a1
    set -g fish_color_comment 7f849c
    set -g fish_color_operator f5c2e7
    set -g fish_color_escape f2cdcd
    set -g fish_color_autosuggestion 6c7086
    set -g fish_color_valid_path --underline
    set -g fish_color_selection --background=313244
    set -g fish_color_search_match --background=313244
    set -g fish_color_history_current --bold
    set -g fish_color_cancel f38ba8
    set -g fish_color_cwd f9e2af
    set -g fish_color_cwd_root f38ba8
    set -g fish_color_user 94e2d5
    set -g fish_color_host 89b4fa
    set -g fish_color_host_remote a6e3a1
    set -g fish_color_status f38ba8
    set -g fish_pager_color_progress 6c7086
    set -g fish_pager_color_prefix f5c2e7 --bold
    set -g fish_pager_color_completion cdd6f4
    set -g fish_pager_color_description 6c7086
    set -g fish_pager_color_selected_background --background=313244

    type -q zoxide; and zoxide init fish --cmd cd | source
    type -q eza; and alias ls eza
    type -q nvim; and alias vim nvim
    type -q zellij; and alias ze zellij
    type -q bat; and alias b bat

    # fzf: Ctrl-T (files) and Alt-C (cd). Loaded before atuin so atuin keeps Ctrl-R and the up arrow.
    if type -q fzf; and fzf --fish >/dev/null 2>&1
        if type -q fd
            set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --exclude .git'
            set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
        end
        # Look: Catppuccin Mocha colors (transparent background), one rounded border, scrollbar and
        # an n/total counter so it is clear when more items are below. Later conf.d files
        # (local.fish) can override it.
        set -gx FZF_DEFAULT_OPTS --layout=reverse --border=rounded --scrollbar=▐ --info=inline-right \
            --pointer=▌ --marker=✓ "--prompt='❯ '" --highlight-line --padding=0,1 \
            --color=bg:-1,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,hl:#f38ba8,hl+:#f38ba8,gutter:-1 \
            --color=info:#cba6f7,prompt:#cba6f7,pointer:#f5e0dc,marker:#b4befe,spinner:#f5e0dc \
            --color=border:#6c7086,label:#cdd6f4,scrollbar:#6c7086,header:#f38ba8,query:#cdd6f4
        fzf --fish | source
    end
    type -q atuin; and atuin init fish | source

    # Always defined (not only when the tool exists), so a missing tool says why instead of
    # "command not found".
    function lgit --wraps=lazygit --description 'lazygit'
        type -q lazygit; or begin
            echo "lgit: lazygit no está instalado (corre ./install.sh)" >&2
            return 127
        end
        lazygit $argv
    end
    function ldocker --wraps=lazydocker --description 'lazydocker'
        type -q lazydocker; or begin
            echo "ldocker: lazydocker no está instalado (corre ./install.sh)" >&2
            return 127
        end
        docker info >/dev/null 2>&1; or begin
            echo "ldocker: Docker no responde, abre Docker Desktop y espera a que arranque" >&2
            return 1
        end
        lazydocker $argv
    end

    # zp [layout] [project]: open a project in a zellij layout (config/zellij/layouts/*.kdl).
    # Without a project, fzf lists ~/code/*/* (root: $ZP_ROOT). Inside zellij it adds a tab,
    # outside it starts a new session. Arguments can come in any order.
    function zp --description 'open a project in a zellij layout'
        set -l root (set -q ZP_ROOT; and echo $ZP_ROOT; or echo ~/code)
        set -l ldir ~/.config/zellij/layouts
        type -q zellij; or begin
            echo "zp: zellij no está instalado (corre ./install.sh)" >&2
            return 127
        end
        set -l layout
        set -l dir
        for a in $argv
            if test -f $ldir/$a.kdl
                set layout $a
            else
                set dir $a
            end
        end
        if test -z "$layout"
            set -l all (path change-extension "" $ldir/*.kdl 2>/dev/null | path basename)
            test (count $all) -gt 0; or begin
                echo "zp: no hay layouts en $ldir (corre ./install.sh)" >&2
                return 1
            end
            if test (count $all) -eq 1
                set layout $all
            else
                type -q fzf; or begin
                    echo "zp: fzf no está instalado (corre ./install.sh)" >&2
                    return 127
                end
                set layout (printf '%s\n' $all | fzf --height 40% --border-label ' layout ')
                test -n "$layout"; or return 1
            end
        end
        if test -z "$dir"
            type -q fzf; or begin
                echo "zp: fzf no está instalado (corre ./install.sh)" >&2
                return 127
            end
            # Repos (anything with .git, any depth under $root) get a repo icon; every folder above a
            # repo gets a folder icon (meta-repos, opened from the folder above). Shown as a tree,
            # names only, with the absolute path in a hidden second field. Needs a Nerd Font.
            set -l repos (find $root -maxdepth 7 -name node_modules -prune -o -name .git -print 2>/dev/null \
                | string replace -r '/\.git$' '' | string replace "$root/" '')
            set -l paths $repos
            for r in $repos
                set -l parts (string split / $r)
                test (count $parts) -gt 1; or continue
                for i in (seq 1 (math (count $parts) - 1))
                    set -a paths (string join / $parts[1..$i])
                end
            end
            set -l rows
            for p in (printf '%s/\n' $paths | LC_ALL=C sort -u | string replace -r '/$' '')
                set -l parts (string split / $p)
                set -l indent (string repeat -n (math 2 \* (count $parts) - 2) ' ')
                if contains -- $p $repos
                    set -a rows (printf '%b\t%s' "$indent\x1b[38;2;137;180;250m\uf401\x1b[0m $parts[-1]" $root/$p)
                else
                    set -a rows (printf '%b\t%s' "$indent\x1b[38;2;249;226;175m\uf07b\x1b[0m \x1b[1;38;2;166;173;200m$parts[-1]\x1b[0m" $root/$p)
                end
            end
            set dir (printf '%s\n' $rows | env SHELL=/bin/sh fzf --height 70% --min-height 20 --ansi \
                --delimiter \t --with-nth 1 --accept-nth 2 --border-label ' proyectos ' \
                --preview-window 'right,55%,border-left' --preview 'sh ~/.config/zp/preview.sh {2}' \
                --footer ' ↑↓ mover   ⏎ abrir   esc salir ')
            test -n "$dir"; or return 1
        else if not test -d $dir
            set dir (zoxide query $dir 2>/dev/null); or begin
                echo "zp: no encuentro el proyecto '$argv'" >&2
                return 1
            end
        end
        set dir (path resolve $dir)
        if set -q ZELLIJ
            zellij action new-tab --layout $ldir/$layout.kdl --cwd $dir --name (path basename $dir)
        else
            # --name only exists on new-tab, so a new session gets the name written into a copy.
            set -l tmp (mktemp -d)/$layout.kdl
            string replace -r 'tab name="[^"]*"' 'tab name="'(path basename $dir)'"' <$ldir/$layout.kdl >$tmp
            cd $dir; and exec zellij --layout $tmp
        end
    end

    # reload: new fish in place of this one, so config.fish and conf.d/* are read again.
    alias reload 'exec fish'

    alias dns-reset 'sudo networksetup -setdnsservers Wi-Fi 1.1.1.1 1.0.0.1'
    abbr --add .. 'cd ..'
    abbr --add ... 'cd ../..'
    abbr --add .... 'cd ../../..'
    abbr --add cd.. 'cd ..'
    abbr --add cd. 'cd ..'

    # UNSAFE: Claude Code with no permission prompts (see README, Security).
    type -q claude; and alias cly 'claude --dangerously-skip-permissions'

    # Ghostty opens straight into zellij, reattaching to the newest session (live, or an exited one
    # that zellij resurrects with its tabs and panes); a new session only if none exist.
    # Skipped inside zellij itself and with DEV_SETUP_NO_ZELLIJ=1.
    if test "$TERM_PROGRAM" = ghostty; and type -q zellij; and not set -q ZELLIJ; and not set -q DEV_SETUP_NO_ZELLIJ
        set -l last (zellij list-sessions -n -s 2>/dev/null | tail -n 1)
        if test -n "$last"
            exec zellij attach $last
        else
            exec zellij
        end
    end
end
