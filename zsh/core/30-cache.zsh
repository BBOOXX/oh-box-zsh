# 30-cache.zsh
# 命令输出缓存工具

# 把外部命令输出的 shell 片段缓存到文件
# 后续启动时优先复用缓存文件
# 需要时再按 TTL 重建缓存

# 适用场景
# 某些工具的 shellenv 输出
# 其他会输出 shell 代码 且输出内容在短时间内相对稳定的命令

# ZSH_CACHE_DEFAULT_TTL 用来定义默认缓存有效期 单位是秒
# zcache_source_cmd 未显式传 TTL 时使用 ZSH_CACHE_DEFAULT_TTL

# 默认 TTL 为 86400 秒
# 平衡启动成本和缓存刷新
# feature 可以按需求覆盖 TTL
typeset -gi ZSH_CACHE_DEFAULT_TTL="${ZSH_CACHE_DEFAULT_TTL:-86400}"
typeset -gi ZSH_CACHE_MAX_KEY_LEN="${ZSH_CACHE_MAX_KEY_LEN:-120}"

# 缓存文件目录
# shell 片段缓存放在 $ZSH_CACHE_DIR/snippets
typeset -g ZSH_CACHE_SNIPPET_DIR="${ZSH_CACHE_SNIPPET_DIR:-$ZSH_CACHE_DIR/snippets}"

# 确保缓存目录存在
zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

# 兼容旧调用点
# 保留旧函数名 兼容已有调用点
zcache_now() {
  zsh_now_seconds
}

# 把用户传入的 cache_key 规范化为适合做文件名的安全字符串
# cache_key 可能包含无法稳定映射为文件名的字符
# 示例 tool-shellenv 保持 tool-shellenv
# 示例 tool/shellenv 变为 tool_shellenv
# 示例 runtime init:zsh 变为 runtime_init_zsh
zcache_sanitize_key() {
  # 取第一个参数作为原始 key
  local raw_key="$1"

  # 定义本地变量 用来存放规范化后的 key
  local safe_key

  # 空 key 统一映射到 default
  if [[ -z "$raw_key" ]]; then
    REPLY="default"
    return 0
  fi

  # 把白名单外字符替换成下划线
  # 白名单保留
  # 英文字母
  # 数字
  # 点号
  # 下划线 _
  # 连字符 -
  safe_key="${raw_key//[^[:alnum:]_.-]/_}"

  # 极端情况下如果替换后变成空字符串也给一个保底值
  [[ -n "$safe_key" ]] || safe_key="default"

  # 通过 REPLY 返回结果
  REPLY="$safe_key"
}

