# 20-detect.zsh
# 环境探测工具

# 尽早识别当前系统环境
# 把结果统一写入全局变量
# 后续各模块根据这些变量决定是否启用

# 识别当前操作系统类型
# macos
# linux
# unknown
zsh_detect_os() {
  local os_name

  # uname -s 通常返回系统内核名 例如
  # Darwin
  # Linux
  # FreeBSD

  # 抑制极少数异常环境里的错误输出
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

# 识别 CPU 架构
# arm64
# x86_64
# 其他未知值则原样返回
zsh_detect_arch() {
  local arch_name

  # uname -m 通常返回机器架构名称 例如
  # arm64
  # aarch64
  # x86_64
  # amd64
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

# 判断当前是否处于 Termux 环境
# 返回值
# 是 Termux 0
# 非 Termux 1

zsh_detect_termux() {
  # TERMUX_VERSION 是 Termux 常见环境变量之一
  [[ -n "${TERMUX_VERSION:-}" ]] && return 0

  # Termux 下 PREFIX 通常为固定前缀
  [[ "${PREFIX:-}" == "/data/data/com.termux/files/usr" ]] && return 0

  # Termux 下 HOME 通常位于固定路径
  [[ "${HOME:-}" == "/data/data/com.termux/files/home" ]] && return 0

  return 1
}

# 判断当前是否处于 WSL Windows Subsystem for Linux 环境
# 是 WSL 0
# 非 WSL 1
zsh_detect_wsl() {
  # WSL_INTEROP 在较新的 WSL 环境里很常见
  [[ -n "${WSL_INTEROP:-}" ]] && return 0

  # WSL_DISTRO_NAME 也是常见特征变量
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0

  # /proc/version 可读时再检查内核版本文本
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

# 判断当前 shell 是否通过 SSH 会话进入
# 返回值
# 是 SSH 0
# 非 SSH 1
zsh_detect_ssh() {
  [[ -n "${SSH_CONNECTION:-}" ]] && return 0
  [[ -n "${SSH_CLIENT:-}" ]] && return 0
  [[ -n "${SSH_TTY:-}" ]] && return 0
  return 1
}

# 执行一次完整环境探测 并把结果写入全局变量
# init.zsh 调用入口
# 输出变量
# ZSH_OS
# ZSH_ARCH
# ZSH_HOSTNAME
# ZSH_IS_TERMUX
# ZSH_IS_WSL
# ZSH_IS_SSH
# ZSH_IS_MACOS
# ZSH_IS_LINUX
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
  # %m 是 zsh 提示符扩展语法 可取得短主机名
  # 避免外部调用 hostname
  typeset -g ZSH_HOSTNAME="${HOST:-${(%):-%m}}"

  # 布尔标记使用整数 0/1
  # 便于 shell 数值比较
  # 后续判断可以用 [[ "$VAR" -eq 1 ]]
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
