# ================================
# 40-lazy.zsh
# 命令懒加载工具
# ================================

# 让某些 很重的初始化逻辑 不要在 shell 启动时立刻执行
# 改为 第一次真正调用相关命令时 再执行初始化
# 初始化成功后 后续调用直接走真实命令 不再经过包装器

# 当前这一层只做 命令级懒加载
# 不做更复杂的按目录 按条件 按 hook 的惰性初始化

# --------------------------------------------------
# 内部状态表
# --------------------------------------------------

# __zlazy_loader_by_cmd
#   记录 某个命令由哪个 loader 负责初始化
#   例如
#   __zlazy_loader_by_cmd[pyenv]="pyenv_lazy_init"

# __zlazy_loader_done
#   记录 某个 loader 是否已经成功跑过
#   例如
#   __zlazy_loader_done[pyenv_lazy_init]=1

# __zlazy_loader_active
#   记录 某个 loader 当前是否正在执行
#   用来防止递归触发和重复进入
typeset -gA __zlazy_loader_by_cmd
typeset -gA __zlazy_loader_done
typeset -gA __zlazy_loader_active

# --------------------------------------------------
# zlazy_is_valid_name
# --------------------------------------------------
# 判断一个字符串是否是 适合作为 zsh 函数名 的安全名称

# zlazy_register 会动态定义包装函数
# 为了避免 eval 注入和非法函数名 我们先把命令名限制成
# - 首字符 字母或下划线
# - 后续字符 字母 / 数字 / 下划线

# 返回值
# - 合法 0
# - 非法 1
zlazy_is_valid_name() {
  # 取第一个参数作为待检查名称
  local name="$1"

  # 使用正则做严格匹配
  # 这里有意不支持带连字符的函数名
  [[ "$name" =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]]
}

# --------------------------------------------------
# __zlazy_define_wrapper
# --------------------------------------------------
# 为某个命令动态创建 懒加载包装函数

# 这是内部函数 不给业务模块直接用
# 外部应通过 zlazy_register 调用它

# 例如为 pyenv 创建包装器后 实际会生成

#   pyenv() {
#     __zlazy_dispatch 'pyenv' "$@"
#   }

# 也就是 先进入统一分发器 再由分发器决定是否运行 loader
__zlazy_define_wrapper() {
  # 取目标命令名
  local cmd="$1"

  # 命令名不能为空
  [[ -n "$cmd" ]] || return 1

  # 命令名必须是合法函数名
  zlazy_is_valid_name "$cmd" || return 1

  # 用 eval 动态定义函数
  # 这里之所以使用 eval 是因为函数名本身需要由变量决定
  # 前面已经做了函数名合法性检查 所以这里是可控的
  # 函数体里把原始参数 "$@" 原样传给统一分发器
  # 并把 cmd 名字作为一个固定字面量传进去
  eval "${cmd}() { __zlazy_dispatch '${cmd}' \"\$@\"; }"
}

# --------------------------------------------------
# __zlazy_run_loader
# --------------------------------------------------
# 运行某个 loader 并处理它的状态标记

# 返回值
# - loader 已经成功运行过 0
# - 本次成功运行完成 0
# - loader 不存在 / 运行失败 非 0

__zlazy_run_loader() {
  # 取 loader 函数名
  local loader="$1"

  # 用于保存 loader 的退出码
  local rc

  # loader 名不能为空
  if [[ -z "$loader" ]]; then
    print -r -- "[zlazy] missing loader name" >&2
    return 2
  fi

  # 如果该 loader 之前已经成功执行过 就不再重复执行
  if [[ -n "${__zlazy_loader_done[$loader]:-}" ]]; then
    return 0
  fi

  # 如果该 loader 当前正在执行 说明发生了递归触发
  # 这通常是配置设计问题 例如 loader 里又间接触发了同一个懒加载链
  if [[ -n "${__zlazy_loader_active[$loader]:-}" ]]; then
    print -r -- "[zlazy] recursive loader invocation detected: $loader" >&2
    return 1
  fi

  # 这里要求 loader 必须已经是一个已定义的 shell 函数
  if ! typeset -f "$loader" >/dev/null 2>&1; then
    print -r -- "[zlazy] loader function not found: $loader" >&2
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
    print -r -- "[zlazy] loader failed: $loader (rc=$rc)" >&2
    return "$rc"
  fi

  # 到这里 说明 loader 已成功完成
  # 记录该 loader 已完成 后续不再重复运行
  __zlazy_loader_done[$loader]=1
  return 0
}

