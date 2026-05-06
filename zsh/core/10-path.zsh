# 10-path.zsh
# PATH 管理工具

# 集中处理 PATH 追加和导出
# 统一通过函数增删 PATH
# 自动去重 避免路径越堆越乱

# 开启 path / PATH 自动唯一化
# typeset -U 开启数组唯一化
# 对数组变量加上 -U 之后
# 如果数组里出现重复元素 会自动去重
# 通常保留第一次出现的位置

# 同时声明 path 和 PATH
# path 是数组
# PATH 是与之绑定的标量字符串

# 后续操作 path 时 PATH 自动同步
typeset -gU path PATH

# 判断某个目录是否已经在 path 数组里
# 返回值
# 已存在 0
# 不存在 1
path_contains() {
  local dir="$1"
  local item

  # 空参数视为不存在
  [[ -n "$dir" ]] || return 1

  # 逐项遍历 path 数组做精确匹配
  # 精确匹配可避免路径特殊字符造成误判
  for item in "${path[@]}"; do
    [[ "$item" == "$dir" ]] && return 0
  done

  return 1
}

# 把目录加到 PATH 最前面
# 典型场景
# 用户级 bin 优先于系统级 bin
# 项目私有工具优先于全局工具
path_prepend() {
  local dir="$1"

  # 参数为空 直接跳过
  [[ -n "$dir" ]] || return 0

  # 跳过非目录
  # 避免把无效路径塞进 PATH
  [[ -d "$dir" ]] || return 0

  # 把目录放到数组最前面
  # path 和 PATH 已启用 unique 若该目录本来已存在于后面
  # zsh 会自动去重 最终保留最前面的这一个
  path=("$dir" "${path[@]}")
}

# 把目录加到 PATH 最后面
# 典型场景
# 系统默认目录兜底
# 某些兼容性路径不希望抢优先级
path_append() {
  local dir="$1"

  # 空参数直接跳过
  [[ -n "$dir" ]] || return 0

  # 只有真实存在的目录才加入
  [[ -d "$dir" ]] || return 0

  # 加到数组尾部
  # 已存在于前面时 unique 机制会保留前面的项
  path+=("$dir")
}

# 从 PATH 中移除某个目录
path_remove() {
  local dir="$1"
  local item
  local -a new_path

  # 空参数直接跳过
  [[ -n "$dir" ]] || return 0

  # 从空数组开始重建 path
  new_path=()

  # 遍历旧 path 把不等于目标目录的项保留下来
  for item in "${path[@]}"; do
    [[ "$item" == "$dir" ]] && continue
    new_path+=("$item")
  done

  # 用过滤后的数组替换原 path
  # PATH 会随之自动同步
  path=("${new_path[@]}")
}

# 显式触发一次 path 去重
path_dedup() {
  # 通过重新赋值当前数组 触发 zsh 的唯一化机制
  path=("${path[@]}")
}
