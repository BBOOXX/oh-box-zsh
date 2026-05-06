# features/keybinds.zsh
# 常用按键与编辑模式

# 处理常见交互键位
# 只放高价值 低风险 可解释的默认绑定
# 个人快捷键放到 user/local.zsh

# 职责
# 1 根据 ZSH_KEYMAP 选择 emacs 或 vi
# 2 注册 Ctrl-X Ctrl-E 外部编辑能力
# 3 给上下箭头增加按当前前缀搜索历史的行为
# 4 让 Home / End Delete Shift-Tab 这些按键在常见终端里更稳定
# 5 尽量使用 terminfo 避免写死终端转义序列

# 选择编辑模式
if [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]]; then
  bindkey -v
else
  bindkey -e
fi

# 保持和 oh-my-zsh 接近的单词边界
# Ctrl-W 会按 . / - 等符号分段回删
WORDCHARS=''

# 某些终端在 zle 激活时需要切到 application mode
# 否则方向键 Home End 等 terminfo 项可能表现不稳定
# application mode 兼容方向键 Home End 等按键
function zle-line-init() {
  if (( ${ZSH_KEYBINDS_APPLICATION_MODE:-1} )) && (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    echoti smkx
  fi
}

# 每次结束当前命令行编辑都要清掉方向键历史状态
# 否则回车后下一次上箭头会错误地续接上一轮 sticky search
function zle-line-finish() {
  zsh_keybinds_reset_history_search

  if (( ${ZSH_KEYBINDS_APPLICATION_MODE:-1} )) && (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
    echoti rmkx
  fi
}

zle -N zle-line-init
zle -N zle-line-finish

# Ctrl-X Ctrl-E 在外部编辑器里编辑当前命令行
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# Ctrl-R 做增量历史搜索
# 显式绑定可避免不同 keymap 下行为漂移
bindkey '^R' history-incremental-search-backward

# 清空方向键历史筛选状态
zsh_keybinds_reset_history_search() {
  emulate -L zsh

  typeset -gi __zsh_keybinds_history_active=0
  typeset -g __zsh_keybinds_history_mode=''
  typeset -g __zsh_keybinds_history_query=''
  typeset -g __zsh_keybinds_history_buffer=''
  typeset -gi __zsh_keybinds_history_cursor=0
  typeset -gi __zsh_keybinds_history_position=0
  typeset -ga __zsh_keybinds_history_matches=()
}

# 读取某个历史索引的命令
zsh_keybinds_history_entry_at() {
  emulate -L zsh

  integer idx="$1"

  [[ -n "${history[$idx]:-}" ]] || return 1
  REPLY="${history[$idx]}"
}

# 判断某条历史在当前模式下是否应当参与搜索
zsh_keybinds_history_matches_mode() {
  emulate -L zsh

  local entry="$1"

  if [[ "${__zsh_keybinds_history_mode:-history}" == "prefix" ]]; then
    [[ -n "${__zsh_keybinds_history_query:-}" ]] || return 1
    [[ "$entry" == "${__zsh_keybinds_history_query}"* ]]
    return $?
  fi

  return 0
}

# 展示当前命中的唯一历史项
zsh_keybinds_present_history_match() {
  emulate -L zsh

  integer pos="${__zsh_keybinds_history_position:-0}"
  integer idx

  (( pos > 0 )) || return 1
  idx=${__zsh_keybinds_history_matches[$pos]:-0}
  (( idx > 0 )) || return 1

  zsh_keybinds_history_entry_at "$idx" || return 1
  BUFFER="$REPLY"
  CURSOR=${#BUFFER}
}

# 判断某条命令是否已经出现在唯一历史序列中
zsh_keybinds_history_already_seen() {
  emulate -L zsh

  local entry="$1"
  integer idx

  for idx in "${__zsh_keybinds_history_matches[@]}"; do
    [[ -n "${history[$idx]:-}" ]] || continue
    [[ "${history[$idx]}" == "$entry" ]] && return 0
  done

  return 1
}

# 向更旧的唯一历史项移动
zsh_keybinds_step_history_older() {
  emulate -L zsh

  integer idx
  local entry=''

  if (( ${__zsh_keybinds_history_position:-0} < ${#__zsh_keybinds_history_matches[@]} )); then
    typeset -gi __zsh_keybinds_history_position=$(( __zsh_keybinds_history_position + 1 ))
    zsh_keybinds_present_history_match
    return $?
  fi

  if (( ${#__zsh_keybinds_history_matches[@]} > 0 )); then
    idx=$(( __zsh_keybinds_history_matches[-1] - 1 ))
  else
    idx=$HISTCMD
  fi

  for (( ; idx >= 1; idx-- )); do
    zsh_keybinds_history_entry_at "$idx" || continue
    entry="$REPLY"

    zsh_keybinds_history_matches_mode "$entry" || continue
    zsh_keybinds_history_already_seen "$entry" && continue

    __zsh_keybinds_history_matches+=("$idx")
    typeset -gi __zsh_keybinds_history_position=${#__zsh_keybinds_history_matches[@]}
    BUFFER="$entry"
    CURSOR=${#BUFFER}
    return 0
  done

  return 1
}

# 向更新的唯一历史项移动 到头后回到原始输入
zsh_keybinds_step_history_newer() {
  emulate -L zsh

  if (( ${__zsh_keybinds_history_position:-0} > 1 )); then
    typeset -gi __zsh_keybinds_history_position=$(( __zsh_keybinds_history_position - 1 ))
    zsh_keybinds_present_history_match
    return $?
  fi

  if (( ${__zsh_keybinds_history_position:-0} == 1 )); then
    BUFFER="${__zsh_keybinds_history_buffer:-}"
    CURSOR=${__zsh_keybinds_history_cursor:-0}
    typeset -gi __zsh_keybinds_history_position=0
    return 0
  fi

  BUFFER="${__zsh_keybinds_history_buffer:-}"
  CURSOR=${__zsh_keybinds_history_cursor:-0}
  zsh_keybinds_reset_history_search
  return 0
}

# 判断当前是否还能沿用已有的方向键历史筛选状态
zsh_keybinds_can_continue_history_search() {
  emulate -L zsh

  (( ${__zsh_keybinds_history_active:-0} )) || return 1

  [[ "$BUFFER" == "${__zsh_keybinds_history_buffer:-}" ]] && return 0

  if (( ${__zsh_keybinds_history_position:-0} > 0 )); then
    [[ "$BUFFER" == "${history[${__zsh_keybinds_history_matches[${__zsh_keybinds_history_position}]}]:-}" ]]
    return $?
  fi

  return 1
}

# 上箭头使用固定查询串做连续历史筛选
zsh_keybinds_history_search_up() {
  emulate -L zsh

  if [[ $LBUFFER == *$'\n'* ]]; then
    zle .up-line-or-history
    return
  fi

  if ! zsh_keybinds_can_continue_history_search; then
    typeset -gi __zsh_keybinds_history_active=1
    typeset -g __zsh_keybinds_history_buffer="$BUFFER"
    typeset -gi __zsh_keybinds_history_cursor=$CURSOR
    typeset -gi __zsh_keybinds_history_position=0
    typeset -ga __zsh_keybinds_history_matches=()

    if [[ -n "$BUFFER" ]]; then
      typeset -g __zsh_keybinds_history_mode='prefix'
      typeset -g __zsh_keybinds_history_query="$BUFFER"
    else
      typeset -g __zsh_keybinds_history_mode='history'
      typeset -g __zsh_keybinds_history_query=''
    fi
  fi

  zsh_keybinds_step_history_older || return 0
}

# 下箭头在筛选结果间回退 最后回到原始输入
zsh_keybinds_history_search_down() {
  emulate -L zsh

  if [[ $RBUFFER == *$'\n'* ]]; then
    zle .down-line-or-history
    return
  fi

  if ! zsh_keybinds_can_continue_history_search; then
    zsh_keybinds_reset_history_search
    if [[ -n "${WIDGET:-}" ]]; then
      zle .down-line-or-history
    fi
    return
  fi

  if ! zsh_keybinds_step_history_newer; then
    zle .down-line-or-history
  fi
}

zsh_keybinds_reset_history_search

# 上下箭头按当前输入筛选历史
# 默认使用 sticky-prefix 模式
# 如果当前行为空 方向键先走普通历史
# 只有用户自己改了当前行 才把这行当成新的前缀
# 如果需要旧的行首前缀行为 可以显式切回 prefix 模式
if (( ${ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH:-1} )); then
  case "${ZSH_KEYBINDS_HISTORY_SEARCH_MODE:-sticky-prefix}" in
    prefix)
      autoload -Uz up-line-or-beginning-search
      autoload -Uz down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      typeset -g __zsh_keybinds_history_up_widget='up-line-or-beginning-search'
      typeset -g __zsh_keybinds_history_down_widget='down-line-or-beginning-search'
      ;;
    *)
      zle -N zsh_keybinds_history_search_up
      zle -N zsh_keybinds_history_search_down
      typeset -g __zsh_keybinds_history_up_widget='zsh_keybinds_history_search_up'
      typeset -g __zsh_keybinds_history_down_widget='zsh_keybinds_history_search_down'
      ;;
  esac

  # 先绑定常见的 ANSI 序列
  bindkey -M emacs '^[[A' "$__zsh_keybinds_history_up_widget"
  bindkey -M emacs '^[[B' "$__zsh_keybinds_history_down_widget"
  bindkey -M viins '^[[A' "$__zsh_keybinds_history_up_widget"
  bindkey -M viins '^[[B' "$__zsh_keybinds_history_down_widget"
  bindkey -M vicmd '^[[A' "$__zsh_keybinds_history_up_widget"
  bindkey -M vicmd '^[[B' "$__zsh_keybinds_history_down_widget"

  # 如果 terminfo 提供更可靠的键值 再补一层
  if [[ -n "${terminfo[kcuu1]:-}" ]]; then
    bindkey -M emacs "${terminfo[kcuu1]}" "$__zsh_keybinds_history_up_widget"
    bindkey -M viins "${terminfo[kcuu1]}" "$__zsh_keybinds_history_up_widget"
    bindkey -M vicmd "${terminfo[kcuu1]}" "$__zsh_keybinds_history_up_widget"
  fi

  if [[ -n "${terminfo[kcud1]:-}" ]]; then
    bindkey -M emacs "${terminfo[kcud1]}" "$__zsh_keybinds_history_down_widget"
    bindkey -M viins "${terminfo[kcud1]}" "$__zsh_keybinds_history_down_widget"
    bindkey -M vicmd "${terminfo[kcud1]}" "$__zsh_keybinds_history_down_widget"
  fi
fi

# Home / End 键
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

# Shift-Tab 在补全菜单里反向选择
if (( ${ZSH_KEYBINDS_SHIFT_TAB_REVERSE_MENU:-1} )) && [[ -n "${terminfo[kcbt]:-}" ]]; then
  bindkey -M emacs "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M viins "${terminfo[kcbt]}" reverse-menu-complete
  bindkey -M vicmd "${terminfo[kcbt]}" reverse-menu-complete
fi

# Delete 键
# 一部分终端会通过 terminfo[kdch1] 提供 另一部分只会发 ^[[3~
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
