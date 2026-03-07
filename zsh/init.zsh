# 如果当前 shell 不是 zsh 就在后续 zsh 专属语法执行前立刻停止加载

# 判定依据
# - zsh 启动时会自动设置 ZSH_VERSION
# - bash / sh / dash 默认不会设置这个变量
# 因此只要 ZSH_VERSION 为空 就可以把当前环境视为非 zsh
if [ -z "${ZSH_VERSION-}" ]; then
  # 这个分支是 非 zsh 才会进入
  # 所以分支内部也必须尽量使用跨 shell 可工作的语法
  # 这里故意使用更通用的 printf 而不是 zsh 风格的 print
  printf '%s\n' '[zsh-init] skip: current shell is not zsh.' >&2

  # 先尝试 return
  # - 如果本文件是被 source 的 return 会立刻结束当前文件的加载
  # - 如果本文件是被直接执行的脚本 顶层 return 会失败
  # - source 场景 return 成功 exit 不执行
  # - 直接执行场景 return 失败 于是执行 exit 0 结束当前进程
  return 0 2>/dev/null || exit 0
fi

# 建立基础目录变量
# 使用 typeset -g 定义全局变量，方便 stage / component / module 直接访问
typeset -g ZSH_CONFIG_HOME="$ZDOTDIR"
typeset -g ZSH_LIB_DIR="$ZSH_CONFIG_HOME/lib"
typeset -g ZSH_STAGE_DIR="$ZSH_CONFIG_HOME/stages"
typeset -g ZSH_COMPONENT_DIR="$ZSH_CONFIG_HOME/components"
typeset -g ZSH_MODULE_DIR="$ZSH_CONFIG_HOME/modules"
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# 尝试创建缓存目录
mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null

# -----------------------
# 框架级 一次性引导 保护
# -----------------------
# 在同一个 shell 里 init.zsh 可能被 source 两次
# 1) .zprofile 阶段一次
# 2) .zshrc 阶段一次
# 但基础库加载、环境探测、项目默认配置只需要做一次
if [[ -z "${__zsh_framework_bootstrapped:-}" ]]; then
  if [[ ! -r "$ZSH_LIB_DIR/00-core.zsh" ]]; then
    print -r -- "[zsh-init] missing core library: $ZSH_LIB_DIR/00-core.zsh" >&2
    return 1 2>/dev/null || exit 1
  fi

  source "$ZSH_LIB_DIR/00-core.zsh"

  zsh_source_optional "$ZSH_LIB_DIR/10-path.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/20-detect.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/30-cache.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/40-lazy.zsh"

  if typeset -f zsh_detect_env >/dev/null 2>&1; then
    zsh_detect_env
  fi

  # 配置层加载顺序：
  # 1) components/defaults.zsh：项目默认配置中心
  # local.zsh 不在这里加载
  # 它只属于 interactive 阶段的用户主配置入口
  zsh_source_optional "$ZSH_COMPONENT_DIR/defaults.zsh"

  typeset -g __zsh_framework_bootstrapped=1
  zsh_log_debug "framework bootstrap completed"
fi

# -----------------------
# 阶段执行保护
# -----------------------
typeset -gA __zsh_stage_loaded

# 如果外部没有明确设置阶段 则默认按 interactive 处理
: "${ZSH_INIT_STAGE:=interactive}"

# -----------------------
# 按阶段分发
# -----------------------
case "$ZSH_INIT_STAGE" in
  login)
    if [[ -z "${__zsh_stage_loaded[login]:-}" ]]; then
      zsh_log_debug "enter login stage"
      zsh_source_optional "$ZSH_STAGE_DIR/login.zsh"
      __zsh_stage_loaded[login]=1
    fi
    ;;
  interactive)
    if [[ -z "${__zsh_stage_loaded[interactive]:-}" ]]; then
      zsh_log_debug "enter interactive stage"
      zsh_source_optional "$ZSH_STAGE_DIR/interactive.zsh"
      __zsh_stage_loaded[interactive]=1
    fi
    ;;
  *)
    zsh_log_debug "unknown stage: $ZSH_INIT_STAGE"
    ;;
esac
