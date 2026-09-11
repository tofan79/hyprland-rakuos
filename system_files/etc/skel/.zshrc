# RakuOS Hyprland zsh config - fish-like experience
# Auto-suggestions, syntax highlighting, starship prompt, fzf, zoxide, bat.

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt NO_BEEP

# --- Completion ---
autoload -U compinit
compinit
setopt COMPLETE_IN_WORD

# --- Utilities as defaults ---
export PAGER="bat --paging=never"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
alias cat='bat --paging=never'
alias ls='ls --color=auto'

# --- Fish-like auto-suggestions (as you type) ---
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# --- Starship prompt ---
eval "$(starship init zsh)"

# --- fzf (Ctrl-T pick files, Ctrl-R history, Alt-C cd) ---
eval "$(fzf --zsh)"

# --- zoxide (smart cd, `z <dir>` + `cd <dir>`) ---
eval "$(zoxide init zsh)"

# --- Aliases ---
alias z='zoxide'
alias zi='zoxide query -i'
alias du='du -h'
alias df='df -h'
alias mkdir='mkdir -p'

# --- Syntax highlighting (must be loaded LAST) ---
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh