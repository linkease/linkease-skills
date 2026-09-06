# Remote iStoreOS Task Routing

Remote-control profile tasks must start by establishing a safe SSH or router-API context. Specialized iStoreOS skills may be used only after the target device has been identified.

| User says | First step | Follow-up |
| --- | --- | --- |
| `root@192.168.30.93` / connect to router | `istoreos-ssh-ops` | Read-only min diagnostics |
| Docker 下载慢/拉取失败 | `istoreos-ssh-ops` | `istoreos-docker-acceleration-istoreenhance` |
| GitHub 文件下载慢 | `istoreos-ssh-ops` | `istoreos-kspeeder-domainfold-fetch` |
| 应用安装失败 | `istoreos-ssh-ops` | `istoreos-package-manager`, `istoreos-logs-and-diagnostics` |
| 磁盘/overlay/Docker data-root | `istoreos-ssh-ops` | `istoreos-storage-path`, `istoreos-docker-data-root-migrate` |
| LuCI 打不开 | `istoreos-ssh-ops` | `istoreos-luci-recovery` |
