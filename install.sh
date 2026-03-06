#!/usr/bin/env bash
set -euo pipefail
# ^ 开启 Bash 的 严格模式 尽量让脚本在异常时立刻失败 而不是悄悄继续
#   -e:
#       只要有任意一条命令返回非 0 (失败) 脚本就立即退出
#       这样可以避免前面某步失败了 后面还继续执行 导致把环境搞坏
#   -u:
#       访问未定义变量时直接报错退出
#       这样可以防止因为变量名拼错 参数缺失而产生危险行为
#   pipefail:
#       管道命令中 只要任意一段失败 整个管道都算失败
#       否则默认只看最后一段命令的退出码 容易掩盖前面的问题

MODE="link"
# ^ 安装模式，默认值设为 link (软链接模式)
#   为什么默认用软链接
#   1) 更适合 git 管理的配置仓库
#   2) 仓库更新后立即生效 不需要再次复制
#   3) 配置只有一份真源 不容易出现副本漂移
#
#   可选值
#   - link: 创建符号链接(推荐)
#   - copy: 直接复制文件/目录
FORCE=0
# ^ 是否强制覆盖已有目标
#   0 表示默认不强制
#   如果目标路径已经存在 默认直接报错退出 防止误覆盖用户现有配置
#   显式传入 --force 后 才会先备份再替换
#
#   这里使用 0/1 而不是 true/false 是因为 Bash 中用整数做条件更直接稳定

for arg in "$@"; do
# ^ 遍历脚本收到的所有命令行参数
#   "$@" 表示按原样逐个取出所有参数 能正确保留参数边界
#
#   例如
#   ./install.sh --link --force
#   那么这里会依次处理 --link --force

  case "$arg" in
  # ^ 使用 case 按参数值做分支匹配
  #   比连续 if/elif 更清晰 适合这种少量固定选项的脚本
    --copy|-c)
    # ^ 如果传入 --copy 表示要求用复制模式安装 而不是软链接
      MODE="copy"
      # ^ 把安装模式改成 copy
      ;;
      # ^ 结束当前 case 分支
    --link|-l)
    # ^ 如果传入 --link 则强制使用软链接模式
      MODE="link"
      # ^ 把安装模式改成 link
      ;;
      # ^ 结束当前 case 分支
    --force|-f)
    # ^ 如果传入 --force 表示允许替换已有目标
      FORCE=1
      # ^ 把强制标志设为 1 后续看到已存在目标时会先备份再替换
      ;;
      # ^ 结束当前 case 分支
    *)
    # ^ 兜底分支 遇到不认识的参数 就直接报错退出
      echo "Unknown option: $arg" >&2
      # ^ 打印错误信息到标准错误(stderr) 而不是标准输出(stdout)
      #   >&2 的目的
      #   1) 让错误信息和正常输出分流
      #   2) 便于日志重定向时单独处理错误
      echo "Usage: $0 [--link|--copy] [--force|-f]" >&2
      # ^ 打印用法说明
      #   $0 是当前脚本的调用名
      exit 1
      # ^ 以非 0 状态退出 告诉调用方执行失败
      ;;
      # ^ 结束兜底分支
  esac
  # ^ 结束 case 语句
done
# ^ 结束参数遍历循环

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ^ 计算 当前 install.sh 所在的项目目录 的绝对路径
#
#   逐层拆解
#   - ${BASH_SOURCE[0]}
#       当前这个脚本文件本身的路径 比 $0 更可靠
#       因为 $0 在被 source 或某些调用方式下不一定稳定
#   - dirname "${BASH_SOURCE[0]}"
#       取出脚本所在目录
#   - cd "..."
#       切换到该目录
#   - pwd
#       输出该目录的绝对路径
#
#   最终结果
#   无论从哪里执行 ./install.sh PROJECT_DIR 都会指向仓库根目录
#   这是后面定位 zshenv 和 zsh/ 子目录的基础
#
#   为什么必须算绝对路径
#   因为用绝对路径最省心
#   创建软链接时 如果源路径是相对路径 将来从别处查看/使用时可能不稳定
SRC_ZSHENV="$PROJECT_DIR/zshenv"
# ^ 源 zshenv 文件路径
#   这个文件位于仓库根目录 内容通常只有一行
#   export ZDOTDIR="$HOME/.config/zsh"
#
#   安装时会把它链接(或复制) 到用户家目录的 ~/.zshenv
#   这样 zsh 启动时就会知道真正配置目录在 ~/.config/zsh
SRC_ZSH_DIR="$PROJECT_DIR/zsh"
# ^ 源 zsh 配置目录路径
#   安装时会把这个目录链接(或复制) 到 ~/.config/zsh

