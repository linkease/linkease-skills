---
name: istoreos-download-acceleration
description: iStoreOS 下载加速总入口；把 Docker 镜像/Compose、外部文件与包制品、公开 HTTPS Git 仓库克隆分流到 KSpeeder/iStoreEnhance 对应的 registry mirror、DomainFold 下载或 Git Smart HTTP 链路。
---

# iStoreOS Download Acceleration

Use this skill when the user says Docker image pulls are slow/failing, asks to pull a Docker image, installs a Docker-style app, downloads files from GitHub/GitLab/HuggingFace/package registries, or wants to accelerate cloning a public HTTPS Git repository.

## User-Level Policy

Do not ask the user to choose a skill. Treat "下载慢", "拉镜像失败", "GitHub 下载失败", "git clone 太慢", "帮我下载这个链接", and "帮我安装 Docker 应用" as one product capability: download acceleration.

Internally keep three protocols separate:

- Docker images use the configured registry mirror.
- Files and package artifacts use `iStoreEnhance/kspeeder download` or an ecosystem-specific package mirror.
- Git repositories use a remapped repository URL with native Git Smart HTTP; the file downloader cannot clone a repository.

## Dispatch Rules

1. If the input is an external file URL, use `iStoreEnhance download --mode auto --json --events=ndjson -O <FILE> <URL>` or `kspeeder download --mode auto --json --events=ndjson -O <FILE> <URL>`; use `istoreos-kspeeder-domainfold-fetch/scripts/ksget.sh` only as a legacy-compatible wrapper.
2. If the input is a public HTTPS Git repository, remap the repository URL through KSpeeder and run native `git clone`. Use the dispatcher below; do not pass a repository URL to the `download` subcommand.
3. If the input is a Docker image pull, first run Docker space checks, then ensure `istoreenhance` is ready, then run the original `docker pull`.
4. If the input is Docker Compose or an iStore Docker-style app install, route to `istoreos-docker-basics` first; that skill will require the KSpeeder readiness check before any pull-like action.
5. If setup emits `need-confirmation:`, explain the install/UCI/service effect in user language, ask once, and rerun only after explicit confirmation.

## Script

Use the dispatcher when the user provided a concrete URL or image:

```sh
SKILLS_DIR="${KAIPLUS_SKILLS_DIR:-${KAIPLUS_HOME:?KAIPLUS_HOME is required}/config/skills}"
sh "$SKILLS_DIR/istoreos-download-acceleration/scripts/dispatch.sh" url -o /tmp/file.bin "https://github.com/..."
sh "$SKILLS_DIR/istoreos-download-acceleration/scripts/dispatch.sh" git-clone "https://github.com/owner/repo.git" /tmp/repo
sh "$SKILLS_DIR/istoreos-download-acceleration/scripts/dispatch.sh" docker-pull nginx:latest
iStoreEnhance download --mode auto --json --events=ndjson -O /tmp/file.bin "https://github.com/..."
```

## Git Dependencies and Build Downloads

- Registry/index mirrors accelerate normal package artifacts, but they do not automatically cover dependencies declared as `git+https`, Git URLs, submodules, or build recipes using Git. Remap those repository URLs explicitly.
- When a package manager must spawn Git internally, use a process-scoped `url.<accelerated-base>.insteadOf` environment/config only after deriving and validating the accelerated base from the remap/routes API. Never write a global Git rewrite from this skill.
- For OpenWrt/iStoreOS build `make download`, distinguish archive URLs from Git source URLs. Archive downloads may use the file-download lane; Git sources need the Git lane. This only works when the build host can resolve and reach the router-backed KSpeeder TLS endpoint.

## Git Diagnostics and FAQ

- Check `git --version`, KSpeeder installation/service state, and the original repository protocol.
- Run `istoreos-kspeeder-domainfold-fetch/scripts/remap_url.sh <REPOSITORY_URL>`, then `git ls-remote <OUTPUT_URL> HEAD` before a large clone when diagnosing DNS, TLS, port `5443`, authentication, or upstream errors.
- GitHub and GitLab public HTTPS repositories are covered by the current default routes. Check `/api/domainfold/routes` for other hosts.
- Gitee is not Gitea. The current default route set includes `gitea.com`, not `gitee.com`; do not promise Gitee acceleration unless the active routes explicitly contain it.
- Private repositories and SSH credentials are not automatically converted. Keep their original transport unless the user explicitly approves an authenticated proxy design.

## Boundaries

- Do not use `ks-cli` on iStoreOS for the normal local-router path; iStoreOS uses the resident iStoreEnhance/KSpeeder service.
- Do not rewrite Docker image names manually. Let Docker use the configured registry mirror.
- Do not change global `curl/wget/uclient-fetch` behavior.
- Do not write `git config --global url.*.insteadOf` or send private-repository credentials to an alias host by default.
- Do not auto-start or install services unless the user has confirmed the specific effect.
- For mise Node.js installs, prefer `MISE_NODE_MIRROR_URL=https://dl-node-unofficial.linkease.net:5443/` through `mise-istore`; do not start a separate download gateway process for the product path.
- For mise Python installs, source `/lib/functions/mise.sh`, run `istore_runtime_env`, then use `mise-istore install python@<version>` so GitHub Release URL replacement can accelerate the Python runtime artifact through `dl-github`.
- For pip package installs, prefer `PIP_INDEX_URL=https://dl-pypi.linkease.net:5443/simple/ python -m pip install <pkg>`; do not use `extra-index-url` for the default product path.
- For npm global package installs, prefer `npm install -g <pkg> --registry=https://dl-npm.linkease.net:5443`; do not use `registry.npmmirror.com` when the user wants KSpeeder-owned adaptive selection.
- For Homebrew installs, prefer `eval "$(iStoreEnhance brew-env --mode free)"` first. Free mode accelerates only Homebrew API metadata through `dl-homebrew-api`; Plus mode may add `HOMEBREW_ARTIFACT_DOMAIN=https://ghcr.linkease.net:5443` for GHCR-backed bottle OCI paths. Do not use `HOMEBREW_BOTTLE_DOMAIN` for GHCR-backed bottles, and do not default bottle/source/cask traffic to DomainFold/admin_proxy.
