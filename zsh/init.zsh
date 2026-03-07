# init.zsh 是整个框架的唯一 bootstrap 入口.
#
# 它的职责被严格限制为以下几件事.
# 1. 确认当前 shell 的确是 zsh.
# 2. 建立目录变量.
# 3. 加载 core 层.
# 4. 做环境探测.
# 5. 加载项目默认值.
# 6. 加载用户声明式配置.
# 7. 按阶段分发到 login 或 interactive.
#
# 它明确不做这些事.
# - 不直接实现 history, completion, prompt.
# - 不直接写第三方工具接入逻辑.
# - 不直接加载 user/local.zsh.
# - 不在这里堆 alias 和 bindkey.
#
# 这样约束之后, 目录职责会非常稳定.
# - conf 只放默认值和示例.
# - core 只放基础设施.
# - features 只放功能实现.
# - stage 只放阶段调度.
# - user/config.zsh 只放声明式配置.
# - user/local.zsh 只放个人脚本.
#
# 如果当前 shell 不是 zsh, 立刻停止.
# 这个分支必须尽量使用通用 shell 语法, 因为 zsh 专属语法还没有开始执行.
if [ -z "${ZSH_VERSION-}" ]; then
  printf '%s\n' '[zsh-init] skip: current shell is not zsh.' >&2
  return 0 2>/dev/null || exit 0
fi

# 建立目录变量.
# 这些变量会被后续 core, feature, stage 层共享使用.
typeset -g ZSH_ROOT="$ZDOTDIR"
typeset -g ZSH_CONF_DIR="$ZSH_ROOT/conf"
typeset -g ZSH_CORE_DIR="$ZSH_ROOT/core"
typeset -g ZSH_FEATURE_DIR="$ZSH_ROOT/features"
typeset -g ZSH_STAGE_DIR="$ZSH_ROOT/stage"
typeset -g ZSH_THEME_DIR="$ZSH_ROOT/themes"
typeset -g ZSH_USER_DIR="$ZSH_ROOT/user"
typeset -g ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# 先尝试准备缓存目录.
# 失败时也不直接终止, 因为不是所有 feature 都依赖缓存目录.
mkdir -p "$ZSH_CACHE_DIR" 2>/dev/null

# framework bootstrap 保护.
# 在一个 login + interactive 的完整会话里, init.zsh 可能被 source 两次.
# 例如 zsh -lic 的场景里, .zprofile 和 .zshrc 都会走到这里.
# 但是 core 加载, 环境探测, 默认值加载这些事情只需要做一次.
if [[ -z "${__zsh_framework_bootstrapped:-}" ]]; then
  # 00-core.zsh 是最低依赖的前提.
  # 它如果不存在, 整个框架没有继续运行的意义.
  if [[ ! -r "$ZSH_CORE_DIR/00-core.zsh" ]]; then
    print -r -- "[zsh-init] missing core: $ZSH_CORE_DIR/00-core.zsh" >&2
    return 1 2>/dev/null || exit 1
  fi

  # 先加载核心函数层.
  source "$ZSH_CORE_DIR/00-core.zsh"

  # 按顺序加载其他 core.
  # 10-path 提供 PATH 工具函数.
  # 20-detect 提供平台和环境探测.
  # 30-cache 提供可信 shell 片段缓存.
  # 40-lazy 提供懒加载包装器.
  zsh_source_required "$ZSH_CORE_DIR/10-path.zsh"
  zsh_source_required "$ZSH_CORE_DIR/20-detect.zsh"
  zsh_source_optional "$ZSH_CORE_DIR/30-cache.zsh"
  zsh_source_optional "$ZSH_CORE_DIR/40-lazy.zsh"

  # 做一次环境探测.
  # 这是给 feature 层提供事实输入, 例如 macOS / Linux, arm64 / x86_64, SSH, Termux, WSL.
  if typeset -f zsh_detect_env >/dev/null 2>&1; then
    zsh_detect_env
  fi

  # 先加载项目默认值, 再加载用户声明式配置.
  # 这是整个项目最重要的分层规则之一.
  # defaults 只给默认值.
  # user/config.zsh 用来覆盖默认值.
  #
  # 注意这里故意不加载 user/local.zsh.
  # local 只属于 interactive 阶段末尾的脚本层.
  zsh_source_required "$ZSH_CONF_DIR/defaults.zsh"
  zsh_source_optional "$ZSH_USER_DIR/config.zsh"

  # 标记 bootstrap 已完成.
  typeset -g __zsh_framework_bootstrapped=1
  zsh_log_debug "framework bootstrap complete"
fi

# 阶段执行保护.
# login 和 interactive 各自只应在当前 shell 中执行一次.
typeset -gA __zsh_stage_loaded

# 如果外部没有明确设置阶段, 则默认按 interactive 处理.
: "${ZSH_INIT_STAGE:=interactive}"

# 按阶段分发.
case "$ZSH_INIT_STAGE" in
  login)
    if [[ -z "${__zsh_stage_loaded[login]:-}" ]]; then
      zsh_source_required "$ZSH_STAGE_DIR/login.zsh"
      __zsh_stage_loaded[login]=1
    fi
    ;;
  interactive)
    if [[ -z "${__zsh_stage_loaded[interactive]:-}" ]]; then
      zsh_source_required "$ZSH_STAGE_DIR/interactive.zsh"
      __zsh_stage_loaded[interactive]=1
    fi
    ;;
  *)
    print -r -- "[zsh-init] unknown stage: $ZSH_INIT_STAGE" >&2
    ;;
esac
