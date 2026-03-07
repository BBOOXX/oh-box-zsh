# stages/login.zsh
# login 阶段初始化

# 这个文件只负责 login 阶段的最小准备工作
# 原则：
# 1) 只放轻量、基础、一次性的环境设置
# 2) 不放交互体验配置
# 3) 不放用户主配置入口 config.zsh
# 4) 不直接写第三方工具细节，模块接入统一交给 module loader

zsh_log_debug "login stage start"

# --------------------------------------------------
# 用户级 PATH 基础目录
# --------------------------------------------------
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

# --------------------------------------------------
# 系统常见补充路径
# --------------------------------------------------
if [[ "${ZSH_IS_MACOS:-0}" -eq 1 ]]; then
  path_append "/usr/local/bin"
  path_append "/usr/local/sbin"
  path_append "/opt/homebrew/bin"
  path_append "/opt/homebrew/sbin"
elif [[ "${ZSH_IS_LINUX:-0}" -eq 1 ]]; then
  path_append "/usr/local/bin"
  path_append "/usr/local/sbin"
fi

# --------------------------------------------------
# 最基础的通用环境变量
# --------------------------------------------------
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"

# login 阶段的外部工具模块
zsh_source_optional "$ZSH_COMPONENT_DIR/module-loader-login.zsh"

zsh_log_debug "login stage done"
