# config.zsh
# 用户主配置入口：平时优先改这里
# 目标是尽量恢复“以前主要改 .zshrc”那种使用体验
# 这里放：
# 1) 开关
# 2) 偏好
# 3) 模块列表
# 4) 模块参数
#
# 不要把实现细节写到这里：
# - conf/* 负责实现
# - modules/* 负责外部工具接入
# - local.zsh 负责任意自定义代码

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

# ------------------------------
# 模块参数（按需取消注释）
# ------------------------------

# pyenv 初始化策略（未来模块会消费这个值）
# 可选示例：
# typeset -g ZSH_PYENV_MODE="lazy"
# typeset -g ZSH_PYENV_MODE="full"

# tmux 行为策略（未来模块会消费这个值）
# 可选示例：
# typeset -g ZSH_TMUX_MODE="attach-or-new"
# typeset -g ZSH_TMUX_MODE="plain"

# fzf / brew / 其他模块的参数以后也统一放这里
