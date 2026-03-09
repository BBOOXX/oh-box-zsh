# themes/avit.zsh
# OMZ avit 的本地移植版.
#
# 迁移原则.
# 1. 主题文件只负责 prompt, 不顺带改 ls 或 grep 配色.
# 2. 不依赖 OMZ 的 prompt helper, 在仓库内自包含.
# 3. 用 precmd 和 zle hook 预计算状态, 避免把多段命令替换散到 PROMPT 字符串里.

if [[ -n "${__zsh_theme_avit_loaded:-}" ]]; then
  return 0
fi
typeset -g __zsh_theme_avit_loaded=1

typeset -g __zsh_avit_dir_segment='%B%F{blue}%3~%f%b '
typeset -g __zsh_avit_user_host_segment=''
typeset -g __zsh_avit_virtualenv_segment=''
typeset -g __zsh_avit_vi_mode_segment=''
typeset -g __zsh_avit_git_left_segment=''
typeset -g __zsh_avit_rprompt_segment=''

# --------------------------------------------------
# __zsh_avit_build_user_host_segment
# --------------------------------------------------
# 仅在 SSH 或显式切换用户时显示用户和主机.
__zsh_avit_build_user_host_segment() {
  emulate -L zsh

  local me=''

  if [[ -n "${SSH_CONNECTION:-}" ]]; then
    me='%n@%m'
  elif [[ -n "${USER:-}" && "${LOGNAME:-}" != "${USER:-}" ]]; then
    me='%n'
  fi

  if [[ -n "$me" ]]; then
    REPLY="%F{cyan}${me}%f:"
  else
    REPLY=''
  fi
}

# --------------------------------------------------
# __zsh_avit_build_virtualenv_segment
# --------------------------------------------------
# 只在启用开关时显示 Python 环境名.
__zsh_avit_build_virtualenv_segment() {
  emulate -L zsh

  local name=''

  if (( ! ${ZSH_THEME_AVIT_SHOW_PYTHON_ENV:-1} )); then
    REPLY=''
    return 0
  fi

  if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    name="${VIRTUAL_ENV:t}"
  elif [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
    name="${CONDA_DEFAULT_ENV}"
  fi

  if [[ -n "$name" ]]; then
    REPLY="%F{magenta}(${name})%f "
  else
    REPLY=''
  fi
}

# --------------------------------------------------
# __zsh_avit_update_vi_mode_segment
# --------------------------------------------------
# 只在 vi keymap 的命令模式下显示提示, 减少常驻噪音.
__zsh_avit_update_vi_mode_segment() {
  emulate -L zsh

  __zsh_avit_vi_mode_segment=''

  [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]] || return 0
  (( ${ZSH_THEME_AVIT_SHOW_VI_MODE:-1} )) || return 0

  case "${KEYMAP:-viins}" in
    vicmd)
      __zsh_avit_vi_mode_segment="%B%F{yellow}❮%f%b%F{yellow}❮❮%f "
      ;;
  esac
}

# --------------------------------------------------
# __zsh_avit_now_seconds
# --------------------------------------------------
# 优先读 zsh 自带时间参数, 缺失时再退回外部 date.
__zsh_avit_now_seconds() {
  emulate -L zsh

  if (( ! ${+EPOCHSECONDS} )); then
    zmodload zsh/datetime 2>/dev/null || true
  fi

  if (( ${+EPOCHSECONDS} )); then
    REPLY="$EPOCHSECONDS"
    return 0
  fi

  zsh_has_cmd date || return 1

  REPLY="$(command date +%s 2>/dev/null)" || return 1
}

# --------------------------------------------------
# __zsh_avit_build_commit_age_segment
# --------------------------------------------------
# 把距离最近一次 commit 的秒数格式化成短字符串.
__zsh_avit_build_commit_age_segment() {
  emulate -L zsh

  local seconds="$1"
  local minutes hours days years
  local age color

  (( seconds < 0 )) && seconds=0

  minutes=$((seconds / 60))
  hours=$((minutes / 60))
  days=$((hours / 24))
  years=$((days / 365))

  if (( years > 0 )); then
    age="${years}y$((days % 365))d"
  elif (( days > 0 )); then
    age="${days}d$((hours % 24))h"
  elif (( hours > 0 )); then
    age="${hours}h$((minutes % 60))m"
  else
    age="${minutes}m"
  fi

  if (( minutes < 60 )); then
    color='green'
  elif (( hours < 24 )); then
    color='yellow'
  else
    color='red'
  fi

  REPLY="%F{${color}}${age}%f"
}

