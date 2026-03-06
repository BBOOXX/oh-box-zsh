# conf/defaults.zsh
# 框架内部默认值层：
# - 只负责兜底
# - 不作为日常编辑入口
# - 用户配置请写到 config.zsh / config.local.zsh

# ------------------------------
# 内建 zsh 行为开关
# ------------------------------
(( ${+ZSH_ENABLE_HISTORY} )) || typeset -gi ZSH_ENABLE_HISTORY=1
(( ${+ZSH_ENABLE_COMPLETION} )) || typeset -gi ZSH_ENABLE_COMPLETION=0
(( ${+ZSH_ENABLE_KEYBINDS} )) || typeset -gi ZSH_ENABLE_KEYBINDS=1
(( ${+ZSH_ENABLE_PROMPT} )) || typeset -gi ZSH_ENABLE_PROMPT=1

# ------------------------------
# 用户偏好默认值
# ------------------------------
(( ${+ZSH_KEYMAP} )) || typeset -g ZSH_KEYMAP="emacs"
(( ${+ZSH_THEME} )) || typeset -g ZSH_THEME="basic"

# ------------------------------
# 模块列表默认值
# ------------------------------
if (( ! ${+ZSH_LOGIN_MODULES} )); then
  typeset -ga ZSH_LOGIN_MODULES
  ZSH_LOGIN_MODULES=()
fi

if (( ! ${+ZSH_INTERACTIVE_MODULES} )); then
  typeset -ga ZSH_INTERACTIVE_MODULES
  ZSH_INTERACTIVE_MODULES=()
fi
