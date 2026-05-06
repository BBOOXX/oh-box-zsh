# 40-lazy.zsh
# 命令懒加载工具

# 把较重初始化延迟到首次命令调用
# 首次调用相关命令时执行初始化
# 初始化成功后后续调用直接走真实命令

# __zlazy_loader_by_cmd
#   记录 某个命令由哪个 loader 负责初始化
#   例如
#   __zlazy_loader_by_cmd[tool]="tool_lazy_init"

# __zlazy_loader_done
#   记录 某个 loader 是否已经成功跑过
#   例如
#   __zlazy_loader_done[tool_lazy_init]=1

# __zlazy_loader_active
#   记录 某个 loader 当前是否正在执行
#   用来防止递归触发和重复进入
typeset -gA __zlazy_loader_by_cmd
typeset -gA __zlazy_loader_done
typeset -gA __zlazy_loader_active

# 判断字符串是否适合作为 zsh 函数名
# zlazy_register 会动态定义包装函数
# 限制命令名以避免 eval 注入
# 首字符 字母或下划线
# 后续字符 字母 / 数字 / 下划线
# 返回值
# 合法 0
# 非法 1
zlazy_is_valid_name() {
  # 取第一个参数作为待检查名称
  local name="$1"

  # 使用正则做严格匹配
  # 连字符不属于本项目允许的懒加载命令名字符
  [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]
}

# 为某个命令动态创建懒加载包装函数
# 内部函数由 zlazy_register 调用
# 例如为 tool 创建包装器后 实际会生成
#   tool() {
#     __zlazy_dispatch 'tool' "$@"
#   }
# 包装函数先进入统一分发器 再由分发器决定是否运行 loader
__zlazy_define_wrapper() {
  # 取目标命令名
  local cmd="$1"

  # 命令名不能为空
  [[ -n "$cmd" ]] || return 1

  # 命令名必须是合法函数名
  zlazy_is_valid_name "$cmd" || return 1

  # 用 eval 动态定义函数
  # eval 用于按变量生成函数名
  # 函数名已通过合法性检查
  # 函数体里把原始参数 "$@" 原样传给统一分发器
  # 并把 cmd 名字作为一个固定字面量传进去
  eval "${cmd}() { __zlazy_dispatch '${cmd}' \"\$@\"; }"
}

# 运行 loader 并处理状态标记
# 返回值
# loader 已经成功运行过 0
# 本次成功运行完成 0
# loader 不存在 / 运行失败 非 0
__zlazy_run_loader() {
  # 取 loader 函数名
  local loader="$1"

  # 用于保存 loader 的退出码
  local rc

  # loader 名不能为空
  if [[ -z "$loader" ]]; then
    zsh_msg warn zlazy "missing loader name"
    return 2
  fi

  # loader 成功执行过则跳过
  if [[ -n "${__zlazy_loader_done[$loader]:-}" ]]; then
    return 0
  fi

  # 如果该 loader 当前正在执行 说明发生了递归触发
  # 这通常是配置设计问题 例如 loader 里又间接触发了同一个懒加载链
  if [[ -n "${__zlazy_loader_active[$loader]:-}" ]]; then
    zsh_msg warn zlazy "recursive loader invocation detected: $loader"
    return 1
  fi

  # loader 必须是已定义的 shell 函数
  if ! typeset -f "$loader" >/dev/null 2>&1; then
    zsh_msg warn zlazy "loader function not found: $loader"
    return 127
  fi

  # 标记 该 loader 正在执行
  __zlazy_loader_active[$loader]=1

  # 输出调试日志
  zsh_log_debug "run lazy loader: $loader"

  # 真正执行 loader
  "$loader"
  rc=$?

  # 无论成功还是失败 都先清掉正在执行标记
  unset "__zlazy_loader_active[$loader]"

  # 如果 loader 返回非 0 则视为失败
  if (( rc != 0 )); then
    zsh_msg warn zlazy "loader failed: $loader (rc=$rc)"
    return "$rc"
  fi

  # 标记 loader 已完成
  __zlazy_loader_done[$loader]=1
  return 0
}

