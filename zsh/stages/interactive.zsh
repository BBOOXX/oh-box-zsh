# stages/interactive.zsh
# interactive 阶段初始化：只做调度，按用户主配置 + 功能开关加载 components

# 这个阶段只在交互式 shell 执行
# 目标：
# 1) 先加载 local.zsh，作为用户主配置入口
# 2) 再根据 local/defaults 的结果加载具体组件
# 3) 让 stage 本身保持为轻量调度层
zsh_log_debug "interactive stage start"

# --------------------------------------------------
# 用户主配置入口
# --------------------------------------------------
# local.zsh 只在 interactive 阶段加载。
# 它既可以覆盖 defaults 中的变量，也可以写 alias / function / 临时代码。
zsh_source_optional "$ZSH_CONFIG_HOME/local.zsh"

# --------------------------------------------------
# 按开关分发组件
# --------------------------------------------------
# 默认值来自 components/defaults.zsh
# 用户覆盖来自 local.zsh
# 这里不再重复定义默认值，避免默认来源分散。

# 1) 历史记录策略：文件路径、容量、并发写锁等
if (( ZSH_ENABLE_HISTORY )); then
  zsh_source_optional "$ZSH_COMPONENT_DIR/history.zsh"
fi

# 2) 补全系统：仅在需要时启用，避免默认引入额外启动开销
if (( ZSH_ENABLE_COMPLETION )); then
  zsh_source_optional "$ZSH_COMPONENT_DIR/completion.zsh"
fi

# 3) 交互按键：emacs/vi 模式切换与常用快捷键入口
if (( ZSH_ENABLE_KEYBINDS )); then
  zsh_source_optional "$ZSH_COMPONENT_DIR/keybinds.zsh"
fi

# 4) 提示符：主题选择入口与回退逻辑
if (( ZSH_ENABLE_PROMPT )); then
  zsh_source_optional "$ZSH_COMPONENT_DIR/prompt.zsh"
fi

# interactive 阶段的外部工具模块
zsh_source_optional "$ZSH_COMPONENT_DIR/module-loader-interactive.zsh"

zsh_log_debug "interactive stage done"
