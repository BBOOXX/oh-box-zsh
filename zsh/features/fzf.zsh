# features/fzf.zsh
# fzf 接入层.
#
# 这里不主动去跑复杂探测命令.
# 策略是非常朴素的.
# 1. 先给一个温和的默认 FZF_DEFAULT_OPTS.
# 2. 再尝试 source 常见安装路径里的 shell 集成脚本.
#
# 这样做的好处.
# - 成本低.
# - 行为容易理解.
# - 不依赖某个特定包管理器.

# 给一个温和的默认交互参数.
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40% --layout=reverse --border}"

# 准备常见集成脚本路径列表.
local -a files
files=(
  "$HOME/.fzf.zsh"
  "/usr/share/fzf/completion.zsh"
  "/usr/share/fzf/key-bindings.zsh"
  "/opt/homebrew/opt/fzf/shell/completion.zsh"
  "/opt/homebrew/opt/fzf/shell/key-bindings.zsh"
  "/usr/local/opt/fzf/shell/completion.zsh"
  "/usr/local/opt/fzf/shell/key-bindings.zsh"
)

# 逐个尝试加载.
local file
for file in "${files[@]}"; do
  zsh_source_optional "$file"
done
