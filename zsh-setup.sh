#!/usr/bin/env bash
#
# zsh-setup.sh — Friendly Zsh + Oh My Zsh installer / uninstaller
# -----------------------------------------------------------------
# For Ubuntu (tested on 24.04 / 26.04). Beginner-friendly & interactive.
#
# Made by Chandirasegaran — https://github.com/Chandirasegaran
#
#   What it does:
#     * Installs zsh, Oh My Zsh, and popular plugins
#     * Lets you pick from several themes (incl. Powerlevel10k)
#     * Can change your theme later
#     * Can COMPLETELY remove everything and put things back
#
#   How to run it:
#     1) Open a terminal in this folder
#     2) Type:   bash zsh-setup.sh
#     3) Follow the friendly menu. That's it!
#
#   Not sure what an option does? Pick "Help" in the menu, or run:
#     bash zsh-setup.sh --help
#
# You do NOT need to be an expert. Just read the questions and pick a number.
# -----------------------------------------------------------------

set -u  # treat unset variables as errors (helps catch bugs)

# ----------------------------- Colors ----------------------------
if [ -t 1 ]; then
  IS_TTY=1
  BOLD="$(tput bold 2>/dev/null || echo '')"
  RESET="$(tput sgr0 2>/dev/null || echo '')"
  RED="$(tput setaf 1 2>/dev/null || echo '')"
  GREEN="$(tput setaf 2 2>/dev/null || echo '')"
  YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
  BLUE="$(tput setaf 4 2>/dev/null || echo '')"
  CYAN="$(tput setaf 6 2>/dev/null || echo '')"
else
  IS_TTY=0
  BOLD=""; RESET=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
fi

# ----------------------------- Author ----------------------------
AUTHOR_NAME="Chandirasegaran"
AUTHOR_URL="https://github.com/Chandirasegaran"

# Print text as a clickable link using an OSC 8 hyperlink. Modern terminals
# (GNOME Terminal, Konsole, iTerm2, Windows Terminal, VS Code) turn it into a
# real link — Ctrl+click or plain click, depending on the terminal.
# Terminals that don't support it just show the plain text, so callers print
# the URL alongside it; that way nobody is left without something to copy.
#
# NOTE: this checks $IS_TTY (worked out once at startup) rather than calling
# [ -t 1 ] here. This function is used inside "$(link ...)", and in a command
# substitution stdout is a pipe — so [ -t 1 ] would always say "not a
# terminal" and we would silently never emit a link at all.
link() {
  local text="${1-}" url="${2-}"
  if [ "$IS_TTY" = 1 ]; then
    printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$url" "$text"
  else
    printf '%s' "$text"
  fi
}

# The "Made by" line shown on the welcome screen, in Help, and on the way out.
# Pass an indent (e.g. "  ") to line it up inside an indented section.
credit() {
  local indent="${1-}" name
  name="$(link "$AUTHOR_NAME" "$AUTHOR_URL")"
  printf '%s%sMade by %s%s%s  %s%s\n' \
    "$indent" "$CYAN" "$BOLD" "$name" "$RESET$CYAN" "$AUTHOR_URL" "$RESET"
}

# ----------------------------- Helpers ---------------------------
say()   { printf '%s\n' "${1-}"; }
info()  { printf '%s➜ %s%s\n'  "$BLUE"   "${1-}" "$RESET"; }
ok()    { printf '%s✔ %s%s\n'  "$GREEN"  "${1-}" "$RESET"; }
warn()  { printf '%s! %s%s\n'  "$YELLOW" "${1-}" "$RESET"; }
err()   { printf '%s✗ %s%s\n' "$RED"    "${1-}" "$RESET" 1>&2; }
title() { printf '\n%s%s%s\n' "$BOLD$CYAN" "${1-}" "$RESET"; }

