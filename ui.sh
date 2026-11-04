#!/usr/bin/env bash
# ============================================================================
#  NaleHut VM Kit — shared animated terminal UI library
#  Sourced by install.sh and every tools/vm-*.sh script.
#
#  Public API:
#    ui_init [title]              -> init colors/anims (call once at start)
#    banner [subtitle]            -> animated NaleHut ASCII banner
#    mini_banner [title]          -> small header for the VM tools
#    type_print [-n] "text"       -> typewriter text
#    step "title"                 -> big animated section header
#    run_spinner "label" cmd...   -> run cmd behind a braille spinner
#    run_bar "label" cmd...       -> run cmd behind an animated progress bar
#    ok|warn|fail|info|skip "msg" -> status lines
#    hr / center
#    ask_yesno "prompt" [Y|N]     -> returns 0 = yes, 1 = no
#    ask_input "prompt" [default] -> answer in $REPLY_VALUE
#    die "msg"                    -> red error and exit 1
#    ui_cleanup                   -> restores cursor (auto-trapped)
# ============================================================================
# ui.sh is intentionally NOT run with set -e: it is sourced into scripts that
# manage their own shell options. We only guard against unset variables.
set -u

# ---------------------------------------------------------------- anim state
UI_TTY=0
UI_ANIM_ON=0
UI_SPIN_FRAME=0
UI_FRAMES='|/-\\'   # replaced with braille in ui_init when UTF-8
SPIN_GLYPH='|'
UI_CHILD_PID=""
UI_LOG_FILE=""
UI_START_TS=0
UI_UTF8=1

# ---------------------------------------------------------------- colors
ui_init() {
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
        UI_TTY=1
        R=$'\e[0m';        B=$'\e[1m';        DIM=$'\e[2m'
        RED=$'\e[31m';     GREEN=$'\e[32m';   YELLOW=$'\e[33m'
        BLUE=$'\e[34m';    MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
        GRAY=$'\e[90m';    WHITE=$'\e[97m'
        BRED=$'\e[1;91m';  BGREEN=$'\e[1;92m'; BYELLOW=$'\e[1;93m'
        BBLUE=$'\e[1;94m'; BMAG=$'\e[1;95m';  BCYAN=$'\e[1;96m'
        TEAL=$'\e[38;5;44m'; BTEAL=$'\e[1;38;5;44m'; DTEAL=$'\e[38;5;30m'
    else
        R=""; B=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""
        CYAN=""; GRAY=""; WHITE=""; BRED=""; BGREEN=""; BYELLOW=""; BBLUE=""
        BMAG=""; BCYAN=""; TEAL=""; BTEAL=""; DTEAL=""
    fi
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf8*) UI_UTF8=1 ;;
        *) UI_UTF8=0 ;;
    esac
    if [ "$UI_UTF8" = "1" ]; then UI_FRAMES='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'; else UI_FRAMES='|/-\\'; fi
    [ "$UI_TTY" = "1" ] && UI_ANIM_ON=1
    trap ui_cleanup EXIT INT TERM
}

ui_cleanup() {
    [ "$UI_TTY" = "1" ] && printf '\e[?25h'   # show cursor
    return 0
}

