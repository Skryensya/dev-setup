# dev-setup

Quick start for a new macOS dev environment. One command installs my tools and
config. Run it again any time: anything already installed is skipped.

```sh
git clone https://github.com/Skryensya/dev-setup && cd dev-setup && ./install.sh
```

A progress bar stays at the bottom of the terminal while logs scroll above it.

## What it sets up

| Area | Installed |
|---|---|
| Base | Xcode Command Line Tools, Homebrew, fish (set as default shell) |
| Node | nvm.fish (and Node LTS if none), pnpm, [ni](https://github.com/antfu-collective/ni) |
| Terminal | Ghostty, zellij (with my config), yazi, neovim, zoxide, eza |
| Dev | gh, Docker Desktop |
| AI | Claude Code, [pi](https://github.com/earendil-works/pi), the `usage-hud` Claude Code mod, pi extensions (`usage-hud` HUD, `search-browser`: `web_search` through SearXNG in Docker) |
| Skills | [skills.sh](https://skills.sh) packages from `emilkowalski/skills` and `mattpocock/skills` |

## Notes

- **Xcode tools:** if missing, the script opens macOS's installer and exits. Rerun it when that finishes.
- **Shell:** fish becomes the default shell (asks for your password once). `~/.config/fish/config.fish` gets `cd` → zoxide, `ls` → eza and `vim` → nvim, interactive sessions only; scripts keep the normal commands. Your old `~/.zshrc` is left alone. Open a new terminal to load it.
- **zellij config:** copied to `~/.config/zellij/config.kdl`; an existing different file is saved as `config.kdl.bak`.
- **pi search:** `web_search` starts the SearXNG container (`127.0.0.1:8888`) on first use, so Docker Desktop must be running. `/search-browser-up` and `/search-browser-down` control it.
- **GitHub:** run `gh auth login` yourself afterwards.
- **Adding a tool:** one line, `brew_pkg <name>` (or `brew_pkg <formula> <binary>` when they differ) in `install.sh`.

## Layout

```
install.sh                 the installer
config/zellij/config.kdl   zellij config
mods/usage-hud/            Claude Code HUD mod
pi/extensions/             pi extensions (usage-hud, search-browser)
```
