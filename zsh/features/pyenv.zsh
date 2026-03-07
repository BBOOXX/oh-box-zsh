# features/pyenv.zsh
# pyenv 接入层.
#
# pyenv 和其他很多工具不太一样.
# 它通常同时涉及两类需求.
# 1. login 阶段要尽早准备 PATH, 让 shims 能生效.
# 2. interactive 阶段可能还需要 pyenv init - zsh 带来的函数和 shell 集成.
#
# 所以这里故意让同一个 feature 支持阶段感知.
# - 当前阶段是 login 时, 只做 PATH 级准备.
# - 当前阶段是 interactive 时, 再决定是 eager init 还是 lazy init.
#
# 这也是为什么如果你想完整接入 pyenv, 往往要把 pyenv 同时放到 login 和 interactive 的 feature 列表里.

# 全局开关.
(( ${ZSH_PYENV_ENABLE:-1} )) || return 0

# 确定 PYENV_ROOT.
# 如果外部没给, 默认回落到 ~/.pyenv.
: "${PYENV_ROOT:=$HOME/.pyenv}"

# login 阶段只做 PATH 准备.
if [[ "$ZSH_CURRENT_STAGE" == "login" ]]; then
  path_prepend "$PYENV_ROOT/bin"
  path_prepend "$PYENV_ROOT/shims"
  return 0
fi

# 非 interactive 且非 login 的奇怪阶段, 直接跳过.
if [[ "$ZSH_CURRENT_STAGE" != "interactive" ]]; then
  return 0
fi

# interactive 阶段至少先把 pyenv bin 放进 PATH.
# 这样后面即使选择 lazy, 第一次触发时也更稳.
path_prepend "$PYENV_ROOT/bin"

# 如果 pyenv 根本不存在, 就不继续.
if ! zsh_has_cmd pyenv && [[ ! -x "$PYENV_ROOT/bin/pyenv" ]]; then
  return 0
fi

# 定义一个真正执行 pyenv init - zsh 的 loader.
# 这个 loader 既可以被 eager 直接调用, 也可以被 lazy 包装器调用.
zsh_feature_pyenv_loader() {
  # 某些环境里 PATH 还没看到 pyenv, 但 $PYENV_ROOT/bin/pyenv 实际存在.
  # 所以这里再兜一次.
  if ! zsh_has_cmd pyenv && [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
    path_prepend "$PYENV_ROOT/bin"
  fi

  # 只有在 pyenv 实际可用时, 才 eval 它输出的初始化片段.
  if zsh_has_cmd pyenv; then
    eval "$(pyenv init - zsh)"
  fi
}

# 如果启用了 lazy, 且 lazy 基础设施存在, 则注册懒加载命令.
if (( ${ZSH_PYENV_LAZY:-1} )) && typeset -f zlazy_register >/dev/null 2>&1; then
  local -a cmds

  # 把字符串变量拆成命令数组.
  # 默认只对 pyenv 本身做懒初始化.
  cmds=(${=ZSH_PYENV_INIT_COMMANDS})
  (( ${#cmds[@]} )) || cmds=(pyenv)

  zlazy_register zsh_feature_pyenv_loader "${cmds[@]}"
else
  # 否则直接 eager 初始化.
  zsh_feature_pyenv_loader
fi