DST_ZSHENV="$HOME/.zshenv"
# ^ 目标 zshenv 路径
#   这是 zsh 启动时最早读取的配置文件之一
#   把它放在家目录 是因为 zsh 默认就会去这里找

DST_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
# ^ 用户的 ~/.config 目录
#   这是 XDG 风格常见的配置根目录
#   我们不假定它一定存在 因此后面会先 mkdir -p 创建它

DST_ZSH_DIR="$DST_CONFIG_DIR/zsh"
# ^ 目标 zsh 配置目录路径 也就是 ~/.config/zsh
#   这是我们最终希望 ZDOTDIR 指向的位置
#
#   安装后通常会是
#   - 软链接：~/.config/zsh -> /仓库路径/zsh
#   或
#   - 实体目录：~/.config/zsh (由复制模式生成)

backup_path() {
# ^ 定义一个 备份已有路径 的函数
#   如果目标已存在 就把它重命名为带时间戳的备份

  local target="$1"
  # ^ 取函数的第一个参数作为要备份的目标路径
  #
  #   使用 local 的原因
  #   1) 防止污染全局变量
  #   2) 函数内部变量作用域更清晰
  #   3) 避免和外部同名变量互相覆盖
  #
  #   这里 target 可以是文件 目录 软链接 统一按路径处理
  if [[ -e "$target" || -L "$target" ]]; then
  # ^ 判断该路径是否值得备份
  #
  #   -e
  #     路径存在 (普通文件 目录 设备文件等
  #   -L
  #     路径是符号链接
  #
  #   为什么两个条件都要写
  #   因为 坏掉的符号链接 在某些情况下可能 -e 为假 但 -L 为真
  #   我们仍然希望把这种链接也当作现有目标处理 而不是忽略它
    local ts
    # ^ 定义本地变量 ts 用来保存当前时间戳
    #   单独拆出来是为了让后面的 backup 文件名更清晰
    ts="$(date +%Y%m%d_%H%M%S)"
    # ^ 生成一个精确到秒的时间戳 例如
    #   20260305_142530
    #
    #   这样做的目的
    #   1) 避免备份文件名冲突
    #   2) 一眼能看出备份生成时间
    #   3) 排序时按时间顺序自然排列
    local backup="${target}.backup.${ts}"
    # ^ 构造备份路径
    #   例如
    #   ~/.zshenv.backup.20260305_142530
    #   ~/.config/zsh.backup.20260305_142530
    #
    #   这里采用 原路径 + .backup.时间戳 的命名方式
    echo "Backup: $target -> $backup"
    # ^ 打印备份操作日志 方便看到脚本做了什么
    #   这是正常信息 打印到 stdout 即可
    mv "$target" "$backup"
    # ^ 用 mv 直接把原目标改名为备份路径
    #
    #   为什么用 mv 而不是 cp
    #   1) 我们接下来要在原路径创建新的链接/文件 原路径必须腾出来
    #   2) mv 在同一文件系统内通常是原子级重命名 速度快
  fi
  # ^ 如果目标不存在就什么都不做 静默返回
}
# ^ 结束 backup_path 函数定义

ensure_parent_dir() {
# ^ 定义 确保目标的父目录存在 的函数
#   这是一个很基础的辅助函数 目的是避免在创建文件/链接前
#   因为父目录不存在而失败

  local target="$1"
   # ^ 取函数第一个参数 表示 将要写入的目标路径
  mkdir -p "$(dirname "$target")"
  # ^ 创建目标路径的父目录
  #
  #   分解说明
  #   - dirname "$target"
  #       取出目标路径的上级目录
  #       例如
  #       /Users/box/.config/zsh -> /Users/box/.config
  #       /Users/box/.zshenv     -> /Users/box
  #   - mkdir -p
  #       如果目录不存在就创建
  #       如果已经存在则不报错
}
# ^ 结束 ensure_parent_dir 函数定义

