# features/completion.zsh
# 补全系统初始化

# 启用 zsh 原生补全并配置高频交互行为
# 每个增强点都有独立配置项

# 把已存在的补全函数目录追加到 fpath 尾部
zsh_completion_append_fpath_dir() {
  emulate -L zsh

  local dir="$1"
  local item

  [[ -n "$dir" ]] || return 0
  [[ -d "$dir" ]] || return 0

  for item in "${fpath[@]}"; do
    [[ "$item" == "$dir" ]] && return 0
  done

  fpath+=("$dir")
}

# 常见系统 fpath 候选目录
# 覆盖 Homebrew Linuxbrew site-functions vendor-completions 和 Alpine zsh-completions
zsh_completion_system_fpath_candidates() {
  emulate -L zsh

  local homebrew_prefix="${HOMEBREW_PREFIX:-}"
  local -a candidates

  candidates=()

  if [[ -n "$homebrew_prefix" ]]; then
    candidates+=(
      "$homebrew_prefix/share/zsh-completions"
      "$homebrew_prefix/share/zsh/site-functions"
    )
  fi

  case "${ZSH_OS:-unknown}" in
    macos)
      candidates+=(
        "/opt/homebrew/share/zsh-completions"
        "/opt/homebrew/share/zsh/site-functions"
        "/usr/local/share/zsh-completions"
      )
      ;;
    linux)
      candidates+=(
        "/usr/share/zsh/plugins/zsh-completions/src"
        "/home/linuxbrew/.linuxbrew/share/zsh-completions"
        "/home/linuxbrew/.linuxbrew/share/zsh/site-functions"
      )
      ;;
  esac

  candidates+=(
    "/usr/local/share/zsh/site-functions"
    "/usr/share/zsh/site-functions"
    "/usr/local/share/zsh/vendor-completions"
    "/usr/share/zsh/vendor-completions"
  )

  reply=("${candidates[@]}")
}

# 在 compinit 前接入系统和用户声明的补全目录
zsh_completion_setup_fpath() {
  emulate -L zsh

  local dir
  local -a candidates

  candidates=()

  if (( ${ZSH_COMPLETION_USE_SYSTEM_FPATHS:-1} )); then
    zsh_completion_system_fpath_candidates
    candidates+=("${reply[@]}")
  fi

  if (( ${+ZSH_COMPLETION_EXTRA_FPATHS} )); then
    candidates+=("${ZSH_COMPLETION_EXTRA_FPATHS[@]}")
  fi

  for dir in "${candidates[@]}"; do
    zsh_completion_append_fpath_dir "$dir"
  done
}

# 确保 compdump 和 completion cache 目录存在
zsh_ensure_dir "$ZSH_CACHE_DIR/compdump"
zsh_ensure_dir "$ZSH_CACHE_DIR/completion"

# compdump 文件名包含环境特征
# 防止不同平台或不同 zsh 版本共用 compdump
local zver="${ZSH_VERSION//./_}"
typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/compdump/zcompdump-${ZSH_OS}-${ZSH_ARCH}-${zver}"

# menu select 依赖 zsh/complist
# zmodload -i 行为
# 如果模块存在 就加载
# 如果模块已经加载 不报错
# 模块缺失时只返回失败 避免硬中断 shell
if (( ${ZSH_COMPLETION_MENU_SELECT:-1} )); then
  zmodload -i zsh/complist 2>/dev/null || true
fi

zsh_completion_setup_fpath

# 设置补全交互相关 shell option
# 每个 option 都对应一个明确配置项
(( ${ZSH_COMPLETION_AUTO_MENU:-1} )) && setopt AUTO_MENU || unsetopt AUTO_MENU
(( ${ZSH_COMPLETION_COMPLETE_IN_WORD:-1} )) && setopt COMPLETE_IN_WORD || unsetopt COMPLETE_IN_WORD
(( ${ZSH_COMPLETION_ALWAYS_TO_END:-1} )) && setopt ALWAYS_TO_END || unsetopt ALWAYS_TO_END

# menu_complete 和 menu select 是两个不同语义
# 关闭 menu_complete 避免 Tab 直接选中第一项
unsetopt MENU_COMPLETE

# 加载并初始化补全系统
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"

# 用户明确要求兼容 bash completion 时开启 bashcompinit
# bashcompinit 会增加一点复杂度和启动成本
# 所以默认关闭 需要时再开
if (( ${ZSH_COMPLETION_USE_BASHCOMPINIT:-0} )); then
  autoload -Uz bashcompinit
  bashcompinit
fi

# 给 menuselect keymap 绑定接受当前项的快捷键
# Shift-Tab 的反向菜单行为统一放在 keybinds feature 里处理
if (( ${ZSH_COMPLETION_MENU_SELECT:-1} )); then
  zstyle ':completion:*:*:*:*:*' menu select
  bindkey -M menuselect '^o' accept-and-infer-next-history
fi

# 构造 matcher-list
# matcher-list 按配置项逐段拼装
# 每种匹配能力都能单独关
local -a matcher_list
matcher_list=()

# 大小写无关匹配
if (( ${ZSH_COMPLETION_CASE_INSENSITIVE:-1} )); then
  if (( ${ZSH_COMPLETION_HYPHEN_INSENSITIVE:-0} )); then
    matcher_list+=('m:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}')
  else
    matcher_list+=('m:{[:lower:][:upper:]}={[:upper:][:lower:]}')
  fi
fi

# substring 匹配
# 例如输入 down 也能命中 Downloads
if (( ${ZSH_COMPLETION_MATCH_SUBSTRING:-1} )); then
  matcher_list+=('r:|=*')
fi

# partial-word 匹配
# 例如多段名称中间的局部单词也更容易被命中
if (( ${ZSH_COMPLETION_MATCH_PARTIAL_WORD:-1} )); then
  matcher_list+=('l:|=* r:|=*')
fi

# 只有在 matcher_list 非空时才设置 zstyle
# 匹配增强全部关闭时退回原生行为
if (( ${#matcher_list[@]} )); then
  zstyle ':completion:*' matcher-list "${matcher_list[@]}"
fi

# 允许 . 和 .. 在目录补全里正常出现
(( ${ZSH_COMPLETION_SPECIAL_DIRS:-1} )) && zstyle ':completion:*' special-dirs true

# 启用 completion cache
# 这对某些重补全场景更有价值 例如包管理器和大命令集
if (( ${ZSH_COMPLETION_USE_CACHE:-1} )); then
  zstyle ':completion:*' use-cache yes
  zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/completion"
else
  zstyle ':completion:*' use-cache no
fi
