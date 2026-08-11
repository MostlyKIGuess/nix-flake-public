# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

zsh_custom_directory="$HOME/.zsh_custom"
[[ -r "$zsh_custom_directory/themes/powerlevel10k/powerlevel10k.zsh-theme" ]] &&
  source "$zsh_custom_directory/themes/powerlevel10k/powerlevel10k.zsh-theme"

autoload -Uz compinit
# -i skips insecure directories instead of asking a [y/n] question that the
# instant prompt cannot answer.
compinit -i -d "${XDG_CACHE_HOME:-$HOME/.cache}/zcompdump"

[[ -r "$zsh_custom_directory/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] &&
  source "$zsh_custom_directory/plugins/fzf-tab/fzf-tab.plugin.zsh"
[[ -r "$zsh_custom_directory/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] &&
  source "$zsh_custom_directory/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -r "$zsh_custom_directory/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh" ]] &&
  source "$zsh_custom_directory/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"

# Keybindings
bindkey -e
zmodload -i zsh/terminfo
[[ -n "${terminfo[kcuu1]}" ]] &&
  bindkey "${terminfo[kcuu1]}" history-search-backward
[[ -n "${terminfo[kcud1]}" ]] &&
  bindkey "${terminfo[kcud1]}" history-search-forward
#bindkey 'v' history-search-backward

# History
HISTSIZE=100000
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

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu no
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always $realpath'

# helpful aliases
alias c='clear' # clear terminal
alias l='eza -lh --icons=auto' # long list
alias ls='eza -1 --icons=auto' # short list
alias ll='eza -lha --icons=auto --sort=name --group-directories-first' # long list all
alias ld='eza -lhd --icons=auto' # long list dirs
alias lt='eza --icons=auto --tree' # list folder as tree
alias vc='code' # gui code editor
alias y='yazi'

# directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'

# always mkdir a path (this doesn't inhibit functionality to make a single dir)
alias mkdir='mkdir -p'

# to customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

export DIRENV_LOG_FORMAT=""

bindkey "\e[1;5D" backward-word
bindkey "\e[1;5C" forward-word

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down


# Open the current command in your $EDITOR (e.g., neovim)
# Press Ctrl+X followed by Ctrl+E to trigger
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

bindkey ' ' magic-space

bindkey '^[l' autosuggest-accept
bindkey '^F' autosuggest-accept-word


bindkey '^[k' history-substring-search-up
bindkey '^[j' history-substring-search-down

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
  alias cd='z'
fi

# This plugin must remain last because it wraps widgets defined above.
[[ -r "$zsh_custom_directory/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] &&
  source "$zsh_custom_directory/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
