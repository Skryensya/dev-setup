#!/usr/bin/env bash
# Idempotent macOS dev setup. Run again any time: installed things are skipped.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
have() { command -v "$1" >/dev/null 2>&1; }
die()  { printf '\n✗ %s\n' "$*" >&2; exit 1; }
warn() { printf '    ⚠ %s\n' "$*" >&2; }

# Opciones: --no-shell (o DEV_SETUP_SKIP_SHELL=1) no toca el shell de login.
SET_SHELL=true
for arg in "$@"; do
  case $arg in
    --no-shell) SET_SHELL=false ;;
    -h|--help) echo "Uso: ./install.sh [--no-shell]"; exit 0 ;;
    *) die "opción desconocida: $arg (usa --help)" ;;
  esac
done
if [ -n "${DEV_SETUP_SKIP_SHELL:-}" ]; then SET_SHELL=false; fi

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
trap 'printf "\n✗ Falló el paso «%s» (línea %s)\n" "$CUR" "$LINENO" >&2' ERR

# install_file <origen> <destino>: copia solo si cambió y respalda lo anterior antes de pisarlo.
install_file() {
  local src=$1 dest=$2 bak
  [ -f "$src" ] || die "falta $src en el repo"
  if cmp -s "$src" "$dest" 2>/dev/null; then skip "$(basename "$dest")"; return; fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    bak="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$dest" "$bak"
    echo "    backup en $bak"
  fi
  cp "$src" "$dest"
}

# Xcode Command Line Tools (brew también los instala, pero así queda explícito)
log "Xcode Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then skip xcode-tools; else
  xcode-select --install || warn "xcode-select --install falló (¿ya hay un instalador abierto?)"
  echo "    Termina el instalador gráfico y vuelve a correr ./install.sh"; exit 0
fi

# Homebrew (Apple Silicon: /opt/homebrew, Intel: /usr/local)
log "Homebrew"
find_brew() {
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then eval "$("$b" shellenv)"; return 0; fi
  done
  return 1
}
if find_brew || have brew; then skip brew; else
  [ -t 0 ] || export NONINTERACTIVE=1  # sin terminal, el instalador de brew no puede preguntar nada
  brew_installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) \
    || die "no pude descargar el instalador de Homebrew"
  /bin/bash -c "$brew_installer"
  find_brew || die "Homebrew no quedó instalado"
fi
have brew || die "no encuentro brew en el PATH"

