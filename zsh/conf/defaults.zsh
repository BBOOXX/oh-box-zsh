# conf/defaults.zsh
# 项目默认值中心.
#
# 这里有几个硬约束.
# 1. 这里只定义默认值.
# 2. 不写业务逻辑.
# 3. 不调用外部命令.
# 4. 不写 alias, function, bindkey.
#
# 用户如果想覆盖默认值, 应该在 user/config.zsh 中做.
# 不要直接改 feature 实现文件.
#
# 这份默认值有一个明确取向.
# - 保留 OMZ 里高频且低风险的交互体验.
# - 避免 OMZ 那种默认全开很多外部行为的策略.
# - 让每个体验增强都能被用户明确关闭.

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
# history 相关默认值
# ------------------------------
# 这里把 shell 历史的容量和行为显式化.
# 这样后续如果你要调试 share_history 或 hist_verify, 不需要再去改 feature 文件.
(( ${+ZSH_HISTORY_SIZE} )) || typeset -gi ZSH_HISTORY_SIZE=50000
(( ${+ZSH_HISTORY_SAVE_SIZE} )) || typeset -gi ZSH_HISTORY_SAVE_SIZE=50000
(( ${+ZSH_HISTORY_SHARE} )) || typeset -gi ZSH_HISTORY_SHARE=1
(( ${+ZSH_HISTORY_EXTENDED} )) || typeset -gi ZSH_HISTORY_EXTENDED=1
(( ${+ZSH_HISTORY_VERIFY} )) || typeset -gi ZSH_HISTORY_VERIFY=1

# ------------------------------
# completion 相关默认值
# ------------------------------
# 这一组默认值是在"速度可接受"前提下, 尽量把 zsh 原生补全调到更顺手.
# 这些行为都来自 zsh 自己, 不是第三方框架的独占能力.
(( ${+ZSH_COMPLETION_AUTO_MENU} )) || typeset -gi ZSH_COMPLETION_AUTO_MENU=1
(( ${+ZSH_COMPLETION_COMPLETE_IN_WORD} )) || typeset -gi ZSH_COMPLETION_COMPLETE_IN_WORD=1
(( ${+ZSH_COMPLETION_ALWAYS_TO_END} )) || typeset -gi ZSH_COMPLETION_ALWAYS_TO_END=1
(( ${+ZSH_COMPLETION_MENU_SELECT} )) || typeset -gi ZSH_COMPLETION_MENU_SELECT=1
(( ${+ZSH_COMPLETION_CASE_INSENSITIVE} )) || typeset -gi ZSH_COMPLETION_CASE_INSENSITIVE=1
(( ${+ZSH_COMPLETION_HYPHEN_INSENSITIVE} )) || typeset -gi ZSH_COMPLETION_HYPHEN_INSENSITIVE=0
(( ${+ZSH_COMPLETION_MATCH_SUBSTRING} )) || typeset -gi ZSH_COMPLETION_MATCH_SUBSTRING=1
(( ${+ZSH_COMPLETION_MATCH_PARTIAL_WORD} )) || typeset -gi ZSH_COMPLETION_MATCH_PARTIAL_WORD=1
(( ${+ZSH_COMPLETION_SPECIAL_DIRS} )) || typeset -gi ZSH_COMPLETION_SPECIAL_DIRS=1
(( ${+ZSH_COMPLETION_USE_CACHE} )) || typeset -gi ZSH_COMPLETION_USE_CACHE=1
(( ${+ZSH_COMPLETION_USE_BASHCOMPINIT} )) || typeset -gi ZSH_COMPLETION_USE_BASHCOMPINIT=0

# ------------------------------
# keybinds 相关默认值
# ------------------------------
# 这里只定义行为开关.
# 具体 bindkey 逻辑仍然在 features/keybinds.zsh.
(( ${+ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH} )) || typeset -gi ZSH_KEYBINDS_HISTORY_PREFIX_SEARCH=1
(( ${+ZSH_KEYBINDS_HOME_END} )) || typeset -gi ZSH_KEYBINDS_HOME_END=1
(( ${+ZSH_KEYBINDS_DELETE} )) || typeset -gi ZSH_KEYBINDS_DELETE=1
(( ${+ZSH_KEYBINDS_SHIFT_TAB_REVERSE_MENU} )) || typeset -gi ZSH_KEYBINDS_SHIFT_TAB_REVERSE_MENU=1
(( ${+ZSH_KEYBINDS_APPLICATION_MODE} )) || typeset -gi ZSH_KEYBINDS_APPLICATION_MODE=1

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
