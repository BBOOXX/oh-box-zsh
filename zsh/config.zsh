# config.zsh
# 用户主配置入口：日常优先改这里，而不是 conf/* 或 modules/*

# ------------------------------
# 内建 zsh 行为开关
# ------------------------------
typeset -gi ZSH_ENABLE_HISTORY=1
typeset -gi ZSH_ENABLE_COMPLETION=0
typeset -gi ZSH_ENABLE_KEYBINDS=1
typeset -gi ZSH_ENABLE_PROMPT=1

# ------------------------------
# 用户偏好
# ------------------------------
typeset -g ZSH_KEYMAP="emacs"
typeset -g ZSH_THEME="basic"

# ------------------------------
# 模块列表
# login 阶段：更偏环境准备的一次性模块
# interactive 阶段：更偏交互体验的模块
# ------------------------------
typeset -ga ZSH_LOGIN_MODULES
typeset -ga ZSH_INTERACTIVE_MODULES

ZSH_LOGIN_MODULES=(
)

ZSH_INTERACTIVE_MODULES=(
)
