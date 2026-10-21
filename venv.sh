# ============================================================
# venv-manager: a small Python virtual environment manager
# Works in bash and zsh, on macOS and Linux.
# Environments are stored in $VENV_HOME (default: ~/.venvs).
#
# Load it from your shell config:
#   source /path/to/venv.sh
# ============================================================

# Clear any old aliases with these names, or defining the functions fails
unalias venv 2>/dev/null
unalias venvs 2>/dev/null
unalias mkvenv 2>/dev/null

VENV_HOME="${VENV_HOME:-$HOME/.venvs}"

_venv_help() {
    local cmd="${1:-main}"

    case "$cmd" in
        main)
            cat <<'EOF'
Python Virtual Environment Manager

Usage:
  venv <command> [arguments]
  venv [option] [arguments]

Commands:
  list, ls          List virtual environments
  activate NAME     Activate an environment
  create NAME [PY]  Create and activate an environment
  delete, rm NAME   Delete an environment
  current           Show the active environment
  deactivate        Deactivate the active environment
  help              Show help

Options:
  -l, --list                 List environments
  -a, --activate NAME        Activate NAME
  -c, --create NAME [PY]     Create NAME using optional Python version
  -d, --delete NAME          Delete NAME
  -s, --current              Show current environment
  -x, --deactivate           Deactivate the active environment
  -h, --help                 Show help

Run 'venv <command> --help' for help on one command.
EOF
            ;;

        list)
            cat <<'EOF'
Usage:
  venv list
  venv ls
  venv -l
  venv --list

Lists all environments under ~/.venvs.
The active environment is marked with *.
EOF
            ;;

        activate)
            cat <<'EOF'
Usage:
  venv activate NAME
  venv -a NAME
  venv --activate NAME

Activates an existing Python virtual environment.
EOF
            ;;

        create)
            cat <<'EOF'
Usage:
  venv create NAME [PYTHON]
  venv -c NAME [PYTHON]
  venv --create NAME [PYTHON]

Creates and activates a new virtual environment.

PYTHON may be a version, command or interpreter path.
Without it, python3 is used.
EOF
            ;;

        delete)
            cat <<'EOF'
Usage:
  venv delete NAME
  venv remove NAME
  venv rm NAME
  venv -d NAME
  venv --delete NAME

Permanently deletes an environment after confirmation.

Safety:
  - Cannot delete the active environment.
  - Only removes environments under ~/.venvs.
  - Requires typing the environment name to confirm.
EOF
            ;;

        current)
            cat <<'EOF'
Usage:
  venv current
  venv -s
  venv --current

Shows the active Python virtual environment and version.
EOF
            ;;

        deactivate)
            cat <<'EOF'
Usage:
  venv deactivate
  venv -x
  venv --deactivate

Exits the currently active Python virtual environment.
EOF
            ;;

        *)
            echo "Unknown help topic: $cmd"
            return 1
            ;;
    esac
}


# Names: start with a letter or digit, then letters, digits, - or _
_venv_valid_name() {
    case "$1" in
        ''|[!a-zA-Z0-9]*|*[!a-zA-Z0-9_-]*)
            echo "Invalid environment name: $1"
            echo "Use letters, numbers, hyphens or underscores."
            return 1
            ;;
    esac
    return 0
}


