#!/usr/bin/env bash
# ============================================================
# venv-manager installer
#
# Install or update:
#   curl -fsSL https://raw.githubusercontent.com/olliehockey/venv-manager/main/install.sh | bash
#   (or, from a clone:  ./install.sh)
#
# Uninstall:
#   ~/.venv-manager/install.sh --uninstall
#
# Safe to run more than once. Never touches your environments.
# ============================================================

set -euo pipefail

REPO="${VENV_MANAGER_REPO:-https://github.com/olliehockey/venv-manager}"
BRANCH="${VENV_MANAGER_BRANCH:-main}"
INSTALL_DIR="${VENV_MANAGER_DIR:-$HOME/.venv-manager}"
MARK="# venv-manager"

say()  { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------
# Which config files should load venv-manager?
# Always the login shell's; also the other shell's if its config exists.
# ------------------------------------------------------------
config_targets() {
    local login="${SHELL##*/}"

    # zsh
    if [ "$login" = "zsh" ] || [ -f "$HOME/.zshrc" ]; then
        printf '%s\n' "$HOME/.zshrc"
    fi

    # bash
    if [ "$login" = "bash" ] || [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ]; then
        if [ -d "$HOME/.bashrc.d" ]; then
            printf '%s\n' "$HOME/.bashrc.d/venv-manager.sh"   # Fedora-style drop-in
        elif [ "$(uname)" = "Darwin" ]; then
            printf '%s\n' "$HOME/.bash_profile"               # macOS login shells
        else
            printf '%s\n' "$HOME/.bashrc"
        fi
    fi
}

# Remove our marker line and source line from a file, keeping everything else.
strip_lines() {
    local file="$1" tmp
    [ -f "$file" ] || return 0
    tmp="$(mktemp)"
    awk -v mark="$MARK" '
        $0 == mark { next }
        /venv-manager.*venv\.sh/ && /source|^\./ { next }
        { print }
    ' "$file" > "$tmp"
    cat "$tmp" > "$file"     # keep the original file's permissions
    rm -f "$tmp"
}

# ------------------------------------------------------------
# Uninstall
# ------------------------------------------------------------
if [ "${1:-}" = "--uninstall" ]; then
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [ -f "$f" ] && grep -q "venv-manager" "$f"; then
            strip_lines "$f"
            say "Removed from $f"
        fi
    done
    if [ -f "$HOME/.bashrc.d/venv-manager.sh" ]; then
        rm -f "$HOME/.bashrc.d/venv-manager.sh"
        say "Removed $HOME/.bashrc.d/venv-manager.sh"
    fi
    # Only delete the folder if it really is a venv-manager install
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/venv.sh" ]; then
        rm -rf -- "$INSTALL_DIR"
        say "Removed $INSTALL_DIR"
    fi
    say "Uninstalled. Your environments in ${VENV_HOME:-$HOME/.venvs} were not touched."
    say "Open a new terminal to finish."
    exit 0
fi

# ------------------------------------------------------------
# 1. Get venv.sh
# ------------------------------------------------------------
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SRC_DIR=""
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
    SRC_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
fi

if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/venv.sh" ]; then
    # Running from a clone: use it where it is
    VENV_SH="$SRC_DIR/venv.sh"
    if [ -d "$SRC_DIR/.git" ] && command -v git >/dev/null 2>&1; then
        git -C "$SRC_DIR" pull --ff-only --quiet 2>/dev/null \
            && say "Updated to the latest version." || true
    fi
else
    # Running via curl | bash: fetch into INSTALL_DIR
    if command -v git >/dev/null 2>&1; then
        if [ -d "$INSTALL_DIR/.git" ]; then
            git -C "$INSTALL_DIR" pull --ff-only --quiet || warn "Could not update; using the existing copy."
            say "Updated $INSTALL_DIR"
        else
            [ -e "$INSTALL_DIR" ] && die "$INSTALL_DIR exists but is not a git checkout. Move it and try again."
            git clone --quiet --depth 1 --branch "$BRANCH" "$REPO" "$INSTALL_DIR" \
                || die "Could not download from $REPO"
            say "Downloaded to $INSTALL_DIR"
        fi
    else
        RAW="${VENV_MANAGER_RAW:-${REPO/github.com/raw.githubusercontent.com}/$BRANCH}"
        mkdir -p "$INSTALL_DIR"
        for f in venv.sh install.sh; do
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$RAW/$f" -o "$INSTALL_DIR/$f" || die "Could not download $f"
            elif command -v wget >/dev/null 2>&1; then
                wget -qO "$INSTALL_DIR/$f" "$RAW/$f" || die "Could not download $f"
            else
                die "Need git, curl or wget to download venv-manager."
            fi
        done
        chmod +x "$INSTALL_DIR/install.sh"
        say "Downloaded to $INSTALL_DIR"
    fi
    VENV_SH="$INSTALL_DIR/venv.sh"
fi

[ -f "$VENV_SH" ] || die "venv.sh not found at $VENV_SH"
LINE="source \"$VENV_SH\""

# ------------------------------------------------------------
# 2. Add the source line to each shell config
# ------------------------------------------------------------
CONFIGURED=""
while IFS= read -r rc; do
    [ -n "$rc" ] || continue
    mkdir -p "$(dirname "$rc")"
    touch "$rc"

    if grep -Fqx "$LINE" "$rc"; then
        say "Already set up in $rc"
    else
        strip_lines "$rc"      # replace any older venv-manager line
        if [ "${rc##*/}" = "venv-manager.sh" ]; then
            printf '%s\n%s\n' "$MARK" "$LINE" > "$rc"
        else
            printf '\n%s\n%s\n' "$MARK" "$LINE" >> "$rc"
        fi
        say "Set up in $rc"
    fi
    CONFIGURED="$CONFIGURED $rc"
done < <(config_targets)

[ -n "$CONFIGURED" ] || die "Could not find a bash or zsh config file to set up."

# ------------------------------------------------------------
# 3. Look for older venv functions that would clash
# ------------------------------------------------------------
CLASH_FILES=""
for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME"/.bashrc.d/*; do
    [ -f "$f" ] || continue
    [ "${f##*/}" = "venv-manager.sh" ] && continue
    [ "$f" = "$VENV_SH" ] && continue
    CLASH_FILES="$CLASH_FILES
$f"
done

CLASHES="$(printf '%s\n' "$CLASH_FILES" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -nE '^[[:space:]]*(function[[:space:]]+)?(venv|venvs|mkvenv)[[:space:]]*\(\)|^[[:space:]]*function[[:space:]]+(venv|venvs|mkvenv)([[:space:]]|\{|$)|^[[:space:]]*alias[[:space:]]+(venv|venvs|mkvenv)=' "$f" 2>/dev/null \
        | sed "s|^|  $f:|"
done)"

if [ -n "$CLASHES" ]; then
    say ""
    warn "Found older venv commands that may clash with venv-manager:"
    printf '%s\n' "$CLASHES" >&2
    say "Delete those definitions so only venv-manager's version loads."
fi

# ------------------------------------------------------------
# 4. Done
# ------------------------------------------------------------
say ""
say "venv-manager is installed. Open a new terminal, then try:  venv -h"