# --------------------------------------------------
# __zlazy_dispatch
# --------------------------------------------------
# 这是所有懒加载包装函数的统一分发入口

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
    print -r -- "[zlazy] no loader registered for command: $cmd" >&2
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
    # 保证下次调用还能继续尝试 而不是永久失去懒加载入口
    __zlazy_define_wrapper "$cmd" >/dev/null 2>&1 || true

    # 把 loader 的失败码原样返回给调用方
    return "$rc"
  fi

  # 到这里说明 loader 已经成功
  # 现在优先检查 loader 是否定义了一个同名 shell 函数
  if (( $+functions[$cmd] )); then
    "$cmd" "$@"
    return $?
  fi

  # 如果没有同名 shell 函数 再尝试直接执行外部命令
  # command 会绕过 shell 函数查找 直接找外部命令
  # 这适合 loader 只负责修改 PATH / 环境 而不负责定义函数的情况
  command "$cmd" "$@"
}

# --------------------------------------------------
# zlazy_register
# --------------------------------------------------

# 用途
# 注册一个 loader 并把一个或多个命令包装成 首次调用时再初始化

# 用法
#   zlazy_register <loader_func> <cmd1> [cmd2 ...]

# 示例
#   zlazy_register pyenv_lazy_init pyenv

# 如果你想多个命令共用一个 loader 也可以
#   zlazy_register some_loader foo bar baz

# 这样
# - 第一次调用 foo / bar / baz 中任意一个时
# - 都会触发同一个 loader

# 当前实现要求
# - loader_func 必须已经是已定义函数
# - cmd 名必须是合法 shell 函数名
zlazy_register() {
  # 第一个参数是 loader 函数名
  local loader="$1"

  # 当前循环处理的命令名
  local cmd

  # loader 名不能为空
  if [[ -z "$loader" ]]; then
    print -r -- "[zlazy] usage: zlazy_register <loader_func> <cmd1> [cmd2 ...]" >&2
    return 2
  fi

  # 把 loader 参数移走 剩下的都是命令名
  shift

  # 至少要有一个命令
  if (( $# == 0 )); then
    print -r -- "[zlazy] no command specified for loader: $loader" >&2
    return 2
  fi

  # loader 必须已经存在 且必须是函数
  # 这是为了把错误尽量提前暴露 而不是等第一次命令调用时才发现
  if ! typeset -f "$loader" >/dev/null 2>&1; then
    print -r -- "[zlazy] loader function not found at register time: $loader" >&2
    return 2
  fi

  # 逐个注册命令
  for cmd in "$@"; do
    # 命令名必须合法
    if ! zlazy_is_valid_name "$cmd"; then
      print -r -- "[zlazy] invalid lazy command name: $cmd" >&2
      return 2
    fi

    # 记录 这个命令由哪个 loader 负责
    __zlazy_loader_by_cmd[$cmd]="$loader"

    # 为该命令创建包装器
    __zlazy_define_wrapper "$cmd" || {
      print -r -- "[zlazy] failed to define wrapper for command: $cmd" >&2
      return 1
    }

    # 调试日志
    zsh_log_debug "lazy command registered: cmd=$cmd loader=$loader"
  done
}

# --------------------------------------------------
# zlazy_mark_loaded
# --------------------------------------------------
# 手动把某个 loader 标记为"已完成"
# 这是一个辅助函数不是必需方便调试和过渡

# 典型场景
# - 后来改成了某个 loader 在启动时就主动执行
# - 但仍然保留了之前的懒加载包装器定义
# - 此时可以手工把 loader 标记成 done 避免它再跑一次

zlazy_mark_loaded() {
  # 取 loader 名
  local loader="$1"

  # 空值直接跳过
  [[ -n "$loader" ]] || return 0

  # 标记为已完成
  __zlazy_loader_done[$loader]=1
}

# --------------------------------------------------
# zlazy_reset_loader
# --------------------------------------------------
# 清除某个 loader 的已完成状态
# 典型场景
# - 手工重载了某模块
# - 想让某个 loader 下次再次真正执行

# 注意
# 这个函数只清状态不自动重新挂包装器
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
