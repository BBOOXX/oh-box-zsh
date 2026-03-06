# config.zsh
# 用户主配置入口 平时优先改这里

ZSH_KEYMAP="emacs"
ZSH_THEME="basic"

# login 阶段 更偏环境准备的一次性模块
typeset -ga ZSH_LOGIN_MODULES
ZSH_LOGIN_MODULES=(
)

# interactive 阶段 更偏交互体验的模块
typeset -ga ZSH_INTERACTIVE_MODULES
ZSH_INTERACTIVE_MODULES=(
)
