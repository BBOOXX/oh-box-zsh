# conf/features.zsh
# 功能开关集中定义 提供 默认值 + 本机覆盖点

# - 统一管理 interactive 能力开关
# - 允许用环境变量快速覆写 CI/临时排障
# - 允许本机私有配置 local.features.zsh 覆盖且不进仓库

# 交互能力开关 整数 0/1

# history 默认开启 保证历史体验可用
typeset -gi ZSH_ENABLE_HISTORY="${ZSH_ENABLE_HISTORY:-1}"

# completion 默认关闭 先保证启动链稳定
# 需要时可显式开启 再按平台逐步优化 compinit 成本
typeset -gi ZSH_ENABLE_COMPLETION="${ZSH_ENABLE_COMPLETION:-0}"

# keybinds 默认开启 保持交互式编辑体验
typeset -gi ZSH_ENABLE_KEYBINDS="${ZSH_ENABLE_KEYBINDS:-1}"

# prompt 默认开启 提供最小可读提示符
typeset -gi ZSH_ENABLE_PROMPT="${ZSH_ENABLE_PROMPT:-1}"

# 可读性配置项
# 编辑模式 emacs / vi
# 注意 这里只定义 意图 真正 bindkey 在 conf/keybinds.zsh 执行
typeset -g ZSH_KEYMAP="${ZSH_KEYMAP:-emacs}"

# 主题名 映射到 zsh/themes/<name>.zsh
# 注意 这里只定义选择 真正加载在 conf/prompt.zsh 执行
typeset -g ZSH_THEME="${ZSH_THEME:-basic}"

# 本机覆盖点
# 约定 放在 $ZSH_CONFIG_HOME/local.features.zsh
# 用于机器差异配置 例如 办公室机开启 completion 云主机关闭
zsh_source_optional "$ZSH_CONFIG_HOME/local.features.zsh"
