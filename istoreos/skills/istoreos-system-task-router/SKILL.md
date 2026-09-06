---
name: istoreos-system-task-router
description: iStoreOS 用户任务分流入口；把应用安装、Docker、下载加速、磁盘空间、服务异常、LuCI 故障、日志诊断和备份恢复分配给对应闭环 skill。
---

# iStoreOS System Task Router

Use this skill when the user describes an iStoreOS problem in product language and the exact subsystem is not yet clear.

## First Split

1. "安装/卸载/升级/找软件/应用商店" -> `istoreos-package-manager`.
2. "Docker/容器/镜像/compose/拉取/构建" -> `istoreos-docker-basics`, then `istoreos-download-acceleration` before pull-like actions.
3. "GitHub/GitLab/HuggingFace/下载链接/文件下载慢" -> `istoreos-download-acceleration`.
4. "磁盘满/overlay 满/数据目录/装到硬盘/迁移目录" -> `istoreos-storage-path`; Docker data-root migration routes to `istoreos-docker-data-root-migrate`.
5. "服务打不开/端口不通/启动失败/开机自启" -> `istoreos-service-manager` plus `istoreos-logs-and-diagnostics`.
6. "LuCI/网页管理/登录循环/500/空白页" -> `istoreos-luci-recovery`.
7. "不知道配置字段/不确定脚本行为/要改配置" -> `istoreos-source-introspect` first.
8. "恢复/重置/升级/危险修改/迁移前" -> `istoreos-backup-restore` first.

## Operating Contract

- Start with read-only evidence when the subsystem is unclear.
- Do not expose skill names as choices unless the user asks for implementation details.
- Before a dangerous action, state the command class, target config/service/path, expected effect, rollback or backup path, then ask for confirmation.
- After every write, run a read-only verification step and report the result.

## Minimum Evidence Set

Collect only what is needed for the selected branch:

- System: `/etc/openwrt_release`, `ubus call system board`.
- Storage: `df -h`, `df -i`, `mount`.
- Packages: `command -v is-opkg`, `command -v opkg`, `opkg print-architecture`.
- Docker: `docker version`, `/etc/init.d/dockerd status`, `uci -q show dockerd`.
- KSpeeder: `uci -q show istoreenhance`, `/etc/init.d/istoreenhance status`.
- Logs: `logread | tail -n 200` and service-specific filters when needed.
