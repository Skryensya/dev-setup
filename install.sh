#!/usr/bin/env bash
# Idempotent macOS dev setup. Run again any time: installed things are skipped.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
have() { command -v "$1" >/dev/null 2>&1; }

# Progreso: barra fija abajo (logs scrollean arriba). Sin TTY, solo imprime el %.
STEPS=$(( $(grep -c '^log "' "$0") - 1 )); DONE=0; CUR=""
TTY=false; [ -t 1 ] && TTY=true
if $TTY; then
  ROWS=$(tput lines)
  printf '\n'; tput csr 0 $((ROWS - 2)); tput cup $((ROWS - 2)) 0
  trap 'tput csr 0 $((ROWS - 1)); tput cup $((ROWS - 1)) 0; echo' EXIT
fi
bar() {
  local pct=$(( DONE * 100 / STEPS )) w=30 f i b=""
  f=$(( pct * w / 100 ))
  for ((i = 0; i < w; i++)); do [ $i -lt $f ] && b+="█" || b+="░"; done
  if $TTY; then
    tput sc; tput cup $((ROWS - 1)) 0; tput el
    printf ' %s %3d%%  (%d/%d) %s' "$b" "$pct" "$DONE" "$STEPS" "$CUR"; tput rc
  else printf '    [%3d%%] %d/%d\n' "$pct" "$DONE" "$STEPS"; fi
}
log() { [ -n "$CUR" ] && DONE=$((DONE + 1)); CUR="$*"; printf '\n==> %s\n' "$*"; bar; }
skip() { printf '    ✓ %s ya instalado, skip\n' "$*"; }

# Xcode Command Line Tools (brew también los instala, pero así queda explícito)
log "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then skip xcode-tools; else
  xcode-select --install || true
  echo "    Termina el instalador gráfico y vuelve a correr ./install.sh"; exit 0
fi

# Homebrew
log "Homebrew"
if have brew; then skip brew; else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Apple Silicon vs Intel
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [ -x "$b" ] && eval "$("$b" shellenv)"; done

brew_pkg() { # brew_pkg <formula> [binario]
  if brew list --formula "$1" >/dev/null 2>&1 || have "${2:-$1}"; then skip "$1"; else brew install "$1"; fi
}

log "nvm"
if [ -s "$HOME/.nvm/nvm.sh" ] || brew list --formula nvm >/dev/null 2>&1; then skip nvm; else
  brew install nvm
  mkdir -p "$HOME/.nvm"
  grep -q 'NVM_DIR' "$HOME/.zshrc" 2>/dev/null || cat >> "$HOME/.zshrc" <<'EOF'

export NVM_DIR="$HOME/.nvm"
[ -s "$(brew --prefix nvm)/nvm.sh" ] && . "$(brew --prefix nvm)/nvm.sh"
EOF
fi

# macOS ya trae /bin/zsh (viejo), así que se revisa brew, no el PATH.
log "zsh"
if brew list --formula zsh >/dev/null 2>&1; then skip zsh; else brew install zsh; fi

log "pnpm";    brew_pkg pnpm
log "ni";      brew_pkg ni
log "zellij";  brew_pkg zellij

log "Ghostty"
if [ -d /Applications/Ghostty.app ] || brew list --cask ghostty >/dev/null 2>&1; then skip ghostty; else
  brew install --cask ghostty
fi

log "Node (nvm)"
if have node; then skip node; else
  . "$(brew --prefix nvm)/nvm.sh"; nvm install --lts
fi

log "Claude Code"
if have claude; then skip claude; else curl -fsSL https://claude.ai/install.sh | bash; fi
export PATH="$HOME/.local/bin:$PATH"

log "pi agent"
if have pi; then skip pi; else npm install -g @earendil-works/pi-coding-agent; fi

log "Mod usage-hud"
mod="$HOME/.claude/mods/usage-hud"
plugins=$(claude plugin list 2>/dev/null || true)
if grep -q 'usage-hud@' <<<"$plugins"; then skip usage-hud; else
  mkdir -p "$mod" && cp -R "$DIR/mods/usage-hud/." "$mod/"
  claude plugin marketplace add "$mod"
  claude plugin install usage-hud@allison-mods
fi

log "gh";     brew_pkg gh

log "yazi";   brew_pkg yazi

log "neovim"; brew_pkg neovim nvim

log "zoxide + eza";  brew_pkg zoxide; brew_pkg eza

log "Shell: cd -> zoxide, ls -> eza"
# .zshrc solo lo lee el zsh interactivo: los scripts siguen usando cd/ls normales.
if grep -q '# dev-setup: zoxide/eza' "$HOME/.zshrc" 2>/dev/null; then skip "alias en .zshrc"; else
  cat >> "$HOME/.zshrc" <<'EOF'

# dev-setup: zoxide/eza
eval "$(zoxide init zsh --cmd cd)"
alias ls='eza'
EOF
fi

log "Docker"
if [ -d /Applications/Docker.app ] || brew list --cask docker-desktop >/dev/null 2>&1; then skip docker; else
  brew install --cask docker-desktop
fi

log "Shell: vim -> nvim"
if grep -q '# dev-setup: nvim' "$HOME/.zshrc" 2>/dev/null; then skip "alias vim"; else
  printf "\n# dev-setup: nvim\nalias vim='nvim'\n" >> "$HOME/.zshrc"
fi

# skills.sh (CLI de Vercel, se corre con npx): solo instala las que falten.
skill_add() { # skill_add <repo> <skill>...
  local repo=$1 skill missing=()
  shift
  for skill in "$@"; do [ -e "$HOME/.claude/skills/$skill" ] || missing+=("$skill"); done
  if [ ${#missing[@]} -eq 0 ]; then skip "$repo"; else
    npx -y skills add "$repo" -g -y -a claude-code -s "${missing[@]}"
  fi
}

log "Skills: emilkowalski"
skill_add emilkowalski/skills animate apple-design break-ui emil-design-eng \
  find-animation-opportunities improve-animations mobile-native pick-ui-library \
  prototype review-animations

log "Skills: mattpocock (planificación y git)"
skill_add mattpocock/skills grill-me grill-with-docs grilling to-spec to-tickets \
  to-questionnaire wayfinder wizard retro teach wait-what \
  git-guardrails-claude-code setup-pre-commit setup-ts-deep-modules setup-matt-pocock-skills

log "Config de zellij"
dest="$HOME/.config/zellij/config.kdl"
mkdir -p "$(dirname "$dest")"
if cmp -s "$DIR/config/zellij/config.kdl" "$dest" 2>/dev/null; then skip "config zellij"; else
  [ -e "$dest" ] && cp "$dest" "$dest.bak" && echo "    backup en $dest.bak"
  cp "$DIR/config/zellij/config.kdl" "$dest"
fi

log "Listo ✔  (abre una terminal nueva para cargar nvm)"
