# iStoreOS Task Routing

This is the compact product-task map. Select one primary skill first; load a helper only when evidence from the primary flow requires it.

| User says | Primary skill | Helper only if needed |
| --- | --- | --- |
| 安装/卸载/升级应用或软件 | `istoreos-package-manager` | `istoreos-app-search`, `istoreos-app-diagnostics`, `istoreos-service-manager` |
| Docker 镜像慢、拉取失败、compose up | `istoreos-download-acceleration` | `istoreos-docker-basics`, `istoreos-docker-acceleration-istoreenhance` |
| GitHub/GitLab 文件下载或公开 Git 项目克隆慢 | `istoreos-download-acceleration` | `istoreos-kspeeder-domainfold-fetch` |
| 磁盘满、overlay 满、装到硬盘 | `istoreos-storage-path` | `istoreos-docker-data-root-migrate`, `istoreos-backup-restore` |
| 服务打不开、端口不通、启动失败 | `istoreos-service-manager` | `istoreos-logs-and-diagnostics`, `istoreos-source-introspect` |
| LuCI 网页管理异常 | `istoreos-luci-recovery` | `istoreos-backup-restore` |
| 网速、测速、延迟/抖动、NAT、IPv6 可用性或局域网吞吐 | `istoreos-network-quality` | `istoreos-logs-and-diagnostics` |
| 修改 IPv6 模式、硬盘休眠、iStore 商店或升级后内核模块问题 | `istoreos-systools` | `istoreos-logs-and-diagnostics`, `istoreos-backup-restore` |
| 安装 Python、Node.js 或 Go 运行环境 | `istoreos-mise-runtime` | `istoreos-package-manager`, `istoreos-download-acceleration` |
| `.run` 文件或未知可执行安装包 | `istoreos-run-executable` | `istoreos-download-acceleration`, `istoreos-backup-restore` |
| 不确定配置/源码行为 | `istoreos-system-task-router` | `istoreos-source-introspect` |
| 危险操作、恢复、迁移前 | `istoreos-backup-restore` | Owning domain skill |

## Loading Policy

- Auto-discovered skills represent user tasks. Implementation helpers use `invocation: manual` and are reached by name from a primary skill or this router.
- Never load all skills in a row. Start with one primary skill and add at most one helper at a time.
- If no row matches, load `istoreos-system-task-router` and follow its unknown-problem contract. Lack of a dedicated skill must not block safe diagnosis or ordinary reasoning.
