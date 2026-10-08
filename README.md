# LinkEase Device Skills

让 AI 安全维护 iStoreOS、ASUSWRT、Windows、macOS 和常见 Linux 设备。仓库按用户最自然的两个问题组织：**是什么设备**，以及 **AI 在设备上运行还是从别处远程控制**。

## 直接告诉 AI

把仓库 URL 和下面一句话发给 Codex、OpenCode 或其他支持 Skills 的 Agent：

```text
请从 https://github.com/linkease/linkease-skills 安装适合“远程控制 iStoreOS”的 skills。
只选择一个匹配的 preset，先 dry-run 告诉我将安装什么，不要安装全部系统。
```

如果 AI 就运行在 iStoreOS 设备上，把引号里的内容改为“在 iStoreOS 上使用”。

## 按设备选择

### iStoreOS

- [`platforms/istoreos/on-device`](platforms/istoreos/on-device)：AI 已经在 iStoreOS 设备上运行。
- [`platforms/istoreos/remote-control`](platforms/istoreos/remote-control)：AI 在电脑或另一台主机上，通过 SSH/LuCI 控制 iStoreOS。

每个目录都是自包含安装预设。不要从 `components/` 安装；那里是维护者使用的唯一源码。

### Windows

- [`platforms/windows/on-device`](platforms/windows/on-device)：AI 在 Windows 的 PowerShell 环境运行。
- [`platforms/windows/remote-control`](platforms/windows/remote-control)：AI 通过 Windows OpenSSH + PowerShell 远程控制。

### macOS

- [`platforms/macos/on-device`](platforms/macos/on-device)：AI 直接在 Mac 上运行。
- [`platforms/macos/remote-control`](platforms/macos/remote-control)：AI 在其他设备上，通过 SSH 控制 Mac。

## 安装器

先查看可用预设：

```sh
sh install.sh --list
sh install.sh --list --json
sh install.sh --describe istoreos-remote-control
```

预演并安装到 Codex：

```sh
sh install.sh --platform istoreos --mode remote-control --consumer codex --dry-run
sh install.sh --platform istoreos --mode remote-control --consumer codex
```

安装到 OpenCode 或明确目录：

```sh
sh install.sh --platform istoreos --mode remote-control --consumer opencode --dry-run
sh install.sh --platform istoreos --mode on-device --consumer generic \
  --target-skills /path/to/agent/skills --dry-run
```

Reasonix 的通用 Skill Store 通过自定义 skills 搜索目录消费相同预设：使用 `--consumer generic --target-skills DIR`，先 dry-run，再将该目录加入 Reasonix 配置的 `[skills].paths`（loader 中的 CustomPaths）。也可选择它实际扫描的项目 `.reasonix/skills` 或 `.agents/skills` 目录。按 Agent 是否在目标设备上运行选择 on-device 或 remote-control；不要把 Ubuntu 控制端当成 iStoreOS 目标系统。仓库的实际 Reasonix loader 测试覆盖两个模式的描述、触发词、系统路由元数据和辅助脚本发现。

Kai 内置的 vendored System Pack/source lock 属于另一条同步流程，本次不会自动替换其快照。iStoreOS 的运行时和依赖合约见 [`docs/architecture/runtime-download-contract.md`](docs/architecture/runtime-download-contract.md)；其他系统继续遵循各自技能。

安装器从不默认安装所有平台。若设备或使用方式不明确，它只会要求补充缺少的那一项。

## Kai 与第三方 Agent 的区别

`platforms/*/remote-control` 只服务于自身没有 Target Transport 的第三方 Agent。Kai 已经绑定并探测设备时，会直接选择 `components/system-packs` 中的 canonical 系统包，并使用 Kai 自身的 Transport；即使设备通过 SSH 添加，也不会加载第三方 remote-control preset。

公开架构见 [LinkEase Skills 最终架构](https://github.com/linkease/reasonix-kai/blob/main/docs/kaiplus/LINKEASE_SKILLS_FINAL_ARCHITECTURE.zh-CN.md)。Kai 的 Target、Transport 和会话隔离内部设计保留在 Kai 项目文档中。

## 维护与发布

修改 `components/` 后运行：

```sh
sh tools/generate-platforms.sh
sh tools/verify-generated.sh
sh tools/build-release.sh release
```

每个 release 同时提供 `.tar.gz`、`.zip` 和带 SHA-256/source commit/tree digest 的清单。安装器使用原子目录交换，并在 `.linkease-skills/` 记录所有权；升级或卸载前若发现用户修改，会停止并保留原内容。完整流程见 [`docs/RELEASING.md`](docs/RELEASING.md)。

旧 `--profile istoreos` 与 `--profile remote-control-istoreos` 命令在迁移期仍可使用，但会输出迁移提示。
