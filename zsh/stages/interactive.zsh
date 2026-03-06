# stages/interactive.zsh
# interactive 阶段初始化 只做调度 按功能开关加载 conf 片段

# 这个阶段只在交互式 shell 执行
# 目标 把 具体业务逻辑 下沉到 conf/* 这里保持可读 可回滚的调度层
# 好处
# 1) 一眼可见当前 interactive 阶段做了哪些事
# 2) 每个能力都可单独开关 便于排障与性能对比
# 3) 避免把大量细节塞回 init.zsh / stage 文件
zsh_log_debug "interactive stage start"

# --------------------------------------------------
# 按开关分发 conf 模块
# --------------------------------------------------
# 开关值统一由 config.defaults.zsh / config.zsh / config.local.zsh 提供。
# 这里不再重复定义默认值，避免默认来源分散造成维护漂移。
# 原则：stage 只做“是否加载”的决策，不承载具体实现细节。
# 具体行为（history setopt / compinit / bindkey / prompt）都在 conf/* 中维护。

# 1) 历史记录策略：文件路径、容量、并发写锁等
if (( ZSH_ENABLE_HISTORY )); then
  zsh_source_optional "$ZSH_CONF_DIR/history.zsh"
fi

# 2) 补全系统：仅在需要时启用，避免默认引入额外启动开销
if (( ZSH_ENABLE_COMPLETION )); then
  zsh_source_optional "$ZSH_CONF_DIR/completion.zsh"
fi

# 3) 交互按键：emacs/vi 模式切换与常用快捷键入口
if (( ZSH_ENABLE_KEYBINDS )); then
  zsh_source_optional "$ZSH_CONF_DIR/keybinds.zsh"
fi

# 4) 提示符：主题选择入口与回退逻辑
if (( ZSH_ENABLE_PROMPT )); then
  zsh_source_optional "$ZSH_CONF_DIR/prompt.zsh"
fi

# interactive 阶段的外部工具模块
zsh_source_optional "$ZSH_CONF_DIR/modules-interactive.zsh"

zsh_log_debug "interactive stage done"
