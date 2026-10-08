# iStoreOS Task Routing

Select one primary skill; load at most one evidence-required helper. Other targets (including Ubuntu) use their own System Pack; do not apply iStore UCI/mise-exec rules there.

| User task | Primary | Helper if needed |
| --- | --- | --- |
| 应用/系统包、opkg/apk、mise 插件 | `istoreos-package-manager` | app-search, app-diagnostics, service-manager |
| Docker 拉取、文件、公开 Git、pip/npm/Go modules 下载或安装失败 | `istoreos-download-acceleration` | mise-runtime, docker-basics, docker-acceleration-istoreenhance, kspeeder-domainfold-fetch |
| Python/Node/Go SDK 安装、版本/预编译/解释器异常 | `istoreos-mise-runtime` | package-manager, download-acceleration |
| 磁盘/overlay/持久化目录 | `istoreos-storage-path` | docker-data-root-migrate, backup-restore |
| 服务/端口/开机启动 | `istoreos-service-manager` | logs-and-diagnostics, source-introspect |
| LuCI 网页异常 | `istoreos-luci-recovery` | backup-restore |
| 测速、延迟、NAT、IPv6/LAN | `istoreos-network-quality` | logs-and-diagnostics |
| IPv6 模式、休眠、商店/内核修复 | `istoreos-systools` | logs-and-diagnostics |
| .run/未知安装文件 | `istoreos-run-executable` | download-acceleration, backup-restore |
| 危险操作/恢复/迁移 | `istoreos-backup-restore` | owning skill |
| 未知任务/源码与配置 | `istoreos-system-task-router` | source-introspect |

Helper shorthand uses the `istoreos-` prefix. Never preload all named helpers. Primary skills describe user tasks; internal evidence helpers use invocation: manual. Lack of a dedicated skill must not block safe diagnosis or ordinary reasoning. Follow the router's unknown-problem contract when no row matches.
