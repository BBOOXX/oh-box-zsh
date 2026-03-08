# 30-cache.zsh
# 命令输出缓存工具

# 把外部命令输出的 shell 片段缓存到文件
# 后续启动时优先复用缓存文件
# 需要时再按 TTL 重建缓存

# 它主要服务这类场景
# - brew shellenv
# - 其他会输出 shell 代码 且输出内容在短时间内相对稳定的命令

# 这一层当前只做缓存 shell 片段并 source
# 先不做更复杂的泛用缓存 例如 JSON / 二进制 / 多级缓存

# --------------------------------------------------
# 默认 TTL 秒
# --------------------------------------------------

# ZSH_CACHE_DEFAULT_TTL 用来定义默认缓存有效期 单位是秒
# 如果调用 zcache_source_cmd 时没有显式传 TTL 就会使用它

# 默认值设为 86400 也就是 24 小时
# 这个值是一个偏保守的工程默认值
# - 不会每次都重跑外部命令
# - 也不会无限期不刷新

# 当然 具体模块 例如 brew 可以按自己的需求覆盖 TTL
typeset -gi ZSH_CACHE_DEFAULT_TTL="${ZSH_CACHE_DEFAULT_TTL:-86400}"

# --------------------------------------------------
#  缓存文件目录
# --------------------------------------------------

# 这里单独定义一个shell 片段缓存目录放在
#   $ZSH_CACHE_DIR/snippets
typeset -g ZSH_CACHE_SNIPPET_DIR="${ZSH_CACHE_SNIPPET_DIR:-$ZSH_CACHE_DIR/snippets}"

# 确保缓存目录存在
zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

# --------------------------------------------------
# zcache_sanitize_key
# --------------------------------------------------
# 把用户传入的 cache_key 规范化为适合做文件名的安全字符串

# cache_key 可能包含空格斜杠冒号等不适合作为文件名的字符
# 例如
# - "brew-shellenv"        -> "brew-shellenv"
# - "homebrew/shellenv"    -> "homebrew_shellenv"
# - "pyenv init:zsh"       -> "pyenv_init_zsh"
zcache_sanitize_key() {
  # 取第一个参数作为原始 key
  local raw_key="$1"

  # 定义本地变量 用来存放规范化后的 key
  local safe_key

  # 如果调用方传了空 key 我们不让结果也为空
  # 这样可以避免后面生成出奇怪的路径 例如只剩 .zsh
  if [[ -z "$raw_key" ]]; then
    REPLY="default"
    return 0
  fi

  # 把所有不在白名单里的字符替换成下划线
  # 白名单保留
  # - 英文字母
  # - 数字
  # - 点号 .
  # - 下划线 _
  # - 连字符 -
  safe_key="${raw_key//[^[:alnum:]_.-]/_}"

  # 极端情况下如果替换后变成空字符串也给一个保底值
  [[ -n "$safe_key" ]] || safe_key="default"

  # 通过 REPLY 返回结果
  REPLY="$safe_key"
}

# --------------------------------------------------
# zcache_path
# --------------------------------------------------
# 根据 cache_key 计算对应的缓存文件路径

# 例如
# cache_key = "brew-shellenv"
# 则可能得到
#   ~/.cache/zsh/snippets/brew-shellenv.zsh
zcache_path() {
  # 取原始 key
  local cache_key="$1"

  # 定义本地变量用来接收规范化后的 key
  local safe_key

  # 先把 key 规范化成安全文件名
  zcache_sanitize_key "$cache_key"
  safe_key="$REPLY"

  # 拼接成最终缓存文件路径并通过 REPLY 返回
  REPLY="$ZSH_CACHE_SNIPPET_DIR/${safe_key}.zsh"
}

# --------------------------------------------------
# zcache_get_mtime
# --------------------------------------------------
# 获取某个缓存文件的"最后修改时间Unix 时间戳"

# - 成功 把 mtime 写入 REPLY 返回 0
# - 失败 返回 1

