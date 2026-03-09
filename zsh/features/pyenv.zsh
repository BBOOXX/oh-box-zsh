# features/pyenv.zsh
# pyenv 初始化层

# 这个 feature 只做 pyenv 自己的初始化
# 1. 统一准备 PYENV_ROOT 和 root/bin
# 2. 按阶段加载 pyenv init --path 或 pyenv init -
# 3. 通过缓存压住 pyenv init 的外部命令成本
# 4. 不混入 virtualenv 自动激活或自定义 alias

# --------------------------------------------------
# zsh_pyenv_root
# --------------------------------------------------
# 计算当前 shell 应该使用的 PYENV_ROOT
zsh_pyenv_root() {
  local pyenv_root="${ZSH_PYENV_ROOT:-${PYENV_ROOT:-$HOME/.pyenv}}"

  [[ -n "$pyenv_root" ]] || return 1

  REPLY="$pyenv_root"
}

# --------------------------------------------------
# zsh_pyenv_prepare_env
# --------------------------------------------------
# 提前导出 PYENV_ROOT, 并在需要时把 root/bin 放进 PATH
zsh_pyenv_prepare_env() {
  local pyenv_root=''
  local pyenv_bin_dir=''
  local had_bin_dir=0

  if ! zsh_pyenv_root; then
    zsh_log_debug "pyenv: prepare-env return=1 reason=missing-root"
    return 1
  fi
  pyenv_root="$REPLY"

  typeset -gx PYENV_ROOT="$pyenv_root"
  pyenv_bin_dir="$PYENV_ROOT/bin"

  if path_contains "$pyenv_bin_dir"; then
    had_bin_dir=1
  fi

  path_prepend "$pyenv_bin_dir"

  if (( ! had_bin_dir )) && path_contains "$pyenv_bin_dir"; then
    rehash
    zsh_log_debug "pyenv: prepare-env add-bin dir=$pyenv_bin_dir"
  else
    zsh_log_debug "pyenv: prepare-env root=$PYENV_ROOT"
  fi
}

