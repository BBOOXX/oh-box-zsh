# 00-core.zsh
# 基础核心工具
#
# 这是整个框架里最基础的一层.
# 原则如下.
# 1. 只放通用, 轻量, 低依赖的函数.
# 2. 不放具体业务逻辑.
# 3. 不依赖后续 feature.
# 4. 尽量不调用外部重命令.
#
# 这个文件由 init.zsh 最先加载.
#
# --------------------------------------------------
# 调试开关
# --------------------------------------------------
# ZSH_DEBUG 用于控制 zsh_log_debug 是否输出调试信息.
#
# 默认值是 0, 也就是关闭.
# 推荐调试方式.
#   ZSH_DEBUG=1 zsh -lic 'exit'
# 如果要在当前 shell 中连续测试, 也可以.
#   export ZSH_DEBUG=1
#   zsh -lic 'exit'
#   unset ZSH_DEBUG
typeset -g ZSH_DEBUG="${ZSH_DEBUG:-0}"

# --------------------------------------------------
# zsh_source_optional
# --------------------------------------------------
# 安全地 source 一个可选文件.
#
# 设计原因.
# - 在模块化框架里, 不是每个文件都一定存在.
# - 如果每次都直接 source, 一旦文件缺失就会报错.
zsh_source_optional() {
  local file="$1"

  [[ -n "$file" ]] || return 0
  [[ -r "$file" ]] || return 0

  source "$file"
}

# --------------------------------------------------
# zsh_source_required
# --------------------------------------------------
# 安全地 source 一个必须存在的文件.
#
# 语义.
# - 文件可读则 source.
# - 文件缺失则输出错误并返回失败.
zsh_source_required() {
  local file="$1"

  [[ -n "$file" ]] || return 1

  if [[ ! -r "$file" ]]; then
    print -r -- "[zsh] missing required file: $file" >&2
    return 1
  fi

  source "$file"
}

# --------------------------------------------------
# zsh_has_cmd
# --------------------------------------------------
# 判断某个命令是否在当前 PATH 中可用.
#
# 在 zsh 中, 直接使用 commands 哈希表通常比 command -v 更轻量.
# 返回值约定.
# - 命令存在, 返回 0.
# - 命令不存在, 返回 1.
zsh_has_cmd() {
  (( $+commands[$1] ))
}

# --------------------------------------------------
# zsh_is_interactive
# --------------------------------------------------
# 判断当前 shell 是否是交互式 shell.
zsh_is_interactive() {
  [[ $- == *i* ]]
}

# --------------------------------------------------
# zsh_is_login
# --------------------------------------------------
# 判断当前 shell 是否是 login shell.
zsh_is_login() {
  [[ -o login ]]
}

# --------------------------------------------------
# zsh_log_debug
# --------------------------------------------------
# 在调试模式下输出调试日志.
zsh_log_debug() {
  [[ "${ZSH_DEBUG:-0}" == "1" ]] || return 0
  print -r -- "[zsh-debug] $*" >&2
}

# --------------------------------------------------
# zsh_warn
# --------------------------------------------------
# 输出统一风格的警告信息.
zsh_warn() {
  print -r -- "[zsh] $*" >&2
}

# --------------------------------------------------
# zsh_ensure_dir
# --------------------------------------------------
# 确保某个目录存在.
zsh_ensure_dir() {
  local dir="$1"

  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] && return 0

  mkdir -p "$dir" 2>/dev/null
}

# --------------------------------------------------
# zsh_feature_is_valid_name
# --------------------------------------------------
# 校验 feature 名是否安全.
#
# 这里显式限制只允许字母, 数字, 下划线, 连字符.
# 目的不是美观, 而是防止出现路径穿越或奇怪的 source 目标.
zsh_feature_is_valid_name() {
  local name="$1"
  [[ "$name" =~ '^[A-Za-z0-9_-]+$' ]]
}

# --------------------------------------------------
# zsh_load_feature
# --------------------------------------------------
# 加载一个 feature 文件.
#
# 约定.
# - feature 名来自配置数组.
# - 文件路径固定为 $ZSH_FEATURE_DIR/<name>.zsh.
# - 缺失时输出警告并返回失败.
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

# --------------------------------------------------
# zsh_load_feature_list
# --------------------------------------------------
# 按数组顺序依次加载一组 feature.
#
# 这里保留顺序语义.
# 谁在前, 谁就先执行.
# 这样用户可以通过数组顺序控制依赖链, 例如先 homebrew 再 completion.
zsh_load_feature_list() {
  local feature
  local rc=0

  for feature in "$@"; do
    [[ -n "$feature" ]] || continue
    zsh_load_feature "$feature" || rc=$?
  done

  return "$rc"
}