# Ask a yes/no question. Returns 0 for yes, 1 for no. Default = No.
ask_yes_no() {
  local prompt="${1:-Are you sure?}" answer
  read -r -p "$(printf '%s%s [y/N]: %s' "$YELLOW" "$prompt" "$RESET")" answer
  case "${answer:-}" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# Run a command with sudo, explaining why we need the password.
need_sudo() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

OMZ_DIR="$HOME/.oh-my-zsh"
ZSHRC="$HOME/.zshrc"
CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"
ALIASES_FILE="$HOME/.zsh_aliases"

# Create the personal aliases file (only if it doesn't exist yet).
ensure_aliases_file() {
  [ -f "$ALIASES_FILE" ] && return 0
  cat > "$ALIASES_FILE" <<'EOF'
# ~/.zsh_aliases — YOUR personal shortcuts. Safe from reinstalls!
#
# An "alias" is a nickname for a longer command. Format:
#     alias name='the real command'
# Example:
#     alias gs='git status'
# Then just type   gs   instead of   git status
#
# A "function" can do more (take input). Example:
#     backup() { cp "$1" "$1.bak"; }   # usage:  backup notes.txt
#
# After editing this file, run:  source ~/.zshrc   (or open a new terminal)
# --- add your own below this line ---

EOF
  ok "Created your personal aliases file: $ALIASES_FILE"
}

# --------------------------- Safety checks -----------------------
pre_checks() {
  if ! command -v apt-get >/dev/null 2>&1; then
    err "This script is made for Ubuntu/Debian (needs 'apt'). Stopping."
    exit 1
  fi
  if [ "$(id -u)" -eq 0 ]; then
    warn "You are running as root. It's better to run as your normal user."
    ask_yes_no "Continue anyway?" || exit 1
  fi
}

# ---------------------- Install system packages -------------------
install_packages() {
  info "Updating the software list (you may be asked for your password)..."
  need_sudo apt-get update -y

  info "Installing zsh, git, curl, and helper tools..."
  # fzf  = fuzzy finder (super handy Ctrl+R history search & file picker)
  # bat/eza are nicer versions of 'cat' and 'ls' (optional, used by aliases)
  need_sudo apt-get install -y \
    zsh git curl fzf \
    zsh-autosuggestions zsh-syntax-highlighting fonts-powerline || {
      err "Package installation failed. Please check your internet connection."
      return 1
    }
  # These two are "nice to have" — don't fail the whole install if missing.
  need_sudo apt-get install -y bat eza 2>/dev/null || true
  ok "System packages are installed."
}

# ------------------------- Install Oh My Zsh ----------------------
install_omz() {
  if [ -d "$OMZ_DIR" ]; then
    ok "Oh My Zsh is already installed. Skipping."
    return 0
  fi
  info "Installing Oh My Zsh..."
  # RUNZSH=no  -> don't jump into zsh immediately
  # KEEP_ZSHRC=yes -> don't overwrite an existing .zshrc without us knowing
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
      err "Oh My Zsh install failed."
      return 1
    }
  ok "Oh My Zsh installed."
}

# --------------------- Install extra plugins ----------------------
install_plugins() {
  local dir
  info "Setting up plugins (autosuggestions + syntax highlighting)..."

  dir="$CUSTOM/plugins/zsh-autosuggestions"
  if [ ! -d "$dir" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$dir" \
      && ok "Added zsh-autosuggestions" || warn "Could not add zsh-autosuggestions"
  fi

  dir="$CUSTOM/plugins/zsh-syntax-highlighting"
  if [ ! -d "$dir" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$dir" \
      && ok "Added zsh-syntax-highlighting" || warn "Could not add zsh-syntax-highlighting"
  fi

  dir="$CUSTOM/plugins/zsh-history-substring-search"
  if [ ! -d "$dir" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search "$dir" \
      && ok "Added history-substring-search (type + ↑ to search)" \
      || warn "Could not add zsh-history-substring-search"
  fi
}

# --------------------- Install Powerlevel10k ----------------------c
install_p10k() {
  local dir="$CUSTOM/themes/powerlevel10k"
  if [ -d "$dir" ]; then
    ok "Powerlevel10k already present."
    return 0
  fi
  info "Downloading the Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k "$dir" \
    && ok "Powerlevel10k added" || warn "Could not add Powerlevel10k"
}

# ---------------- Install the Kali Linux-style theme --------------
# Reproduces Kali's famous two-line prompt:
#   ┌──(user㉿host)-[~/folder]
#   └─$
install_kali_theme() {
  local dir="$CUSTOM/themes"
  local file="$dir/kali.zsh-theme"
  mkdir -p "$dir"

  # ---- Ask: which colours? (basic green/blue look washed out on Ubuntu) ----
  title "Pick the colours for your Kali prompt"
  say "  ${BOLD}1)${RESET} Bright green + cyan  ${CYAN}(high contrast — recommended)${RESET}"
  say "  ${BOLD}2)${RESET} Bright blue + cyan   ${CYAN}(the blue Kali screenshot look)${RESET}"
  say "  ${BOLD}3)${RESET} Purple + pink        ${CYAN}(high contrast, different vibe)${RESET}"
  say "  ${BOLD}4)${RESET} Classic Kali         ${CYAN}(original colours — dimmer)${RESET}"
  local cpick frame name path gitc sym
  read -r -p "$(printf '%sPick [1-4] (default 1): %s' "$YELLOW" "$RESET")" cpick
  case "${cpick:-1}" in
    2) frame=39;  name=51;  path=255; gitc=214; sym=39  ;;
    3) frame=141; name=213; path=255; gitc=222; sym=213 ;;
    4) frame=2;   name=4;   path=7;   gitc=3;   sym=4   ;;
    *) frame=46;  name=51;  path=255; gitc=214; sym=46  ;;
  esac

  # ---- Ask: show the git branch? ----
  local show_git=0
  if ask_yes_no "Show your git branch in the prompt (when inside a git project)?"; then
    show_git=1
  fi

  info "Creating the Kali-style theme..."

  # Part 1: your chosen settings (easy to edit later by hand).
  cat > "$file" <<EOF
