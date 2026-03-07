# conf/defaults.zsh
# 项目默认值中心.
#
# 这里有几个严格约束.
# 1. 这里只定义默认值.
# 2. 不写业务逻辑.
# 3. 不调用外部命令.
# 4. 不写 alias, function, bindkey.
#
# 用户如果想覆盖默认值, 应该在 user/config.zsh 中做, 而不是直接改 feature 实现文件.

# ------------------------------
# 主题与编辑模式
# ------------------------------
(( ${+ZSH_THEME} )) || typeset -g ZSH_THEME="basic"
(( ${+ZSH_KEYMAP} )) || typeset -g ZSH_KEYMAP="emacs"

# ------------------------------
# 本地脚本层开关
# ------------------------------
# 1 表示 interactive 阶段最后会加载 user/local.zsh.
# 0 表示完全禁用本地脚本层.
(( ${+ZSH_ENABLE_LOCAL} )) || typeset -gi ZSH_ENABLE_LOCAL=1

# ------------------------------
# 缓存相关默认值
# ------------------------------
(( ${+ZSH_CACHE_DEFAULT_TTL} )) || typeset -gi ZSH_CACHE_DEFAULT_TTL=86400

# ------------------------------
# homebrew 相关默认值
# ------------------------------
(( ${+ZSH_HOMEBREW_ENABLE} )) || typeset -gi ZSH_HOMEBREW_ENABLE=1
(( ${+ZSH_HOMEBREW_SHELLENV_TTL} )) || typeset -gi ZSH_HOMEBREW_SHELLENV_TTL=86400

# ------------------------------
# pyenv 相关默认值
# ------------------------------
(( ${+ZSH_PYENV_ENABLE} )) || typeset -gi ZSH_PYENV_ENABLE=1
(( ${+ZSH_PYENV_LAZY} )) || typeset -gi ZSH_PYENV_LAZY=1
(( ${+ZSH_PYENV_INIT_COMMANDS} )) || typeset -g ZSH_PYENV_INIT_COMMANDS="pyenv"

# ------------------------------
# tmux 相关默认值
# ------------------------------
(( ${+ZSH_TMUX_AUTO_ATTACH} )) || typeset -gi ZSH_TMUX_AUTO_ATTACH=0
(( ${+ZSH_TMUX_SESSION} )) || typeset -g ZSH_TMUX_SESSION="main"

# ------------------------------
# feature 列表默认值
# ------------------------------
# 这里用数组表达 feature 列表, 而不是一堆 ZSH_ENABLE_XXX.
# 这样做有三个好处.
# 1. feature 是统一模型.
# 2. 顺序可控.
# 3. 以后接新功能时, 配置面不会继续膨胀.
if (( ! ${+ZSH_LOGIN_FEATURES} )); then
  typeset -ga ZSH_LOGIN_FEATURES
  ZSH_LOGIN_FEATURES=(env-path)
fi

if (( ! ${+ZSH_INTERACTIVE_FEATURES} )); then
  typeset -ga ZSH_INTERACTIVE_FEATURES
  ZSH_INTERACTIVE_FEATURES=(history completion keybinds prompt)
fi
