# features/autosuggestions.zsh
# zsh-autosuggestions 启动器

# 这个 feature 只负责找到并 source 官方脚本.
# 它不负责安装插件, 也不在每次启动时执行 brew --prefix
# 原因是 brew 本身是外部进程, 交互启动热路径里没必要重复付这笔成本

if [[ -n "${__zsh_feature_autosuggestions_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_feature_autosuggestions_loaded=1

# 根据 brew 可执行文件路径推导插件脚本路径
zsh_autosuggestions_candidate_from_brew() {
  emulate -L zsh

  local brew_bin="$1"
  local prefix

  [[ -n "$brew_bin" ]] || return 1

  prefix="${brew_bin:h:h}"
  [[ -n "$prefix" ]] || return 1

  REPLY="$prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
}

# 根据 Homebrew 前缀推导插件脚本路径
zsh_autosuggestions_candidate_from_prefix() {
  emulate -L zsh

  local prefix="$1"

  [[ -n "$prefix" ]] || return 1

  REPLY="$prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
}

# 根据当前平台返回 Homebrew 默认前缀下的插件脚本路径
zsh_autosuggestions_default_file() {
  emulate -L zsh

  local prefix

  case "${ZSH_OS:-unknown}:${ZSH_ARCH:-unknown}" in
    macos:arm64)
      prefix="/opt/homebrew"
      ;;
    macos:*)
      prefix="/usr/local"
      ;;
    linux:*)
      prefix="/home/linuxbrew/.linuxbrew"
      ;;
    *)
      zsh_log_debug "autosuggestions: default-file return=1 reason=unsupported-platform"
      return 1
      ;;
  esac

  REPLY="$prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  zsh_log_debug "autosuggestions: default-file return=0 file=$REPLY"
}

# 按优先级定位插件脚本
# 1. 用户显式覆盖的文件路径
# 2. 已初始化好的 HOMEBREW_PREFIX
# 3. 当前 PATH 里的 brew 所在前缀
# 4. 平台默认 Homebrew 前缀
zsh_autosuggestions_find_file() {
  emulate -L zsh

  local file="${ZSH_AUTOSUGGESTIONS_FILE:-}"
  local prefix="${HOMEBREW_PREFIX:-}"

  if [[ -n "$file" ]]; then
    if [[ -r "$file" ]]; then
      REPLY="$file"
      zsh_log_debug "autosuggestions: find-file return=0 source=override file=$REPLY"
      return 0
    fi

    zsh_log_debug "autosuggestions: find-file return=1 reason=override-not-readable file=$file"
    return 1
  fi

  if [[ -n "$prefix" ]]; then
    zsh_autosuggestions_candidate_from_prefix "$prefix"
    file="$REPLY"

    if [[ -r "$file" ]]; then
      REPLY="$file"
      zsh_log_debug "autosuggestions: find-file return=0 source=homebrew-prefix file=$REPLY"
      return 0
    fi

    zsh_log_debug "autosuggestions: find-file miss source=homebrew-prefix file=$file"
  fi

  if (( $+commands[brew] )); then
    zsh_autosuggestions_candidate_from_brew "${commands[brew]}"
    file="$REPLY"

    if [[ -r "$file" ]]; then
      REPLY="$file"
      zsh_log_debug "autosuggestions: find-file return=0 source=brew-path file=$REPLY"
      return 0
    fi

    zsh_log_debug "autosuggestions: find-file miss source=brew-path file=$file"
  fi

  if ! zsh_autosuggestions_default_file; then
    zsh_log_debug "autosuggestions: find-file return=1 reason=no-default-file"
    return 1
  fi
  file="$REPLY"

  if [[ ! -r "$file" ]]; then
    zsh_log_debug "autosuggestions: find-file return=1 reason=not-readable file=$file"
    return 1
  fi

  REPLY="$file"
  zsh_log_debug "autosuggestions: find-file return=0 source=default file=$REPLY"
}

zsh_log_debug "autosuggestions: init start"

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
export ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste accept-line)

if zsh_autosuggestions_find_file; then
  source "$REPLY"
  typeset -gi __zsh_autosuggestions_source_rc="$?"

  if (( __zsh_autosuggestions_source_rc == 0 )); then
    bindkey '^f' autosuggest-accept
    bindkey '^h' forward-word
  fi

  zsh_log_debug "autosuggestions: init return=$__zsh_autosuggestions_source_rc file=$REPLY"
  unset __zsh_autosuggestions_source_rc
else
  zsh_log_debug "autosuggestions: init return=0 reason=file-not-found"
fi
