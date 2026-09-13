# iStoreOS Task Routing

Select one primary skill; load at most one evidence-required helper.

| User says | Primary skill | Helper only if needed |
| --- | --- | --- |
| 安装/卸载/升级应用或软件 | `istoreos-package-manager` | `istoreos-app-search`, `istoreos-app-diagnostics`, `istoreos-service-manager` |
| Docker 镜像慢、拉取失败 | `istoreos-download-acceleration` | `istoreos-docker-basics`, `istoreos-docker-acceleration-istoreenhance` |
| 外部文件或公开 Git 下载慢 | `istoreos-download-acceleration` | `istoreos-kspeeder-domainfold-fetch` |
| 磁盘满、overlay 满、装到硬盘 | `istoreos-storage-path` | `istoreos-docker-data-root-migrate`, `istoreos-backup-restore` |
| 服务打不开、端口不通、启动失败 | `istoreos-service-manager` | `istoreos-logs-and-diagnostics`, `istoreos-source-introspect` |
| LuCI 网页管理异常 | `istoreos-luci-recovery` | `istoreos-backup-restore` |
| 测速、延迟、NAT、IPv6/LAN 测试 | `istoreos-network-quality` | `istoreos-logs-and-diagnostics` |
| IPv6 模式、硬盘休眠、商店/内核修复 | `istoreos-systools` | `istoreos-logs-and-diagnostics`, `istoreos-backup-restore` |
| 安装 Python、Node.js 或 Go 运行环境 | `istoreos-mise-runtime` | `istoreos-package-manager`, `istoreos-download-acceleration` |
| `.run` 文件或未知可执行安装包 | `istoreos-run-executable` | `istoreos-download-acceleration`, `istoreos-backup-restore` |
| 不确定配置/源码行为 | `istoreos-system-task-router` | `istoreos-source-introspect` |
| 危险操作、恢复、迁移前 | `istoreos-backup-restore` | Owning domain skill |

## Loading Policy

- Primary skills represent user tasks. Helpers use `invocation: manual`.
- Never load all skills. Use one primary plus at most one helper.
- If no row matches, load `istoreos-system-task-router` and follow its unknown-problem contract. Lack of a dedicated skill must not block safe diagnosis or ordinary reasoning.