install_link() {
# ^ 定义 用软链接方式安装 的函数
#   这个函数负责把某个源路径 src 链接到目标路径 dst

  local src="$1"
  # ^ 第一个参数 源路径
  local dst="$2"
  # ^ 第二个参数 目标路径

  ensure_parent_dir "$dst"
  # ^ 在创建链接前 先确保目标的父目录已经存在
  #   否则 ln -s 会因为父目录缺失而失败

  if [[ -L "$dst" ]]; then
  # ^ 如果目标本身已经是一个符号链接 就进入 是否已正确链接 的快速检查
  #   只有已经是软链接时 我们才有必要比较它当前指向哪里
  #   如果它是普通文件/目录 则后面按 已存在目标 处理
    local current
    # ^ 定义一个本地变量 用来保存该符号链接当前指向的路径
    current="$(readlink "$dst" || true)"
    # ^ 读取符号链接的目标路径
    #
    #   - readlink "$dst"
    #       读取符号链接指向的原始路径字符串
    #   - || true
    #       即使 readlink 因异常失败 也不要让整个脚本因为 set -e 直接退出
    #
    #   虽然理论上 -L 成立时 readlink 应该能工作 但在某些异常系统状态下
    #   这里仍可能失败 这里做一次兜底 避免脚本过早中断
    if [[ "$current" == "$src" ]]; then
    # ^ 如果目标链接已经准确指向我们想要的源路径
    #   说明这一步已经完成 没必要重复创建
      echo "Already linked: $dst -> $src"
      return 0
      # ^ 直接成功返回
    fi
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
  # ^ 走到这里 说明
  #   1) 目标可能是普通文件 / 目录
  #   2) 或者是符号链接 但指向不对
  #   3) 或者是损坏符号链接
  #
  #   统一把它视为 已有占位需要处理
    if [[ "$FORCE" -eq 1 ]]; then
    # ^ 如果用户明确允许强制覆盖就先备份原目标
      backup_path "$dst"
      # ^ 调用统一备份逻辑 避免直接删掉用户原有内容
    else
    # ^ 如果没有 --force 则拒绝继续 防止误操作
      echo "Target exists: $dst"
      echo "Re-run with --force to back up and replace it."
      # ^ 告诉用户哪个目标路径已存在
      exit 1
      # ^ 以失败退出 因为当前条件下脚本不能安全继续
    fi
  fi

  ln -s "$src" "$dst"
  # ^ 创建符号链接
  #
  #   -s
  #     表示创建 软链接 而不是硬链接
  #
  #   因为我们前面已经显式检查并处理了 目标已存在 的情况
  #   所以这里不用 ln -sf 逻辑更透明
  #   - 有冲突时 要么报错退出
  #   - 要么在 --force 下先备份再创建
  #   如果直接用 -f 会绕过这套保护流程 不利于可控性
  echo "Linked: $dst -> $src"
}
# ^ 结束 install_link 函数定义

install_copy_file() {
# ^ 定义 复制单个文件 的安装函数

  local src="$1"
  # ^ 第一个参数 源路径
  local dst="$2"
  # ^ 第二个参数 目标路径

  ensure_parent_dir "$dst"
  # ^ 在创建链接前 先确保目标的父目录已经存在

  if [[ -e "$dst" || -L "$dst" ]]; then
  # ^ 如果目标已存在 (包括文件目录符号链接) 就进入冲突处理逻辑
    if [[ "$FORCE" -eq 1 ]]; then
    # ^ 允许强制时
      backup_path "$dst"
      # ^ 先备份原目标
    else
      echo "Target exists: $dst"
      echo "Re-run with --force to back up and replace it."
      exit 1
      # ^ 失败退出
    fi
  fi

  cp "$src" "$dst"
  # ^ 复制文件到目标路径
  echo "Copied file: $src -> $dst"
}
# ^ 结束 install_copy_file 函数定义

