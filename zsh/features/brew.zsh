# features/brew.zsh
# Homebrew shellenv 缓存层

# 这个 feature 不自己拼 HOMEBREW_* 或 PATH
# 而是复用 brew shellenv 的官方输出

# 设计目标
# 1. shell 环境定义以 brew 自己的 shellenv 为准
# 2. 通过缓存减少 login 阶段反复启动 brew 的成本
# 3. 只处理当前 PATH 或官方默认安装位置里的 brew
# 4. 如果本机没装 brew, 直接静默跳过

# 根据当前平台返回 Homebrew 默认 brew 可执行文件路径
# 输出方式
# - 成功时把路径写入 REPLY
# - 不支持的平台返回 1
zsh_brew_default_bin() {
  zsh_log_debug "brew: default-bin lookup os=${ZSH_OS:-unknown} arch=${ZSH_ARCH:-unknown}"

  case "${ZSH_OS:-unknown}:${ZSH_ARCH:-unknown}" in
    macos:arm64)
      REPLY="/opt/homebrew/bin/brew"
      ;;
    macos:*)
      REPLY="/usr/local/bin/brew"
      ;;
    linux:*)
      REPLY="/home/linuxbrew/.linuxbrew/bin/brew"
      ;;
    *)
      zsh_log_debug "brew: default-bin return=1 reason=unsupported-platform"
      return 1
      ;;
  esac

  zsh_log_debug "brew: default-bin return=0 brew=$REPLY"
}

# 优先从当前 PATH 找 brew
# 如果还没进 PATH, 再回退到官方默认安装位置
zsh_brew_find_bin() {
  local brew_bin=""

  zsh_log_debug "brew: find-bin start"

  if (( $+commands[brew] )); then
    brew_bin="${commands[brew]}"
    zsh_log_debug "brew: find-bin source=path brew=$brew_bin"
  elif zsh_brew_default_bin; then
    brew_bin="$REPLY"
    zsh_log_debug "brew: find-bin source=default brew=$brew_bin"
  fi

  if [[ -z "$brew_bin" ]]; then
    zsh_log_debug "brew: find-bin return=1 reason=not-found"
    return 1
  fi

  if [[ ! -x "$brew_bin" ]]; then
    zsh_log_debug "brew: find-bin return=1 reason=not-executable brew=$brew_bin"
    return 1
  fi

  REPLY="$brew_bin"
  zsh_log_debug "brew: find-bin return=0 brew=$REPLY"
}

# 用 brew 可执行文件路径作为 cache key 的一部分
# 这样不同前缀或多套 brew 不会共用同一个缓存
zsh_brew_cache_key() {
  local brew_bin="$1"

  if [[ -z "$brew_bin" ]]; then
    zsh_log_debug "brew: cache-key return=1 reason=empty-brew-bin"
    return 1
  fi

  REPLY="brew-shellenv:$brew_bin"
  zsh_log_debug "brew: cache-key return=0 key=$REPLY"
}

# 输出 brew shellenv zsh 的结果
# 这里显式清掉当前 PATH 里的 brew 前缀影响
# 否则当当前 shell 已经初始化过 brew 时
# brew shellenv 可能因为幂等短路而输出空内容
# 空输出一旦被缓存, 下一次新 shell 就拿不到环境
zsh_brew_print_shellenv() {
  local brew_bin="$1"
  local clean_path="/usr/bin:/bin:/usr/sbin:/sbin"
  local rc

  if [[ -z "$brew_bin" ]]; then
    zsh_log_debug "brew: shellenv return=2 reason=empty-brew-bin"
    return 2
  fi

  if [[ ! -x "$brew_bin" ]]; then
    zsh_log_debug "brew: shellenv return=1 reason=not-executable brew=$brew_bin"
    return 1
  fi

  zsh_log_debug "brew: shellenv exec brew=$brew_bin path=$clean_path"
  /usr/bin/env PATH="$clean_path" HOMEBREW_PATH="$clean_path" "$brew_bin" shellenv zsh
  rc=$?
  zsh_log_debug "brew: shellenv return=$rc brew=$brew_bin"
  return "$rc"
}

# 通过缓存执行 brew shellenv 并 source 结果
zsh_brew_load_shellenv() {
  local brew_bin="$1"
  local ttl="${ZSH_BREW_SHELLENV_TTL:-${ZSH_CACHE_DEFAULT_TTL:-86400}}"
  local cache_key
  local rc

  if [[ -z "$brew_bin" ]]; then
    zsh_log_debug "brew: load-shellenv return=2 reason=empty-brew-bin"
    return 2
  fi

  zsh_log_debug "brew: load-shellenv start brew=$brew_bin ttl=$ttl"

  if ! typeset -f zcache_source_cmd >/dev/null 2>&1; then
    zsh_warn "brew feature requires zcache_source_cmd"
    zsh_log_debug "brew: load-shellenv return=1 reason=missing-zcache"
    return 1
  fi

  if ! zsh_brew_cache_key "$brew_bin"; then
    zsh_log_debug "brew: load-shellenv return=1 reason=cache-key-failed"
    return 1
  fi
  cache_key="$REPLY"

  zcache_source_cmd "$cache_key" "$ttl" -- zsh_brew_print_shellenv "$brew_bin"
  rc=$?
  zsh_log_debug "brew: load-shellenv return=$rc brew=$brew_bin key=$cache_key"
  return "$rc"
}

# 如果找到 brew, 就加载它的 shellenv 缓存
zsh_brew_init() {
  local brew_bin
  local rc

  zsh_log_debug "brew: init start"

  if ! zsh_brew_find_bin; then
    zsh_log_debug "brew: init return=0 reason=brew-not-found"
    return 0
  fi
  brew_bin="$REPLY"

  zsh_log_debug "brew: init brew=$brew_bin"
  zsh_brew_load_shellenv "$brew_bin"
  rc=$?
  zsh_log_debug "brew: init return=$rc brew=$brew_bin"
  return "$rc"
}

zsh_brew_init

alias bubo='brew update -v && brew outdated -v'
alias bubc='brew upgrade && brew cleanup -v'
alias bubu='bubo && bubc'
