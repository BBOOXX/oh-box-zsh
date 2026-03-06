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

# 使用 typeset -g 定义 全局变量
# -g 表示即使当前在函数里(虽然此处不在函数里) 也强制定义为全局
# 这样后续 stage 文件和模块文件都能直接访问这些变量

typeset -g ZSH_CONFIG_HOME="$ZDOTDIR"
# ^ zsh 配置根目录 也就是当前整套框架所在目录

typeset -g ZSH_LIB_DIR="$ZSH_CONFIG_HOME/lib"
# ^ 基础函数库目录 用来放可复用工具函数

typeset -g ZSH_STAGE_DIR="$ZSH_CONFIG_HOME/stages"
# ^ 阶段目录 用来放 login / interactive 分阶段逻辑

typeset -g ZSH_CONF_DIR="$ZSH_CONFIG_HOME/conf"
# ^ 通用配置片段目录

typeset -g ZSH_MODULE_DIR="$ZSH_CONFIG_HOME/modules"
# ^ 模块目录
# 后续 homebrew / pyenv / tmux / fzf 等可选模块会放在这里

typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
# ^ zsh 缓存目录
# 这个目录后续会用于
# - history 文件
# - 未来的缓存 eval 输出
# - 未来的 compdump
# - 未来的 profiling 结果


# 尝试创建缓存目录
# 如果目录已存在 mkdir -p 不会报错
# 如果因为权限等问题失败 这里暂时不让它打断整个 shell 启动流程
mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null

# -----------------------
# 框架级 一次性引导 保护
# -----------------------

# 在同一个 shell 里 init.zsh 会被 source 两次
# 1) .zprofile 阶段一次
# 2) .zshrc 阶段一次
# 但基础库加载 环境探测这些 框架级动作 只需要做一次
# 所以这里做一个 bootstrapped 标记
if [[ -z "${__zsh_framework_bootstrapped:-}" ]]; then
  # 只有第一次进入时 才执行这部分 全局引导 逻辑

  # 先加载最基础的 00-core.zsh
  if [[ ! -r "$ZSH_LIB_DIR/00-core.zsh" ]]; then
    print -r -- "[zsh-init] missing core library: $ZSH_LIB_DIR/00-core.zsh" >&2
    return 1 2>/dev/null || exit 1
  fi

  # source 基础核心库
  source "$ZSH_LIB_DIR/00-core.zsh"

  # 加载剩余基础库
  # 这里使用 zsh_source_optional 而不是裸 source
  # 这样即使某个文件暂时还不存在 也不会让整个 shell 启动失败
  # 保持可选加载有利于以后按阶段逐步扩展
  zsh_source_optional "$ZSH_LIB_DIR/10-path.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/20-detect.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/30-cache.zsh"
  zsh_source_optional "$ZSH_LIB_DIR/40-lazy.zsh"

  # 进行环境探测
  # 只有当 zsh_detect_env 已经定义时才调用
  if typeset -f zsh_detect_env >/dev/null 2>&1; then
    zsh_detect_env
  fi

  zsh_source_optional "$ZSH_CONF_DIR/features.zsh"

  # 标记框架基础引导已经完成
  # 后续同一个 shell 再次 source init.zsh 时就不会重复跑这部分
  typeset -g __zsh_framework_bootstrapped=1

  # 调试输出 (默认关闭)
  zsh_log_debug "framework bootstrap completed"
fi

# -----------------------
# 阶段执行保护
# -----------------------

# 虽然基础引导只需要一次
# 但 login / interactive 两个阶段都应该各自执行一次
# 所以这里用一个按阶段记录的关联数组来做保护
typeset -gA __zsh_stage_loaded
# ^ 关联数组 (associative array) 键是阶段名 值是 1
# 例如
# __zsh_stage_loaded[login]=1
# __zsh_stage_loaded[interactive]=1

# 如果外部没有明确设置阶段 则默认按 interactive 处理
# 避免直接 source init.zsh 时没有阶段变量可用
: "${ZSH_INIT_STAGE:=interactive}"

# -----------------------
# 按阶段分发
# -----------------------
case "$ZSH_INIT_STAGE" in
  login)
    # 如果 login 阶段还没执行过 才去加载它
    if [[ -z "${__zsh_stage_loaded[login]:-}" ]]; then
      zsh_log_debug "enter login stage"

      # 加载 login 阶段逻辑
      zsh_source_optional "$ZSH_STAGE_DIR/login.zsh"

      # 记录 login 阶段已完成
      __zsh_stage_loaded[login]=1
    fi
    ;;
  interactive)
    # 如果 interactive 阶段还没执行过 才去加载它
    if [[ -z "${__zsh_stage_loaded[interactive]:-}" ]]; then
      zsh_log_debug "enter interactive stage"

      # 加载 interactive 阶段逻辑
      zsh_source_optional "$ZSH_STAGE_DIR/interactive.zsh"

      # 记录 interactive 阶段已完成
      __zsh_stage_loaded[interactive]=1
    fi
    ;;
  *)
    # 如果阶段值不是我们认识的 login / interactive
    # 不直接报错中断 而是打印调试信息后忽略
    # 避免某个误设置变量把整个 shell 启动打断
    zsh_log_debug "unknown stage: $ZSH_INIT_STAGE"
    ;;
esac

# -----------------------
# 预留：本地私有覆盖文件
# -----------------------

# 这里不强制要求 local.zsh 存在
# 如果希望在某台机器上做私有覆盖可以手工创建这个文件
# 后面做机器差异化配置时会很方便
if [[ -z "${__zsh_local_loaded:-}" ]]; then
  zsh_source_optional "$ZSH_CONFIG_HOME/local.zsh"
  typeset -g __zsh_local_loaded=1
fi
