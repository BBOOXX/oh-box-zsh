# features/env-path.zsh
# 轻量 PATH 基础层

# 这个 feature 的目标非常克制
# 1. 只做安全的 PATH 拼接
# 2. 不调用重命令
# 3. 不做复杂自动探测
# 4. 不承载第三方工具目录
#
# 这层通常适合放到 login 阶段
# 因为 PATH 是最基础的环境准备之一
# 第三方工具如果需要改 PATH, 应该放到独立 feature 中
# 再通过 ZSH_LOGIN_FEATURES 或 ZSH_INTERACTIVE_FEATURES 显式接入

# 用户级常见目录优先
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.local/sbin"
path_prepend "$HOME/bin"

# 通用系统级本地目录放在后面兜底
# path_append 自带目录存在检查, 不存在的目录会被静默跳过
path_append "/usr/local/bin"
path_append "/usr/local/sbin"

# 显式再做一次去重, 让 feature 自身的语义完整
path_dedup
