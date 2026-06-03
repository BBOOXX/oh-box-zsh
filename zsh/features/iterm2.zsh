# features/iterm2.zsh
# iTerm2 shell integration 入口

if [[ -n "${__zsh_feature_iterm2_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_feature_iterm2_loaded=1

# 只加载已有的官方脚本
if [[ -r "$HOME/.iterm2_shell_integration.zsh" ]]; then
  zsh_log_debug "iterm2: source $HOME/.iterm2_shell_integration.zsh"
  source "$HOME/.iterm2_shell_integration.zsh"
  return 0
fi

# 官方安装脚本在 zsh 且存在 ZDOTDIR 时可能把文件安装到 ZDOTDIR
if [[ "$ZDOTDIR" != "$HOME" && -r "$ZDOTDIR/.iterm2_shell_integration.zsh" ]]; then
  zsh_log_debug "iterm2: source $ZDOTDIR/.iterm2_shell_integration.zsh"
  source "$ZDOTDIR/.iterm2_shell_integration.zsh"
  return 0
fi

zsh_log_debug "iterm2: integration file not found"
