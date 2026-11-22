# Workflow

How the tools installed by [dev-setup](README.md) fit together in a normal day.
The README covers installing; this covers using.

## 1. Start

Open Ghostty. It starts fish (the login shell), which loads the PATH, the aliases and the integrations from `config/fish/conf.d/dev-setup.fish`.

```sh
ze                # zellij: panes, tabs and sessions in one terminal
```

Zellij uses the default keybindings and the `catppuccin-mocha` theme from `config/zellij/config.kdl`, plus the layouts in `config/zellij/layouts/` (open a project with `zp`). Keep one session per project and detach instead of closing it.

## 2. Move around and read

| Do | With |
|---|---|
| Jump to a directory you visited before | `cd name` (zoxide learns your history; plain `cd /path` still works) |
| List files | `ls` (eza) |
| Browse and preview a tree | `yazi` |
| Read a file with colors and paging | `b file` (bat; `cat` is still the real `cat`) |
| Search code | `rg pattern` (ripgrep) |
| Find an old command | `Ctrl-R` (atuin: searchable history with context) |

`cd`, `ls`, `cat` and `vim` are aliases for interactive sessions only. Scripts, Makefiles and `#!/bin/bash` files still get the real commands.

## 3. Edit and commit

```sh
vim .             # opens neovim (nvim is also $EDITOR and $VISUAL)
lgit              # lazygit: stage hunks, commit, branch, rebase
gh pr create      # GitHub CLI; run `gh auth login` once per machine
lazydocker        # containers, logs and images in a TUI (Docker Desktop must be running)
```

Small helpers: `fd name` finds files, `jq . file.json` reads JSON, `xh httpbin.org/get` makes an HTTP request, and `fzf` filters any list (`fd | fzf`).

## 4. Node and packages

Node comes from nvm.fish, so `nvm install 22`, `nvm use 22` and `nvm list` work as usual. A `.nvmrc` or `.node-version` file is picked up by a bare `nvm use`. The version you installed first is the default for new shells.

Global npm packages (`npm install -g`) live inside the active Node version's directory: switch versions and they disappear from the PATH, and a new version starts without them. Details and the `nvm_default_packages` option are in the [README](README.md#nodejs).

Use [ni](https://github.com/antfu-collective/ni) so you never have to remember which package manager a project uses: `ni` (install), `nr dev` (run a script), `nun pkg` (uninstall). pnpm and bun are on the PATH when a project needs them directly.

## 5. Containers

Docker Desktop must be running. Start it from the app, then use `docker` and `docker compose` as usual. It is also what the pi search tool needs (section 6).

## 6. AI tools

- **Claude Code:** `claude`. The `usage-hud` mod shows your limits and context above the prompt, and the skills from skills.sh (planning, git, animation, UI) load on demand.
- **Unsafe mode:** `cly` is `claude --dangerously-skip-permissions`: no permission prompts at all. Use it only in projects you would let it edit freely; plain `claude` asks as usual.
- **pi:** `pi`. Its `usage-hud` extension shows the context left, and `web_search` queries a local SearXNG container (`127.0.0.1:8888`), started the first time it is used. `/search-browser-up` and `/search-browser-down` start and stop it.

## 7. Personal and machine-specific settings

Put anything private or machine-specific (VPN aliases, credentials, work paths) in `~/.config/fish/conf.d/local.fish`. The repo never touches it, and nothing in it is committed.

## 8. Changing this setup

1. Edit the repo copy, never the installed one: `config/fish/conf.d/dev-setup.fish`, `config/zellij/config.kdl`, or a `brew_pkg` line in `install.sh`.
2. `./scripts/validate.sh` (read-only: syntax, required files, loads the fish config in a throwaway HOME).
3. `./install.sh --no-shell` applies it. Changed files are backed up as `<file>.bak.<timestamp>` first, and unchanged ones are skipped.
4. Open a new terminal to load it, then commit.