install_copy_dir() {
# ^ 定义 复制整个目录 的安装函数
#   用于处理 zsh/ 配置目录
#
#   复制模式的意义
#   1) 适合一次性部署不依赖仓库长期存在
#   2) 目标机器可以脱离仓库独立运行

  local src="$1"
  # ^ 第一个参数 源路径
  local dst="$2"
  # ^ 第二个参数 目标路径

  ensure_parent_dir "$dst"
  # ^ 在创建链接前 先确保目标的父目录已经存在

  if [[ -e "$dst" || -L "$dst" ]]; then
  # ^ 如果目标已存在 (包括文件目录符号链接) 就进入冲突处理逻辑
    if [[ "$FORCE" -eq 1 ]]; then
    # ^ 如果用户明确允许强制覆盖就先备份原目标
      backup_path "$dst"
      # ^ 调用统一备份逻辑 避免直接删掉用户原有内容
    else
    # ^ 如果没有 --force 则拒绝继续 防止误操作
      echo "Target exists: $dst"
      echo "Re-run with --force to back up and replace it."
      # ^ 告诉用户哪个目标路径已存在
      exit 1
      # ^ 以失败退出 因为当前条件下脚本不能安全继续
    fi
  fi

  cp -R "$src" "$dst"
  # ^ 递归复制整个目录
  #
  #   为什么用 cp -R
  #   1) macOS / BSD / GNU 环境都普遍支持
  #   2) 足够处理普通配置目录复制
  #   3) 比起某些 GNU 特有参数 如 -a 更通用
  echo "Copied dir: $src -> $dst"
}
# ^ 结束 install_copy_dir 函数定义

main() {
# ^ 定义主流程函数
#
#   1) 校验源文件/目录是否存在
#   2) 创建 ~/.config
#   3) 根据 MODE 选择 link 或 copy
#   4) 输出完成提示
  if [[ ! -f "$SRC_ZSHENV" ]]; then
  # ^ 校验源 zshenv 是否存在且是普通文件
  #   如果仓库结构不完整 后面再去创建链接/复制只会得到更隐蔽的错误
    echo "Missing file: $SRC_ZSHENV" >&2
    exit 1
    # 提前失败
  fi

  if [[ ! -d "$SRC_ZSH_DIR" ]]; then
  # ^ 校验源 zsh 目录是否存在且确实是目录。
  #   如果仓库结构不完整 后面再去创建链接/复制只会得到更隐蔽的错误
    echo "Missing directory: $SRC_ZSH_DIR" >&2
    exit 1
    # 提前失败
  fi

  mkdir -p "$DST_CONFIG_DIR"
  # ^ 预先确保 ~/.config 存在

  if [[ "$MODE" == "link" ]]; then
  # ^ 如果安装模式是 link 则执行链接安装分支
    install_link "$SRC_ZSHENV" "$DST_ZSHENV"
    install_link "$SRC_ZSH_DIR" "$DST_ZSH_DIR"
  else
  # ^ 否则说明 MODE 是 copy 进入复制安装分支
    install_copy_file "$SRC_ZSHENV" "$DST_ZSHENV"
    install_copy_dir "$SRC_ZSH_DIR" "$DST_ZSH_DIR"
  fi

  echo
  echo "Done."
  echo "Verify with:"
  echo "  echo \$ZDOTDIR"
  echo "  zsh -lic 'echo ZDOTDIR=\$ZDOTDIR'"
  # ^ 提示用户启动一个新的 login + interactive zsh 并输出它看到的 ZDOTDIR
  #
  #   参数解释
  #   -l
  #     以 login shell 启动 zsh 会读取 .zprofile 等登录阶段配置
  #   -i
  #     以 interactive shell 启动 会读取 .zshrc 等交互阶段配置
  #   -c '...'
  #     执行给定命令后退出
}
# ^ 结束 main 函数定义

main "$@"
# ^ 调用主函数 启动整个脚本
#
#   这里把 "$@" 传进去 虽然当前 main 并没有显式读取位置参数
#   但这样写有两个好处
#   1) 保持接口完整 后续如果想让 main 处理参数 不用改调用形式
#   2) 语义上表达 用当前脚本收到的原始参数启动主流程