# Un binario cuenta como instalado salvo que sea el del sistema (p. ej. el vim de macOS).
bin_installed() {
  local p
  p=$(command -v "$1") || return 1
  case $p in /usr/bin/*|/bin/*|/usr/sbin/*|/sbin/*) return 1 ;; esac
}
brew_pkg() { # brew_pkg <formula> [binario]
  if brew list --formula "$1" >/dev/null 2>&1 || bin_installed "${2:-$1}"; then skip "$1"; else brew install "$1"; fi
}

log "fish"
if brew list --formula fish >/dev/null 2>&1; then skip fish; else brew install fish; fi
FISH="$(brew --prefix)/bin/fish"
[ -x "$FISH" ] || die "no encuentro fish en $FISH"

# nvm.fish (vía fisher), con versiones fijas: nvm-sh es bash y no carga en fish.
log "nvm (fish)"
if "$FISH" -c 'functions -q nvm'; then skip nvm; else
  "$FISH" -c 'curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/4.4.8/functions/fisher.fish | source; and fisher install jorgebucaran/fisher@4.4.8 jorgebucaran/nvm.fish@2.2.17'
  "$FISH" -c 'functions -q nvm' || die "nvm.fish no quedó instalado"
fi

log "pnpm";    brew_pkg pnpm
log "ni";      brew_pkg ni
log "zellij";  brew_pkg zellij

log "Ghostty"
if [ -d /Applications/Ghostty.app ] || brew list --cask ghostty >/dev/null 2>&1; then skip ghostty; else
  brew install --cask ghostty
fi

# nvm.fish solo activa nvm_default_version en shells interactivos, así que desde bash
# se activa a mano. Un node cualquiera en el PATH no prueba que nvm.fish esté configurado.
log "Node (nvm.fish)"
nvm_node_bin() { "$FISH" -c 'nvm use --silent default >/dev/null 2>&1; or exit 1; dirname (command -s node)'; }
if NODE_BIN=$(nvm_node_bin 2>/dev/null); then skip "node (default de nvm.fish)"; else
  # `nvm install` no vuelve a bajar una versión ya instalada y deja intactas las demás.
  "$FISH" -c 'nvm install lts; and set --universal nvm_default_version (nvm current)' \
    || die "no pude instalar Node LTS con nvm.fish"
  NODE_BIN=$(nvm_node_bin) || die "Node se instaló pero nvm.fish no logra activarlo"
fi
export PATH="$NODE_BIN:$PATH"
for tool in node npm npx; do
  "$tool" --version >/dev/null 2>&1 || die "$tool no funciona con el Node de nvm.fish ($NODE_BIN)"
done
echo "    node $(node --version), npm $(npm --version)"

log "Claude Code"
if have claude; then skip claude; else curl -fsSL https://claude.ai/install.sh | bash; fi
export PATH="$HOME/.local/bin:$PATH"

log "pi agent"
if have pi; then skip pi; else npm install -g @earendil-works/pi-coding-agent; fi

log "Mod usage-hud"
mod="$HOME/.claude/mods/usage-hud"
if ! plugins=$(claude plugin list 2>&1); then
  warn "no pude listar los plugins de Claude Code, salto usage-hud: $plugins"
elif grep -q 'usage-hud@' <<<"$plugins"; then skip usage-hud; else
  mkdir -p "$mod" && cp -R "$DIR/mods/usage-hud/." "$mod/"
  claude plugin marketplace add "$mod"
  claude plugin install usage-hud@allison-mods
fi

log "gh";     brew_pkg gh

log "yazi";   brew_pkg yazi

log "neovim"; brew_pkg neovim nvim

log "zoxide + eza";  brew_pkg zoxide; brew_pkg eza

log "atuin, lazygit, ripgrep, bat"; brew_pkg atuin; brew_pkg lazygit; brew_pkg ripgrep rg; brew_pkg bat

log "Shell: config de fish"
# conf.d lo carga fish solo. Lo tuyo va en conf.d/local.fish, que este repo nunca toca.
install_file "$DIR/config/fish/conf.d/dev-setup.fish" "$HOME/.config/fish/conf.d/dev-setup.fish"

log "Docker"
if [ -d /Applications/Docker.app ] || brew list --cask docker-desktop >/dev/null 2>&1; then skip docker; else
  brew install --cask docker-desktop
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

# Extensiones de pi: usage-hud (HUD de contexto) y search-browser (web_search con SearXNG en Docker).
log "pi extensions"
for ext in "$DIR"/pi/extensions/*/; do
  [ -d "$ext" ] || continue
  name=$(basename "$ext"); dest="$HOME/.pi/agent/extensions/$name"
  if [ -e "$dest" ]; then skip "pi/$name"; else mkdir -p "$dest" && cp -R "$ext." "$dest/"; fi
done

log "Skills: emilkowalski"
skill_add emilkowalski/skills animate apple-design break-ui emil-design-eng \
  find-animation-opportunities improve-animations mobile-native pick-ui-library \
  prototype review-animations

log "Skills: mattpocock (planificación y git)"
skill_add mattpocock/skills grill-me grill-with-docs grilling to-spec to-tickets \
  to-questionnaire wayfinder wizard retro teach wait-what \
  git-guardrails-claude-code setup-pre-commit setup-ts-deep-modules setup-matt-pocock-skills

log "Config de zellij"
install_file "$DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"

log "Shell por defecto: fish"
SHELL_HINT=""
login_shell() { dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'; }
if ! $SET_SHELL; then echo "    - omitido (--no-shell)"
elif [ "$(login_shell)" = "$FISH" ]; then skip "fish por defecto"
else
  MANUAL="    grep -qx $FISH /etc/shells || echo $FISH | sudo tee -a /etc/shells
    sudo chsh -s $FISH $(id -un)"
  # Sin terminal ni sudo sin contraseña no se intenta: no hay quien escriba la contraseña.
  if [ -t 0 ] || sudo -n true 2>/dev/null; then
    if { grep -qx "$FISH" /etc/shells || echo "$FISH" | sudo tee -a /etc/shells >/dev/null; } \
      && sudo chsh -s "$FISH" "$(id -un)"; then
      echo "    ✓ fish es ahora tu shell por defecto"
    else
      SHELL_HINT="No pude cambiar el shell de login (no afecta al resto de la instalación). Hazlo tú:
$MANUAL
  y abre una terminal nueva (o reinicia Ghostty)."
    fi
  else
    SHELL_HINT="Sin terminal interactiva no cambié el shell de login. Para hacerlo:
$MANUAL
  y abre una terminal nueva (o reinicia Ghostty)."
  fi
fi

log "Listo ✔  (abre una terminal nueva para usar fish)"
[ -z "$SHELL_HINT" ] || printf '\n⚠ %s\n' "$SHELL_HINT"
