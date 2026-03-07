# components/defaults.zsh
# 项目默认配置中心
# - 这是仓库内提交的默认配置面板
# - 用户日常修改请写到 config.zsh
# - 这里只定义项目默认值与兜底值

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
(( ${+HIST_STAMPS} )) || typeset -g HIST_STAMPS="yyyy-mm-dd"

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
