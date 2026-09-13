---
name: istoreos-mise-runtime
description: 在 iStoreOS 上检查、安装和验证 Python、Node.js 或 Go 运行环境；使用系统集成的 mise 存储目录与下载加速配置。
owner: system-pack/istoreos
systems: istoreos
triggers: 安装 Python, 安装 Node.js, 安装 node, 安装 Go, 安装 golang, Python 版本, Node.js 版本, Go 版本, 开发环境, 运行环境
negative-triggers: 安装 OpenWrt 软件包, 安装 Docker, 编译 KaiPlus
auto-use: prefer
routing-group: istoreos-primary
needs-fresh-data: true
cost: medium
---

# iStoreOS Runtime Environment

Use this skill only for Python, Node.js and Go runtimes on iStoreOS. The supported entrypoint is `mise-istore`; it applies the device's persistent runtime directory and any configured iStoreEnhance/KSpeeder acceleration.

## Workflow

1. Run `scripts/check.sh [python|node|go|all]` to check architecture, disk space, runtime directory, mise availability and installed versions.
2. If `mise-istore` is missing, route installation of the iStore mise package through the package manager skill. Do not install upstream mise with curl.
3. Resolve the runtime and version with the user. For Node.js, use `lts` only when the user has no version preference; do not silently change a requested version.
4. Explain that installation downloads files and writes under the configured runtime directory, then obtain explicit confirmation.
5. Run `KAIPLUS_CONFIRMED=1 scripts/install.sh <python|node|go> <version>` and verify the executable and reported version.

If the runtime directory is on overlay or available space is low, stop and recommend moving it to persistent storage before installation. For download failures, use the download-acceleration skill rather than bypassing certificate checks or replacing the system integration.
