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
    print -r -- "[zsh] missing required file: $file" >&2
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
  print -r -- "[zsh-debug] $*" >&2
}

# 输出统一风格的警告信息
zsh_warn() {
  print -r -- "[zsh] $*" >&2
}

# 确保某个目录存在
zsh_ensure_dir() {
  local dir="$1"

  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] && return 0

  mkdir -p "$dir" 2>/dev/null
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
