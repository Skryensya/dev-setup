# dev-setup

Quick start for a new macOS dev environment. One idempotent command installs my
tools and config; run it again any time.

How the tools work together day to day: [WORKFLOW.md](WORKFLOW.md).

## Bootstrap a fresh Mac

```sh
git clone https://github.com/Skryensya/dev-setup && cd dev-setup && ./install.sh
```

(`git` itself comes with the Xcode Command Line Tools: macOS offers to install them the first time you run `git`.)

- If the Xcode Command Line Tools are missing, the script opens macOS's installer and exits. Rerun it when that finishes.
- `./install.sh` always opens a small menu first when it runs in a terminal (arrows or `j`/`k` to move, space to tick, `a` all, `n` none, `d` defaults, enter to install, esc to cancel; every key is listed at the bottom). `./install.sh -y` skips the menu and installs the default set, which is also what happens without a terminal (pipes, CI). Slack, Discord and Microsoft Teams are in the menu but not in the default set. The list of ids lives in `CATALOG` at the top of `install.sh`, and each step is tied to an id with `log "Name" id`. Steps without an id (Xcode tools, Homebrew, fish, nvm.fish, Node, fish config, default shell) always run.
- To leave your login shell alone: `./install.sh --no-shell` (or `DEV_SETUP_SKIP_SHELL=1 ./install.sh`; only the value `1` counts).
- Each step prints its title with a counter (`▶ Homebrew 3/23`), the live percentage goes in the window title, and the full bar is printed once at the end. Nothing is pinned to the screen, so scrolling works (colors off with `NO_COLOR=1` or when piped).

## Why Bash, and what about Fish

`install.sh` is Bash because a fresh Mac has Bash and zsh, not Fish. Fish is
installed with Homebrew and becomes the interactive shell:

- `config/fish/conf.d/dev-setup.fish` is copied to `~/.config/fish/conf.d/` (fish loads it by itself). It sets the PATH (Homebrew on Apple Silicon and Intel, `~/.local/bin`, pi, bun, pnpm; no duplicates, missing directories skipped), `EDITOR`/`VISUAL` = nvim when they are unset, and, interactive sessions only: `cd` → zoxide, `ls` → eza, `b` → bat (`cat` stays the real `cat`), `vim` → nvim, `ze` → zellij, `lgit` → lazygit, `ldocker` → lazydocker (both explain what is missing, and `ldocker` checks that Docker is running), fzf (Ctrl-T files, Alt-C directories) and atuin's shell history (it keeps Ctrl-R and the up arrow) and a few abbreviations. Every optional tool is checked first, so a missing one prints nothing.
- In Ghostty the shell opens straight into zellij, reattaching to the newest session (an exited one is resurrected with its tabs, panes and folders; commands wait for Enter). With no sessions it starts a new one. Several windows share that session. Opt out with `DEV_SETUP_NO_ZELLIJ=1` (e.g. in `local.fish`); it is skipped inside zellij.
- `zp [layout] [project]` opens a project in a zellij layout (`config/zellij/layouts/*.kdl`, installed to `~/.config/zellij/layouts/`). Without a project, an fzf tree (names only, indented; folder icon in yellow, repo icon in blue) of every repo under `~/code` at any depth (anything with `.git`) and every folder above one, like `asimov/uc/educacion-continua` (a folder opens from the folder above). A preview on the right shows the git state, last commits and contents (`config/zp/preview.sh`, installed to `~/.config/zp/`). Needs a Nerd Font (root: `$ZP_ROOT`); with several layouts and none given, fzf asks for one. Inside zellij it adds a tab; outside it starts a new session. Layout `dev`: `cly` on the left, two panes stacked on the right.
- Look: Catppuccin Mocha everywhere. zellij uses its built-in `catppuccin-mocha` theme; fish syntax, pager and prompt colors and fzf (`FZF_DEFAULT_OPTS`: one rounded border, scrollbar, `n/total` counter) use the same palette, shared by `zp`, Ctrl-T and Alt-C. Override either in `local.fish`. For the terminal itself, Ghostty has the same theme: `theme = Catppuccin Mocha` in its config (not managed here).
- Put machine-specific or private settings in `~/.config/fish/conf.d/local.fish`. The repo never touches it.
- Login shell: the script adds Fish to `/etc/shells` only if needed and runs `sudo chsh`. It only tries with a terminal (one password prompt) or passwordless sudo. Otherwise, or if it fails, it prints the exact commands and carries on: the rest of the install never depends on it.

## Node.js