# 对过长的安全 key 做二次压缩
# 保留可读前缀并避免触碰文件名长度上限
zcache_compact_key() {
  local safe_key="$1"
  local max_len="${ZSH_CACHE_MAX_KEY_LEN:-120}"
  local digest=''
  local prefix=''
  local suffix=''

  [[ -n "$safe_key" ]] || safe_key="default"
  [[ "$max_len" == <-> ]] || max_len=120
  (( max_len > 32 )) || max_len=120

  if (( ${#safe_key} <= max_len )); then
    REPLY="$safe_key"
    return 0
  fi

  digest="$(printf '%s' "$safe_key" | cksum 2>/dev/null)" || digest=""
  digest="${digest%% *}"
  [[ -n "$digest" ]] || digest="${#safe_key}"

  prefix="${safe_key[1,40]}"
  suffix="${safe_key[-16,-1]}"
  REPLY="${prefix}_${digest}_${suffix}"
}

# 根据 cache_key 计算对应的缓存文件路径
# 示例 cache_key 为 tool-shellenv
# 可能得到
#   ~/.cache/zsh/snippets/tool-shellenv.zsh
zcache_path() {
  # 取原始 key
  local cache_key="$1"

  # 定义本地变量用来接收规范化后的 key
  local safe_key

  # 先把 key 规范化成安全文件名
  zcache_sanitize_key "$cache_key"
  safe_key="$REPLY"

  # 再把可能过长的 key 压缩到更稳妥的文件名长度
  zcache_compact_key "$safe_key"
  safe_key="$REPLY"

  # 拼接成最终缓存文件路径并通过 REPLY 返回
  REPLY="$ZSH_CACHE_SNIPPET_DIR/${safe_key}.zsh"
}

# 获取某个缓存文件的最后修改时间 Unix 时间戳
# 成功 把 mtime 写入 REPLY 返回 0
# 失败 返回 1

zcache_get_mtime() {
  zsh_file_mtime "$1"
}

# 判断某个缓存文件是否仍然足够新鲜
# $1 文件路径
# $2 TTL 秒 可省略 省略时使用默认 TTL
# 返回值
# 新鲜 0
# 过期 / 不存在 / 无法判断 1

# freshness 语义
# TTL 大于 0 时按当前时间减 mtime 小于等于 TTL 判断
# TTL 为 0 时只要文件存在就视为永不过期

# TTL 为 0 适合极少变化的命令输出
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
  if [[ ! -r "$file" ]]; then
    zsh_log_debug "zcache: fresh-check return=1 reason=unreadable file=$file"
    return 1
  fi

  # TTL 非纯数字时回退到默认 TTL
  if [[ "$ttl" != <-> ]]; then
    zsh_log_debug "zcache: fresh-check invalid-ttl ttl=$ttl fallback=$ZSH_CACHE_DEFAULT_TTL file=$file"
    ttl="$ZSH_CACHE_DEFAULT_TTL"
  fi

  # TTL 为 0 的特殊语义
  # 只要文件存在 就视为新鲜
  if (( ttl == 0 )); then
    zsh_log_debug "zcache: fresh-check return=0 reason=ttl-zero file=$file"
    return 0
  fi

  # 读不到 mtime 则保守起见 视为不新鲜
  if ! zcache_get_mtime "$file"; then
    zsh_log_debug "zcache: fresh-check return=1 reason=mtime-unavailable file=$file"
    return 1
  fi
  mtime="$REPLY"

  # 获取当前时间戳
  # 命中 builtin 路径时可以减少启动阶段的外部进程数
  if ! zcache_now; then
    zsh_log_debug "zcache: fresh-check return=1 reason=clock-unavailable file=$file"
    return 1
  fi
  now="$REPLY"

  # 计算缓存年龄 当前时间 - 文件修改时间
  age=$(( now - mtime ))

  # 时钟回拨可能导致 age 为负
  # 钳制到 0 避免比较逻辑异常
  if (( age < 0 )); then
    age=0
  fi

  # 年龄小于等于 TTL 则认为新鲜
  if (( age <= ttl )); then
    zsh_log_debug "zcache: fresh-check return=0 age=$age ttl=$ttl file=$file"
    return 0
  fi

  zsh_log_debug "zcache: fresh-check return=1 age=$age ttl=$ttl file=$file"
  return 1
}

# 主动删除某个 cache_key 对应的缓存文件
# 典型场景
# 升级了 brew 希望立刻重建 shellenv 缓存
# 修改了某模块的初始化逻辑 想强制刷新

# 返回值
# 删除成功或文件本来就不存在 0
# 删除失败 非 0
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

# 确保某个命令输出已经被缓存到文件中
# 如果缓存不存在或已过期 就重新执行命令并重建缓存
# 只确保缓存文件存在且可用
# 参数格式
#   zcache_ensure_cmd <cache_key> [ttl_seconds] -- <command...>
# 示例
#   zcache_ensure_cmd "brew-shellenv" 86400 -- "$brew_bin" shellenv
# 返回方式
# 成功 把缓存文件路径写入 REPLY 返回 0
# 失败 返回命令失败码或 2 参数错误
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
    zsh_msg warn zcache "missing cache key"
    return 2
  fi

  # 把已消费的第一个参数移掉
  shift

  # 如果后面已经没有参数了 说明调用方至少漏掉了 --
  if (( $# == 0 )); then
    zsh_msg warn zcache "usage: zcache_ensure_cmd <cache_key> [ttl_seconds] -- <command...>"
    return 2
  fi

  # 解析可选 TTL
  # 下一个参数非 -- 时当作 TTL
  # 如果下一个参数是 -- 说明调用方省略了 TTL 直接用默认值
  if [[ "$1" != "--" ]]; then
    ttl="$1"
    shift
  fi

  # 现在下一个参数必须是分隔符 --
  # 区分缓存参数和真正要执行的命令
  if (( $# == 0 )) || [[ "$1" != "--" ]]; then
    zsh_msg warn zcache "usage: zcache_ensure_cmd <cache_key> [ttl_seconds] -- <command...>"
    return 2
  fi

  # 跳过 --
  shift

  # -- 后面必须至少还有一个命令参数
  if (( $# == 0 )); then
    zsh_msg warn zcache "missing command after --"
    return 2
  fi

  # 计算缓存文件路径
  zcache_path "$cache_key"
  cache_file="$REPLY"

  zsh_log_debug "zcache: ensure start key=$cache_key ttl=$ttl file=$cache_file"

  # 如果缓存仍然新鲜 直接返回缓存文件路径 不重建
  if zcache_is_fresh "$cache_file" "$ttl"; then
    zsh_log_debug "zcache: ensure cache-hit key=$cache_key file=$cache_file"
    REPLY="$cache_file"
    return 0
  fi

  zsh_log_debug "zcache: ensure cache-miss key=$cache_key file=$cache_file"

  # 确保缓存目录存在
  zsh_ensure_dir "$ZSH_CACHE_SNIPPET_DIR"

  # 构造临时文件路径
  # 加上当前 shell 的 PID 避免同一时刻多个 shell 冲突写同一个临时文件名
  tmp_file="${cache_file}.tmp.$$"

  # 输出调试日志 默认关闭
  zsh_log_debug "refresh cache: key=$cache_key ttl=$ttl file=$cache_file"

  # 执行真正的命令 把标准输出写入临时文件
  # >| 明确覆盖 noclobber
  # 也允许我们明确覆盖临时文件
  # 命令输出必须是可 source 的 shell 代码
  if "$@" >| "$tmp_file"; then
    zsh_log_debug "zcache: ensure command-ok key=$cache_key tmp=$tmp_file"
    :
  else
    rc=$?

    # 如果命令失败 清理临时文件 避免留下脏文件
    rm -f "$tmp_file" 2>/dev/null

    # 输出错误信息到 stderr
    zsh_msg warn zcache "command failed while rebuilding cache: $cache_key"
    zsh_log_debug "zcache: ensure return=$rc reason=command-failed key=$cache_key"

    # 把原始失败码返回给调用方 便于上层判断
    return "$rc"
  fi

  # 使用 mv 原子替换正式缓存文件
  # shell 中途被打断时正式缓存文件仍保持完整
  if mv "$tmp_file" "$cache_file"; then
    zsh_log_debug "zcache: ensure refresh-done key=$cache_key file=$cache_file"
    :
  else
    rc=$?

    # 如果 mv 失败 同样清理临时文件
    rm -f "$tmp_file" 2>/dev/null

    # 输出错误信息
    zsh_msg warn zcache "failed to move temp cache file into place: $cache_file"
    zsh_log_debug "zcache: ensure return=$rc reason=move-failed key=$cache_key file=$cache_file"

    # 返回 mv 的失败码
    return "$rc"
  fi

  # 成功后 通过 REPLY 返回正式缓存文件路径
  REPLY="$cache_file"
  zsh_log_debug "zcache: ensure return=0 key=$cache_key file=$cache_file"
  return 0
}


# 调用 zcache_ensure_cmd 确保缓存文件存在且可用
# 然后 source 那个缓存文件
# 参数格式
#   zcache_source_cmd <cache_key> [ttl_seconds] -- <command...>
# 典型用途
#   zcache_source_cmd "brew-shellenv" 86400 -- "$brew_bin" shellenv
# 只用于可信命令输出
zcache_source_cmd() {
  # 先确保缓存文件存在且可用
  local rc

  zcache_ensure_cmd "$@"
  rc=$?
  if (( rc != 0 )); then
    zsh_log_debug "zcache: source return=$rc reason=ensure-failed"
    return "$rc"
  fi

  # 接收缓存文件路径
  local cache_file="$REPLY"

  # 再次做一个可读检查
  if [[ ! -r "$cache_file" ]]; then
    zsh_msg warn zcache "cache file is not readable: $cache_file"
    zsh_log_debug "zcache: source return=1 reason=unreadable file=$cache_file"
    return 1
  fi

  # 在当前 shell 中 source 缓存文件
  # source 让环境变量和 PATH 变更回到当前 shell
  zsh_log_debug "zcache: source file=$cache_file"
  source "$cache_file"
  rc=$?
  zsh_log_debug "zcache: source return=$rc file=$cache_file"
  return "$rc"
}
