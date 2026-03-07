# oh-box-zsh

一个不依赖 oh-my-zsh 的 zsh 配置框架。

## 目标

- 分离 login / interactive 两个阶段
- 把基础库、组件、模块拆开
- 保持跨 macOS / Linux / Termux 可演进
- 允许后续接入 cache / lazy 机制优化启动

## 当前结构

- `zsh/local.zsh`：用户主配置入口，只在 interactive 阶段加载
- `zsh/local.zsh.example`：用户主配置示例
- `zsh/components/defaults.zsh`：项目默认配置中心
- `zsh/components/`：zsh 行为实现组件与模块加载器
- `zsh/modules/`：可选模块目录
- `zsh/lib/`：基础能力
- `zsh/stages/`：阶段调度
- `zsh/themes/`：主题实现

```text
.
├── install.sh
├── test-local-zsh.sh
├── zshenv
└── zsh/
    ├── .zprofile
    ├── .zshrc
    ├── init.zsh
    ├── local.zsh
    ├── local.zsh.example
    ├── components/
    │   ├── defaults.zsh
    │   ├── history.zsh
    │   ├── completion.zsh
    │   ├── keybinds.zsh
    │   ├── prompt.zsh
    │   ├── module-loader-common.zsh
    │   ├── module-loader-login.zsh
    │   └── module-loader-interactive.zsh
    ├── modules/
    ├── lib/
    ├── stages/
    └── themes/
```

## 启动顺序

```text
zshenv
  -> ZDOTDIR
  -> init.zsh
  -> lib/*
  -> components/defaults.zsh
  -> stages/login.zsh or stages/interactive.zsh

interactive 阶段内部：
  -> local.zsh (optional)
  -> components/history.zsh
  -> components/completion.zsh
  -> components/keybinds.zsh
  -> components/prompt.zsh
  -> components/module-loader-interactive.zsh
```

关键语义：

- `defaults.zsh` 是项目默认配置
- `local.zsh` 是用户主配置入口
- `login` 不读取 `local.zsh`
- `interactive` 才读取 `local.zsh`

## 安装

### link 模式

```bash
./install.sh --link --force
```

### copy 模式

```bash
./install.sh --copy --force
```

## 验证

```bash
chmod +x ./test-local-zsh.sh
./test-local-zsh.sh
```

## 本地私有文件

以下文件默认不进版本控制：

- `zsh/local.zsh`
