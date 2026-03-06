# stages/login.zsh
# login 阶段初始化

# 这个文件只负责 login 阶段的最小准备工作

# 当前阶段的原则
# 1) 只放轻量 基础 一次性的环境设置
# 2) 不放交互体验配置
# 3) 不放重初始化
# 4) 不直接写第三方工具细节 模块接入统一交给 modules loader

# 也就是说
# - 可以做 PATH 基础组装
# - 可以设编辑器/分页器之类的基础环境变量
# - 不要直接在这里写 prompt / completion / pyenv / brew 的具体逻辑

# 记录调试信息
zsh_log_debug "login stage start"

# --------------------------------------------------
# 用户级 PATH 基础目录
# --------------------------------------------------

# 这些目录通常是用户自定义命令最常见的位置
# 放在前面 意味着它们优先于系统默认路径

# 使用 path_prepend 的好处
# - 自动过滤不存在目录
# - 自动去重
# - 不再手工拼 PATH 字符串
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/bin"

# --------------------------------------------------
# 系统常见补充路径
# --------------------------------------------------

# 这一步只加非常常见且轻量的路径不做工具探测

# macOS 下
# - /usr/local/bin      常见于 Intel Mac 或历史安装路径
# - /usr/local/sbin
# - /opt/homebrew/bin   常见于 Apple Silicon Homebrew
# - /opt/homebrew/sbin
#
# Linux 下
# - /usr/local/bin
# - /usr/local/sbin

# 注意
# 这里先用 append 而不是 prepend
# 因为用户级目录 如 ~/.local/bin 通常更应该有更高优先级
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

# 这里只设最通用最保守的几个
# 原则是
# - 如果外部已经定义了就尊重外部值
# - 如果没有定义才给默认值

# 这样不会强行覆盖用户或系统已有环境
export EDITOR="${EDITOR:-vim}"
# ^ 默认编辑器

export VISUAL="${VISUAL:-$EDITOR}"
# ^ VISUAL 通常代表更偏全屏交互式的编辑器
#   如果外部没定义就跟随 EDITOR

export PAGER="${PAGER:-less}"
# ^ 默认分页器

export LESS="${LESS:--R}"
# ^ 给 less 一个保守默认参数
#   -R 表示允许显示原始颜色控制字符 (但仍保守处理)

# login 阶段的外部工具模块
zsh_source_optional "$ZSH_CONF_DIR/modules-login.zsh"

# 调试输出结束
zsh_log_debug "login stage done"