# kali.zsh-theme — Kali Linux look for Oh My Zsh
# Made by zsh-setup.sh. Edit the numbers below to re-colour your prompt.
#
# Colour numbers are 0-255. Handy ones:
#   46=bright green  51=cyan  39=blue  141=purple  213=pink
#   214=orange       226=yellow        255=white   196=red
KALI_FRAME=$frame     # the ┌── └─ frame and the brackets
KALI_NAME=$name       # your name㉿computer
KALI_PATH=$path       # the [~/folder] path
KALI_GIT=$gitc        # the git branch
KALI_SYM=$sym         # the \$ at the end
KALI_SHOW_GIT=$show_git      # 1 = show git branch, 0 = hide it
EOF

  # Part 2: the prompt itself (written literally; zsh reads it later).
  cat >> "$file" <<'THEME'

# REQUIRED: lets the prompt expand $variables (colours, git, venv) each
# time it is drawn. Without this they would show up as literal text.
setopt PROMPT_SUBST

# Safety net: bright colours (0-255) only work on modern terminals. On a
# plain text console (Ctrl+Alt+F3) there are just 8 colours, so fall back
# to basic ones instead of printing garbage.
zmodload -i zsh/terminfo 2>/dev/null
if (( ${terminfo[colors]:-8} < 256 )); then
  KALI_FRAME=2; KALI_NAME=4; KALI_PATH=7; KALI_GIT=3; KALI_SYM=4
fi

# The symbol between your name and the computer name.
# If it shows as an empty box, change it to a plain @
prompt_symbol=㉿

# Shows "-[branch ✗]" when you are inside a git project ( ✗ = unsaved changes).
# Prints nothing at all when you are not in a git project.
kali_git_segment() {
  [[ "$KALI_SHOW_GIT" == 1 ]] || return
  local branch dirty
  branch=$(command git symbolic-ref --short HEAD 2>/dev/null) \
    || branch=$(command git rev-parse --short HEAD 2>/dev/null) \
    || return
  [[ -n $(command git status --porcelain 2>/dev/null) ]] && dirty=" ✗"
  print -n "%F{$KALI_FRAME}-[%B%F{$KALI_GIT}${branch}${dirty}%b%F{$KALI_FRAME}]"
}

# The two-line Kali prompt.
# Root automatically turns red (name and the # symbol) as a warning.
PROMPT=$'%F{$KALI_FRAME}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.196.$KALI_NAME)}%n${prompt_symbol}%m%b%F{$KALI_FRAME})-[%B%F{$KALI_PATH}%(6~.%-1~/…/%4~.%5~)%b%F{$KALI_FRAME}]$(kali_git_segment)\n└─%B%(#.%F{196}#.%F{$KALI_SYM}$)%b%f '

# Optional: uncomment to show the clock on the right side.
# RPROMPT=$'%F{$KALI_FRAME}[%B%F{$KALI_PATH}%D{%H:%M:%S}%b%F{$KALI_FRAME}]%f'
THEME
  ok "Kali-style theme created."
}

# ------------------------- Theme chooser --------------------------
# IMPORTANT: this function's ONLY stdout is the chosen theme name, because
# callers capture it with theme="$(choose_theme)". All the menu text must
# therefore go to stderr (>&2), or it would end up inside ZSH_THEME.
choose_theme() {
  {
    title "Pick a theme (this changes how your terminal looks)"
    say  "  ${BOLD}1)${RESET} robbyrussell   ${CYAN}(simple, the default — great for beginners)${RESET}"
    say  "  ${BOLD}2)${RESET} agnoster       ${CYAN}(shows folder + git in a nice bar)${RESET}"
    say  "  ${BOLD}3)${RESET} powerlevel10k  ${CYAN}(fancy, fast, most popular — needs a Nerd Font)${RESET}"
    say  "  ${BOLD}4)${RESET} avit           ${CYAN}(clean and minimal)${RESET}"
    say  "  ${BOLD}5)${RESET} bira           ${CYAN}(two-line prompt with lots of info)${RESET}"
    say  "  ${BOLD}6)${RESET} kali           ${CYAN}(the Kali Linux hacker look — ┌──(you㉿pc)-[dir])${RESET}"
  } >&2
  local pick
  read -r -p "$(printf '%sEnter a number [1-6] (default 1): %s' "$YELLOW" "$RESET")" pick >&2
  case "${pick:-1}" in
    1) printf 'robbyrussell' ;;
    2) printf 'agnoster' ;;
    3) install_p10k >&2; printf 'powerlevel10k/powerlevel10k' ;;
    4) printf 'avit' ;;
    5) printf 'bira' ;;
    6) install_kali_theme >&2; printf 'kali' ;;
    *) warn "Didn't understand that — using robbyrussell." >&2; printf 'robbyrussell' ;;
  esac
}

# ------------------ Write / update the .zshrc ---------------------
backup_zshrc() {
  if [ -f "$ZSHRC" ] && [ ! -f "$ZSHRC.pre-zsh-setup" ]; then
    cp "$ZSHRC" "$ZSHRC.pre-zsh-setup"
    ok "Saved a backup of your old settings to: $ZSHRC.pre-zsh-setup"
  fi
}