zcache_get_mtime() {
  # 取第一个参数作为文件路径
  local file="$1"

  # 用于存放最后读到的 mtime 值
  local mtime

  # 文件不可读 直接失败
  [[ -r "$file" ]] || return 1

  # 先尝试 GNU stat
  #   stat -c %Y <file>
  # 会输出文件的 mtime 秒级 Unix 时间戳
  mtime="$(stat -c %Y "$file" 2>/dev/null)" || mtime=""

  # 如果拿到了纯数字 就认为成功
  if [[ "$mtime" == <-> ]]; then
    REPLY="$mtime"
    return 0
  fi

  # 如果 GNU stat 不可用 再尝试 BSD stat macOS 常见
  #   stat -f %m <file>
  mtime="$(stat -f %m "$file" 2>/dev/null)" || mtime=""

  # 如果这里拿到了纯数字 也认为成功
  if [[ "$mtime" == <-> ]]; then
    REPLY="$mtime"
    return 0
  fi

  # 两种方式都失败则返回失败
  return 1
}

# --------------------------------------------------
# zcache_is_fresh
# --------------------------------------------------
# 判断某个缓存文件是否仍然足够新鲜

# - $1: 文件路径
# - $2: TTL 秒 可省略 省略时使用默认 TTL

# 返回值
# - 新鲜 0
# - 过期 / 不存在 / 无法判断 1

# 这里定义一个重要语义
# - TTL > 0 按 当前时间 - mtime <= TTL 判断
# - TTL = 0 只要文件存在,就视为永不过期

# TTL=0 的好处
# 对某些极少变化的命令 例如某些 shellenv 输出 非常实用
# 如果想强制刷新 直接删掉对应缓存文件即可
zcache_is_fresh() {
  # 取文件路径
  local file="$1"

  # 取 TTL 如果没传 就用默认值
  local ttl="${2:-$ZSH_CACHE_DEFAULT_TTL}"

  # 用于接收 mtime
  local mtime

  # 用于接收 当前时间戳
  local now

  # 用于表示缓存文件年龄 秒
  local age

  # 文件不可读 直接视为不新鲜
  [[ -r "$file" ]] || return 1

  # 如果 TTL 不是纯数字 回退到默认 TTL
  [[ "$ttl" == <-> ]] || ttl="$ZSH_CACHE_DEFAULT_TTL"

  # TTL = 0 的特殊语义
  # 只要文件存在 就视为新鲜
  if (( ttl == 0 )); then
    return 0
  fi

  # 读不到 mtime 则保守起见 视为不新鲜
  zcache_get_mtime "$file" || return 1
  mtime="$REPLY"

  # 获取当前时间戳
  now="$(date +%s 2>/dev/null)" || return 1

  # 拿不到纯数字时间戳 也保守地视为不新鲜
  [[ "$now" == <-> ]] || return 1

  # 计算缓存年龄 当前时间 - 文件修改时间
  age=$(( now - mtime ))

  # 如果出现时钟回拨或奇怪时间 导致 age 为负
  # 这里把它钳制到 0 避免比较逻辑异常
  if (( age < 0 )); then
    age=0
  fi

  # 年龄小于等于 TTL 则认为新鲜
  (( age <= ttl ))
}

# --------------------------------------------------
# zcache_invalidate
# --------------------------------------------------
# 主动删除某个 cache_key 对应的缓存文件

# 典型场景
# - 升级了 brew 希望立刻重建 shellenv 缓存
# - 修改了某模块的初始化逻辑 想强制刷新

# 返回值
# - 删除成功或文件本来就不存在 0
# - 删除失败 非 0
zcache_invalidate() {
  # 取 cache_key
  local cache_key="$1"

  # 用于接收缓存文件路径
  local cache_file

  # 先算出缓存文件路径
  zcache_path "$cache_key"
  cache_file="$REPLY"

  # 如果文件不存在 直接视为成功
  [[ -e "$cache_file" || -L "$cache_file" ]] || return 0

  # 删除缓存文件
  rm -f "$cache_file"
}

# --------------------------------------------------
# zcache_ensure_cmd
# --------------------------------------------------
# 确保某个命令输出已经被缓存到文件中
# 如果缓存不存在或已过期 就重新执行命令并重建缓存

# 它本身不 source 只负责 确保缓存文件存在且可用

# 参数格式
#   zcache_ensure_cmd <cache_key> [ttl_seconds] -- <command...>

# 示例
#   zcache_ensure_cmd "brew-shellenv" 86400 -- "$brew_bin" shellenv

