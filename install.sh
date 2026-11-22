#!/usr/bin/env bash
# Idempotent macOS dev setup. Run again any time: installed things are skipped.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
have() { command -v "$1" >/dev/null 2>&1; }
# Colores solo con terminal (y sin NO_COLOR); si no, todas las variables quedan vacías.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\e[0m' B=$'\e[1m' D=$'\e[2m' RED=$'\e[38;5;203m' GRN=$'\e[38;5;114m' YLW=$'\e[38;5;221m' CYN=$'\e[38;5;81m' ORG=$'\e[38;5;215m'
else R="" B="" D="" RED="" GRN="" YLW="" CYN="" ORG=""; fi
die()  { printf '\n%s✗ %s%s\n' "$RED$B" "$*" "$R" >&2; exit 1; }
note() { printf '    %s→%s %s%s%s\n' "$CYN" "$R" "$D" "$*" "$R"; }
okay() { printf '    %s✓ %s%s\n' "$GRN" "$*" "$R"; }
warn() { printf '    %s⚠ %s%s\n' "$YLW" "$*" "$R" >&2; }

# Opciones: --no-shell (o DEV_SETUP_SKIP_SHELL=1; solo el valor 1) no toca el shell de login.
SET_SHELL=true; CHOOSE=true
for arg in "$@"; do
  case $arg in
    --no-shell) SET_SHELL=false ;;
    -y|--yes) CHOOSE=false ;;
    -h|--help) echo "Uso: ./install.sh [-y|--yes] [--no-shell]
  (con terminal abre un menú para elegir; -y instala el conjunto por defecto sin preguntar)"; exit 0 ;;
    *) die "opción desconocida: $arg (usa --help)" ;;
  esac
done
if [ "${DEV_SETUP_SKIP_SHELL:-}" = 1 ]; then SET_SHELL=false; fi

# --- selección -----------------------------------------------------------------------------------
# Lo que se puede elegir: id|1 (por defecto) o 0 (opcional)|descripción. Las líneas con # son grupos.
# Cada paso de abajo se ata a un id con `log "Nombre" id`; sin id, el paso siempre corre.
CATALOG='#Herramientas de terminal
pnpm|1|pnpm
ni|1|ni (un comando para npm, pnpm y yarn)
zellij|1|zellij con mi config
neovim|1|neovim (vim abre nvim)
yazi|1|yazi (explorador de archivos)
gh|1|gh (GitHub CLI)
zoxide|1|zoxide + eza
shell-tools|1|atuin, lazygit, ripgrep, bat
cli-tools|1|xh, lazydocker, fzf, fd, jq
font|1|JetBrains Mono Nerd Font
#Apps
ghostty|1|Ghostty
chrome|1|Google Chrome
docker|1|Docker Desktop
slack|0|Slack
discord|0|Discord
teams|0|Microsoft Teams
#Agentes de IA
claude|1|Claude Code + HUD usage-hud
pi|1|pi agent + extensiones
skills-emil|1|Skills de emilkowalski
skills-matt|1|Skills de mattpocock (planificación y git)'

IDS=() DEF=() LABEL=() GROUP=(); grp=""
while IFS='|' read -r id def label; do
  case $id in '#'*) grp=${id#\#}; continue ;; esac
  IDS+=("$id"); DEF+=("$def"); LABEL+=("$label"); GROUP+=("$grp")
done <<<"$CATALOG"
ON=("${DEF[@]}")
selected_ids() { local i out=" "; for i in "${!IDS[@]}"; do [ "${ON[i]}" = 1 ] && out+="${IDS[i]} "; done; echo "$out"; }
want() { case "$SELECTED" in *" $1 "*) return 0 ;; esac; return 1; }
SELECTED=$(selected_ids)

# Menú (Bash puro, sin dependencias). Solo con terminal. Convenciones: flechas o j/k para moverse,
# espacio marca, enter confirma, esc o q cancelan; todas las teclas están en la barra de abajo; el
# estado se ve en el texto ([x]), no solo en el color; se adapta al tamaño de la ventana.
tui_off() { printf '\e[?25h\e[?1049l'; }
choose() {
  local n=${#IDS[@]} cur=0 top=0 i r key rest prev crow page rows cols lab mark ptr cnt up down foot size="" now
  local L=() LI=()
  trap 'tui_off; exit 130' INT TERM
  printf '\e[?1049h\e[?25l'
  while :; do
    rows=$(tput lines); cols=$(tput cols); now="$rows x $cols"
    if [ "${need:-1}" = 1 ] || [ "$now" != "$size" ]; then
      size=$now; need=0; L=(); LI=(); prev="__"; crow=0; cnt=0
      for ((i = 0; i < n; i++)); do
        if [ "${GROUP[i]}" != "$prev" ]; then L+=("${B}${GROUP[i]}${R}"); LI+=(-1); prev=${GROUP[i]}; fi
        mark="[ ]"; ptr=" "; lab=${LABEL[i]}
        if [ "${ON[i]}" = 1 ]; then mark="${GRN}[x]${R}"; cnt=$((cnt + 1)); fi
        if [ $i -eq $cur ]; then ptr="${CYN}❯${R}"; lab="${B}${lab}${R}"; crow=${#L[@]}; fi
        L+=("  $ptr $mark $lab"); LI+=("$i")
      done
      page=$((rows - 5)); [ $page -ge 3 ] || page=3
      [ $crow -ge $top ] || top=$crow
      [ $crow -lt $((top + page)) ] || top=$((crow - page + 1))
      if [ $crow -gt 0 ] && [ "${LI[crow - 1]}" = -1 ] && [ $top -gt $((crow - 1)) ]; then top=$((crow - 1)); fi
      up=" "; down=" "
      [ $top -eq 0 ] || up="↑"
      [ $((top + page)) -ge ${#L[@]} ] || down="↓"
      printf '\e[H %sdev-setup%s · elige qué instalar  %s%d de %d marcados %s%s%s\e[K\n\n' "$ORG$B" "$R" "$D" "$cnt" "$n" "$up" "$down" "$R"
      for ((r = top; r < top + page && r < ${#L[@]}; r++)); do printf '%s\e[K\n' "${L[r]}"; done
      printf '\e[J'
      foot="↑↓ mover · espacio marcar · a todo · n nada · d por defecto · enter instalar · esc salir"
      printf '\e[%d;1H%s%s%s\e[K' "$rows" "$D" "${foot:0:$((cols - 1))}" "$R"
    fi
    # Sin tecla en 1 s: solo revisa si cambió el tamaño. (El código de salida del timeout cambia entre
    # versiones de Bash, p. ej. 1 en la 3.2 de macOS, así que no se distingue de otro fallo de lectura.)
    IFS= read -rsn1 -t 1 key || continue
    need=1
    case $key in
      $'\e') rest=""; IFS= read -rsn2 -t 1 rest || true
             case $rest in
               '[A') [ $cur -le 0 ] || cur=$((cur - 1)) ;;
               '[B') [ $cur -ge $((n - 1)) ] || cur=$((cur + 1)) ;;
               '') tui_off; trap - INT TERM; echo "cancelado"; exit 130 ;;
             esac ;;
      k) [ $cur -le 0 ] || cur=$((cur - 1)) ;;
      j) [ $cur -ge $((n - 1)) ] || cur=$((cur + 1)) ;;
      g) cur=0 ;;
      G) cur=$((n - 1)) ;;
      ' ') if [ "${ON[cur]}" = 1 ]; then ON[cur]=0; else ON[cur]=1; fi ;;
      a) for ((i = 0; i < n; i++)); do ON[i]=1; done ;;
      n) for ((i = 0; i < n; i++)); do ON[i]=0; done ;;
      d) ON=("${DEF[@]}") ;;
      q) tui_off; trap - INT TERM; echo "cancelado"; exit 130 ;;
      '') break ;;
    esac
  done
  tui_off; trap - INT TERM
}
# El menú sale siempre que haya terminal; sin terminal (pipe, CI) o con -y se usa el conjunto por defecto.
if $CHOOSE && [ -t 0 ] && [ -t 1 ]; then choose; SELECTED=$(selected_ids); fi

# Los pasos (nombre|id) salen de los `log "..."` de este archivo, así la lista nunca se desfasa.
# El último `log` es el cierre, no un paso. Solo cuentan los pasos elegidos.
PLAN=()
while IFS='|' read -r name id; do
  if [ -z "$id" ] || want "$id"; then PLAN+=("$name"); fi
done < <(grep -E '^(if )?log "' "$0" | sed -E 's/^(if )?log "([^"]*)" *([a-z0-9-]*).*/\2|\3/' | sed '$d')
# --- fin selección -------------------------------------------------------------------------------

