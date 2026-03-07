# 20-detect.zsh
# 环境探测工具

# 尽早识别当前系统环境
# 把结果统一写入全局变量
# 后续各模块根据这些变量决定是否启用
# 这层只做探测不做具体模块加载

# --------------------------------------------------
# zsh_detect_os
# --------------------------------------------------
# 识别当前操作系统类型

# 输出方式
# 把结果写入特殊变量 REPLY
# 这是 shell 中常见的一种轻量返回约定 适合返回一个简单字符串

# 可能值：
# - macos
# - linux
# - unknown
zsh_detect_os() {
  local os_name

  # uname -s 通常返回系统内核名 例如
  # - Darwin
  # - Linux
  # - FreeBSD

  # 2>/dev/null 是为了在极少数异常环境里抑制错误输出
  os_name="$(uname -s 2>/dev/null)"

  case "$os_name" in
    Darwin)
      REPLY="macos"
      ;;
    Linux)
      REPLY="linux"
      ;;
    *)
      REPLY="unknown"
      ;;
  esac
}

# --------------------------------------------------
# zsh_detect_arch
# --------------------------------------------------
# 识别 CPU 架构

# 输出同样写入 REPLY

# 常见归一化结果
# - arm64
# - x86_64
# - 其他未知值则原样返回
zsh_detect_arch() {
  local arch_name

  # uname -m 通常返回机器架构名称 例如
  # - arm64
  # - aarch64
  # - x86_64
  # - amd64
  arch_name="$(uname -m 2>/dev/null)"

  case "$arch_name" in
    arm64|aarch64)
      REPLY="arm64"
      ;;
    x86_64|amd64)
      REPLY="x86_64"
      ;;
    *)
      # 对于未知架构 不强行映射 直接保留原始值
      REPLY="${arch_name:-unknown}"
      ;;
  esac
}

# --------------------------------------------------
# zsh_detect_termux
# --------------------------------------------------
# 判断当前是否处于 Termux 环境

# 返回值
# - 是 Termux 0
# - 不是1

zsh_detect_termux() {
  # TERMUX_VERSION 是 Termux 常见环境变量之一
  [[ -n "${TERMUX_VERSION:-}" ]] && return 0

  # PREFIX 是 shell 常见变量 但在 Termux 下通常是这个固定前缀
  [[ "${PREFIX:-}" == "/data/data/com.termux/files/usr" ]] && return 0

  # HOME 在 Termux 下通常位于这个路径
  [[ "${HOME:-}" == "/data/data/com.termux/files/home" ]] && return 0

  return 1
}

# --------------------------------------------------
# zsh_detect_wsl
# --------------------------------------------------
# 判断当前是否处于 WSL (Windows Subsystem for Linux) 环境

# 返回值
# - 是 WSL 0
# - 不是 1

# 判定策略
# 先快速看常见环境变量
# 再查看 /proc/version 中是否包含 Microsoft / WSL 特征字样
zsh_detect_wsl() {
  # WSL_INTEROP 在较新的 WSL 环境里很常见
  [[ -n "${WSL_INTEROP:-}" ]] && return 0

  # WSL_DISTRO_NAME 也是常见特征变量
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0

  # 只有在 Linux 且 /proc/version 可读时 才进一步检查
  if [[ -r /proc/version ]]; then
    # 直接把文件内容读进变量 避免额外起 grep 进程
    # 这在启动路径里更轻量
    local proc_version
    proc_version="$(</proc/version)"

    # WSL 的 /proc/version 中通常会出现 Microsoft 或 WSL 字样
    [[ "$proc_version" == *Microsoft* ]] && return 0
    [[ "$proc_version" == *microsoft* ]] && return 0
    [[ "$proc_version" == *WSL* ]] && return 0
  fi

  return 1
}

# --------------------------------------------------
# zsh_detect_ssh
# --------------------------------------------------
# 判断当前 shell 是否是通过 SSH 会话进入

# 返回值
# - 是 SSH 0
# - 不是 1
#
# 判定依据
# SSH 会话里通常至少会有以下变量之一
# - SSH_CONNECTION
# - SSH_CLIENT
# - SSH_TTY
zsh_detect_ssh() {
  [[ -n "${SSH_CONNECTION:-}" ]] && return 0
  [[ -n "${SSH_CLIENT:-}" ]] && return 0
  [[ -n "${SSH_TTY:-}" ]] && return 0
  return 1
}

# --------------------------------------------------
# zsh_detect_env
# --------------------------------------------------
# 执行一次完整环境探测 并把结果写入全局变量

# 这是给 init.zsh 调用的统一入口

# 输出变量
# - ZSH_OS
# - ZSH_ARCH
# - ZSH_HOSTNAME
# - ZSH_IS_TERMUX
# - ZSH_IS_WSL
# - ZSH_IS_SSH
# - ZSH_IS_MACOS
# - ZSH_IS_LINUX
zsh_detect_env() {
  # 探测 OS
  zsh_detect_os
  typeset -g ZSH_OS="$REPLY"
  # ^ 保存标准化后的系统类型字符串

  # 探测架构
  zsh_detect_arch
  typeset -g ZSH_ARCH="$REPLY"
  # ^ 保存标准化后的架构字符串

  # 探测主机名
  # %m 是 zsh 的提示符扩展语法 在这里通过参数展开取得短主机名
  # 这种写法通常比外部调用 hostname 更轻量
  typeset -g ZSH_HOSTNAME="${HOST:-${(%):-%m}}"

  # 初始化布尔标记
  # 这里用整数 0/1 而不是字符串 true/false
  # - 更适合 shell 的数值比较
  # - 后续判断时可以用 [[ "$VAR" -eq 1 ]]
  typeset -gi ZSH_IS_TERMUX=0
  typeset -gi ZSH_IS_WSL=0
  typeset -gi ZSH_IS_SSH=0
  typeset -gi ZSH_IS_MACOS=0
  typeset -gi ZSH_IS_LINUX=0

  # 写入平台布尔标记
  [[ "$ZSH_OS" == "macos" ]] && ZSH_IS_MACOS=1
  [[ "$ZSH_OS" == "linux" ]] && ZSH_IS_LINUX=1

  # 探测 Termux / WSL / SSH
  zsh_detect_termux && ZSH_IS_TERMUX=1
  zsh_detect_wsl && ZSH_IS_WSL=1
  zsh_detect_ssh && ZSH_IS_SSH=1

  # 调试输出
  zsh_log_debug "env: os=$ZSH_OS arch=$ZSH_ARCH host=$ZSH_HOSTNAME termux=$ZSH_IS_TERMUX wsl=$ZSH_IS_WSL ssh=$ZSH_IS_SSH"
}
