# venv-manager

A small command for creating, switching between and deleting Python virtual environments, all kept in one place (`~/.venvs`).

Works in **bash** and **zsh**, on **macOS** and **Linux**. It's a single shell file with no dependencies beyond Python's built-in `venv` module.

```
$ venv create main 3.12
Creating: main
Using: Python 3.12.4
...
Created and activated: main

$ venv list
Available virtual environments:

    main
  * main             (active)
```

## Install

One command, on macOS or Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/olliehockey/venv-manager/main/install.sh | bash
```

Then open a new terminal and run `venv -h`.

Run the same command again at any time to update.

**What the installer does:**

- Downloads venv-manager to `~/.venv-manager` (with git if you have it, otherwise curl or wget).
- Adds one line to the config of each shell you use:
  - zsh: `~/.zshrc`
  - bash on Linux: `~/.bashrc`, or a new file `~/.bashrc.d/venv-manager.sh` if you have a `~/.bashrc.d` folder (Fedora does by default)
  - bash on macOS: `~/.bash_profile`
- Warns you about any older `venv`, `venvs` or `mkvenv` definitions in your config files, with file and line numbers, so you can remove them.

It never touches your environments, and running it twice won't add anything twice.

**Prefer to clone?**

```bash
git clone https://github.com/olliehockey/venv-manager.git ~/.venv-manager
~/.venv-manager/install.sh
```

**Or set it up by hand:** add this line to your shell config.

```bash
source ~/.venv-manager/venv.sh
```

**Debian and Ubuntu:** the `venv` module is a separate package there. Install it once with `sudo apt install python3-venv`. macOS and Fedora include it already.

## Uninstall

```bash
~/.venv-manager/install.sh --uninstall
```

This removes the lines it added and the `~/.venv-manager` folder. Your environments in `~/.venvs` are left alone.

## Usage

| Command                   | Short                 | What it does                                      |
| ------------------------- | --------------------- | ------------------------------------------------- |
| `venv list`             | `venv -l`           | List environments; the active one is marked `*` |
| `venv create NAME [PY]` | `venv -c NAME [PY]` | Create and activate an environment                |
| `venv activate NAME`    | `venv -a NAME`      | Activate an environment                           |
| `venv current`          | `venv -s`           | Show the active environment and Python version    |
| `venv deactivate`       | `venv -x`           | Leave the active environment                      |
| `venv delete NAME`      | `venv -d NAME`      | Delete an environment, after confirmation         |
| `venv help`             | `venv -h`           | Show help                                         |

`venv <command> --help` shows help for a single command.

### Choosing a Python version

`PY` can be a version number, a command name or a full path:

```bash
venv create main            # uses python3
venv create main 3.12       # uses python3.12
venv create main python3.11
venv create main /opt/homebrew/bin/python3.12
```

### Deleting safely

`venv delete` will only remove a folder inside `~/.venvs` that contains a `pyvenv.cfg` file, refuses to delete the environment you're in, and asks you to type the name to confirm. It shows the path, Python version and size first.

## Options

Set `VENV_HOME` before the `source` line to keep environments somewhere other than `~/.venvs`:

```bash
export VENV_HOME="$HOME/envs"
source ~/.venv-manager/venv.sh
```

## Licence

MIT
