# AGENTS.md

> 本仓库目标是摆脱 oh-my-zsh, 但保留够用的交互体验, 同时把启动路径压到足够简单, 足够快, 足够可验证.

## 1. 角色与优先级

你在这个仓库里扮演工程协作者.

优先级固定如下.

1. 正确启动.
2. 性能可控.
3. 结构一致.
4. 配置清晰.
5. 可验证.

任何改动都应该附带.

- 改动文件列表.
- 改动原因.
- 验证命令.
- 判定标准.
- 风险点与回滚方式.

## 2. 总体边界

本项目不是.

- oh-my-zsh 兼容层.
- 插件市场.
- 大量 shell hack 的堆放目录.
- 通过一堆自动探测来猜用户需求的黑盒框架.

本项目是.

- 一套自维护, 轻量, 清晰的 zsh 配置框架.
- 为个人长期使用而设计, 但结构足够干净, 可以持续扩展.
- 默认偏保守, 按需开启增强能力.

## 3. 四层模型

整个仓库严格分成四层.

### 3.1 默认层
文件位置.

- `zsh/conf/defaults.zsh`

职责.

- 只定义项目默认值.
- 不写业务逻辑.
- 不调用外部命令.
- 不写 alias, function, bindkey.

### 3.2 声明层
文件位置.

- `zsh/user/config.zsh`

职责.

- 在 login 和 interactive 之前加载.
- 只放声明式配置.
- 例如 feature 列表, 主题名, 编辑模式, 模块参数.

### 3.3 实现层
文件位置.

- `zsh/core/*`
- `zsh/features/*`
- `zsh/themes/*`

职责.

- `core` 放基础设施.
- `features` 放功能实现.
- `themes` 放 prompt 主题.
- 不把用户主配置重新分散回实现文件.

### 3.4 脚本层
文件位置.

- `zsh/user/local.zsh`

职责.

- 只在 interactive 末尾加载.
- 允许 alias, function, bindkey, 临时代码.
- 不作为项目主配置入口.

## 4. 目录职责

```text
.
├── install.sh
├── test/
├── zshenv
└── zsh/
    ├── .zprofile
    ├── .zshrc
    ├── init.zsh
    ├── conf/
    ├── core/
    ├── features/
    ├── stage/
    ├── themes/
    └── user/
```

约束如下.

- `conf/` 只放默认值和示例.
- `core/` 只放基础设施.
- `features/` 统一放功能实现, 不再拆成 components 和 modules 两套模型.
- `stage/` 只做阶段调度.
- `user/` 只放用户入口.

## 5. 启动模型

### 5.1 zshenv
`zshenv` 只能设置 ZDOTDIR.

禁止.

- eval.
- source 复杂文件.
- 外部命令.
- PATH 重逻辑.
- compinit.
- 第三方工具初始化.

### 5.2 统一入口
`.zprofile` 和 `.zshrc` 只做两件事.

1. 设置阶段名.
2. source `init.zsh`.

### 5.3 init.zsh 职责
`init.zsh` 只允许做这些事.

1. 非 zsh 保护.
2. 建立目录变量.
3. 加载 `core/*`.
4. 做环境探测.
5. 加载 `conf/defaults.zsh`.
6. 加载 `user/config.zsh`.
7. 按阶段分发到 `stage/login.zsh` 或 `stage/interactive.zsh`.
8. 处理 bootstrap guard 和 stage guard.

禁止.

- 直接实现 history, completion, prompt.
- 直接写第三方工具逻辑.
- 直接加载 `user/local.zsh`.

### 5.4 feature 顺序
feature 列表顺序有意义.

- `ZSH_LOGIN_FEATURES` 的顺序就是 login 阶段执行顺序.
- `ZSH_INTERACTIVE_FEATURES` 的顺序就是 interactive 阶段执行顺序.

因此用户如果需要先 homebrew 再 completion, 只要把 homebrew 排在 completion 前面.

## 6. 测试要求

优先使用临时 HOME 做集成测试, 不污染真实环境.

推荐命令.

```bash
TMPHOME="$(mktemp -d)"

HOME="$TMPHOME" XDG_CONFIG_HOME="$TMPHOME/.config" ./install.sh --link --force

HOME="$TMPHOME" XDG_CONFIG_HOME="$TMPHOME/.config" zsh -lc 'echo login:$ZDOTDIR'

HOME="$TMPHOME" XDG_CONFIG_HOME="$TMPHOME/.config" zsh -ic 'echo interactive:$ZDOTDIR'
```

判定标准.

- 命令退出码为 0.
- `ZDOTDIR` 等于 `$XDG_CONFIG_HOME/zsh`.
- login 能看到 `user/config.zsh`.
- interactive 能看到 `user/local.zsh`.

## 7. 代码风格

- shell 目标是 zsh, 不要求 bash 兼容.
- 新增函数必须有职责说明.
- 重逻辑优先考虑 cache 或 lazy.
- 任何外部命令输出如果要 source, 必须保证来源可信.
- 中文注释必须清楚解释"为什么", 标点统一使用英文标点.
