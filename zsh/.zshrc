# Set the directory we want to store zinit and plugins
# The XDG bit is parameter expansion which gets the ENV VAR for XDG
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
	mkdir -p "$(dirname $ZINIT_HOME)"
	git clone https://github.com/zdharma-continuum/zinit "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Load Completions
autoload -U compinit && compinit

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Keybindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion Styling

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no



alias ff='fastfetch'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias polybar-c='nvim ~/.config/polybar/config.ini'
alias polybar-l='nvim ~/.config/polybar/launch_polybar.sh'
alias i3-c='nvim ~/.config/i3/config'

# To start fuzzy finder
eval "$(fzf --zsh)"

export PATH="$HOME/.local/bin:$PATH"

export EDITOR=nvim
ff
