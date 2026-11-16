#!/usr/bin/env bash
# Read-only checks for this repo: installs nothing, never touches your real config.
set -uo pipefail
cd "$(dirname "$0")/.."

pass=0 fail=0 skipped=0
ok()   { pass=$((pass + 1));       printf '  ok    %s\n' "$*"; }
bad()  { fail=$((fail + 1));       printf '  FAIL  %s\n' "$*"; }
skip() { skipped=$((skipped + 1)); printf '  SKIP  %s\n' "$*"; }
check() { local label=$1; shift; if "$@" >/dev/null 2>&1; then ok "$label"; else bad "$label"; fi; }

echo "Repository files"
for f in install.sh scripts/validate.sh README.md WORKFLOW.md config/zellij/config.kdl \
  config/fish/conf.d/dev-setup.fish mods/usage-hud/.claude-plugin/plugin.json \
  pi/extensions/usage-hud/index.ts pi/extensions/search-browser/index.ts \
  pi/extensions/search-browser/docker-compose.yml; do
  check "$f exists" test -f "$f"
done
check "install.sh is executable" test -x install.sh

echo "Bash syntax"
check "install.sh" bash -n install.sh
check "scripts/validate.sh" bash -n scripts/validate.sh

echo "Fish"
FISH=$(command -v fish || true)
[ -n "$FISH" ] || for p in /opt/homebrew/bin/fish /usr/local/bin/fish; do [ -x "$p" ] && FISH=$p && break; done
if [ -z "$FISH" ]; then
  skip "fish not found: syntax and load checks not run"
else
  for f in config/fish/conf.d/*.fish; do check "syntax $f" "$FISH" --no-execute "$f"; done
  # Load the config in a throwaway HOME. Any output means an error or noise.
  home=$(mktemp -d); trap 'rm -rf "$home"' EXIT
  for mode in "-c" "-ic"; do
    for path in "$PATH" "/usr/bin:/bin"; do  # second run: no optional tool is installed
      out=$(env HOME="$home" PATH="$path" "$FISH" --no-config "$mode" 'source config/fish/conf.d/dev-setup.fish' 2>&1)
      if [ -z "$out" ]; then ok "loads cleanly (fish $mode, PATH=${path:0:12}...)"; else bad "loads with output (fish $mode): $out"; fi
    done
  done
  path_out=$(env HOME="$home" PATH="/usr/bin:/bin" "$FISH" --no-config -c 'source config/fish/conf.d/dev-setup.fish; printf "%s\n" $PATH' 2>&1)
  check "PATH keeps system entries" grep -qx /usr/bin <<<"$path_out"
  [ "$(sort <<<"$path_out" | uniq -d | wc -l)" -eq 0 ] && ok "no duplicate PATH entries" || bad "duplicate PATH entries"
fi

echo "Configuration"
check "no Zellij layouts directory" test ! -e config/zellij/layouts
check "install.sh does not install Zellij layouts" bash -c '! grep -qi layout install.sh'
check "unsafe cly alias is opt-in" grep -q 'set -q DEV_SETUP_UNSAFE_CLY; and alias cly' config/fish/conf.d/dev-setup.fish
check "no credentials in the repo" bash -c '! grep -rIlE "passwd-on-stdin|BEGIN [A-Z ]*PRIVATE KEY" . --exclude-dir=.git --exclude=validate.sh'
if command -v zellij >/dev/null 2>&1; then
  check "zellij accepts config.kdl" zellij --config config/zellij/config.kdl setup --check
else
  skip "zellij not found: config.kdl not checked"
fi

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skipped"
[ "$skipped" -eq 0 ] || echo "Skipped checks did NOT run; install the missing tool and rerun."
[ "$fail" -eq 0 ]