write_zshrc() {
  local theme="$1"
  backup_zshrc
  info "Writing your new Zsh settings file..."
  cat > "$ZSHRC" <<EOF
# ~/.zshrc — generated by zsh-setup.sh
# You can edit this file any time. Lines starting with # are notes.

export ZSH="\$HOME/.oh-my-zsh"

# The look of your prompt:
ZSH_THEME="$theme"

# Plugins add handy features. What each one does:
#   git                     -> short git commands (gst, gco, gp ...)
#   sudo                    -> press ESC twice to add 'sudo' to a command
#   z                       -> jump to folders you visit a lot: 'z downloads'
#   extract                 -> unpack any archive with one word: 'extract file.zip'
#   colored-man-pages       -> colorful, easier-to-read manuals
#   command-not-found       -> suggests the package to install a missing command
#   zsh-autosuggestions     -> greyed-out suggestions as you type (press → to accept)
#   zsh-syntax-highlighting -> commands turn green (ok) or red (typo)
#   zsh-history-substring-search -> type a few letters then ↑ to find old commands
plugins=(
  git
  sudo
  z
  extract
  colored-man-pages
  command-not-found
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
)

source \$ZSH/oh-my-zsh.sh

# ==================================================================
#  Essential Zsh settings
# ==================================================================

# ---- Report the right shell ----
# Some apps (VS Code's built-in terminal, tmux, some IDEs) read the \$SHELL
# variable to decide which shell to start. \$SHELL is normally only set when
# you log in, so right after switching to zsh it can still say "bash".
# This line makes sure anything you launch from zsh gets the correct value.
export SHELL="\$(command -v zsh)"

# ---- History: remember lots, no duplicates, shared across terminals ----
HISTFILE=\$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # don't keep duplicate commands
setopt HIST_IGNORE_SPACE      # a leading space hides a command from history
setopt HIST_REDUCE_BLANKS     # tidy up extra spaces
setopt SHARE_HISTORY          # all open terminals share one history
setopt INC_APPEND_HISTORY     # write commands right away

# ---- Nicer navigation & typing ----
setopt AUTO_CD                # type a folder name to 'cd' into it
setopt AUTO_PUSHD             # keep a stack of visited folders
setopt PUSHD_IGNORE_DUPS
setopt INTERACTIVE_COMMENTS   # allow # comments when typing commands

# NOTE: "autocorrect" is deliberately OFF. It nags things like
#   zsh: correct 'npm' to 'nm' [nyae]?
# which is more annoying than helpful. Uncomment if you really want it:
# setopt CORRECT

# ---- Auto-suggestions (the grey "ghost text" that guesses your command) ----
# Press the RIGHT ARROW (→) to accept a suggestion. Ctrl+→ accepts one word.
# The default grey is very hard to read, so we brighten it here.
# Higher number = brighter. Try 240 (dim) up to 250 (bright).
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=245'
# Guess from your history first, then from completions:
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# Don't try to suggest for giant pasted commands (keeps things fast):
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
bindkey '^ ' autosuggest-accept        # Ctrl+Space also accepts a suggestion

# ---- Smarter tab-completion ----
autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' menu select                          # arrow-key menu
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"     # colored matches

# ---- Handy keyboard shortcuts ----
bindkey '^[[A' history-substring-search-up     # Up arrow  = search history
bindkey '^[[B' history-substring-search-down   # Down arrow = search history
bindkey '^[[H' beginning-of-line               # Home key
bindkey '^[[F' end-of-line                     # End key
bindkey '^[[3~' delete-char                    # Delete key

# ---- Everyday aliases (shortcuts) ----
alias ll='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias l='ls -CF --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias mkcd='foo(){ mkdir -p "\$1" && cd "\$1"; }; foo'   # make a folder and enter it
alias please='sudo \$(fc -ln -1)'                        # re-run last command with sudo
alias update='sudo apt update && sudo apt upgrade -y'   # update the whole system
# Use nicer tools if they were installed:
command -v batcat >/dev/null && alias cat='batcat --paging=never'
command -v eza    >/dev/null && alias ls='eza --group-directories-first --icons=auto'

# ==================================================================
#  Developer tools
#  Each block only runs if you actually have that tool installed, so
#  it is safe to leave them all here. This is what makes commands like
#  node / npm / nvm work in zsh the same way they do in bash.
# ==================================================================

# ---- nvm (Node.js version manager) ----
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && source "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && source "\$NVM_DIR/bash_completion"

# ---- Rust / cargo ----
[ -f "\$HOME/.cargo/env" ] && source "\$HOME/.cargo/env"

# ---- pyenv (Python version manager) ----
if [ -d "\$HOME/.pyenv" ]; then
  export PYENV_ROOT="\$HOME/.pyenv"
  [ -d "\$PYENV_ROOT/bin" ] && export PATH="\$PYENV_ROOT/bin:\$PATH"
  command -v pyenv >/dev/null && eval "\$(pyenv init -)"
fi

# ---- Your own programs in ~/.local/bin (pip, pipx, etc.) ----
[ -d "\$HOME/.local/bin" ] && export PATH="\$HOME/.local/bin:\$PATH"

# ---- fzf: fuzzy finder (Ctrl+R = search history, Ctrl+T = pick a file) ----
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && \\
  source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/doc/fzf/examples/completion.zsh ] && \\
  source /usr/share/doc/fzf/examples/completion.zsh