# Turn "3.12", "python3.12" or a path into an interpreter path
_venv_find_python() {
    local requested="${1:-python3}"
    local candidate=""

    case "$requested" in
        */*)
            [ -x "$requested" ] && candidate="$requested"
            ;;
        [0-9].[0-9]*|[0-9])
            candidate="$(command -v "python$requested" 2>/dev/null)"
            ;;
        *)
            candidate="$(command -v "$requested" 2>/dev/null)"
            ;;
    esac

    if [ -z "$candidate" ]; then
        echo "Python interpreter not found: $requested" >&2
        return 1
    fi

    printf '%s\n' "$candidate"
}


# Print the full path of each environment, one per line, sorted
_venv_list_paths() {
    [ -d "$VENV_HOME" ] || return 0
    find "$VENV_HOME" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort
}


venv() {
    local action="${1:-help}"
    local name=""
    local target=""
    local python_bin=""
    local answer=""
    local env_path=""
    local env_name=""
    local found=0
    local old_name=""

    # --------------------------------------------------------
    # Normalise commands and aliases
    # --------------------------------------------------------

    case "$action" in
        help|--help|-h)
            _venv_help "${2:-main}"
            return $?
            ;;
        list|ls|--list|-l)
            action="list"
            ;;
        activate|--activate|-a)
            action="activate"
            ;;
        create|mkvenv|--create|-c)
            action="create"
            ;;
        delete|remove|rm|--delete|--remove|-d)
            action="delete"
            ;;
        current|--current|-s)
            action="current"
            ;;
        deactivate|--deactivate|-x)
            action="deactivate"
            ;;
        *)
            echo "Unknown command: $action"
            echo
            _venv_help main
            return 1
            ;;
    esac

    # --------------------------------------------------------
    # Command-specific help
    # --------------------------------------------------------

    if [ "${2:-}" = "--help" ] || [ "${2:-}" = "-h" ]; then
        _venv_help "$action"
        return $?
    fi

    # --------------------------------------------------------
    # Execute action
    # --------------------------------------------------------

    case "$action" in

        list)
            echo "Available virtual environments:"
            echo

            while IFS= read -r env_path; do
                [ -n "$env_path" ] || continue
                env_name="${env_path##*/}"

                if [ "${VIRTUAL_ENV:-}" = "$env_path" ]; then
                    printf "  * %-20s (active)\n" "$env_name"
                else
                    printf "    %s\n" "$env_name"
                fi

                found=1
            done < <(_venv_list_paths)

            if [ "$found" -eq 0 ]; then
                echo "    No environments found."
            fi
            ;;

        activate)
            name="${2:-}"

            if [ -z "$name" ]; then
                _venv_help activate
                return 1
            fi

            _venv_valid_name "$name" || return 1

            target="$VENV_HOME/$name"

            if [ ! -f "$target/bin/activate" ]; then
                echo "Environment '$name' not found."
                echo
                venv list
                return 1
            fi

            . "$target/bin/activate" || return 1

            echo "Activated: $name"
            echo "Python: $(python --version 2>&1)"
            ;;

        create)
            name="${2:-}"

            if [ -z "$name" ]; then
                _venv_help create
                return 1
            fi

            _venv_valid_name "$name" || return 1

            target="$VENV_HOME/$name"

            if [ -e "$target" ] || [ -L "$target" ]; then
                echo "Environment '$name' already exists."
                return 1
            fi

            python_bin="$(_venv_find_python "${3:-python3}")" || return 1

            mkdir -p "$VENV_HOME" || return 1

            echo "Creating: $name"
            echo "Using: $("$python_bin" --version 2>&1)"

            if ! "$python_bin" -m venv "$target"; then
                rm -rf -- "$target"
                echo
                echo "Could not create the environment."
                echo "On Debian or Ubuntu, install the venv module first, e.g.:"
                echo "  sudo apt install python3-venv"
                return 1
            fi

            . "$target/bin/activate" || return 1

            python -m pip install --upgrade pip

            echo
            echo "Created and activated: $name"
            echo "Location: $target"
            ;;

        delete)
            name="${2:-}"

            if [ -z "$name" ]; then
                _venv_help delete
                return 1
            fi

            _venv_valid_name "$name" || return 1

            target="$VENV_HOME/$name"

            if [ ! -d "$target" ] || [ -L "$target" ]; then
                echo "Environment '$name' does not exist."
                return 1
            fi

            if [ ! -f "$target/pyvenv.cfg" ]; then
                echo "Refusing deletion: pyvenv.cfg missing."
                return 1
            fi

            if [ "${VIRTUAL_ENV:-}" = "$target" ]; then
                echo "Deactivate '$name' before deleting it."
                return 1
            fi

            echo "WARNING: This will permanently remove:"
            echo "  Path:   $target"
            echo "  Python: $("$target/bin/python" --version 2>&1)"
            echo "  Size:   $(du -sh "$target" 2>/dev/null | cut -f1)"
            echo

            printf "Type '%s' to confirm: " "$name"
            read -r answer

            if [ "$answer" != "$name" ]; then
                echo "Deletion cancelled."
                return 1
            fi

            rm -rf -- "$target"
            echo "Deleted: $name"
            ;;

        current)
            if [ -n "${VIRTUAL_ENV:-}" ]; then
                echo "Active: ${VIRTUAL_ENV##*/}"
                echo "Location: $VIRTUAL_ENV"
                echo "Python: $(python --version 2>&1)"
            else
                echo "No virtual environment active."
            fi
            ;;

        deactivate)
            if [ -z "${VIRTUAL_ENV:-}" ]; then
                echo "No virtual environment active."
                return 0
            fi

            old_name="${VIRTUAL_ENV##*/}"

            if type deactivate >/dev/null 2>&1; then
                deactivate
                echo "Deactivated: $old_name"
            else
                echo "Deactivation function unavailable."
                return 1
            fi
            ;;
    esac
}


# ============================================================
# Shortcuts
# ============================================================

venvs() {
    venv list "$@"
}

mkvenv() {
    venv create "$@"
}
