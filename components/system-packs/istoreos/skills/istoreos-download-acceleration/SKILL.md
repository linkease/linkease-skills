---
name: istoreos-download-acceleration
description: iStoreOS 下载与依赖加速入口；分流文件、Git、Docker 和 pip/npm/Go modules，验证实际网关请求并诊断失败。
owner: system-pack/istoreos
systems: istoreos
triggers: 下载慢, 拉取失败, 拉镜像失败, 镜像下载慢, docker pull, GitHub 下载, GitLab 下载, HuggingFace, git clone, 镜像加速, 文件下载失败, pip install, pip 安装, Python 依赖, npm install, npm ci, npm 依赖, Go modules, go mod, 模块下载
negative-triggers: 网速慢, 网络测速, 宽带速度, 延迟测试, 局域网测速
auto-use: prefer
routing-group: istoreos-primary
needs-fresh-data: true
cost: medium
---

# iStoreOS Download Acceleration

Select one download lane for the user's task; do not ask users to assemble skills. This is the iStoreOS/OpenWrt integration workflow. Ubuntu and other systems retain their own package/service/runtime policies. ks-cli is a client of the resident KSpeeder service on iStoreOS, not a competing service installer.

## Dispatch

1. Python/Node/Go SDK installation or interpreter-version failure: use mise-runtime for system package prerequisites and runtime validation; SDK installation is distinct from dependency installation.
2. pip/npm/Go modules: follow the dependency workflow below. Runtime tools missing or a venv/launcher failure load mise-runtime only when needed; keep the dependency task as the primary lane.
3. External file URL: use the resident `iStoreEnhance download --mode auto --json --events=ndjson -O FILE URL`, or its kspeeder binary equivalent. `dispatch.sh url` retains legacy ksget fallback when the resident download command is absent.
4. Public HTTPS Git repository: `dispatch.sh git-clone URL [DIRECTORY]` remaps the URL and runs native Git Smart HTTP. Load internal `istoreos-kspeeder-domainfold-fetch` for remap/DNS/TLS evidence. File download and package registry adapters do not cover Git dependencies, submodules or private repositories. Inspect active routes; Gitee is not Gitea.
5. Docker pull: `dispatch.sh docker-pull IMAGE` performs space and resident-service readiness checks before the original pull. Compose/iStore Docker app setup uses docker-basics first. Do not rewrite image names.

## Dependency workflow

If the user supplies an already installed complete SDK version, a new isolated directory and download authorization, take the acceptance path directly: `KAIPLUS_CONFIRMED=1 sh scripts/smoke.sh TOOL RESOLVED_VERSION NEW_ABSOLUTE_DIRECTORY` (resolve the script from this skill's location). This helper enters mise-exec, selects that exact SDK, creates/activates the venv for pip and runs doctor in the selected environment. Do not prepend login-shell Python/mise/doctor checks or manually rediscover SDK paths. A missing prerequisite fails explicitly; then diagnose that failure with mise-runtime. After success verify current-window gateway evidence as described below.

For dependency work outside that acceptance case:

1. Run sibling `../istoreos-mise-runtime/scripts/check.sh` from this skill directory. It checks release, arch/libc, manager and tools inside mise-exec. Inspect runtime tools there, not in the login shell's different HOME. If integration is missing, install the verified system package first. For custom commands read mise-runtime's `data/execution.md`; `exec.sh PROGRAM_FILE [ARG...]` takes an existing program file, not `sh -c`. Every call restores integration, cwd and activation.
2. Select an already installed, complete runtime version. Installation and selection use mise-runtime; do not rely on the system interpreter. Python defaults to a project venv created by that explicit Python version; activate and check its actual pip launcher. Node and Go commands execute under explicit mise exec.
3. Inspect health, capabilities, actual TLS/admin ports and the side-effect-free explain plan. Helpers run `ks-cli doctor TOOL --json` inside the selected runtime, after venv activation for pip; do not run login-shell doctor first. Missing/outdated service components use the detected package/iStore lifecycle. Include possible installed-service startup in authorization for network commands.
4. Run authorized dependencies via `KAIPLUS_CONFIRMED=1 sh scripts/dispatch.sh pip|npm|go RESOLVED_VERSION -- TOOL_ARGS...`. The helper re-enters integration, selects Node/Go, restores the explicitly chosen venv for pip, checks integrity and doctor before calling the native adapter. It preserves arguments/exit status and writes no global client configuration.
5. Read `data/dependencies.md` for acceptance recipes and results. The smoke helper uses pinned real dependencies and isolated caches/projects; client success still leaves gateway verification pending.
6. Capture matching current-instance gateway logs for the same test window. `scripts/evidence.sh TOOL CLIENT_LOG GATEWAY_LOG ACTUAL_TLS_PORT` verifies the maintained smoke recipes' metadata/index and artifact requests, rejecting cache-only, wrong-port, unrelated-artifact and client-direct evidence. Inspect actual strategy and verification outcomes; never report acceleration from explain output or cache success alone.

## Scope and diagnosis

- ks-cli mise URL replacements cover matching internal HTTP requests; pip/npm/go adapters are separate. Do not promise all backends, Git dependencies, lockfile tarball hosts or download sources are covered.
- Distinguish client direct fallback from a gateway choosing its canonical origin; the latter still traverses the gateway. Go's proxy list includes direct fallback, which must be reported when observed.
- For DNS/TLS/capability/port failures check current configuration and bounded client/gateway logs. Preserve TLS, checksum, signatures, lockfile integrity and Go sumdb. No trusted-host/insecure flags as a shortcut.
- For global pip's missing realpath, create/activate a project venv and test ks-cli pip itself; python -m pip alone is insufficient. No system Python packages or break-system-packages. A provider for realpath must be discovered in actual feeds if still needed.
- Do not change global curl/wget behavior, Git insteadOf, npmrc, pip config or go env settings. Private credentials must not be forwarded to alias hosts by default.
- Reuse authorization for the stated scope. If a setup helper reports need-confirmation, request only a newly required effect; do not restart approval for an already authorized action.
