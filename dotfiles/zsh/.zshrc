# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#Created by newuser for 5.9

autoload -Uz compinit
compinit
_comp_options+=(globdots)

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/tim/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] 

# theme/plugins
source ~/.config/zsh/.p10k.zsh
source ~/.config/zsh/powerlevel10k/powerlevel10k.zsh-theme
source ~/.config/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.config/zsh/zsh-autosuggestions.zsh
source ~/.config/zsh/zsh-history-substring-search.zsh
source ~/.config/zsh/auto-notify.plugin.zsh
source ~/.config/zsh/you-should-use.plugin.zsh

# history substring options
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# auto notify options 
AUTO_NOTIFY_IGNORE+=("lf")

# My custom aliases
alias vim='nvim'
alias sudo='sudo '
alias code='codium'