# Load Ubuntu's system plugins too, if present:
[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \\
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \\
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==================================================================
#  YOUR personal aliases & settings live in a SEPARATE file so they
#  are safe even if you change themes or reinstall.
#  Edit it any time with:   nano ~/.zsh_aliases
#  (Or use this script's menu -> "Add an alias".)
# ==================================================================
[ -f "\$HOME/.zsh_aliases" ] && source "\$HOME/.zsh_aliases"
EOF

  if [ "$theme" = "powerlevel10k/powerlevel10k" ]; then
    cat >> "$ZSHRC" <<'EOF'

# Powerlevel10k: run `p10k configure` to set up the fancy prompt.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF
  fi
  ok "Settings written to $ZSHRC"
}

# ------------------ Make zsh the default shell --------------------
set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [ -z "$zsh_path" ] && { warn "zsh not found on PATH; skipping default-shell step."; return; }

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "zsh is already your default shell."
    return
  fi
  if ask_yes_no "Make zsh your default shell from now on?"; then
    if chsh -s "$zsh_path"; then
      ok "Done! zsh will start automatically next time you open a terminal."
    else
      warn "Could not change the default shell automatically."
      say  "You can do it later with:  ${BOLD}chsh -s $zsh_path${RESET}"
    fi
  else
    say "No problem. You can start zsh any time by typing:  ${BOLD}zsh${RESET}"
  fi
}

# Read the user's REAL configured login shell (not the $SHELL variable,
# which only updates after you log out).
current_login_shell() {
  local s
  s="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
  [ -z "$s" ] && s="${SHELL:-unknown}"
  printf '%s' "$s"
}

# Standalone menu: let the user pick zsh or bash as their default shell.
do_set_default_shell() {
  title "Set your default shell"
  local now zsh_path bash_path
  now="$(current_login_shell)"
  zsh_path="$(command -v zsh || true)"
  bash_path="$(command -v bash || echo /bin/bash)"

  say "Your default shell right now is:  ${BOLD}$now${RESET}"
  say "The \$SHELL variable says:         ${BOLD}${SHELL:-unknown}${RESET}"
  # Explain the classic "I changed it but VS Code still opens bash" situation.
  if [ "$now" != "${SHELL:-}" ]; then
    say ""
    warn "These two do not match — that is normal right after switching shells."
    say  "\$SHELL is only refreshed when you LOG IN. Until you log out and back"
    say  "in, apps started from the desktop (VS Code, IDEs) may still open"
    say  "${BOLD}$(basename "${SHELL:-bash}")${RESET} even though your real default is ${BOLD}$(basename "$now")${RESET}."
    say  "${GREEN}Fix: log out and log back in (or reboot).${RESET}"
  fi
  say ""
  say "  ${BOLD}1)${RESET} zsh   ${CYAN}(the fancy one this script sets up)${RESET}"
  say "  ${BOLD}2)${RESET} bash  ${CYAN}(the classic Ubuntu default)${RESET}"
  say "  ${BOLD}3)${RESET} Cancel"
  local pick target
  read -r -p "$(printf '%sPick [1-3]: %s' "$YELLOW" "$RESET")" pick
  case "${pick:-}" in
    1)
      if [ -z "$zsh_path" ]; then
        err "zsh isn't installed yet. Run the Install option first."
        return 1
      fi
      target="$zsh_path"
      ;;
    2) target="$bash_path" ;;
    3|"") say "Cancelled. Nothing changed."; return ;;
    *) warn "Please type 1, 2, or 3."; return ;;
  esac

  if [ "$now" = "$target" ]; then
    ok "That's already your default shell. Nothing to do."
    return
  fi
  info "Changing your default shell to: $target"
  if chsh -s "$target"; then
    ok "Done! It takes effect the next time you open a terminal (or log out/in)."
  else
    warn "Could not change it automatically."
    say  "Run this yourself:  ${BOLD}chsh -s $target${RESET}"
  fi
}

# ============================ INSTALL =============================
do_install() {
  title "Installing Zsh — sit back and relax!"
  pre_checks
  install_packages   || return 1
  install_omz        || return 1
  install_plugins
  ensure_aliases_file
  local theme
  theme="$(choose_theme)"
  write_zshrc "$theme"

  # Offer to bring over existing Bash aliases/exports.
  if ask_yes_no "Import your existing aliases & exports from Bash?"; then
    do_import_from_bash
  fi

  set_default_shell

  title "All done! ✰"
  ok "Zsh + Oh My Zsh are ready."
  say ""
  say "Next steps:"
  say "  1) Close this terminal and open a new one (or type: ${BOLD}zsh${RESET})"
  say "  ${BOLD}2) Log out and log back in${RESET} — this makes apps like VS Code"
  say "     open zsh too. Without it they keep opening bash."
  if [ "$theme" = "powerlevel10k/powerlevel10k" ]; then
    say "  2) Run ${BOLD}p10k configure${RESET} to design your fancy prompt"
    say "     (Tip: install a 'Nerd Font' like MesloLGS NF for the icons.)"
  fi
  say ""
}

