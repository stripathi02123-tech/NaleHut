#!/usr/bin/env bash
# NaleHut installer UI helpers
: "${NO_COLOR:=}"
if [ -n "$NO_COLOR" ]; then
  R="" B="" BRED="" BTEAL="" GRAY=""
else
  R=$'\033[0m'; B=$'\033[1m'; BRED=$'\033[1;31m'; BTEAL=$'\033[1;36m'; GRAY=$'\033[90m'
fi
ui_init() { :; }
banner() { printf '\n%s\n  %s%s\n%s\n\n' "$BTEAL" "$B" "$1" "$R"; }
step() { printf '\n%s==>%s %s\n' "$BTEAL" "$R" "$1"; }
info() { printf '  %s[i]%s %s\n' "$BTEAL" "$R" "$*"; }
ok() { printf '  %s[OK]%s %s\n' "$BTEAL" "$R" "$*"; }
warn() { printf '  %s[WARN]%s %s\n' "$BRED" "$R" "$*"; }
skip() { printf '  %s[SKIP]%s %s\n' "$GRAY" "$R" "$*"; }
fail() { printf '  %s[FAIL]%s %s\n' "$BRED" "$R" "$*"; }
die() { printf '\n%s[FATAL]%s %s\n' "$BRED" "$R" "$*" >&2; exit 1; }
hr() { printf '%s\n' '------------------------------------------------------------'; }
type_print() { printf '%b\n' "$1"; }
ask_yesno() {
  local prompt="$1" default="${2:-Y}" answer
  if [ "$default" = "Y" ]; then read -r -p "$prompt [Y/n] " answer || true; answer="${answer:-Y}"
  else read -r -p "$prompt [y/N] " answer || true; answer="${answer:-N}"; fi
  [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]]
}
run_bar() {
  local label="$1"; shift
  printf '  %s...%s ' "$label" ""
  if "$@"; then printf '%s[OK]%s\n' "$BTEAL" "$R"; return 0
  else local rc=$?; printf '%sFAILED%s\n' "$BRED" "$R"; return "$rc"; fi
}
run_spinner() { run_bar "$@"; }
