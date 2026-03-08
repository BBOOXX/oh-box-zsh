# features/completion.zsh
# 补全系统初始化.
#
# 这个 feature 的目标不是"把所有能开的都开满".
# 目标是.
# 1. 启用 zsh 原生补全系统.
# 2. 把高频且低风险的体验增强做成默认值.
# 3. 把每个增强点都抽成配置项.
# 4. 保证以后你如果想关掉某一种补全行为, 只改 config.zsh 就够了.
#
# 这里迁入的主要体验包括.
# - 自动弹出菜单.
# - 在单词中间补全.
# - 补全后把光标移到单词末尾.
# - 大小写不敏感.
# - substring 匹配.
# - partial-word 匹配.
# - compdump 缓存文件单独存放.
#
# 这些都仍然是 zsh 原生能力, 不是第三方框架能力.

# 确保 compdump 和 completion cache 目录存在.
zsh_ensure_dir "$ZSH_CACHE_DIR/compdump"
zsh_ensure_dir "$ZSH_CACHE_DIR/completion"

# compdump 文件名包含环境特征.
# 这样同一个仓库在不同平台或不同 zsh 版本下共用缓存时, 不容易互相污染.
local zver="${ZSH_VERSION//./_}"
typeset -g ZSH_COMPDUMP="$ZSH_CACHE_DIR/compdump/zcompdump-${ZSH_OS}-${ZSH_ARCH}-${zver}"

# menu select 依赖 zsh/complist.
# zmodload -i 的意思是.
# - 如果模块存在, 就加载.
# - 如果模块已经加载, 不报错.
# - 如果模块不存在, 返回失败但不至于像硬依赖一样把整个 shell 打挂.
if (( ${ZSH_COMPLETION_MENU_SELECT:-1} )); then
  zmodload -i zsh/complist 2>/dev/null || true
fi

# 这里先设置和补全交互体验直接相关的 shell option.
# 每个 option 都对应一个明确配置项.
(( ${ZSH_COMPLETION_AUTO_MENU:-1} )) && setopt AUTO_MENU || unsetopt AUTO_MENU
(( ${ZSH_COMPLETION_COMPLETE_IN_WORD:-1} )) && setopt COMPLETE_IN_WORD || unsetopt COMPLETE_IN_WORD
(( ${ZSH_COMPLETION_ALWAYS_TO_END:-1} )) && setopt ALWAYS_TO_END || unsetopt ALWAYS_TO_END

# menu_complete 和 menu select 是两个不同语义.
# 这里主动关闭 menu_complete, 避免一按 Tab 就直接选中第一项, 保留更可控的菜单行为.
unsetopt MENU_COMPLETE

# 加载并初始化补全系统.
autoload -Uz compinit
compinit -d "$ZSH_COMPDUMP"

# 如果用户明确要求兼容 bash completion, 这里再开启 bashcompinit.
# 这个能力有价值, 但会增加一点复杂度和启动成本.
# 所以默认关闭, 需要时再开.
if (( ${ZSH_COMPLETION_USE_BASHCOMPINIT:-0} )); then
  autoload -Uz bashcompinit
  bashcompinit
fi

# menu select 开启后, 在补全菜单里按 Shift-Tab 可以更自然地反向选择.
if (( ${ZSH_COMPLETION_MENU_SELECT:-1} )); then
  zstyle ':completion:*:*:*:*:*' menu select
  bindkey -M menuselect '^o' accept-and-infer-next-history
fi

# 构造 matcher-list.
# 这里不直接把 matcher-list 写死成一个字符串, 而是按配置项逐段拼装.
# 好处是每种匹配能力都能单独关.
local -a matcher_list
matcher_list=()

# 大小写无关匹配.
if (( ${ZSH_COMPLETION_CASE_INSENSITIVE:-1} )); then
  if (( ${ZSH_COMPLETION_HYPHEN_INSENSITIVE:-0} )); then
    matcher_list+=('m:{[:lower:][:upper:]-_}={[:upper:][:lower:]_-}')
  else
    matcher_list+=('m:{[:lower:][:upper:]}={[:upper:][:lower:]}')
  fi
fi

# substring 匹配.
# 例如输入 down, 也能命中 Downloads.
if (( ${ZSH_COMPLETION_MATCH_SUBSTRING:-1} )); then
  matcher_list+=('r:|=*')
fi

# partial-word 匹配.
# 例如多段名称中间的局部单词也更容易被命中.
if (( ${ZSH_COMPLETION_MATCH_PARTIAL_WORD:-1} )); then
  matcher_list+=('l:|=* r:|=*')
fi

# 只有在 matcher_list 非空时才设置 zstyle.
# 这样用户把所有匹配增强都关掉时, 就会退回更朴素的原生行为.
if (( ${#matcher_list[@]} )); then
  zstyle ':completion:*' matcher-list "${matcher_list[@]}"
fi

# 允许 . 和 .. 在目录补全里正常出现.
(( ${ZSH_COMPLETION_SPECIAL_DIRS:-1} )) && zstyle ':completion:*' special-dirs true

# 启用 completion cache.
# 这对某些重补全场景更有价值, 例如包管理器和大命令集.
if (( ${ZSH_COMPLETION_USE_CACHE:-1} )); then
  zstyle ':completion:*' use-cache yes
  zstyle ':completion:*' cache-path "$ZSH_CACHE_DIR/completion"
else
  zstyle ':completion:*' use-cache no
fi
