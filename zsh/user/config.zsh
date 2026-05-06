# 用户声明式配置入口

# 日常主要编辑入口
# 声明层职责
# 1 覆盖项目默认值
# 2 决定哪些 feature 启用
# 3 决定 feature 的顺序
# 4 决定主题 编辑模式 模块参数

# alias function bindkey 和临时代码放到 user/local.zsh

# 默认给一个保守但可用的基线
# login 只做轻量 PATH 基础层
typeset -ga ZSH_LOGIN_FEATURES
ZSH_LOGIN_FEATURES=(
  brew
  env-path
  pyenv
)

# interactive 默认启用基础交互能力
# 刚装好即可使用补全 键位和 prompt
typeset -ga ZSH_INTERACTIVE_FEATURES
ZSH_INTERACTIVE_FEATURES=(
  history
  completion
  pyenv
  z
  tmux
  keybinds
  prompt
  autosuggestions
)

# 默认主题
ZSH_THEME="avit"

# 默认编辑模式
ZSH_KEYMAP="emacs"