# =========================== UNINSTALL ===========================
do_uninstall() {
  title "Remove Zsh setup"
  warn "This will remove Oh My Zsh, the plugins, and the settings this script made."
  ask_yes_no "Are you SURE you want to uninstall?" || { say "Cancelled. Nothing changed."; return; }

  # 1) Switch default shell back to bash first (so you're never stuck).
  #    We read your REAL configured shell from the system (getent), not the
  #    $SHELL variable, because $SHELL doesn't update until you log out.
  local bash_path current_shell
  bash_path="$(command -v bash || echo /bin/bash)"
  current_shell="$(current_login_shell)"
  if [ "$current_shell" != "$bash_path" ]; then
    info "Setting your default shell back to bash..."
    if chsh -s "$bash_path"; then
      ok "Default shell is bash again."
    else
      warn "Could not switch shell automatically."
      say  "Run this yourself to finish:  ${BOLD}chsh -s $bash_path${RESET}"
    fi
  else
    ok "Your default shell is already bash."
  fi

  # 2) Remove Oh My Zsh (this also removes custom plugins/themes inside it)
  if [ -d "$OMZ_DIR" ]; then
    info "Removing $OMZ_DIR ..."
    rm -rf "$OMZ_DIR" && ok "Oh My Zsh removed."
  fi

  # 3) Restore or remove .zshrc
  if [ -f "$ZSHRC.pre-zsh-setup" ]; then
    mv "$ZSHRC.pre-zsh-setup" "$ZSHRC"
    ok "Restored your original .zshrc."
  elif [ -f "$ZSHRC" ]; then
    rm -f "$ZSHRC" && ok "Removed the generated .zshrc."
  fi
  # Powerlevel10k + history leftovers
  [ -f "$HOME/.p10k.zsh" ] && rm -f "$HOME/.p10k.zsh" && ok "Removed .p10k.zsh"
  [ -f "$HOME/.zsh_history" ] && rm -f "$HOME/.zsh_history" && ok "Removed .zsh_history"
  [ -f "$HOME/.zcompdump" ] && rm -f "$HOME"/.zcompdump* && ok "Removed completion cache"

  # Personal aliases are YOUR work — keep them unless you say otherwise.
  if [ -f "$ALIASES_FILE" ]; then
    if ask_yes_no "Also delete your personal aliases file ($ALIASES_FILE)?"; then
      rm -f "$ALIASES_FILE" && ok "Removed your aliases file."
    else
      ok "Kept your aliases file at $ALIASES_FILE (safe for next time)."
    fi
  fi

  # 4) Optionally remove the zsh program itself
  if ask_yes_no "Also uninstall the zsh program with apt? (optional)"; then
    need_sudo apt-get remove -y zsh zsh-autosuggestions zsh-syntax-highlighting \
      && ok "zsh packages removed." || warn "Could not remove zsh packages."
    if ask_yes_no "Clean up unused leftover packages too?"; then
      need_sudo apt-get autoremove -y
    fi
  else
    say "Kept the zsh program installed (you can still type 'zsh')."
  fi

  title "Uninstall complete."
  ok  "You're back to a clean setup. Open a new terminal to see bash."
}

# ======================== CHANGE THEME ONLY ======================
do_change_theme() {
  title "Change your Zsh theme"
  if [ ! -d "$OMZ_DIR" ]; then
    err "Oh My Zsh isn't installed yet. Please run the Install option first."
    return 1
  fi
  local theme
  theme="$(choose_theme)"
  # Regenerate the whole .zshrc cleanly. This is safe because your personal
  # aliases/exports live in ~/.zsh_aliases (untouched), so nothing is lost —
  # and it also repairs any earlier broken ZSH_THEME line.
  write_zshrc "$theme"
  ok "Theme changed to: $theme"
  say "Open a new terminal (or type 'zsh') to see it."
}

# ===================== ADD / MANAGE ALIASES ======================
do_add_alias() {
  title "Add a shortcut (alias)"
  ensure_aliases_file
  say "An alias is a short nickname for a longer command."
  say "Example: name ${BOLD}gs${RESET}  ->  command ${BOLD}git status${RESET}"
  say ""

  local name cmd
  read -r -p "$(printf '%sShort name (no spaces): %s' "$YELLOW" "$RESET")" name
  # Keep only safe characters for the name.
  if ! printf '%s' "$name" | grep -Eq '^[A-Za-z0-9_-]+$'; then
    err "That name has spaces or odd characters. Use letters/numbers only."
    return 1
  fi
  read -r -p "$(printf '%sThe full command it should run: %s' "$YELLOW" "$RESET")" cmd
  if [ -z "${cmd// }" ]; then
    err "The command was empty. Nothing added."
    return 1
  fi

  # If an alias with this name already exists, offer to replace it.
  if grep -Eq "^alias[[:space:]]+$name=" "$ALIASES_FILE" 2>/dev/null; then
    ask_yes_no "'$name' already exists. Replace it?" || { say "Kept the old one."; return; }
    # Remove the old line (portable in-place edit).
    sed -i "/^alias[[:space:]]\+$name=/d" "$ALIASES_FILE"
  fi

  # Escape any single quotes in the command so the alias line stays valid.
  local safe_cmd
  safe_cmd=$(printf "%s" "$cmd" | sed "s/'/'\\\\''/g")
  printf "alias %s='%s'\n" "$name" "$safe_cmd" >> "$ALIASES_FILE"
  ok "Added:  $name  ->  $cmd"
  say "It works in NEW terminals, or run ${BOLD}source ~/.zshrc${RESET} now."
}

