# 10-path.zsh
# PATH 管理工具

# 不再到处手写 export PATH="xxx:$PATH"
# 统一通过函数增删 PATH
# 自动去重 避免路径越堆越乱

# 开启 path / PATH 自动唯一化
# typeset -U 的含义是 唯一化unique
# 对数组变量加上 -U 之后
# - 如果数组里出现重复元素 会自动去重
# - 通常保留第一次出现的位置

# 这里同时对 path 和 PATH 做声明
# - path 是数组
# - PATH 是与之绑定的标量字符串

# 这样后面只要操作 path, PATH 会自动同步
typeset -gU path PATH

# 判断某个目录是否已经在 path 数组里
# 返回值
# - 已存在 0
# - 不存在 1
path_contains() {
  local dir="$1"
  local item

  # 空参数直接视为 不存在
  [[ -n "$dir" ]] || return 1

  # 逐项遍历 path 数组做精确匹配
  # 这里不用通配符匹配 避免路径里有特殊字符时产生误判
  for item in "${path[@]}"; do
    [[ "$item" == "$dir" ]] && return 0
  done

  return 1
}

# 把目录加到 PATH 最前面
# 典型场景
# - 用户级 bin 优先于系统级 bin
# - 项目私有工具优先于全局工具
path_prepend() {
  local dir="$1"

  # 参数为空 直接跳过
  [[ -n "$dir" ]] || return 0

  # 不是目录就不加
  # 这样可以避免把无效路径塞进 PATH
  [[ -d "$dir" ]] || return 0

  # 把目录放到数组最前面
  # 因为 path/path 已启用 unique 若该目录本来已存在于后面
  # zsh 会自动去重 最终保留最前面的这一个
  path=("$dir" "${path[@]}")
}

# 把目录加到 PATH 最后面
# 典型场景
# - 系统默认目录兜底
# - 某些兼容性路径不希望抢优先级
path_append() {
  local dir="$1"

  # 空参数直接跳过
  [[ -n "$dir" ]] || return 0

  # 只有真实存在的目录才加入
  [[ -d "$dir" ]] || return 0

  # 加到数组尾部
  # 如果它已存在于前面 由于 unique 机制 前面的那个会被保留
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
