# Zsh Easy Setup

A friendly, menu-driven installer that turns a plain Ubuntu terminal into a
fully configured **Zsh + Oh My Zsh** setup — themes, autosuggestions, syntax
highlighting, smart history and more.

No prior shell knowledge needed. You run one command and pick numbers from a
menu. Every step explains itself, asks before it changes anything, and can be
completely undone later.

```bash
bash zsh-setup.sh
```

---

## Table of contents

- [Why this exists](#why-this-exists)
- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [The menu, option by option](#the-menu-option-by-option)
- [Themes](#themes)
- [What gets configured](#what-gets-configured)
- [Your personal aliases](#your-personal-aliases)
- [Files this script touches](#files-this-script-touches)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [License](#license)
- [Author](#author)

---

## Why this exists

Setting up Zsh usually means following a blog post, copy-pasting a `curl | sh`
line you can't read, hand-editing `~/.zshrc`, and hoping you didn't break your
terminal. If you don't like the result, undoing it is its own research project.

This script does the whole thing interactively, tells you what each choice
means in plain English, keeps your personal shortcuts in a separate file so
reinstalls never eat them, and ships a real uninstaller that puts you back on
bash with your original config restored.

## Features

- **Interactive menu** — no flags to memorise, every option is a number.
- **Six themes**, including Powerlevel10k and a Kali Linux-style prompt with
  pickable colours.
- **Plugins preconfigured** — autosuggestions, syntax highlighting, history
  substring search, `z`, `extract`, fzf key bindings, and more.
- **Imports your Bash aliases** so switching shells doesn't lose your muscle
  memory.
- **Your aliases live in `~/.zsh_aliases`** — a separate file the script never
  overwrites, so changing themes or reinstalling is always safe.
- **Backs up your existing `~/.zshrc`** before writing a new one.
- **Real uninstaller** — restores bash and your original config.
- **Safe to re-run** — it detects what you already have and skips it.
- **Built-in help** — `bash zsh-setup.sh --help`, or option 6 in the menu.

## Requirements

| | |
|---|---|
| **OS** | Ubuntu / Debian (anything with `apt`). Tested on Ubuntu 24.04 and 26.04. |
| **Shell to run it** | `bash` (the script installs zsh for you). |
| **Access** | A `sudo` password, for installing packages. |
| **Network** | Needed to fetch Oh My Zsh, plugins and themes from GitHub. |
| **Font** *(optional)* | A [Nerd Font](https://www.nerdfonts.com/) such as MesloLGS NF, if you pick Powerlevel10k or the Kali theme. |

The script refuses to run on non-apt systems rather than half-installing
something, and warns you if you run it as root.

## Quick start

```bash
# 1. Get the script
git clone https://github.com/Chandirasegaran/OhMyZsh.git
cd OhMyZsh

# 2. See what it does before running anything (optional)
bash zsh-setup.sh --help

# 3. Run it and pick option 1
bash zsh-setup.sh
```

Then **close your terminal and open a new one**, and **log out and back in
once** so desktop apps (VS Code, IDEs) also pick up zsh.

## The menu, option by option

```
===== Zsh Easy Setup =====
  1) Install Zsh + Oh My Zsh  (recommended)
  2) Change my theme
  3) Add / manage my shortcuts (aliases)
  4) Set my default shell (zsh or bash)
  5) Uninstall / remove everything
  6) Help  (what does each option do?)
  7) Quit
```

### 1) Install Zsh + Oh My Zsh

The main event. It installs the packages, installs Oh My Zsh, clones the
plugins, lets you pick a theme, writes a fresh `~/.zshrc`, offers to import
your Bash aliases, and offers to make zsh your default shell.

Safe to run more than once — anything already present is detected and skipped.

### 2) Change my theme

Reopens the theme picker and regenerates `~/.zshrc` with your new choice. This
is safe: your personal settings live in `~/.zsh_aliases`, which isn't touched.
Regenerating also repairs a `~/.zshrc` you may have broken by hand.

### 3) Add / manage my shortcuts (aliases)

A submenu:

| | |
|---|---|
| **Add a new alias** | Asks for a short name and the command it should run, validates both, and offers to replace an existing alias of the same name. |
| **Show my aliases** | Lists everything you've added. |
| **Import from Bash** | Shows every `alias` and `export` line found in your Bash config and asks before importing, skipping duplicates. |
| **Edit by hand** | Opens `~/.zsh_aliases` in `$EDITOR` (or nano). |

### 4) Set my default shell (zsh or bash)

Switch your login shell either way. It reads your **real** configured shell
from the system rather than trusting `$SHELL`, and explains the difference if
the two disagree (see [Troubleshooting](#troubleshooting)).

### 5) Uninstall / remove everything

See [Uninstalling](#uninstalling).

### 6) Help

Prints an in-terminal summary of all of the above, the files involved, the
keyboard shortcuts you get, and common fixes. Also available without opening
the menu:

```bash
bash zsh-setup.sh --help    # or -h, or: help
```

At the menu prompt you can also just press `h` or `?`.

## Themes

| # | Theme | Looks like | Nerd Font? |
|---|---|---|---|
| 1 | **robbyrussell** | The Oh My Zsh default. Simple, fast, hard to dislike. | No |
| 2 | **agnoster** | Folder and git branch in a solid colour bar. | Recommended |
| 3 | **powerlevel10k** | The popular one. Fast, highly configurable, run `p10k configure` to design it. | **Yes** |
| 4 | **avit** | Clean and minimal. | No |
| 5 | **bira** | Two lines, lots of info. | No |
| 6 | **kali** | The Kali Linux hacker look. | **Yes** |

### About the Kali theme

Reproduces Kali's two-line prompt:

```
┌──(user㉿host)-[~/folder]-[main ✗]
└─$
```

The script generates it locally and asks you two things first:

- **Colours** — bright green + cyan (default), bright blue + cyan, purple +
  pink, or classic Kali. The brighter sets exist because the classic Kali
  colours look washed out on Ubuntu's default palette.
- **Git branch** — whether to show the current branch and a `✗` when you have
  uncommitted changes.

Your answers are written as plain, commented variables at the top of
`~/.oh-my-zsh/custom/themes/kali.zsh-theme`, so you can recolour it later by
editing a number. It also detects terminals without 256-colour support and
falls back to basic colours instead of printing garbage.

## What gets configured

The generated `~/.zshrc` is heavily commented — every block explains itself.
It sets up:

**Plugins**

| Plugin | What it gives you |
|---|---|
| `git` | Short git commands (`gst`, `gco`, `gp`, …) |
| `sudo` | Press <kbd>Esc</kbd> <kbd>Esc</kbd> to prepend `sudo` |
| `z` | `z downloads` jumps to folders you use often |
| `extract` | `extract file.zip` unpacks any archive |
| `colored-man-pages` | Readable, colourful manuals |
| `command-not-found` | Suggests the package for a missing command |
| `zsh-autosuggestions` | Grey ghost text from your history; <kbd>→</kbd> accepts |
| `zsh-syntax-highlighting` | Commands turn green (valid) or red (typo) |
| `zsh-history-substring-search` | Type a few letters, then <kbd>↑</kbd> |

**Shell behaviour**

- History: 50,000 entries, no duplicates, shared live across open terminals.
- `AUTO_CD` — type a folder name to enter it.
- Case-insensitive tab completion with an arrow-key menu and coloured matches.
- Home/End/Delete keys bound correctly.
- Brightened autosuggestion text (the default grey is unreadable on most
  themes), plus <kbd>Ctrl</kbd>+<kbd>Space</kbd> to accept.
- Autocorrect deliberately **off** — the `zsh: correct 'npm' to 'nm'?` nagging
  costs more than it saves. Uncomment one line if you want it.
- `export SHELL` fixed so VS Code, tmux and IDEs launch the right shell.

**Developer tools** — each block only activates if you actually have the tool,
so they're all safe to leave in: nvm, cargo/Rust, pyenv, `~/.local/bin`, and
fzf (<kbd>Ctrl</kbd>+<kbd>R</kbd> history search, <kbd>Ctrl</kbd>+<kbd>T</kbd>
file picker).

**Everyday aliases** — `ll`, `la`, `l`, `..`, `...`, `mkcd`, `update`, and
`please` (re-runs your last command with sudo). If `bat` and `eza` are
installed, `cat` and `ls` are upgraded to them automatically.

## Your personal aliases

Anything you add lives in **`~/.zsh_aliases`**, which the script creates with a
short tutorial inside and then never overwrites. `~/.zshrc` sources it at the
end.

This is the whole reason changing themes and reinstalling are safe operations:
your work is never in the file that gets regenerated.

```bash
# ~/.zsh_aliases
alias gs='git status'
alias gp='git push'
backup() { cp "$1" "$1.bak"; }   # usage: backup notes.txt
```

Apply changes with `source ~/.zshrc`, or just open a new terminal.

## Files this script touches

| Path | What it is |
|---|---|
| `~/.zshrc` | Your zsh settings. **Generated** — expect it to be rewritten. |
| `~/.zshrc.pre-zsh-setup` | Backup of the `~/.zshrc` you had before. |
| `~/.zsh_aliases` | **Yours.** Never overwritten. |
| `~/.oh-my-zsh/` | Oh My Zsh, plus custom themes and plugins. |
| `~/.p10k.zsh` | Powerlevel10k config, if you use that theme. |
| `~/.zsh_history` | Your command history. |

## Uninstalling

Run the script and pick **5**. In order, it:

1. Switches your default shell back to **bash first**, so you're never stranded
   in a broken shell.
2. Removes `~/.oh-my-zsh/` and its plugins/themes.
3. Restores `~/.zshrc.pre-zsh-setup` over `~/.zshrc` if a backup exists, or
   removes the generated file if not.
4. Cleans up `~/.p10k.zsh`, `~/.zsh_history` and the completion cache.
5. **Asks** before deleting `~/.zsh_aliases` — it's your work, so it's kept by
   default.
6. **Asks** whether to `apt remove` zsh itself, and again before `autoremove`.

Every destructive step is behind a confirmation.

## Troubleshooting

**I see boxes, question marks, or missing icons.**
Your font lacks the glyphs. Install a [Nerd Font](https://www.nerdfonts.com/)
(MesloLGS NF is the usual pick) and select it in your terminal's profile
settings. Themes 3 and 6 want one. For the Kali theme specifically, you can
also just replace `prompt_symbol=㉿` with `@` in the theme file.

**VS Code / my IDE still opens bash.**
This is normal right after switching, and it's the most common confusion. Your
`$SHELL` variable is only refreshed **when you log in**, so apps launched from
the desktop keep seeing the old value. **Log out and log back in once** (or
reboot). Option 4 detects this and tells you when it's happening.

**My change isn't showing up.**
Run `source ~/.zshrc`, or open a new terminal.

**`chsh` failed.**
Run it yourself: `chsh -s $(command -v zsh)`. Some systems require your
password or a PAM policy change. Option 4 prints the exact command.

**I want my old setup back.**
Option 5 restores your `~/.zshrc.pre-zsh-setup` backup.

**The prompt looks washed out / unreadable.**
For the Kali theme, re-run option 2 and choose one of the brighter colour
sets — the classic Kali colours are dim on Ubuntu's default palette.

## FAQ

**Is it safe to run twice?**
Yes. Packages, Oh My Zsh, plugins and themes are all detected and skipped if
present.

**Will it delete my existing `.zshrc`?**
It backs it up to `~/.zshrc.pre-zsh-setup` first, then writes a fresh one.
Uninstall restores the backup.

**Will I lose my aliases if I change theme?**
No. They're in `~/.zsh_aliases`, which is never regenerated.

**Does it work on Fedora / Arch / macOS?**
Not currently — it depends on `apt` and exits early elsewhere. The `.zshrc` it
generates is portable, but package installation isn't.

**Can I use it without making zsh my default shell?**
Yes. Say no when it asks, and just type `zsh` when you want it.

**What does "Import from Bash" actually copy?**
Only `alias` and `export` lines. Tool loaders (the nvm/pyenv/cargo lines in
`.bashrc`) are deliberately **not** copied, because the generated `.zshrc`
already loads those tools properly. Anything more exotic you'll want to move
across by hand.

## License

Released under the [MIT License](LICENSE) — use it, fork it, ship it.

## Author

Made by **[Chandirasegaran](https://github.com/Chandirasegaran)**

Issues and pull requests are welcome.
