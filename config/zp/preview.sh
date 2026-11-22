#!/bin/sh
# zp preview, run by fzf with the project folder as $1: name, path, git state, contents.
cd "$1" 2>/dev/null || exit
hi='\033[1;38;2;203;166;247m'; dim='\033[38;2;108;112;134m'; rs='\033[0m'
printf "${hi}%s${rs}\n${dim}%s${rs}\n\n" "$(basename "$PWD")" "$(printf %s "$PWD" | sed "s|^$HOME|~|")"
if [ -e .git ]; then
  git -c color.ui=always status -sb 2>/dev/null | head -12
  printf '\n'
  git -c color.ui=always log -5 --format='%C(yellow)%h%C(reset) %s %C(dim)%cr%C(reset)' 2>/dev/null
  printf '\n'
fi
if command -v eza >/dev/null 2>&1; then
  eza -1 --icons=always --color=always --group-directories-first . | head -40
else
  ls -1A | head -40
fi