# advance the spinner frame IN-PLACE (no subshell: state must persist)
spin_next() {
    UI_SPIN_FRAME=$(( (UI_SPIN_FRAME + 1) % ${#UI_FRAMES} ))
    SPIN_GLYPH="${UI_FRAMES:$UI_SPIN_FRAME:1}"
}

# ---------------------------------------------------------------- text fx
# type_print [-n] text [speed_cs]
type_print() {
    local nl=1
    if [ "${1:-}" = "-n" ]; then nl=0; shift; fi
    local text="${1:-}"; local ms="${2:-6}"
    if [ "$UI_ANIM_ON" != "1" ]; then
        if [ "$nl" = "1" ]; then printf '%s\n' "$text"; else printf '%s' "$text"; fi
        return 0
    fi
    local i
    for ((i = 0; i < ${#text}; i++)); do
        printf '%s' "${text:$i:1}"
        sleep "0.00${ms}" 2>/dev/null || sleep 0.01
    done
    [ "$nl" = "1" ] && printf '\n'
    return 0
}

hr()     { printf '%s\n' "${DTEAL}  ────────────────────────────────────────────────────────────${R}"; }

# ---------------------------------------------------------------- status
ok()   { printf '  %s✔%s %b\n' "$BGREEN" "$R" "$*"; }
skip() { printf '  %s○%s %b\n' "$GRAY"   "$R" "$*"; }
info() { printf '  %s➜%s %b\n' "$BCYAN"  "$R" "$*"; }
warn() { printf '  %s▲%s %b\n' "$BYELLOW" "$R" "$*"; }
fail() { printf '  %s✘%s %b\n' "$BRED"   "$R" "$*"; }

die() {
    printf '\n  %s✘ FATAL:%s %s\n' "${BRED:-}" "${R:-}" "$*" >&2
    ui_cleanup
    exit 1
}

# ---------------------------------------------------------------- banner
banner() {
    local sub="${1:-Windows VM Stack Installer}"
    [ "$UI_ANIM_ON" = "1" ] && printf '\e[?25l'   # hide cursor
    local art=(
      "  _   _      _        _   _   _       _     _   _          "
      " | \ | | ___| |__   | | | \ | | __ _| |_  | | | | __ _ ___ "
      " |  \| |/ _ \ '_ \  | | |  \| |/ _\` | __| | |_| |/ _\` / __|"
      " | |\  |  __/ |_) | | | | |\  | (_| | |_  |  _  | (_| \__ \\"
      " |_| \_|\___|_.__/  |_| |_| \_|\__,_|\__| |_| |_|\__,_|___/"
    )
    local colors=("$TEAL" "$BTEAL" "$CYAN" "$BCYAN" "$BBLUE")
    local i
    for i in "${!art[@]}"; do
        printf '%s%s%s\n' "${colors[$i]}" "${art[$i]}" "$R"
        [ "$UI_ANIM_ON" = "1" ] && sleep 0.05
    done
    printf '\n'
    type_print "        ${B}N a l e H u t   V M   K i t${R}  ${GRAY}v${NH_KIT_VERSION:-1.0}${R}" 8
    type_print "        ${GRAY}$sub${R}" 4
    hr
    printf '\n'
}

mini_banner() {
    local title="${1:-NaleHut VM Tool}"
    [ "$UI_ANIM_ON" = "1" ] && printf '\e[?25l'
    printf '%s\n' "${BTEAL}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${R}"
    printf '%s\n' "${TEAL}  █${R}  ${B}NaleHut${R} ${GRAY}·${R} ${CYAN}$title${R}                     ${TEAL}█${R}"
    printf '%s\n' "${BTEAL}  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${R}"
    printf '\n'
}

# ---------------------------------------------------------------- sections
step() {
    local title="$1"
    printf '\n'
    if [ "$UI_ANIM_ON" = "1" ]; then
        type_print "${B}  ▶ $title${R}" 5
    else
        printf '%s\n' "${B}  ▶ $title${R}"
    fi
    printf '%s\n' "  ${DTEAL}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${R}"
}

# ---------------------------------------------------------------- runners
# internal animation loop while $UI_CHILD_PID lives
_ui_animate() {
    local label="$1" mode="$2"   # mode: spin | bar
    local start=$UI_START_TS
    local pct=3 width=30 filled empty glyph now el
    while kill -0 "$UI_CHILD_PID" 2>/dev/null; do
        now=$(date +%s); el=$(( now - start ))
        spin_next
        if [ "$mode" = "spin" ]; then
            printf '\r  %s%s%s %s %s(%ss)%s  ' \
                "$BTEAL" "$SPIN_GLYPH" "$R" "$label" "$GRAY" "$el" "$R"
        else
            # decelerating pseudo-progress that never crosses 90 until done
            pct=$(( pct + (90 - pct) / 24 + 1 )); [ "$pct" -gt 90 ] && pct=90
            filled=$(( pct * width / 100 )); empty=$(( width - filled ))
            printf '\r  %s%s%s %s[%s%s%s] %3d%% %s(%ss)%s   ' \
                "$BTEAL" "$SPIN_GLYPH" "$R" "$R" \
                "$BTEAL$(printf '█%.0s' $(seq 1 $((filled>0?filled:1))))" \
                "$DTEAL$(printf '░%.0s' $(seq 1 $((empty>0?empty:1))))" \
                "$R" "$pct" "$GRAY" "$el" "$R"
        fi
        sleep 0.09
    done
    printf '\r\033[K'   # wipe the animated line
}

# run_spinner "label" cmd args...
run_spinner() {
    local label="$1"; shift
    UI_START_TS=$(date +%s)
    if [ "$UI_ANIM_ON" != "1" ]; then
        printf '  %s...\n' "$label"
        "$@"; return $?
    fi
    UI_LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/nh-log.XXXXXX")
    "$@" >"$UI_LOG_FILE" 2>&1 &
    UI_CHILD_PID=$!
    _ui_animate "$label" spin
    wait "$UI_CHILD_PID"; local rc=$?
    UI_CHILD_PID=""
    if [ "$rc" -ne 0 ]; then
        printf '  %s✘ %s%s — failed, last output:\n' "$BRED" "$label" "$R" >&2
        tail -n 6 "$UI_LOG_FILE" | sed 's/^/    /' >&2
    fi
    rm -f "$UI_LOG_FILE"
    return $rc
}

# run_bar "label" cmd args...
run_bar() {
    local label="$1"; shift
    UI_START_TS=$(date +%s)
    if [ "$UI_ANIM_ON" != "1" ]; then
        printf '  %s...\n' "$label"
        "$@"; return $?
    fi
    UI_LOG_FILE=$(mktemp "${TMPDIR:-/tmp}/nh-log.XXXXXX")
    "$@" >"$UI_LOG_FILE" 2>&1 &
    UI_CHILD_PID=$!
    _ui_animate "$label" bar
    wait "$UI_CHILD_PID"; local rc=$?
    UI_CHILD_PID=""
    if [ "$rc" -eq 0 ]; then
        printf '  %s✔%s %s\n' "$BGREEN" "$R" "$label"
    else
        printf '  %s✘ %s%s — failed, last output:\n' "$BRED" "$label" "$R" >&2
        tail -n 8 "$UI_LOG_FILE" | sed 's/^/    /' >&2
    fi
    rm -f "$UI_LOG_FILE"
    return $rc
}

# ---------------------------------------------------------------- prompts
ask_yesno() {
    local prompt="$1" def="${2:-Y}" ans
    local hint; if [ "$def" = "Y" ]; then hint="${GRAY}[Y/n]${R}"; else hint="${GRAY}[y/N]${R}"; fi
    while :; do
        printf '  %s%s%s %s ' "$BTEAL" "$prompt" "$R" "$hint"
        if [ "$UI_TTY" = "1" ]; then read -r ans || return 1; else ans=""; fi
        ans="${ans:-$def}"
        case "$ans" in
            [Yy]|[Yy][Ee][Ss]) printf '\n'; return 0 ;;
            [Nn]|[Nn][Oo])     printf '\n'; return 1 ;;
            *) printf '  %splease answer y or n%s\n' "$BYELLOW" "$R" ;;
        esac
    done
}

# ask_input "prompt" "default" -> echoes value into $REPLY_VALUE
REPLY_VALUE=""
ask_input() {
    local prompt="$1" def="${2:-}"
    printf '  %s%s%s %s%s: %s' "$BTEAL" "$prompt" "$R" "$GRAY" "${def:+[$def]}" "$R"
    if [ "$UI_TTY" = "1" ]; then read -r REPLY_VALUE || REPLY_VALUE=""; else REPLY_VALUE=""; fi
    REPLY_VALUE="${REPLY_VALUE:-$def}"
    printf '\n'
}