# --------------------------------------------------
# __zsh_avit_build_git_segments
# --------------------------------------------------
# 用一次 git status 生成左侧分支状态和右侧工作区摘要.
__zsh_avit_build_git_segments() {
  emulate -L zsh

  local status_output
  local -a lines
  local header branch line status_code
  local added=0 modified=0 deleted=0 renamed=0 unmerged=0 untracked=0 dirty=0
  local i x y right=''
  local last_commit now

  __zsh_avit_git_left_segment=''
  __zsh_avit_rprompt_segment=''

  zsh_has_cmd git || return 0

  status_output="$(command git status --porcelain=v1 --branch 2>/dev/null)" || return 0
  lines=("${(@f)status_output}")
  header="${lines[1]:-}"

  if [[ "$header" == '## '* ]]; then
    branch="${header#\#\# }"
    branch="${branch%%...*}"

    case "$branch" in
      'HEAD (detached at '*')')
        branch="${branch#HEAD (detached at }"
        branch="${branch%)}"
        ;;
      'HEAD (detached from '*')')
        branch="${branch#HEAD (detached from }"
        branch="${branch%)}"
        ;;
      'HEAD (no branch)')
        branch='detached'
        ;;
      'No commits yet on '*)
        branch="${branch#No commits yet on }"
        ;;
    esac
  fi

  [[ -n "$branch" ]] || branch='git'

  for (( i = 2; i <= ${#lines[@]}; ++i )); do
    line="${lines[i]}"
    [[ -n "$line" ]] || continue

    if [[ "$line" == '?? '* ]]; then
      untracked=1
      dirty=1
      continue
    fi

    x="${line[1,1]}"
    y="${line[2,2]}"
    status_code="${x}${y}"

    [[ "$status_code" != '  ' ]] && dirty=1

    case "$status_code" in
      DD|AU|UD|UA|DU|AA|UU)
        unmerged=1
        ;;
    esac

    [[ "$x" == 'A' || "$y" == 'A' ]] && added=1
    [[ "$x" == 'M' || "$y" == 'M' ]] && modified=1
    [[ "$x" == 'D' || "$y" == 'D' ]] && deleted=1
    [[ "$x" == 'R' || "$y" == 'R' ]] && renamed=1
    [[ "$x" == 'U' || "$y" == 'U' ]] && unmerged=1
  done

  __zsh_avit_git_left_segment="%F{green}${branch}%f"

  if (( dirty )); then
    __zsh_avit_git_left_segment+=" %F{red}✗%f"
  else
    __zsh_avit_git_left_segment+=" %F{green}✔%f"
  fi
  __zsh_avit_git_left_segment+=" "

  if (( ${ZSH_THEME_AVIT_SHOW_GIT_AGE:-1} )); then
    if last_commit="$(command git -c log.showSignature=false log --format=%at -1 2>/dev/null)"; then
      if __zsh_avit_now_seconds; then
        now="$REPLY"
        __zsh_avit_build_commit_age_segment "$((now - last_commit))"
        right+="$REPLY "
      fi
    fi
  fi

  (( added )) && right+="%F{green}✚ %f"
  (( modified )) && right+="%F{yellow}⚑ %f"
  (( deleted )) && right+="%F{red}✖ %f"
  (( renamed )) && right+="%F{blue}▴ %f"
  (( unmerged )) && right+="%F{cyan}§ %f"
  (( untracked )) && right+="%F{white}◒ %f"

  __zsh_avit_rprompt_segment="${right%% }"
}

# --------------------------------------------------
# __zsh_avit_precmd
# --------------------------------------------------
# 在每次显示 prompt 前集中刷新动态段.
__zsh_avit_precmd() {
  emulate -L zsh

  __zsh_avit_build_user_host_segment
  __zsh_avit_user_host_segment="$REPLY"

  __zsh_avit_build_virtualenv_segment
  __zsh_avit_virtualenv_segment="$REPLY"

  __zsh_avit_update_vi_mode_segment
  __zsh_avit_build_git_segments
}

# --------------------------------------------------
# __zsh_avit_zle_line_init
# --------------------------------------------------
# 链接已有 zle-line-init, 同时初始化 vi mode 提示.
__zsh_avit_zle_line_init() {
  emulate -L zsh

  if typeset -f __zsh_avit_prev_zle_line_init >/dev/null 2>&1; then
    __zsh_avit_prev_zle_line_init "$@"
  fi

  __zsh_avit_update_vi_mode_segment
}

# --------------------------------------------------
# __zsh_avit_zle_keymap_select
# --------------------------------------------------
# 在 vi insert 和 command 模式切换时即时刷新 prompt.
__zsh_avit_zle_keymap_select() {
  emulate -L zsh

  if typeset -f __zsh_avit_prev_zle_keymap_select >/dev/null 2>&1; then
    __zsh_avit_prev_zle_keymap_select "$@"
  fi

  __zsh_avit_update_vi_mode_segment
  zle reset-prompt
}

typeset -ga precmd_functions
if (( ${precmd_functions[(Ie)__zsh_avit_precmd]} == 0 )); then
  precmd_functions+=(__zsh_avit_precmd)
fi

if [[ "${ZSH_KEYMAP:-emacs}" == "vi" ]] && (( ${ZSH_THEME_AVIT_SHOW_VI_MODE:-1} )); then
  if typeset -f zle-line-init >/dev/null 2>&1; then
    functions[__zsh_avit_prev_zle_line_init]="${functions[zle-line-init]}"
  fi

  if typeset -f zle-keymap-select >/dev/null 2>&1; then
    functions[__zsh_avit_prev_zle_keymap_select]="${functions[zle-keymap-select]}"
  fi

  zle -N zle-line-init __zsh_avit_zle_line_init
  zle -N zle-keymap-select __zsh_avit_zle_keymap_select
fi

__zsh_avit_precmd

PROMPT='${__zsh_avit_user_host_segment}${__zsh_avit_dir_segment}${__zsh_avit_git_left_segment}${__zsh_avit_virtualenv_segment}${__zsh_avit_vi_mode_segment}
%(!.%F{red}.%F{white})▶%f '

PROMPT2='%(!.%F{red}.%F{white})◀%f '

RPROMPT='${__zsh_avit_rprompt_segment}%(?.. %B%F{red}⍉%f%b)'