# --------------------------------------------------
# zsh_pyenv_find_bin
# --------------------------------------------------
# 优先复用 PATH 里的 pyenv, 找不到再回退到 PYENV_ROOT/bin/pyenv
zsh_pyenv_find_bin() {
  local pyenv_bin=''

  if (( $+commands[pyenv] )); then
    pyenv_bin="${commands[pyenv]}"
    zsh_log_debug "pyenv: find-bin source=path pyenv=$pyenv_bin"
  elif [[ -n "${PYENV_ROOT:-}" && -x "${PYENV_ROOT}/bin/pyenv" ]]; then
    pyenv_bin="${PYENV_ROOT}/bin/pyenv"
    zsh_log_debug "pyenv: find-bin source=root pyenv=$pyenv_bin"
  fi

  if [[ -z "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: find-bin return=1 reason=not-found"
    return 1
  fi

  if [[ ! -x "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: find-bin return=1 reason=not-executable pyenv=$pyenv_bin"
    return 1
  fi

  REPLY="${pyenv_bin:A}"
  zsh_log_debug "pyenv: find-bin return=0 pyenv=$REPLY"
}

# --------------------------------------------------
# zsh_pyenv_effective_rehash
# --------------------------------------------------
# 计算当前阶段是否真的需要把 rehash 塞进 init 输出
zsh_pyenv_effective_rehash() {
  local stage="$1"
  local rehash="${ZSH_PYENV_REHASH_ON_INIT:-0}"

  [[ "$rehash" == <-> ]] || rehash=0

  if (( rehash )) && [[ "$stage" == "interactive" ]] && [[ -n "${__zsh_feature_pyenv_loaded[login]:-}" ]]; then
    rehash=0
  fi

  REPLY="$rehash"
  zsh_log_debug "pyenv: effective-rehash stage=$stage rehash=$REPLY"
}

# --------------------------------------------------
# zsh_pyenv_cache_key
# --------------------------------------------------
# 把 stage, PYENV_ROOT 和 pyenv 可执行文件一起纳入缓存 key
# 这样 root 变化, brew 升级或阶段切换时都不会误复用旧缓存
zsh_pyenv_cache_key() {
  local pyenv_bin="$1"
  local stage="$2"
  local rehash="$3"
  local pyenv_root="${PYENV_ROOT:-}"

  [[ -n "$pyenv_bin" && -n "$stage" ]] || return 1

  REPLY="pyenv-init:${pyenv_bin:A}:${pyenv_root}:${stage}:rehash=${rehash}:no-push=1:shell=zsh"
  zsh_log_debug "pyenv: cache-key return=0 key=$REPLY"
}

# --------------------------------------------------
# zsh_pyenv_print_init
# --------------------------------------------------
# 输出当前阶段需要 source 的 pyenv init 结果
zsh_pyenv_print_init() {
  local pyenv_bin="$1"
  local stage="$2"
  local rehash="$3"
  local -a cmd
  local rc

  if [[ -z "$pyenv_bin" || -z "$stage" ]]; then
    zsh_log_debug "pyenv: print-init return=2 reason=missing-args"
    return 2
  fi

  if [[ ! -x "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: print-init return=1 reason=not-executable pyenv=$pyenv_bin"
    return 1
  fi

  cmd=("$pyenv_bin" init)

  case "$stage" in
    login)
      cmd+=(--path)
      ;;
    interactive)
      cmd+=(-)
      ;;
    *)
      zsh_log_debug "pyenv: print-init return=2 reason=unsupported-stage stage=$stage"
      return 2
      ;;
  esac

  cmd+=(--no-push-path)

  if [[ "$rehash" != "1" ]]; then
    cmd+=(--no-rehash)
  fi

  if [[ "$stage" == "interactive" ]]; then
    cmd+=(zsh)
  fi

  zsh_log_debug "pyenv: print-init exec stage=$stage rehash=$rehash pyenv=$pyenv_bin"
  "$cmd[@]"
  rc=$?
  zsh_log_debug "pyenv: print-init return=$rc stage=$stage pyenv=$pyenv_bin"
  return "$rc"
}

# --------------------------------------------------
# zsh_pyenv_load_init
# --------------------------------------------------
# 通过缓存加载 pyenv init 输出
zsh_pyenv_load_init() {
  local pyenv_bin="$1"
  local stage="$2"
  local ttl="${ZSH_PYENV_INIT_TTL:-${ZSH_CACHE_DEFAULT_TTL:-86400}}"
  local rehash=''
  local cache_key=''
  local init_script=''
  local rc

  if [[ -z "$pyenv_bin" || -z "$stage" ]]; then
    zsh_log_debug "pyenv: load-init return=2 reason=missing-args"
    return 2
  fi

  zsh_pyenv_effective_rehash "$stage"
  rehash="$REPLY"

  if ! zsh_pyenv_cache_key "$pyenv_bin" "$stage" "$rehash"; then
    zsh_log_debug "pyenv: load-init return=1 reason=cache-key-failed"
    return 1
  fi
  cache_key="$REPLY"

  if typeset -f zcache_source_cmd >/dev/null 2>&1; then
    zcache_source_cmd "$cache_key" "$ttl" -- zsh_pyenv_print_init "$pyenv_bin" "$stage" "$rehash"
    rc=$?
    zsh_log_debug "pyenv: load-init return=$rc stage=$stage pyenv=$pyenv_bin key=$cache_key source=cache"
    return "$rc"
  fi

  init_script="$(zsh_pyenv_print_init "$pyenv_bin" "$stage" "$rehash")"
  rc=$?

  if (( rc != 0 )); then
    zsh_log_debug "pyenv: load-init return=$rc stage=$stage pyenv=$pyenv_bin source=direct"
    return "$rc"
  fi

  # 这里直接 eval 的前提是 pyenv_bin 已经被明确解析为本机可执行文件.
  eval "$init_script"
  rc=$?
  zsh_log_debug "pyenv: load-init return=$rc stage=$stage pyenv=$pyenv_bin source=direct"
  return "$rc"
}

# --------------------------------------------------
# zsh_pyenv_virtualenv_cache_key
# --------------------------------------------------
# 用单独的 cache key 管理 pyenv virtualenv-init 输出
zsh_pyenv_virtualenv_cache_key() {
  local pyenv_bin="$1"
  local pyenv_root="${PYENV_ROOT:-}"

  [[ -n "$pyenv_bin" ]] || return 1

  REPLY="pyenv-virtualenv-init:${pyenv_bin:A}:${pyenv_root}:shell=zsh"
  zsh_log_debug "pyenv: virtualenv cache-key return=0 key=$REPLY"
}

# --------------------------------------------------
# zsh_pyenv_print_virtualenv_init
# --------------------------------------------------
# 输出 pyenv virtualenv-init - 的结果
zsh_pyenv_print_virtualenv_init() {
  local pyenv_bin="$1"
  local rc

  if [[ -z "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: virtualenv print-init return=2 reason=empty-pyenv-bin"
    return 2
  fi

  if [[ ! -x "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: virtualenv print-init return=1 reason=not-executable pyenv=$pyenv_bin"
    return 1
  fi

  zsh_log_debug "pyenv: virtualenv print-init exec pyenv=$pyenv_bin"
  "$pyenv_bin" virtualenv-init -
  rc=$?
  zsh_log_debug "pyenv: virtualenv print-init return=$rc pyenv=$pyenv_bin"
  return "$rc"
}

# --------------------------------------------------
# zsh_pyenv_load_virtualenv_init
# --------------------------------------------------
# 通过缓存加载 pyenv virtualenv-init -
zsh_pyenv_load_virtualenv_init() {
  local pyenv_bin="$1"
  local ttl="${ZSH_PYENV_INIT_TTL:-${ZSH_CACHE_DEFAULT_TTL:-86400}}"
  local cache_key=''
  local init_script=''
  local rc

  if [[ -z "$pyenv_bin" ]]; then
    zsh_log_debug "pyenv: virtualenv load-init return=2 reason=empty-pyenv-bin"
    return 2
  fi

  if ! zsh_pyenv_virtualenv_cache_key "$pyenv_bin"; then
    zsh_log_debug "pyenv: virtualenv load-init return=1 reason=cache-key-failed"
    return 1
  fi
  cache_key="$REPLY"

  if typeset -f zcache_source_cmd >/dev/null 2>&1; then
    zcache_source_cmd "$cache_key" "$ttl" -- zsh_pyenv_print_virtualenv_init "$pyenv_bin"
    rc=$?
    zsh_log_debug "pyenv: virtualenv load-init return=$rc pyenv=$pyenv_bin key=$cache_key source=cache"
    return "$rc"
  fi

  init_script="$(zsh_pyenv_print_virtualenv_init "$pyenv_bin")"
  rc=$?

  if (( rc != 0 )); then
    zsh_log_debug "pyenv: virtualenv load-init return=$rc pyenv=$pyenv_bin source=direct"
    return "$rc"
  fi

  # 这里直接 eval 的前提与 pyenv init 一样, 来源是本机可信 pyenv 可执行文件.
  eval "$init_script"
  rc=$?
  zsh_log_debug "pyenv: virtualenv load-init return=$rc pyenv=$pyenv_bin source=direct"
  return "$rc"
}

# --------------------------------------------------
# zsh_pyenv_find_trigger_file
# --------------------------------------------------
# 按 pyenv 的目录语义沿父目录链向上查找 .python-version
zsh_pyenv_find_trigger_file() {
  emulate -L zsh

  local trigger_file="${ZSH_PYENV_VIRTUALENV_TRIGGER_FILE:-.python-version}"
  local dir="${PWD:A}"
  local candidate=''

  [[ -n "$trigger_file" ]] || return 1

  while :; do
    candidate="$dir/$trigger_file"

    if [[ -f "$candidate" ]]; then
      REPLY="$candidate"
      return 0
    fi

    [[ "$dir" == "/" ]] && break
    dir="${dir:h}"
  done

  return 1
}

# --------------------------------------------------
# zsh_pyenv_disable_virtualenv_lazy
# --------------------------------------------------
# 命中后或确认不可用后, 移除轻量 watcher
zsh_pyenv_disable_virtualenv_lazy() {
  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd __zsh_pyenv_virtualenv_maybe_load 2>/dev/null || true
  add-zsh-hook -d chpwd __zsh_pyenv_virtualenv_maybe_load 2>/dev/null || true
  unset __zsh_pyenv_virtualenv_lazy_registered
}

# --------------------------------------------------
# zsh_pyenv_virtualenv_hook_mode
# --------------------------------------------------
# 计算 pyenv-virtualenv hook 的挂载位置.
# 默认走 chpwd, 避免每次空回车都触发 pyenv 检查.
zsh_pyenv_virtualenv_hook_mode() {
  local mode="${ZSH_PYENV_VIRTUALENV_HOOK_MODE:-chpwd}"

  case "$mode" in
    chpwd|precmd)
      REPLY="$mode"
      return 0
      ;;
  esac

  zsh_log_debug "pyenv: virtualenv hook-mode invalid=$mode fallback=chpwd"
  REPLY="chpwd"
}

# --------------------------------------------------
# zsh_pyenv_register_virtualenv_hook
# --------------------------------------------------
# 统一接管 pyenv-virtualenv 的 hook 挂载点.
# 官方输出默认写进 precmd, 这里按项目策略改挂到 chpwd 或保留 precmd.
zsh_pyenv_register_virtualenv_hook() {
  local mode=''

  (( $+functions[_pyenv_virtualenv_hook] )) || return 0

  zsh_pyenv_virtualenv_hook_mode
  mode="$REPLY"

  autoload -Uz add-zsh-hook
  add-zsh-hook -d precmd _pyenv_virtualenv_hook 2>/dev/null || true
  add-zsh-hook -d chpwd _pyenv_virtualenv_hook 2>/dev/null || true
  add-zsh-hook "$mode" _pyenv_virtualenv_hook

  zsh_log_debug "pyenv: virtualenv hook register mode=$mode"
}

# --------------------------------------------------
# zsh_pyenv_has_virtualenv_hook
# --------------------------------------------------
# 判断当前 shell 是否真的已经载入 pyenv-virtualenv hook.
# tmux 这类长生命周期进程可能只继承 PYENV_VIRTUALENV_INIT=1, 但 shell function 不会随环境变量继承.
zsh_pyenv_has_virtualenv_hook() {
  [[ "${PYENV_VIRTUALENV_INIT:-0}" == "1" ]] || return 1
  (( $+functions[_pyenv_virtualenv_hook] ))
}

# --------------------------------------------------
# __zsh_pyenv_virtualenv_maybe_load
# --------------------------------------------------
# 只在进入带 .python-version 的目录上下文时再加载 virtualenv-init
__zsh_pyenv_virtualenv_maybe_load() {
  local pyenv_bin="${__zsh_feature_pyenv_bin:-}"
  local trigger_file=''
  local rc

  [[ -n "${__zsh_feature_pyenv_virtualenv_loaded:-}" ]] && return 0

  if ! zsh_pyenv_find_trigger_file; then
    return 0
  fi
  trigger_file="$REPLY"

  if [[ -z "$pyenv_bin" ]]; then
    if ! zsh_pyenv_find_bin; then
      zsh_log_debug "pyenv: virtualenv maybe-load return=0 reason=pyenv-not-found"
      zsh_pyenv_disable_virtualenv_lazy
      return 0
    fi
    pyenv_bin="$REPLY"
  fi

  zsh_log_debug "pyenv: virtualenv maybe-load trigger=$trigger_file pyenv=$pyenv_bin"
  zsh_pyenv_load_virtualenv_init "$pyenv_bin"
  rc=$?

  if (( rc != 0 )); then
    zsh_log_debug "pyenv: virtualenv maybe-load return=$rc trigger=$trigger_file"
    zsh_pyenv_disable_virtualenv_lazy
    return 0
  fi

  typeset -g __zsh_feature_pyenv_virtualenv_loaded=1
  zsh_pyenv_disable_virtualenv_lazy
  zsh_pyenv_register_virtualenv_hook

  if (( $+functions[_pyenv_virtualenv_hook] )); then
    _pyenv_virtualenv_hook >/dev/null 2>&1 || true
  fi

  zsh_log_debug "pyenv: virtualenv maybe-load return=0 trigger=$trigger_file"
  return 0
}

# --------------------------------------------------
# zsh_pyenv_enable_virtualenv_lazy
# --------------------------------------------------
# interactive 阶段只在当前目录检查一次, 然后注册 chpwd watcher.
# 这样既能覆盖 shell 一开始就落在 Python 项目里的场景, 也避免每个 prompt 都重复扫父目录链.
zsh_pyenv_enable_virtualenv_lazy() {
  local pyenv_bin="$1"

  (( ${ZSH_PYENV_ENABLE_VIRTUALENV_LAZY:-1} )) || return 0

  if [[ -n "${__zsh_feature_pyenv_virtualenv_loaded:-}" ]] && zsh_pyenv_has_virtualenv_hook; then
    typeset -g __zsh_feature_pyenv_virtualenv_loaded=1
    zsh_pyenv_register_virtualenv_hook
    return 0
  fi

  if zsh_pyenv_has_virtualenv_hook; then
    typeset -g __zsh_feature_pyenv_virtualenv_loaded=1
    zsh_pyenv_register_virtualenv_hook
    return 0
  fi

  if [[ "${PYENV_VIRTUALENV_INIT:-0}" == "1" ]]; then
    zsh_log_debug "pyenv: virtualenv lazy detected env-only init marker, waiting to reload hook"
  fi

  typeset -g __zsh_feature_pyenv_bin="$pyenv_bin"

  if [[ -n "${__zsh_pyenv_virtualenv_lazy_registered:-}" ]]; then
    return 0
  fi

  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd __zsh_pyenv_virtualenv_maybe_load
  typeset -g __zsh_pyenv_virtualenv_lazy_registered=1

  __zsh_pyenv_virtualenv_maybe_load
}

# --------------------------------------------------
# zsh_pyenv_init_stage
# --------------------------------------------------
# 按 login / interactive 阶段执行 pyenv 初始化
zsh_pyenv_init_stage() {
  local stage="${1:-${ZSH_CURRENT_STAGE:-}}"
  local pyenv_bin=''
  local rc

  if [[ -z "$stage" ]]; then
    zsh_log_debug "pyenv: init return=0 reason=missing-stage"
    return 0
  fi

  case "$stage" in
    login|interactive)
      ;;
    *)
      zsh_warn "pyenv feature does not support stage: $stage"
      return 1
      ;;
  esac

  typeset -gA __zsh_feature_pyenv_loaded

  if [[ -n "${__zsh_feature_pyenv_loaded[$stage]:-}" ]]; then
    zsh_log_debug "pyenv: init return=0 reason=already-loaded stage=$stage"
    return 0
  fi

  zsh_log_debug "pyenv: init start stage=$stage"
  zsh_pyenv_prepare_env || return $?

  if ! zsh_pyenv_find_bin; then
    zsh_log_debug "pyenv: init return=0 reason=not-found stage=$stage root=${PYENV_ROOT:-unset}"
    return 0
  fi
  pyenv_bin="$REPLY"

  zsh_pyenv_load_init "$pyenv_bin" "$stage"
  rc=$?

  if (( rc == 0 )); then
    if [[ "$stage" == "interactive" ]]; then
      zsh_pyenv_enable_virtualenv_lazy "$pyenv_bin"
    fi
    __zsh_feature_pyenv_loaded[$stage]=1
  fi

  zsh_log_debug "pyenv: init return=$rc stage=$stage pyenv=$pyenv_bin"
  return "$rc"
}

zsh_pyenv_init_stage
