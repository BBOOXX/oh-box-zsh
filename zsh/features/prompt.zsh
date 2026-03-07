# features/prompt.zsh
# 提示符入口.
#
# 这个 feature 自己不定义具体主题内容.
# 它只负责.
# 1. 打开颜色支持.
# 2. 打开 prompt_subst.
# 3. 按主题名加载 themes/*.zsh.
#
# 这样之后, 主题切换就变成纯配置动作, 不需要再改 feature 代码.
autoload -Uz colors
colors

# 允许 PROMPT 和 RPROMPT 内进行参数展开.
setopt prompt_subst

# 读取主题名并加载对应文件.
local theme="${ZSH_THEME:-basic}"
local file="$ZSH_THEME_DIR/${theme}.zsh"

if [[ -r "$file" ]]; then
  source "$file"
else
  zsh_warn "theme not found: $theme, fallback to basic"
  source "$ZSH_THEME_DIR/basic.zsh"
fi