# 返回方式
# - 成功 把缓存文件路径写入 REPLY 返回 0
# - 失败 返回命令失败码或 2 参数错误
zcache_ensure_cmd() {
  # 第一个参数必须是 cache_key
  local cache_key="$1"

  # 默认 TTL
  local ttl="$ZSH_CACHE_DEFAULT_TTL"

  # 最终缓存文件路径
  local cache_file

  # 临时文件路径
  # 先写临时文件 再 mv 覆盖正式文件 避免写到一半时留下残缺缓存
  local tmp_file

  # 用于保存命令或 mv 的退出码
  local rc

  # 如果第一个参数为空 说明调用格式不对
  if [[ -z "$cache_key" ]]; then
    print -r -- "[zcache] missing cache key" >&2
    return 2
  fi

  # 把已消费的第一个参数移掉
  shift

  # 解析可选 TTL
  # - 如果下一个参数不是 -- 就把它当作 TTL
  # - 如果下一个参数是 -- 说明调用方省略了 TTL 直接用默认值
  if [[ "${1:-}" != "--" ]]; then
    ttl="${1:-$ZSH_CACHE_DEFAULT_TTL}"
    shift
  fi

  # 现在下一个参数必须是分隔符 --
  # 这是为了明确区分 缓存参数 和 真正要执行的命令
  if [[ "${1:-}" != "--" ]]; then
    print -r -- "[zcache] usage: zcache_ensure_cmd <cache_key> [ttl_seconds] -- <command...>" >&2
    return 2
  fi

  # 跳过 --
  shift

  # -- 后面必须至少还有一个命令参数
  if (( $# == 0 )); then
    print -r -- "[zcache] missing command after --" >&2
    return 2
  fi

  # 计算缓存文件路径
  zcache_path "$cache_key"
  cache_file="$REPLY"

  # 如果缓存仍然新鲜 直接返回缓存文件路径 不重建
  if zcache_is_fresh "$cache_file" "$ttl"; then
    REPLY="$cache_file"
    return 0
  fi

  # 确保缓存目录存在
  zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

  # 构造临时文件路径
  # 加上当前 shell 的 PID 避免同一时刻多个 shell 冲突写同一个临时文件名
  tmp_file="${cache_file}.tmp.$$"

  # 输出调试日志 默认关闭
  zsh_log_debug "refresh cache: key=$cache_key ttl=$ttl file=$cache_file"

  # 执行真正的命令 把标准输出写入临时文件
  # 这里用 `>|` 而不是 `>` 目的是即使用户开了 noclobber
  # 也允许我们明确覆盖临时文件
  # 这个命令的输出 预期应该是 可被 source 的 shell 代码
  if "$@" >| "$tmp_file"; then
    :
  else
    rc=$?

    # 如果命令失败 清理临时文件 避免留下脏文件
    rm -f "$tmp_file" 2>/dev/null

    # 输出错误信息到 stderr
    print -r -- "[zcache] command failed while rebuilding cache: $cache_key" >&2

    # 把原始失败码返回给调用方 便于上层判断
    return "$rc"
  fi

  # 使用 mv 原子替换正式缓存文件
  # 这样如果 shell 中途被打断 正式缓存文件也更不容易处于半写入状态
  if mv "$tmp_file" "$cache_file"; then
    :
  else
    rc=$?

    # 如果 mv 失败 同样清理临时文件
    rm -f "$tmp_file" 2>/dev/null

    # 输出错误信息
    print -r -- "[zcache] failed to move temp cache file into place: $cache_file" >&2

    # 返回 mv 的失败码
    return "$rc"
  fi

  # 成功后 通过 REPLY 返回正式缓存文件路径
  REPLY="$cache_file"
  return 0
}

# --------------------------------------------------
# zcache_source_cmd
# --------------------------------------------------
# 这是给调用方直接使用的高层入口函数

# - 调用 zcache_ensure_cmd 确保缓存文件存在且可用
# - 然后 source 那个缓存文件

# 参数格式
#   zcache_source_cmd <cache_key> [ttl_seconds] -- <command...>

# 典型用途
#   zcache_source_cmd "brew-shellenv" 86400 -- "$brew_bin" shellenv

# 注意
# 这里会 source 缓存文件 所以它只应该用于可信命令输出
# 不要把不可信来源的文本拿来缓存并 source
zcache_source_cmd() {
  # 先确保缓存文件存在且可用
  zcache_ensure_cmd "$@" || return $?

  # 接收缓存文件路径
  local cache_file="$REPLY"

  # 再次做一个可读检查
  if [[ ! -r "$cache_file" ]]; then
    print -r -- "[zcache] cache file is not readable: $cache_file" >&2
    return 1
  fi

  # 在当前 shell 中 source 缓存文件
  # 必须 source 而不是开子进程执行 否则环境变量/PATH 变更不会回到当前 shell
  source "$cache_file"
}
