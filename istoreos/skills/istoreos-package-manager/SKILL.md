---
name: istoreos-package-manager
description: 搜索、安装、升级或卸载 iStoreOS 应用和软件包，并区分 iStore meta、opkg 与 Docker 应用；运行时环境和 .run 文件由专用 skill 处理。
triggers: 安装应用, 安装软件, 安装插件, 卸载应用, 升级应用, 找应用, 找插件, 搜索应用, 推荐应用, 推荐插件, 文件管理插件, 软件包, opkg, is-opkg, iStore 应用
negative-triggers: 安装 Python, 安装 Node.js, 安装 Go, Docker 镜像, .run 文件
auto-use: prefer
routing-group: istoreos-primary
needs-fresh-data: true
cost: medium
---

# iStoreOS Package Manager

当用户想“搜索/安装/升级/卸载”软件，或出现“安装/下载失败”时，按下面流程执行。

## 0) 禁忌与前置

- 目标系统是 iStoreOS（OpenWrt 风格），只使用 `is-opkg/opkg`；不要建议 `apt/yum/dnf/apk/pacman/brew/systemctl`。
- 先分流：iStore meta / opkg 包 / Docker 类 iStore 应用（istorec）。

## 1) 分流（必须先做）

1. **iStore meta 应用优先**：以 Store 全量目录或本地 meta 确认准确 `name`，安装包名为 `app-meta-<name>`。本地没有 meta 不代表 Store 中没有该应用。
2. **Docker 类 iStore 应用**：meta 的 `depends` 含 `docker-deps` 或已安装后存在 `/usr/libexec/istorec/<name>.sh`。
3. **否则当作 opkg 包**：走 `opkg list/info/install`。

## 2) 搜索（按分流走）

- iStore meta：
  - 搜索范围以 iStore Store API 汇总目录为准；app-hub 仅覆盖我们维护的第一方应用，不能作为全量列表。
  - 先把用户“口头名”映射到 meta `name`（可能需要反问确认）。
  - 当用户只给“口头描述/功能点”或出现多候选时：优先用 `istoreos-app-search` 输出 Top3，再让用户回复 `name` 确认（未确认前不要安装）：
    - `sh skills/istoreos-app-search/scripts/search.sh "<keyword>" 3`
    - 面向用户的固定展示格式（不显示内部 score）：
      1) `<name>`: `<title>`
         - 类型与来源：`<type_hint>` / `<ownership>`
         - 兼容性：`<compatibility>`
         - 适合原因：`<fit>`
         - 安装后入口：`<entry>`
      反问：请回复上面条目的 `name` 确认要安装哪一个。
  - 若 Top3 为空/都不对：不要停止，改走降级分支并反问用户选哪条路：
    1) 继续当作 OpenWrt 包：走 opkg 搜索（见下方 `opkg`）
    2) 如果用户其实在找 Docker 镜像：走 Docker 镜像搜索（见下方 `Docker 镜像`）
- opkg：
  - `opkg update` 后 `opkg list | grep -i <kw>`，再 `opkg info <pkg>` 确认描述。
  - 推荐用脚本（更一致）：
    - 名称/描述匹配：`sh skills/istoreos-package-manager/scripts/opkg-find.sh "<regexp>" 30`
    - 包详情：`sh skills/istoreos-package-manager/scripts/opkg-info.sh "<pkg|regexp>" 8`
    - 文件归属包：`sh skills/istoreos-package-manager/scripts/opkg-search-file.sh "/path/to/file" 30`
- Docker 镜像（可选）：
  - 先确保 kspeeder/istoreenhance 可用（否则先安装/启用）：转 `istoreos-docker-acceleration-istoreenhance`
  - 若启用 `istoreenhance` 且 registry 可用：用 `registry-search.sh <kw>`（默认查询 `https://registry.linkease.net:5443/v1/search`，可用环境变量 `ISTORE_REGISTRY_SEARCH_URL` 覆盖）
  - registry 不可用时不要硬搜：让用户提供更精确镜像名或转 iStore meta 搜索。

## 3) 安装/升级/卸载

- iStore meta（推荐）：
  - 安装：`is-opkg install app-meta-<name>`
  - 升级：`is-opkg upgrade app-meta-<name>`
  - 卸载：`is-opkg remove app-meta-<name>`
  - 若 meta 支持 `autoconf`（如 `path/enable`）：优先走 `AUTOCONF=<name> path=<base> enable=<0|1>` 的自动配置路径。
  - 安装后若“已安装但不生效/服务没启动/插件未启用”：转 `istoreos-service-manager`，优先执行：
    - 向用户说明影响并确认后：`KAIPLUS_CONFIRMED=1 sh "$SKILLS_DIR/istoreos-service-manager/scripts/ensure.sh" <name> <name>`（通常 service/uci 同名；不确定就先只读确认 `/etc/init.d/<name>` 与 `/etc/config/<name>`）
  - 若服务名不确定（更通用）：先用 `opkg files <pkg>` 定位 init 脚本，再一键确保：
    - 向用户说明影响并确认后：`KAIPLUS_CONFIRMED=1 sh "$SKILLS_DIR/istoreos-package-manager/scripts/ensure_services_from_pkg.sh" <pkg>`
- opkg 包：
  - `is-opkg install <pkg>`（没有 is-opkg 才用 `opkg install <pkg>`）
- Docker 类 iStore 应用（istorec）：
  - 先确保 Docker 可用（必要时转 `istoreos-docker-basics`）。
  - 安装/升级容器应用前先做空间检查（避免把系统盘/overlay 打满）：
    - `SKILLS_DIR="${KAIPLUS_SKILLS_DIR:-${KAIPLUS_HOME:?KAIPLUS_HOME is required}/config/skills}"; sh "$SKILLS_DIR/istoreos-docker-basics/scripts/check_space.sh"`
  - 数据目录/安装路径优先复用应用自带路径算法 + is-opkg autoconf（不要手写 `config_path` 规则）。

## 4) 验证闭环（必须做）

- meta/opkg：`opkg status <pkg>` 或 `opkg list-installed | grep -F <pkg>`
- 有服务的：`/etc/init.d/<svc> status`（必要时 `restart`）
- Docker 类：`/usr/libexec/istorec/<name>.sh status` 或 `docker ps --all -f 'name=^/<name>$'`

## 5) 安装失败或安装后异常（不要猜）

先按需调用 `istoreos-app-diagnostics`，读取 iStore 固定任务的最近日志并与目标应用、当前包状态严格关联：

```sh
SKILLS_DIR="${KAIPLUS_SKILLS_DIR:-${KAIPLUS_HOME:?KAIPLUS_HOME is required}/config/skills}"
sh "$SKILLS_DIR/istoreos-app-diagnostics/scripts/inspect.sh" <app-id>
```

- 报告已给出 `next.skill`：一次只加载该 helper。
- 报告为 `unknown`：再转 `istoreos-logs-and-diagnostics` 收集 `logread`、空间或 Docker 最小证据，继续通用分析。
- `task.correlation=mismatch` 或历史日志不存在：不要把最近任务误归因到目标插件。
