# features/tmux.zsh
# tmux 入口

if [[ -n "${__zsh_feature_tmux_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_feature_tmux_loaded=1

# --------------------------------------------------
# zsh_tmux_has_sessions
# --------------------------------------------------
# 判断当前 tmux server 是否已经有可 attach 的 session
zsh_tmux_has_sessions() {
  command tmux list-sessions >/dev/null 2>&1
}

# --------------------------------------------------
# zsh_tmux_should_auto_attach
# --------------------------------------------------
# 只在外层 shell 接管无参 tmux
# 已经处在 tmux 内时保留原生命令语义, 避免误触发嵌套 attach/new
zsh_tmux_should_auto_attach() {
  (( ${ZSH_TMUX_AUTO_ATTACH:-1} )) || return 1
  [[ -z "${TMUX:-}" ]]
}

# --------------------------------------------------
# zsh_tmux_entry
# --------------------------------------------------
# 统一处理 tmux 命令入口
# - 无参数时: 有 session 则 attach, 否则 new-session
# - 有参数时: 原样透传给真实 tmux
zsh_tmux_entry() {
  if (( $# == 0 )) && zsh_tmux_should_auto_attach; then
    if zsh_tmux_has_sessions; then
      zsh_log_debug "tmux: no-args action=attach"
      command tmux attach-session
      return $?
    fi

    zsh_log_debug "tmux: no-args action=new"
    command tmux new-session
    return $?
  fi

  command tmux "$@"
}

tmux() {
  zsh_tmux_entry "$@"
}
