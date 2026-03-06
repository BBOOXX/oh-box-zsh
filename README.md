# oh-box-zsh

从 0 开始构建的 zsh 配置框架，不依赖 oh-my-zsh。

## 现在的使用方式

平时优先只改一个文件：

- `zsh/config.zsh`：主配置入口

可选覆盖：

- `zsh/config.local.zsh`：本机私有覆盖，不进版本控制
- `zsh/local.zsh`：最后加载的任意自定义代码入口

内部实现目录默认不需要日常编辑：

- `zsh/conf/`：zsh 行为实现与内部默认值
- `zsh/modules/`：外部工具模块
- `zsh/lib/`：基础能力
- `zsh/stages/`：启动阶段调度

## 目录结构

```text
zsh/
├── config.zsh
├── config.local.zsh
├── init.zsh
├── .zprofile
├── .zshrc
├── conf/
│   ├── defaults.zsh
│   ├── history.zsh
│   ├── completion.zsh
│   ├── keybinds.zsh
│   ├── prompt.zsh
│   ├── modules-common.zsh
│   ├── modules-login.zsh
│   └── modules-interactive.zsh
├── modules/
├── lib/
├── stages/
├── themes/
└── local.zsh
````

## 启动顺序

```text
zshenv
  -> ZDOTDIR
  -> init.zsh
  -> lib/*
  -> conf/defaults.zsh
  -> config.zsh
  -> config.local.zsh (optional)
  -> stages/login.zsh or stages/interactive.zsh
  -> local.zsh (optional)
```

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

* `zsh/config.local.zsh`
* `zsh/local.zsh`