list_aliases() {
  title "Your personal aliases"
  if [ ! -f "$ALIASES_FILE" ] || ! grep -q '^alias ' "$ALIASES_FILE"; then
    say "You haven't added any yet. Pick 'Add an alias' to make one!"
    return
  fi
  grep '^alias ' "$ALIASES_FILE" | sed 's/^alias /  • /'
  say ""
  say "Edit them by hand any time:  ${BOLD}nano ~/.zsh_aliases${RESET}"
}

# Import aliases and 'export' variables from the user's bash files.
do_import_from_bash() {
  title "Import from Bash"
  say "This copies your ${BOLD}alias${RESET} and ${BOLD}export${RESET} lines from Bash into Zsh."
  ensure_aliases_file

  # Bash files we look inside (only the ones that exist).
  local sources=("$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.bash_profile" "$HOME/.profile")
  local found=() f
  for f in "${sources[@]}"; do [ -f "$f" ] && found+=("$f"); done
  if [ "${#found[@]}" -eq 0 ]; then
    warn "No Bash config files found in your home folder. Nothing to import."
    return
  fi
  info "Looking inside: ${found[*]}"

  # Gather candidate lines (aliases + exports), skipping comments.
  local tmp; tmp="$(mktemp)"
  grep -hE '^[[:space:]]*(alias|export)[[:space:]]' "${found[@]}" 2>/dev/null \
    | grep -vE '^[[:space:]]*#' > "$tmp"

  if [ ! -s "$tmp" ]; then
    warn "Didn't find any alias/export lines to import."
    rm -f "$tmp"; return
  fi

  say ""
  say "${BOLD}Found these lines:${RESET}"
  sed 's/^[[:space:]]*/  • /' "$tmp"
  say ""
  if ! ask_yes_no "Import these into ~/.zsh_aliases?"; then
    say "Cancelled. Nothing imported."
    rm -f "$tmp"; return
  fi

  # Append, skipping ones already present (by alias name, or exact export line).
  local added=0 skipped=0 line name
  {
    printf '\n# ---- Imported from Bash on %s ----\n' "$(date '+%Y-%m-%d %H:%M')"
  } >> "$ALIASES_FILE"
  while IFS= read -r line; do
    if printf '%s' "$line" | grep -Eq '^[[:space:]]*alias[[:space:]]'; then
      # An alias: skip if we already have one with the same name.
      name="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*alias[[:space:]]+([A-Za-z0-9_-]+)=.*/\1/')"
      if grep -Eq "^[[:space:]]*alias[[:space:]]+$name=" "$ALIASES_FILE"; then
        skipped=$((skipped+1)); continue
      fi
    else
      # An export line: skip if the exact same line is already there.
      if grep -Fxq "$line" "$ALIASES_FILE"; then
        skipped=$((skipped+1)); continue
      fi
    fi
    printf '%s\n' "$line" >> "$ALIASES_FILE"
    added=$((added+1))
  done < "$tmp"
  rm -f "$tmp"

  ok "Imported $added line(s); skipped $skipped already-present."
  say "They load in NEW terminals, or run ${BOLD}source ~/.zshrc${RESET} now."
  say ""
  warn "This only copies 'alias' and 'export' lines."
  say  "Tool loaders in .bashrc (the ${BOLD}[ -s ... ] && . ...${RESET} lines for nvm,"
  say  "pyenv, cargo, etc.) are NOT copied — but your .zshrc already loads those"
  say  "tools automatically, so node/npm/nvm keep working. Anything more exotic"
  say  "you may need to copy over by hand."
}

do_aliases_menu() {
  while true; do
    title "----- Shortcuts (aliases) -----"
    say "  ${BOLD}1)${RESET} Add a new alias"
    say "  ${BOLD}2)${RESET} Show my aliases"
    say "  ${BOLD}3)${RESET} Import aliases & exports from Bash"
    say "  ${BOLD}4)${RESET} Open the file to edit by hand"
    say "  ${BOLD}5)${RESET} Back to main menu"
    local c
    read -r -p "$(printf '%sPick [1-5]: %s' "$YELLOW" "$RESET")" c
    case "${c:-}" in
      1) do_add_alias ;;
      2) list_aliases ;;
      3) do_import_from_bash ;;
      4) ensure_aliases_file; "${EDITOR:-nano}" "$ALIASES_FILE" ;;
      5) return ;;
      *) warn "Please type 1, 2, 3, 4, or 5." ;;
    esac
  done
}

