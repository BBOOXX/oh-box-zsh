# 用户声明式配置入口.
#
# 这就是你日常最应该编辑的文件.
# 它的职责很简单.
# 1. 覆盖项目默认值.
# 2. 决定哪些 feature 启用.
# 3. 决定 feature 的顺序.
# 4. 决定主题, 编辑模式, 模块参数.
#
# 它不适合做这些事.
# - 写 alias.
# - 写 function.
# - 写临时 echo 调试.
# - 写一次性的实验脚本.
#
# 如果你需要上面这些内容, 请写到 user/local.zsh.

# 默认给一个保守但可用的基线.
# login 只做轻量 PATH 基础层.
typeset -ga ZSH_LOGIN_FEATURES
ZSH_LOGIN_FEATURES=(
  env-path
)

# interactive 默认启用几个最基础的交互能力.
# 这样刚装好就能正常用, 但又不会像大型框架那样默认全开一堆东西.
typeset -ga ZSH_INTERACTIVE_FEATURES
ZSH_INTERACTIVE_FEATURES=(
  history
  completion
  keybinds
  prompt
)

# 默认主题.
ZSH_THEME="basic"

# 默认编辑模式.
ZSH_KEYMAP="emacs"
