# features/keybinds.zsh
# 常用按键与编辑模式.
#
# 这个 feature 负责接住最常见的交互手感问题.
# 它只做高价值, 低风险, 可解释的默认绑定.
# 不在这里塞个人专属快捷键.
#
# 当前这层主要做这些事.
# 1. 根据 ZSH_KEYMAP 选择 emacs 或 vi.
# 2. 注册 Ctrl-X Ctrl-E 外部编辑能力.
# 3. 给上下箭头增加"按当前前缀搜索历史"的行为.
# 4. 让 Home / End, Delete, Shift-Tab 这些按键在常见终端里更稳定.
# 5. 尽量使用 terminfo, 避免写死终端转义序列.

# 选择编辑模式.
if [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]]; then
  bindkey -v
else
  bindkey -e
fi

# 某些终端在 zle 激活时需要切到 application mode.
# 否则方向键, Home, End 等 terminfo 项可能表现不稳定.
# 这是一个比较常见但不显眼的兼容性补丁.
if (( ${ZSH_KEYBINDS_APPLICATION_MODE:-1} )) && (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  function zle-line-init() {
    echoti smkx
  }

  function zle-line-finish() {
    echoti rmkx
  }

  zle -N zle-line-init
  zle -N zle-line-finish
fi

# Ctrl-X Ctrl-E 在外部编辑器里编辑当前命令行.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Ctrl-R 做增量历史搜索.
# 很多终端默认已经有这个绑定, 这里显式再绑一次, 避免不同 keymap 下行为漂移.
bindkey '^R' history-incremental-search-backward

# 上下箭头按当前前缀做历史搜索.
# 例如你先输入 git, 再按上箭头, 会优先找历史里以 git 开头的命令.
if (( ${ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH:-1} )); then
  autoload -Uz up-line-or-beginning-search
  autoload -Uz down-line-or-beginning-search
  zle -N up-line-or-beginning-search
  zle -N down-line-or-beginning-search

  # 先绑定常见的 ANSI 序列.
  bindkey -M emacs '^[[A' up-line-or-beginning-search
  bindkey -M emacs '^[[B' down-line-or-beginning-search
  bindkey -M viins '^[[A' up-line-or-beginning-search
  bindkey -M viins '^[[B' down-line-or-beginning-search
  bindkey -M vicmd '^[[A' up-line-or-beginning-search
  bindkey -M vicmd '^[[B' down-line-or-beginning-search

  # 如果 terminfo 提供更可靠的键值, 再补一层.
  if [[ -n "${terminfo[kcuu1]:-}" ]]; then
    bindkey -M emacs "${terminfo[kcuu1]}" up-line-or-beginning-search
    bindkey -M viins "${terminfo[kcuu1]}" up-line-or-beginning-search
    bindkey -M vicmd "${terminfo[kcuu1]}" up-line-or-beginning-search
  fi

  if [[ -n "${terminfo[kcud1]:-}" ]]; then
    bindkey -M emacs "${terminfo[kcud1]}" down-line-or-beginning-search
    bindkey -M viins "${terminfo[kcud1]}" down-line-or-beginning-search
    bindkey -M vicmd "${terminfo[kcud1]}" down-line-or-beginning-search
  fi
fi

# Home / End 键.
if (( ${ZSH_KEYBINDS_HOME_END:-1} )); then
  if [[ -n "${terminfo[khome]:-}" ]]; then
    bindkey -M emacs "${terminfo[khome]}" beginning-of-line
    bindkey -M viins "${terminfo[khome]}" beginning-of-line
    bindkey -M vicmd "${terminfo[khome]}" beginning-of-line
  fi

  if [[ -n "${terminfo[kend]:-}" ]]; then
    bindkey -M emacs "${terminfo[kend]}" end-of-line
    bindkey -M viins "${terminfo[kend]}" end-of-line
    bindkey -M vicmd "${terminfo[kend]}" end-of-line
  fi
fi

# Shift-Tab 在补全菜单里反向选择.
if (( ${ZSH_KEYBINDS_SHIFT_TAB_REVERSE_MENU:-1} )) && [[ -n "${terminfo[kcbt]:-}" ]]; then
  bindkey -M emacs "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M viins "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M vicmd "${terminfo[kcbt]}" reverse-menu-complete
fi

# Delete 键.
# 一部分终端会通过 terminfo[kdch1] 提供, 另一部分只会发 ^[[3~.
if (( ${ZSH_KEYBINDS_DELETE:-1} )); then
  if [[ -n "${terminfo[kdch1]:-}" ]]; then
    bindkey -M emacs "${terminfo[kdch1]}" delete-char
    bindkey -M viins "${terminfo[kdch1]}" delete-char
    bindkey -M vicmd "${terminfo[kdch1]}" delete-char
  else
    bindkey -M emacs '^[[3~' delete-char
    bindkey -M viins '^[[3~' delete-char
    bindkey -M vicmd '^[[3~' delete-char
  fi
fi
