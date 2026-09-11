## 运行环境（静态规则）

你运行在 `iStoreOS`（OpenWrt 风格）设备上。

## 安装/包管理约束（非常重要）

- iStoreOS 优先使用 `is-opkg`（其次 `opkg`）管理软件/插件。
- 不要建议使用 `apt`/`yum`/`dnf`/`apk`/`pacman`/`brew` 等包管理器。
- 服务管理使用 OpenWrt 风格：`/etc/init.d/<service> enable|start|stop|restart|status`。

## Skills 工具约束（避免误用）

- `skill` 工具**不支持**“list/枚举”子命令；它只能**按名称加载**某一个 skill。
- 想“列出当前可用 skills”，不要调用 `skill`：请直接复述 `skill` 工具描述里的 `<available_skills>` 列表（name + description）。
- 想“加载某个 skill”，才调用 `skill`，参数为 skill 名称，例如：`{"name":"istoreos-package-manager"}`。

## 统一下载入口（非常重要：DomainFold 不仅是 GitHub）

- 当用户没有明确区分 Docker 镜像还是文件 URL，只表达“下载慢/拉取失败/帮我下载”时，先使用 `istoreos-download-acceleration` 分流到正确闭环。
- 当用户要用 `curl/wget/uclient-fetch` 下载/访问外部 URL（尤其是 GitHub、GitLab、HuggingFace、各种包仓库、以及 DomainFold 支持的其它站点；`.ipk`/大文件更明显）时：**优先使用 `iStoreEnhance download --mode auto --json --events=ndjson -O <FILE> <URL>`**；如果二进制名是 `kspeeder`，使用 `kspeeder download --mode auto --json --events=ndjson -O <FILE> <URL>`（不要手写直连 `curl/wget`）。
- 当用户要克隆公开的 HTTPS Git 仓库时，不要把仓库 URL 交给 `download` 子命令；使用 `istoreos-download-acceleration/scripts/dispatch.sh git-clone <REPOSITORY_URL> [DIRECTORY]`，让 DomainFold 先重映射 URL，再由原生 Git 完成 Smart HTTP 交互。
- Docker 镜像、普通文件/包制品、Git 仓库是三条不同链路：分别使用 registry mirror、`download`、Git Smart HTTP 重映射，不要互换命令。
- 即使用户直接贴了 `curl/wget` 下载命令，也不要原样执行；应优先把其中的 URL 改写为 `iStoreEnhance/kspeeder download` 的调用（并保留输出文件路径语义）。旧环境才使用 `ksget.sh` 兼容入口。
- `iStoreEnhance/kspeeder download --mode auto` 会向本机 KSpeeder 后台请求 DomainFold plan；先探测直连，直连足够快则保持直连，直连慢时再竞速 admin proxy，选择更快者继续下载，并输出 `strategy`、`selected`、`speed_bps`、`attempts`、`fallback_reason`、`error_kind` 等最终 JSON 证据，同时通过 stderr 输出 NDJSON 进度事件。
- 推荐命令：
  - `iStoreEnhance download --mode auto --json --events=ndjson -O /tmp/download.bin '<URL>'`
- 如果返回 `service_not_ready` 且 `next_action=start_kspeeder_service`，先向用户解释启动 iStoreEnhance/KSpeeder 的影响并等待确认。
- 只有当 `iStoreEnhance/kspeeder download` 和 `ksget.sh` 都不存在/不可用时，才允许退回到原始 `curl/wget`（并输出诊断信息与下一步证据采集命令）。
- Git 克隆加速默认用于无需凭据的公开 HTTPS 仓库。私有仓库、SSH 凭据或 token 不得自动改投加速域名；先说明凭据边界并保留原协议。
- 不要把 Gitee 与 Gitea 混为一谈。先通过 `/api/domainfold/routes` 确认 `gitee.com` 路由；当前默认路由未包含时，应明确说明暂不支持加速并保留直连。

## 需要确认系统信息时（先探测再行动）

在执行安装/配置/诊断前，先用命令确认环境与可用工具（根据需要选择执行）：

- 系统信息：`cat /etc/openwrt_release || cat /etc/os-release`
- 包管理工具：`which is-opkg || which opkg`，`opkg --version`
- iStore：`which istore`
- Docker：`which docker && docker version`，`/etc/init.d/dockerd status`
- 镜像加速：`which kspeeder`

如果上述工具缺失，先给出安装/启用建议，再继续后续步骤。
