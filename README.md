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
- To leave your login shell alone: `./install.sh --no-shell` (or `DEV_SETUP_SKIP_SHELL=1 ./install.sh`).
- A progress bar stays at the bottom of the terminal while logs scroll above it.

## Why Bash, and what about Fish

`install.sh` is Bash because a fresh Mac has Bash and zsh, not Fish. Fish is
installed with Homebrew and becomes the interactive shell:

- `config/fish/conf.d/dev-setup.fish` is copied to `~/.config/fish/conf.d/` (fish loads it by itself). It sets the PATH (Homebrew on Apple Silicon and Intel, `~/.local/bin`, pi, bun, pnpm; no duplicates, missing directories skipped), `EDITOR`/`VISUAL` = nvim when they are unset, and, interactive sessions only: `cd` → zoxide, `ls` → eza, `cat` → bat, `vim` → nvim, `ze` → zellij, `lgit` → lazygit, atuin's shell history (it takes over Ctrl-R and the up arrow) and a few abbreviations. Every optional tool is checked first, so a missing one prints nothing.
- Put machine-specific or private settings in `~/.config/fish/conf.d/local.fish`. The repo never touches it.
- Login shell: the script adds Fish to `/etc/shells` only if needed and runs `sudo chsh`. It only tries with a terminal (one password prompt) or passwordless sudo. Otherwise, or if it fails, it prints the exact commands and carries on: the rest of the install never depends on it.

## Node.js

Node is managed by [nvm.fish](https://github.com/jorgebucaran/nvm.fish), installed with [Fisher](https://github.com/jorgebucaran/fisher) (both pinned to a release). nvm.fish only activates its default version in *interactive* shells, so the Bash installer activates it explicitly (`nvm use default` inside fish), puts that Node first on its `PATH` and checks that `node`, `npm` and `npx` run before any step that needs them. A Node that merely happens to be on the `PATH` does not count.

- No default set: it runs `nvm install lts` and makes that exact version the default. Versions you already installed stay untouched, and nothing is downloaded twice.
- A working default exists: the step is skipped.

## Other tools

Homebrew, fish, pnpm, [ni](https://github.com/antfu-collective/ni), zellij (with my config, no custom layouts), yazi, neovim, zoxide, eza, bat, ripgrep, lazygit, atuin, gh, Ghostty and Docker Desktop; Claude Code, [pi](https://github.com/earendil-works/pi), the `usage-hud` Claude Code mod, pi extensions (`usage-hud`, and `search-browser`: `web_search` through SearXNG in Docker, started on first use, so Docker Desktop must be running) and [skills.sh](https://skills.sh) packages from `emilkowalski/skills` and `mattpocock/skills`. Run `gh auth login` yourself afterwards.

Adding a tool is one line in `install.sh`: `brew_pkg <name>` (or `brew_pkg <formula> <binary>`). A binary counts as installed unless it is the macOS one in `/usr/bin`.

## Running it again

Every step checks first and skips what is done, so a second run changes nothing. Managed config files (`dev-setup.fish`, zellij's `config.kdl`) are compared with the repo copy: identical → skipped; different → the current file is first saved as `<file>.bak.<timestamp>`, then replaced. No backup is made when nothing changes. Everything else in your fish config, `local.fish` and `~/.zshrc` is left alone.

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

- `cly` (`claude --dangerously-skip-permissions`) runs Claude Code with **no permission prompts**: it can edit files and run commands unattended. It is not defined by default. Opt in per machine with `set -Ux DEV_SETUP_UNSAFE_CLY 1`, undo with `set -e DEV_SETUP_UNSAFE_CLY`.
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