# Progreso en el flujo normal de la terminal (sin región de scroll ni procesos de fondo): el scroll y
# el historial funcionan.
STEPS=${#PLAN[@]}; DONE=0; CUR=""
# Barra con ocheavos de bloque, degradado cian → verde, verde sólido al 100%. El braille de la
# izquierda avanza un frame por paso.
bar() {
  local pct=$(( DONE * 100 / STEPS )) w=28 i b="" eighths full part time lead
  local parts=(" " ▏ ▎ ▍ ▌ ▋ ▊ ▉) frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  eighths=$(( DONE * w * 8 / STEPS )); full=$(( eighths / 8 )); part=$(( eighths % 8 ))
  for ((i = 0; i < w; i++)); do
    if [ $i -lt $full ]; then
      [ -n "$R" ] && b+=$'\e[38;5;'$([ $pct -ge 100 ] && echo 114 || echo $((51 - i * 5 / 27)))'m'; b+="█"
    elif [ $i -eq $full ] && [ $part -gt 0 ]; then
      [ -n "$R" ] && b+=$'\e[38;5;45;48;5;238m'; b+="${parts[$part]}"
    else [ -n "$R" ] && b+=$'\e[38;5;238m'; b+="▒"; fi
  done; b+="$R"
  lead="${CYN}${frames[DONE % 10]}${R}"; [ $DONE -lt $STEPS ] || lead="${GRN}✔${R}"
  printf -v time '%d:%02d' $((SECONDS / 60)) $((SECONDS % 60))
  printf '  %s %s %s%3d%%%s %s%s · %d/%d%s\n' "$lead" "$b" "$B" "$pct" "$R" "$D" "$time" "$DONE" "$STEPS" "$R"
}
# Un título por paso con su contador; el % en vivo va en el título de la ventana (no ensucia el
# log ni el scroll) y la barra completa se imprime una sola vez, al final.
log() { # log "Nombre" [id]: con id, el paso solo corre si ese id está elegido (devuelve 1 si no)
  [ -z "${2:-}" ] || want "$2" || return 1
  [ -n "$CUR" ] && DONE=$((DONE + 1)); CUR="$1"
  printf '\n%s▶%s %s%s%s %s%d/%d%s\n' "$ORG$B" "$R" "$B" "$1" "$R" "$D" "$((DONE + 1 > STEPS ? STEPS : DONE + 1))" "$STEPS" "$R"
  if [ $DONE -ge $STEPS ]; then bar; fi
  if [ -t 1 ]; then printf '\e]0;dev-setup %d%% · %s\a' $((DONE * 100 / STEPS)) "$1"; fi
  return 0
}
skip() { printf '    %s✓%s %s %sya instalado, skip%s\n' "$GRN" "$R" "$*" "$D" "$R"; }
trap 'printf "\n%s✗ Falló el paso «%s» (línea %s)%s\n" "$RED$B" "$CUR" "$LINENO" "$R" >&2' ERR

# El procedimiento: los pasos reales, en orden (se leen de los `log "..."` de este archivo, así
# nunca se desfasan). El último `log` es el cierre, no un paso.
printf '\n%s┌ dev-setup%s %s· %d pasos%s\n' "$ORG$B" "$R" "$D" "$STEPS" "$R"
n=0
for name in "${PLAN[@]}"; do
  n=$((n + 1))
  glyph="├─"; [ $n -lt $STEPS ] || glyph="└─"
  printf '%s%s%s %s%2d%s  %s\n' "$D" "$glyph" "$R" "$ORG" "$n" "$R" "$name"
done

# Los backups de carpetas van fuera de ~/.pi y ~/.claude: pi cargaría una copia como extensión duplicada.
BACKUP_DIR="$HOME/.dev-setup-backups/$(date +%Y%m%d-%H%M%S)"

# install_dir <origen> <destino>: sincroniza los archivos del repo si alguno cambió.
# Respalda la carpeta actual, y no borra archivos extra del destino (p. ej. los que genera SearXNG).
install_dir() {
  local src=${1%/} dest=${2%/} f changed=false bak
  [ -d "$src" ] || die "falta $src en el repo"
  while IFS= read -r f; do
    cmp -s "$src/$f" "$dest/$f" 2>/dev/null || { changed=true; break; }
  done < <(cd "$src" && find . -type f -not -name .DS_Store)
  if ! $changed; then skip "$(basename "$dest")"; return; fi
  if [ -d "$dest" ]; then
    bak="$BACKUP_DIR/$(basename "$dest")"
    mkdir -p "$bak" && cp -R "$dest/." "$bak/"
    note "backup en $bak"
  fi
  mkdir -p "$dest" && cp -R "$src/." "$dest/"
  okay "actualizado: $dest ${D}(reinicia la app para cargarlo)"
}

# install_file <origen> <destino>: copia solo si cambió y respalda lo anterior antes de pisarlo.
install_file() {
  local src=$1 dest=$2 bak
  [ -f "$src" ] || die "falta $src en el repo"
  if cmp -s "$src" "$dest" 2>/dev/null; then skip "$(basename "$dest")"; return; fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ]; then
    bak="$dest.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "$dest" "$bak"
    note "backup en $bak"
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
cask_app() { # cask_app <cask> <Nombre.app sin .app>
  if [ -d "/Applications/$2.app" ] || brew list --cask "$1" >/dev/null 2>&1; then skip "$2"; else brew install --cask "$1"; fi
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

log "pnpm" pnpm && brew_pkg pnpm
log "ni" ni && brew_pkg ni
log "zellij" zellij && brew_pkg zellij

log "Ghostty" ghostty && cask_app ghostty Ghostty

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
okay "node ${B}$(node --version)${R}${GRN}, npm ${B}$(npm --version)"

export PATH="$HOME/.local/bin:$PATH"
if log "Claude Code" claude; then
  if have claude; then skip claude; else curl -fsSL https://claude.ai/install.sh | bash; fi
fi

if log "pi agent" pi; then
  if have pi; then skip pi; else npm install -g @earendil-works/pi-coding-agent; fi
fi

if log "Mod usage-hud" claude; then
mod="$HOME/.claude/mods/usage-hud"
install_dir "$DIR/mods/usage-hud" "$mod"
if ! plugins=$(claude plugin list 2>&1); then
  warn "no pude listar los plugins de Claude Code, no registro usage-hud: $plugins"
elif grep -q 'usage-hud@' <<<"$plugins"; then skip "usage-hud (registrado)"; else
  claude plugin marketplace add "$mod"
  claude plugin install usage-hud@allison-mods
fi
fi

log "gh" gh && brew_pkg gh
log "yazi" yazi && brew_pkg yazi
log "neovim" neovim && brew_pkg neovim nvim
log "zoxide + eza" zoxide && { brew_pkg zoxide; brew_pkg eza; }
log "atuin, lazygit, ripgrep, bat" shell-tools && { brew_pkg atuin; brew_pkg lazygit; brew_pkg ripgrep rg; brew_pkg bat; }
log "xh, lazydocker, fzf, fd, jq" cli-tools && { brew_pkg xh; brew_pkg lazydocker; brew_pkg fzf; brew_pkg fd; brew_pkg jq; }

log "Fuente: JetBrains Mono Nerd Font" font && {
  if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then skip "nerd font"; else
    brew install --cask font-jetbrains-mono-nerd-font
  fi
}

log "Shell: config de fish"
# conf.d lo carga fish solo. Lo tuyo va en conf.d/local.fish, que este repo nunca toca.
install_file "$DIR/config/fish/conf.d/dev-setup.fish" "$HOME/.config/fish/conf.d/dev-setup.fish"

log "Google Chrome" chrome && cask_app google-chrome "Google Chrome"
log "Docker" docker && cask_app docker-desktop Docker
log "Slack" slack && cask_app slack Slack
log "Discord" discord && cask_app discord Discord
log "Microsoft Teams" teams && cask_app microsoft-teams "Microsoft Teams"

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
if log "pi extensions" pi; then
  for ext in "$DIR"/pi/extensions/*/; do
    [ -d "$ext" ] || continue
    install_dir "$ext" "$HOME/.pi/agent/extensions/$(basename "$ext")"
  done
fi

log "Skills: emilkowalski" skills-emil && skill_add emilkowalski/skills animate apple-design break-ui emil-design-eng \
  find-animation-opportunities improve-animations mobile-native pick-ui-library \
  prototype review-animations

log "Skills: mattpocock (planificación y git)" skills-matt && skill_add mattpocock/skills grill-me grill-with-docs grilling to-spec to-tickets \
  to-questionnaire wayfinder wizard retro teach wait-what \
  git-guardrails-claude-code setup-pre-commit setup-ts-deep-modules setup-matt-pocock-skills

log "Config de zellij" zellij && install_file "$DIR/config/zellij/config.kdl" "$HOME/.config/zellij/config.kdl"
log "Layouts de zellij (zp)" zellij && for f in "$DIR"/config/zellij/layouts/*.kdl; do install_file "$f" "$HOME/.config/zellij/layouts/$(basename "$f")"; done
log "Preview de zp" zellij && install_file "$DIR/config/zp/preview.sh" "$HOME/.config/zp/preview.sh"

log "Shell por defecto: fish"
SHELL_HINT=""
login_shell() { dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'; }
if ! $SET_SHELL; then note "omitido (--no-shell)"
elif [ "$(login_shell)" = "$FISH" ]; then skip "fish por defecto"
else
  MANUAL="    grep -qx $FISH /etc/shells || echo $FISH | sudo tee -a /etc/shells
    sudo chsh -s $FISH $(id -un)"
  # Sin terminal ni sudo sin contraseña no se intenta: no hay quien escriba la contraseña.
  if [ -t 0 ] || sudo -n true 2>/dev/null; then
    if { grep -qx "$FISH" /etc/shells || echo "$FISH" | sudo tee -a /etc/shells >/dev/null; } \
      && sudo chsh -s "$FISH" "$(id -un)"; then
      printf '    %s✓ fish es ahora tu shell por defecto%s\n' "$GRN" "$R"
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
[ -z "$SHELL_HINT" ] || printf '\n%s⚠ %s%s\n' "$YLW" "$SHELL_HINT" "$R"