Node is managed by [nvm.fish](https://github.com/jorgebucaran/nvm.fish), installed with [Fisher](https://github.com/jorgebucaran/fisher) (both pinned to a release). nvm.fish only activates its default version in *interactive* shells, so the Bash installer activates it explicitly (`nvm use default` inside fish), puts that Node first on its `PATH` and checks that `node`, `npm` and `npx` run before any step that needs them. A Node that merely happens to be on the `PATH` does not count.

**Global npm packages** (`npm install -g`, like pi when installed through npm) are tied to the Node version that was active: nvm.fish sets npm's prefix to that version's directory (`~/.local/share/nvm/<version>`), so packages and their commands live in `<version>/lib/node_modules` and `<version>/bin`. They are only on the `PATH` while that version is active, they are not shared between versions, and a new Node version starts without them. The installer's own `npm install -g` steps use the default version. To reinstall a list of packages on every new version, set `set -U nvm_default_packages pkg1 pkg2`. Packages that must not depend on a Node version belong in Homebrew, pnpm or bun instead.

- No default set: it runs `nvm install lts` and makes that exact version the default. Versions you already installed stay untouched, and nothing is downloaded twice.
- A working default exists: the step is skipped.

## Other tools

Homebrew, fish, pnpm, [ni](https://github.com/antfu-collective/ni), zellij (with my config and layouts), yazi, neovim, zoxide, eza, bat, ripgrep, fzf, fd, jq, xh, lazygit, lazydocker, atuin, gh, JetBrains Mono Nerd Font, Ghostty, Google Chrome and Docker Desktop; Claude Code, [pi](https://github.com/earendil-works/pi), the `usage-hud` Claude Code mod, pi extensions (`usage-hud`, and `search-browser`: `web_search` through SearXNG in Docker, started on first use, so Docker Desktop must be running) and [skills.sh](https://skills.sh) packages from `emilkowalski/skills` and `mattpocock/skills`. Run `gh auth login` yourself afterwards.

Adding a tool is one line in `install.sh`: `brew_pkg <name>` (or `brew_pkg <formula> <binary>`). A binary counts as installed unless it is the macOS one in `/usr/bin`.

## Running it again

Every step checks first and skips what is done, so a second run changes nothing. Managed config files (`dev-setup.fish`, zellij's `config.kdl`) are compared with the repo copy: identical → skipped; different → the current file is first saved as `<file>.bak.<timestamp>`, then replaced. The pi extensions and the Claude Code mod are synced the same way when any repo file changed: the old folder is copied to `~/.dev-setup-backups/<timestamp>/<name>` (outside `~/.pi` and `~/.claude`, which would load a copy as a duplicate), the repo files are copied over, and extra files already in the destination are kept. Restart pi or Claude Code to load the update. No backup is made when nothing changes. Everything else in your fish config, `local.fish` and `~/.zshrc` is left alone.

## Validate and verify

```sh
./scripts/validate.sh      # read-only: bash and fish syntax, required files, loads the fish config in a throwaway HOME
```

It installs nothing and never touches your real config. A check whose tool is missing is reported as `SKIP`, not as passed.

After installing, in a new terminal:

```sh
echo $SHELL; status is-interactive; and type cd    # fish, and cd is zoxide's
node --version; npm --version; nvm current
fish --version; zellij --version; gh --version
```

## Security and limitations

- `cly` (`claude --dangerously-skip-permissions`) is defined in interactive fish sessions and runs Claude Code with **no permission prompts**: it can edit files and run commands unattended. Use it only in projects you would let it change freely, and use plain `claude` otherwise. To drop it on one machine, `functions -e cly` for the session, or remove the line from `~/.config/fish/conf.d/dev-setup.fish` (the installer would restore it).
- The installer downloads and runs scripts from the internet (Homebrew, Claude Code, Fisher) and `npx skills add` installs skills that run with full agent permissions. Read what you install. Fisher and nvm.fish are pinned; the others follow their latest release.
- Tested here on a machine that already has most tools (full run in a throwaway `HOME`), not on a factory-fresh Mac. The Homebrew, Xcode, Claude Code, pi and Docker install paths have not been exercised from scratch.

## Layout

```
install.sh                       the installer (Bash)
WORKFLOW.md                      how to use the setup day to day
scripts/validate.sh              read-only checks
config/fish/conf.d/              fish config (PATH, aliases)
config/zellij/config.kdl         zellij config
mods/usage-hud/                  Claude Code HUD mod
pi/extensions/                   pi extensions (usage-hud, search-browser)
```
