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
#
# 当前这份默认 config 有一个明确策略.
# - 默认启用 zsh 原生里最值回票价的交互增强.
# - 不默认替你接管外部工具生态.
# - 外部工具接入继续保持 opt-in.

# 默认给一个保守但可用的基线.
# login 只做轻量 PATH 基础层.
typeset -ga ZSH_LOGIN_FEATURES
ZSH_LOGIN_FEATURES=(
  env-path
)

# interactive 默认启用几个最基础的交互能力.
# 这样刚装好就有比较顺手的补全, 键位和 prompt.
typeset -ga ZSH_INTERACTIVE_FEATURES
ZSH_INTERACTIVE_FEATURES=(
  history
  completion
  keybinds
  prompt
)

# 默认主题.
# 如果你更想要 git 分支提示, 可以改成 basic-git.
ZSH_THEME="basic"

# 默认编辑模式.
ZSH_KEYMAP="emacs"

# 下面这些行为默认已经在 conf/defaults.zsh 中开启.
# 这里不重复赋值, 只是把最常见的可调开关列出来, 方便你以后直接取消注释.
#
# completion.
# ZSH_COMPLETION_CASE_INSENSITIVE=1
# ZSH_COMPLETION_MATCH_SUBSTRING=1
# ZSH_COMPLETION_MATCH_PARTIAL_WORD=1
# ZSH_COMPLETION_AUTO_MENU=1
# ZSH_COMPLETION_MENU_SELECT=1
#
# keybinds.
# ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH=1
#
# history.
# ZSH_HISTORY_VERIFY=1
