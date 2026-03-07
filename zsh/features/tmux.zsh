# features/tmux.zsh
# tmux 接入层.
#
# 默认情况下这个 feature 是非常克制的.
# 它不会在你没有明确允许时自动 attach.
#
# 开关逻辑如下.
# - ZSH_TMUX_AUTO_ATTACH=0, 直接跳过.
# - 当前不是 interactive shell, 直接跳过.
# - tmux 不存在, 直接跳过.
# - 当前已经在 tmux 内, 直接跳过.
#
# 如果全部条件都满足, 才尝试附着到指定 session.
# session 不存在时, 就新建一个.

# 只有 interactive 阶段才考虑 tmux.
if [[ "$ZSH_CURRENT_STAGE" != "interactive" ]]; then
  return 0
fi

# 默认不开启自动附着.
(( ${ZSH_TMUX_AUTO_ATTACH:-0} )) || return 0

# 只对交互式 shell 生效.
zsh_is_interactive || return 0

# tmux 命令不存在就跳过.
zsh_has_cmd tmux || return 0

# 已经在 tmux 内时, 不要再嵌套 attach.
[[ -n "${TMUX:-}" ]] && return 0

# 有目标 session 就 attach, 否则创建.
if tmux has-session -t "${ZSH_TMUX_SESSION:-main}" 2>/dev/null; then
  exec tmux attach -t "${ZSH_TMUX_SESSION:-main}"
else
  exec tmux new -s "${ZSH_TMUX_SESSION:-main}"
fi
