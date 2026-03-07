# components/prompt.zsh
# 提示符入口 颜色 主题目录 按主题名加载与回退

# 启用颜色支持 供主题使用
autoload -Uz colors
colors

# 允许 PROMPT 中的参数/命令替换
setopt prompt_subst

# 统一主题目录变量 便于后续扩展主题模块
typeset -g ZSH_THEME_DIR="$ZSH_CONFIG_HOME/themes"

# 读取主题名并拼接主题文件路径
local theme="${ZSH_THEME:-basic}"
local theme_file="$ZSH_THEME_DIR/${theme}.zsh"

# 优先加载指定主题 不存在时回退到 basic 保证可启动
if [[ -r "$theme_file" ]]; then
  source "$theme_file"
else
  zsh_log_debug "theme not found: $theme_file, fallback to basic"
  source "$ZSH_THEME_DIR/basic.zsh"
fi