# 所有懒加载包装函数的统一分发入口
# 逻辑流程
# 根据命令名找到对应 loader
# 先移除当前命令的包装函数
# 运行 loader 仅第一次会真正执行
# 再把本次调用转发给真实命令
__zlazy_dispatch() {
  # 第一个参数是 当前被调用的命令名
  local cmd="$1"

  # 接收该命令对应的 loader 名
  local loader

  # 保存 loader 的退出码
  local rc

  # 把第一个参数移走 剩下的就是原始命令参数
  shift

  # 先根据命令名查 loader
  loader="${__zlazy_loader_by_cmd[$cmd]:-}"

  # 如果找不到 loader 说明状态表异常或命令未注册
  if [[ -z "$loader" ]]; then
    zsh_msg warn zlazy "no loader registered for command: $cmd"
    return 127
  fi

  # 先移除当前命令的包装函数
  # 让 loader 可以安全地定义同名真实函数
  # 避免后续转发时又回到包装器本身 形成递归
  # 如果当前函数已经不存在 理论上不常见 也忽略错误
  unfunction "$cmd" 2>/dev/null || true

  # 运行 loader 若已完成则会直接返回成功
  if __zlazy_run_loader "$loader"; then
    :
  else
    rc=$?

    # loader 失败时 把当前命令的包装器重新挂回去
    # 保证下次调用还能继续尝试
    __zlazy_define_wrapper "$cmd" >/dev/null 2>&1 || true

    # 把 loader 的失败码原样返回给调用方
    return "$rc"
  fi

  # loader 成功后优先检查同名 shell 函数
  if (( $+functions[$cmd] )); then
    "$cmd" "$@"
    return $?
  fi

  # 如果没有同名 shell 函数 再尝试直接执行外部命令
  # command 会绕过 shell 函数查找 直接找外部命令
  # 支持只修改 PATH 或环境的 loader
  command "$cmd" "$@"
}

# 注册一个 loader 并把一个或多个命令包装成 首次调用时再初始化
# 用法
#   zlazy_register <loader_func> <cmd1> [cmd2 ...]
# 示例
#   zlazy_register tool_lazy_init tool
# 如果想多个命令共用一个 loader 也可以
#   zlazy_register some_loader foo bar baz
# 触发方式
# 第一次调用 foo / bar / baz 任意一个时
# 都会触发同一个 loader
# 当前实现要求
# loader_func 必须已经是已定义函数
# cmd 名必须是合法 shell 函数名
zlazy_register() {
  # 第一个参数是 loader 函数名
  local loader="$1"

  # 当前循环处理的命令名
  local cmd

  # loader 名不能为空
  if [[ -z "$loader" ]]; then
    zsh_msg warn zlazy "usage: zlazy_register <loader_func> <cmd1> [cmd2 ...]"
    return 2
  fi

  # 把 loader 参数移走 剩下的都是命令名
  shift

  # 至少要有一个命令
  if (( $# == 0 )); then
    zsh_msg warn zlazy "no command specified for loader: $loader"
    return 2
  fi

  # loader 必须已经存在 且必须是函数
  # 注册时暴露 loader 命名错误
  if ! typeset -f "$loader" >/dev/null 2>&1; then
    zsh_msg warn zlazy "loader function not found at register time: $loader"
    return 2
  fi

  # 逐个注册命令
  for cmd in "$@"; do
    # 命令名必须合法
    if ! zlazy_is_valid_name "$cmd"; then
      zsh_msg warn zlazy "invalid lazy command name: $cmd"
      return 2
    fi

  # 记录命令对应的 loader
    __zlazy_loader_by_cmd[$cmd]="$loader"

    # 为该命令创建包装器
    __zlazy_define_wrapper "$cmd" || {
      zsh_msg warn zlazy "failed to define wrapper for command: $cmd"
      return 1
    }

    # 调试日志
    zsh_log_debug "lazy command registered: cmd=$cmd loader=$loader"
  done
}

# 手动把某个 loader 标记为已完成
# 调试和过渡辅助函数
# 典型场景
# loader 已在启动时主动执行但仍保留懒加载包装器时使用
zlazy_mark_loaded() {
  # 取 loader 名
  local loader="$1"

  # 空值直接跳过
  [[ -n "$loader" ]] || return 0

  # 标记为已完成
  __zlazy_loader_done[$loader]=1
}

# 清除某个 loader 的已完成状态
# 典型场景
# 手工重载了某模块
# 想让某个 loader 下次再次真正执行
# 函数只清状态不自动重新挂包装器
# 如果某命令包装器已经被首次调用移除而还想重新懒加载
# 需要重新执行 zlazy_register
zlazy_reset_loader() {
  # 取 loader 名
  local loader="$1"

  # 空值直接跳过
  [[ -n "$loader" ]] || return 0

  # 清掉 已完成 和 执行中 状态
  unset "__zlazy_loader_done[$loader]"
  unset "__zlazy_loader_active[$loader]"
}
