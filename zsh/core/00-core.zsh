# 00-core.zsh
# 基础核心工具
# 这个文件由 init.zsh 最先加载, 是整个框架里最基础的一层

# 只放通用, 轻量, 低依赖的函数
# 不放具体业务逻辑
# 不依赖后续 feature
# 尽量不调用外部重命令

# 调试开关
# ZSH_DEBUG 用于控制 zsh_log_debug 是否输出调试信息
# 默认值是 0 关闭
# 推荐调试方式
#   ZSH_DEBUG=1 zsh -lic 'exit'
# 如果要在当前 shell 中连续测试, 也可以
#   export ZSH_DEBUG=1
#   zsh -lic 'exit'
typeset -g ZSH_DEBUG="${ZSH_DEBUG:-0}"

# 统一构造消息前缀
# 后续如果要给提示, 警告, 调试日志统一加颜色, 只需要改这一条路径
zsh_message_prefix() {
  emulate -L zsh

  local scope="${1:-zsh}"

  REPLY="[${scope}]"
}

# 统一输出消息
# - info 走 stdout, 适合提示和帮助
# - warn / error / debug 走 stderr, 适合异常和调试
zsh_msg() {
  emulate -L zsh

  local level="${1:-info}"
  local scope="${2:-zsh}"
  local old_reply="${REPLY-}"
  local prefix
  local use_stderr=0

  shift 2 2>/dev/null || true

  case "$level" in
    info)
      use_stderr=0
      ;;
    warn|error|debug)
      use_stderr=1
      ;;
    *)
      level="info"
      use_stderr=0
      ;;
  esac

  if [[ "$level" == "debug" ]]; then
    scope="${scope}-debug"
  fi

  zsh_message_prefix "$scope"
  prefix="$REPLY"
  REPLY="$old_reply"

  if (( use_stderr )); then
    print -r -- "$prefix $*" >&2
  else
    print -r -- "$prefix $*"
  fi
}

# 输出统一风格的提示信息
zsh_info() {
  zsh_msg info zsh "$@"
}

# 输出统一风格的警告信息
zsh_warn() {
  zsh_msg warn zsh "$@"
}

# 输出统一风格的错误信息
zsh_error() {
  zsh_msg error zsh "$@"
}

# 安全地 source 一个可选文件
# 文件缺失不会报错
zsh_source_optional() {
  local file="$1"

  [[ -n "$file" ]] || return 0
  [[ -r "$file" ]] || return 0

  source "$file"
}


# 安全地 source 一个必须存在的文件
# 文件可读则 source
# 缺失则输出错误并返回失败
zsh_source_required() {
  local file="$1"

  [[ -n "$file" ]] || return 1

  if [[ ! -r "$file" ]]; then
    zsh_error "missing required file: $file"
    return 1
  fi

  source "$file"
}

# 判断某个命令是否在当前 PATH 中可用
# 返回值约定
# - 命令存在, 返回 0
# - 命令不存在, 返回 1
zsh_has_cmd() {
  (( $+commands[$1] ))
}


# 判断当前 shell 是否是交互式 shell
zsh_is_interactive() {
  [[ $- == *i* ]]
}

# 判断当前 shell 是否是 login shell
zsh_is_login() {
  [[ -o login ]]
}

# 在调试模式下输出调试日志
zsh_log_debug() {
  [[ "${ZSH_DEBUG:-0}" == "1" ]] || return 0
  zsh_msg debug zsh "$@"
}

# 确保某个目录存在
zsh_ensure_dir() {
  local dir="$1"

  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] && return 0

  mkdir -p "$dir" 2>/dev/null
}

# 获取当前 Unix 时间戳
# 优先使用 zsh/datetime 暴露的 EPOCHSECONDS
# 只有模块不可用时才回退到外部 date
zsh_now_seconds() {
  emulate -L zsh

  local now="${EPOCHSECONDS:-}"

  if [[ "$now" != <-> ]]; then
    zmodload -F zsh/datetime b:EPOCHSECONDS 2>/dev/null || true
    now="${EPOCHSECONDS:-}"
  fi

  if [[ "$now" != <-> ]]; then
    now="$(date +%s 2>/dev/null)" || now=""
  fi

  [[ "$now" == <-> ]] || return 1
  REPLY="$now"
}

# 获取文件的 mtime Unix 时间戳
# 优先尝试 GNU stat, 再回退到 BSD stat
zsh_file_mtime() {
  emulate -L zsh

  local file="$1"
  local mtime

  [[ -r "$file" ]] || return 1

  mtime="$(stat -c %Y "$file" 2>/dev/null)" || mtime=""
  if [[ "$mtime" == <-> ]]; then
    REPLY="$mtime"
    return 0
  fi

  mtime="$(stat -f %m "$file" 2>/dev/null)" || mtime=""
  if [[ "$mtime" == <-> ]]; then
    REPLY="$mtime"
    return 0
  fi

  return 1
}

# 校验 feature 名是否安全
# 这里显式限制只允许字母, 数字, 下划线, 连字符
# 目的不是美观, 而是防止出现路径穿越或奇怪的 source 目标
zsh_feature_is_valid_name() {
  local name="$1"
  [[ "$name" =~ '^[A-Za-z0-9_-]+$' ]]
}

# 加载一个 feature 文件
# - feature 名来自配置数组
# - 文件路径固定为 $ZSH_FEATURE_DIR/<name>.zsh
# - 缺失时输出警告并返回失败
zsh_load_feature() {
  local feature="$1"
  local file

  [[ -n "$feature" ]] || return 0

  if ! zsh_feature_is_valid_name "$feature"; then
    zsh_warn "invalid feature name: $feature"
    return 1
  fi

  file="$ZSH_FEATURE_DIR/${feature}.zsh"

  if [[ ! -r "$file" ]]; then
    zsh_warn "feature not found: $feature"
    return 1
  fi

  zsh_log_debug "load feature: stage=${ZSH_CURRENT_STAGE:-unknown} feature=$feature"
  source "$file"
}

# 按数组顺序依次加载一组 feature
# 这里保留顺序语义 谁在前就先执行
# 这样用户可以通过数组顺序控制依赖链
zsh_load_feature_list() {
  local feature
  local rc=0

  for feature in "$@"; do
    [[ -n "$feature" ]] || continue
    zsh_load_feature "$feature" || rc=$?
  done

  return "$rc"
}
