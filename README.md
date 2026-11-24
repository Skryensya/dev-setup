# dev-setup

Quick start for a new macOS dev environment. One idempotent command installs my
tools and config; run it again any time and it only does what is missing.

How the tools work together day to day: [WORKFLOW.md](WORKFLOW.md).

## Bootstrap a fresh Mac

```sh
git clone https://github.com/Skryensya/dev-setup && cd dev-setup && ./install.sh
```

(`git` itself comes with the Xcode Command Line Tools: macOS offers to install them the first time you run `git`.)

When it finishes, open a new terminal (Ghostty) to get fish, zellij and everything below. Then run `gh auth login` and sign in to 1Password yourself.

## The `install.sh` command

| Command | What it does |
|---|---|
| `./install.sh` | In a terminal, opens a menu to choose what to install. Without a terminal (pipes, CI) it installs the default set. |
| `./install.sh -y` | Skips the menu and installs the default set. |
| `./install.sh --no-shell` | Installs everything but leaves your login shell alone (same as `DEV_SETUP_SKIP_SHELL=1 ./install.sh`; only the value `1` counts). |
| `./install.sh --help` | Prints the usage. |

- **The menu.** Arrows or `j`/`k` move, space ticks, `a` all, `n` none, `d` defaults, enter installs, esc cancels; every key is listed at the bottom. Slack, Discord and Microsoft Teams are in the menu but not in the default set.
- **Xcode Command Line Tools.** If they are missing, the script opens macOS's installer and exits. Rerun it when that finishes.
- **Progress.** Each step prints its title with a counter (`▶ Homebrew 3/23`), the live percentage goes in the window title, and the full bar is printed once at the end. Nothing is pinned to the screen, so scrolling works (colors off with `NO_COLOR=1` or when piped).
- **Safe to repeat.** See [Running it again](#running-it-again).

## What it installs

Everything in the menu is on by default unless marked *optional*. The list of ids lives in `CATALOG` at the top of `install.sh`, and each step is tied to an id with `log "Name" id`. Steps without an id always run: Xcode tools, Homebrew, fish, nvm.fish, Node, the fish config and the default shell.

**Always installed**

| Tool | What it is for |
|---|---|
| [Homebrew](https://brew.sh) | Package manager used for almost everything below. |
| [fish](https://fishshell.com) | The interactive shell, set as your login shell (see [fish](#why-bash-and-what-about-fish)). |
| [nvm.fish](https://github.com/jorgebucaran/nvm.fish) + Node | Node.js versions; installs the LTS as default (see [Node.js](#nodejs)). |

**Terminal tools**

| Menu id | Tools | What they are for |
|---|---|---|
| `pnpm` | pnpm | Fast Node package manager. |
| `ni` | [ni](https://github.com/antfu-collective/ni) | One command (`ni`, `nr`...) for npm, pnpm and yarn. |
| `zellij` | zellij | Terminal multiplexer: sessions, tabs and panes, with my config and `dev` layout. |
| `neovim` | neovim | Editor; `vim` opens it and it is the default `EDITOR`. |
| `yazi` | yazi | File manager in the terminal. |
| `gh` | gh | GitHub CLI (run `gh auth login` afterwards). |
| `op` | 1Password CLI | `op`, to read secrets from 1Password. Turn on "Integrate with 1Password CLI" in the app's Developer settings. |
| `zoxide` | zoxide, eza | `cd` that learns the folders you visit; `ls` with icons and colors. |
| `shell-tools` | atuin, lazygit, ripgrep, bat, glow | Searchable shell history; git TUI; fast grep; `cat` with highlighting; Markdown reader. |
| `cli-tools` | xh, lazydocker, fzf, fd, jq | HTTP client; Docker TUI; fuzzy finder; fast `find`; JSON processor. |
| `font` | JetBrains Mono Nerd Font | Font with the icons that `zp`, eza and the prompt use. |

**Apps**

| Menu id | App |
|---|---|
| `ghostty` | Ghostty, the terminal, with the Catppuccin Mocha theme (`config/ghostty/config.ghostty`). |
| `1password` | 1Password. |
| `chrome` | Google Chrome. |
| `vlc` | VLC, plays FLV files and almost any other format. |
| `docker` | Docker Desktop (needed by `ldocker` and the pi `search-browser` extension). |
| `slack`, `discord`, `teams` | *Optional.* Slack, Discord, Microsoft Teams. |

**AI agents**

| Menu id | What it installs |
|---|---|
| `claude` | Claude Code and the `usage-hud` mod (a usage HUD for it). |
| `pi` | The [pi](https://github.com/earendil-works/pi) agent and its extensions: `usage-hud`, and `search-browser` (`web_search` through SearXNG in Docker, started on first use, so Docker Desktop must be running). |
| `skills-emil` | [skills.sh](https://skills.sh) packages from `emilkowalski/skills` (animation and design). |
| `skills-matt` | Packages from `mattpocock/skills` (planning and git). |

Adding a tool is one line in `install.sh`: `brew_pkg <name>` (or `brew_pkg <formula> <binary>`), plus a line in `CATALOG`. A binary counts as installed unless it is the macOS one in `/usr/bin`.

## Commands you get

Defined in `config/fish/conf.d/dev-setup.fish`, interactive sessions only (scripts keep the normal `cd` and `ls`).

| Command | What it does |
|---|---|
| `cd name` | zoxide: jumps to a folder you visited before. `cd /path` and `cd ..` still work. |
| `zp [project]` | Opens a project in the zellij `dev` layout. See below. |
| `zseed [folder]` | Teaches zoxide every repo (anything with `.git`) under a folder (default `$ZP_ROOT` or `~/code`), so `cd name` finds them before you have visited them. |
| `zq` | Stops every process in every zellij session but keeps the sessions, so you can resume them: closing Ghostty or zellij only detaches and leaves processes running, `zq` actually ends them. Opening Ghostty again (or `zellij attach <name>`) restores tabs, panes, folders and what each terminal showed; commands wait for Enter. |
| `ls` | eza. |
| `b file` | bat (`cat` stays the real `cat`). |
| `vim` | nvim. |
| `ze` | zellij. |
| `lgit` | lazygit. |
| `ldocker` | lazydocker; checks that Docker is running first. |
| `cly` | `claude --dangerously-skip-permissions`. **Unsafe**, see [Security](#security-and-limitations). |
| `reload` | Replaces the current fish with a new one, so the config is read again. |
| `Ctrl-T`, `Alt-C` | fzf: pick a file, pick a directory and `cd` into it. |
| `Ctrl-R`, up arrow | atuin's shell history. |

`lgit` and `ldocker` explain what is missing instead of printing "command not found". Every other optional tool is checked first, so a missing one prints nothing. Caps-lock typos (`CLY`, `CD`, `LS`, `ZE`, `ZP`, `ZQ`) run the lowercase command.

### `zp [project]`

Opens a project in the `dev` layout (`config/zellij/layouts/dev.kdl`, installed to `~/.config/zellij/layouts/`): `cly` on the left, two panes stacked on the right.

- **With a project** (`zp my-app` or `zp ~/code/x/my-app`): a folder opens directly; any other name is looked up in zoxide.
- **Without a project:** an fzf tree (names only, indented; folder icon in yellow, repo icon in blue) of every repo under `~/code` at any depth (anything with `.git`) and every folder above one, like `asimov/uc/educacion-continua` (a folder opens from the folder above). A preview on the right shows the git state, last commits and contents (`config/zp/preview.sh`, installed to `~/.config/zp/`). Root: `$ZP_ROOT`. Needs a Nerd Font.
- **Where it opens:** inside zellij it adds a tab named after the folder; outside it starts a new session.
- **zoxide:** every project opened with `zp` is added to zoxide.

## Why Bash, and what about Fish

`install.sh` is Bash because a fresh Mac has Bash and zsh, not Fish. Fish is
installed with Homebrew and becomes the interactive shell:

- `config/fish/conf.d/dev-setup.fish` is copied to `~/.config/fish/conf.d/` (fish loads it by itself). It sets the PATH (Homebrew on Apple Silicon and Intel, `~/.local/bin`, pi, bun, pnpm; no duplicates, missing directories skipped), `EDITOR`/`VISUAL` = nvim when they are unset, and the commands above.
- In Ghostty the shell opens straight into zellij, reattaching to the newest session (an exited one is resurrected with its tabs, panes and folders; commands wait for Enter). With no sessions it starts a new one. The config saves the session every 5 seconds with each terminal's contents (`serialization_interval`, `serialize_pane_viewport`), so resuming after `zq` or a reboot is close to where you left off. Shell history is separate: atuin keeps it. Several windows share that session. Opt out with `DEV_SETUP_NO_ZELLIJ=1` (e.g. in `local.fish`); it is skipped inside zellij.
- Look: Catppuccin Mocha with yellow accents everywhere. zellij uses `catppuccin-mocha-yellow`, defined in its config (the built-in palette with yellow as the active color); fish syntax, pager and prompt colors and fzf (`FZF_DEFAULT_OPTS`: one rounded border, scrollbar, `n/total` counter) use the same palette, shared by `zp`, Ctrl-T and Alt-C. Override either in `local.fish`. Ghostty has the same theme: `theme = Catppuccin Mocha` in `config/ghostty/config.ghostty`, installed to `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` (the old file is backed up).
- Put machine-specific or private settings in `~/.config/fish/conf.d/local.fish`. The repo never touches it.
- Login shell: the script adds Fish to `/etc/shells` only if needed and runs `sudo chsh`. It only tries with a terminal (one password prompt) or passwordless sudo. Otherwise, or if it fails, it prints the exact commands and carries on: the rest of the install never depends on it.

## Node.js

Node is managed by [nvm.fish](https://github.com/jorgebucaran/nvm.fish), installed with [Fisher](https://github.com/jorgebucaran/fisher) (both pinned to a release). nvm.fish only activates its default version in *interactive* shells, so the Bash installer activates it explicitly (`nvm use default` inside fish), puts that Node first on its `PATH` and checks that `node`, `npm` and `npx` run before any step that needs them. A Node that merely happens to be on the `PATH` does not count.

**Global npm packages** (`npm install -g`, like pi when installed through npm) are tied to the Node version that was active: nvm.fish sets npm's prefix to that version's directory (`~/.local/share/nvm/<version>`), so packages and their commands live in `<version>/lib/node_modules` and `<version>/bin`. They are only on the `PATH` while that version is active, they are not shared between versions, and a new Node version starts without them. The installer's own `npm install -g` steps use the default version. To reinstall a list of packages on every new version, set `set -U nvm_default_packages pkg1 pkg2`. Packages that must not depend on a Node version belong in Homebrew, pnpm or bun instead.

- No default set: it runs `nvm install lts` and makes that exact version the default. Versions you already installed stay untouched, and nothing is downloaded twice.
- A working default exists: the step is skipped.

## Running it again

Every step checks first and skips what is done, so a second run changes nothing. Managed config files (`dev-setup.fish`, zellij's `config.kdl` and layouts, Ghostty's `config.ghostty`) are compared with the repo copy: identical → skipped; different → the current file is first saved as `<file>.bak.<timestamp>`, then replaced. The pi extensions and the Claude Code mod are synced the same way when any repo file changed: the old folder is copied to `~/.dev-setup-backups/<timestamp>/<name>` (outside `~/.pi` and `~/.claude`, which would load a copy as a duplicate), the repo files are copied over, and extra files already in the destination are kept. Restart pi or Claude Code to load the update. No backup is made when nothing changes. Everything else in your fish config, `local.fish` and `~/.zshrc` is left alone.

## Validate and verify

```sh
./scripts/validate.sh      # read-only: bash and fish syntax, required files, loads the fish config in a throwaway HOME
```

It installs nothing and never touches your real config. A check whose tool is missing is reported as `SKIP`, not as passed.

After installing, in a new terminal:

```sh
echo $SHELL; status is-interactive; and type cd    # fish, and cd is zoxide's
node --version; npm --version; nvm current
fish --version; zellij --version; gh --version; op --version
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
config/fish/conf.d/              fish config (PATH, commands, theme)
config/zellij/config.kdl         zellij config
config/zellij/layouts/           zellij layouts (dev), used by zp
config/zp/preview.sh             zp's fzf preview
config/ghostty/config.ghostty    Ghostty config (Catppuccin Mocha)
mods/usage-hud/                  Claude Code HUD mod
pi/extensions/                   pi extensions (usage-hud, search-browser)
```