# ============================= HELP ==============================
do_help() {
  title "===== Help — what is this and what does each option do? ====="
  say "This helper sets up ${BOLD}Zsh${RESET} + ${BOLD}Oh My Zsh${RESET}: a friendlier terminal with"
  say "colours, tab-completion, and shortcuts. You just pick numbers."
  say ""

  say "${BOLD}The menu options${RESET}"
  say "  ${BOLD}1) Install Zsh + Oh My Zsh${RESET}"
  say "     Start here. Installs zsh and its plugins, lets you pick a theme,"
  say "     offers to copy your Bash aliases over, and can make zsh your"
  say "     default shell. Safe to run again — it skips what you already have."
  say "  ${BOLD}2) Change my theme${RESET}"
  say "     Changes how your prompt looks. Your personal aliases are untouched."
  say "  ${BOLD}3) Add / manage my shortcuts (aliases)${RESET}"
  say "     Make a nickname for a long command, list the ones you have,"
  say "     import them from Bash, or open the file and edit it by hand."
  say "  ${BOLD}4) Set my default shell (zsh or bash)${RESET}"
  say "     Pick which shell opens when you start a terminal. You can always"
  say "     switch back to bash here."
  say "  ${BOLD}5) Uninstall / remove everything${RESET}"
  say "     Puts your default shell back to bash and removes what this script"
  say "     added. It asks first before deleting your personal aliases."
  say "  ${BOLD}6) Help${RESET}  — this screen."
  say "  ${BOLD}7) Quit${RESET}  — leave the menu. Nothing is changed on the way out."
  say ""

  say "${BOLD}Files this script touches${RESET}"
  say "  ${CYAN}~/.zshrc${RESET}                your zsh settings (this script writes it)"
  say "  ${CYAN}~/.zshrc.pre-zsh-setup${RESET}  a backup of your settings from before"
  say "  ${CYAN}~/.zsh_aliases${RESET}          YOUR shortcuts — never overwritten"
  say "  ${CYAN}~/.oh-my-zsh/${RESET}           Oh My Zsh itself, plus themes and plugins"
  say ""

  say "${BOLD}Handy things once zsh is running${RESET}"
  say "  • Type part of an old command, then ${BOLD}↑${RESET} to find it again"
  say "  • Press ${BOLD}→${RESET} to accept the grey suggestion as you type"
  say "  • ${BOLD}Ctrl+R${RESET} searches your history, ${BOLD}Ctrl+T${RESET} picks a file"
  say "  • Press ${BOLD}ESC ESC${RESET} to put 'sudo' in front of the command you just typed"
  say "  • Type a folder name on its own to enter it; ${BOLD}z name${RESET} jumps to folders you use a lot"
  say "  • ${BOLD}extract file.zip${RESET} unpacks any kind of archive"
  say ""

  say "${BOLD}If something looks wrong${RESET}"
  say "  • ${BOLD}Boxes or ? instead of icons${RESET} — install a Nerd Font (e.g. MesloLGS NF)"
  say "    and choose it in your terminal's settings. Themes 3 and 6 want one."
  say "  • ${BOLD}VS Code still opens bash${RESET} — log out and log back in once."
  say "  • ${BOLD}A change isn't showing up${RESET} — run ${BOLD}source ~/.zshrc${RESET} or open a new terminal."
  say "  • ${BOLD}Want your old setup back${RESET} — option 5 restores your .zshrc backup."
  say ""

  say "You can also read this without opening the menu:"
  say "  ${BOLD}bash zsh-setup.sh --help${RESET}"
  say ""

  say "${BOLD}About${RESET}"
  credit "  "
  say "  Issues and ideas are welcome on GitHub."
}

# ============================= MENU ==============================
main_menu() {
  while true; do
    title "===== Zsh Easy Setup ====="
    say "  ${BOLD}1)${RESET} Install Zsh + Oh My Zsh  ${GREEN}(recommended)${RESET}"
    say "  ${BOLD}2)${RESET} Change my theme"
    say "  ${BOLD}3)${RESET} Add / manage my shortcuts (aliases)"
    say "  ${BOLD}4)${RESET} Set my default shell (zsh or bash)"
    say "  ${BOLD}5)${RESET} Uninstall / remove everything"
    say "  ${BOLD}6)${RESET} Help  ${CYAN}(what does each option do?)${RESET}"
    say "  ${BOLD}7)${RESET} Quit"
    local choice
    read -r -p "$(printf '%sPick a number [1-7]: %s' "$YELLOW" "$RESET")" choice
    case "${choice:-}" in
      1) do_install ;;
      2) do_change_theme ;;
      3) do_aliases_menu ;;
      4) do_set_default_shell ;;
      5) do_uninstall ;;
      6|h|H|\?) do_help ;;
      7) say "Bye! 👋"; credit; exit 0 ;;
      *) warn "Please type a number from 1 to 7 (or 6 for help)." ;;
    esac
    say ""
    read -r -p "$(printf '%sPress Enter to return to the menu...%s' "$CYAN" "$RESET")" _
  done
}

# --------------------------- Start here ---------------------------
# Only show the menu when the script is RUN. If it is sourced by another
# script (or a test), just load the functions and do nothing.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    -h|--help|help) do_help; exit 0 ;;
  esac
  clear 2>/dev/null || true
  title "👋 Welcome! This helper installs a nicer terminal (Zsh)."
  say  "You just pick numbers from a menu. Nothing scary. Let's go!"
  say  "Not sure what something does? Pick ${BOLD}6) Help${RESET}."
  say  ""
  credit
  main_menu
fi
