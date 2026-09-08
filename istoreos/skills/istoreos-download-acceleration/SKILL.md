---
name: istoreos-download-acceleration
description: iStoreOS 下载加速总入口；把 Docker 镜像/Compose、GitHub/GitLab/HuggingFace/包仓库文件下载分流到 KSpeeder/iStoreEnhance 的 Docker registry mirror 或 DomainFold 下载闭环。
---

# iStoreOS Download Acceleration

Use this skill when the user says Docker image pulls are slow/failing, asks to pull a Docker image, installs a Docker-style app, or downloads files from GitHub/GitLab/HuggingFace/package registries.

## User-Level Policy

Do not ask the user to choose a skill. Treat "下载慢", "拉镜像失败", "GitHub 下载失败", "帮我下载这个链接", and "帮我安装 Docker 应用" as one product capability: download acceleration.

## Dispatch Rules

1. If the input is an external file URL, use `iStoreEnhance download --mode auto --json --events=ndjson -O <FILE> <URL>` or `kspeeder download --mode auto --json --events=ndjson -O <FILE> <URL>`; use `istoreos-kspeeder-domainfold-fetch/scripts/ksget.sh` only as a legacy-compatible wrapper.
2. If the input is a Docker image pull, first run Docker space checks, then ensure `istoreenhance` is ready, then run the original `docker pull`.
3. If the input is Docker Compose or an iStore Docker-style app install, route to `istoreos-docker-basics` first; that skill will require the KSpeeder readiness check before any pull-like action.
4. If setup emits `need-confirmation:`, explain the install/UCI/service effect in user language, ask once, and rerun only after explicit confirmation.

## Script

Use the dispatcher when the user provided a concrete URL or image:

```sh
SKILLS_DIR="${KAIPLUS_SKILLS_DIR:-${KAIPLUS_HOME:?KAIPLUS_HOME is required}/config/skills}"
sh "$SKILLS_DIR/istoreos-download-acceleration/scripts/dispatch.sh" url -o /tmp/file.bin "https://github.com/..."
sh "$SKILLS_DIR/istoreos-download-acceleration/scripts/dispatch.sh" docker-pull nginx:latest
iStoreEnhance download --mode auto --json --events=ndjson -O /tmp/file.bin "https://github.com/..."
```

## Boundaries

- Do not use `ks-cli` on iStoreOS for the normal local-router path; iStoreOS uses the resident iStoreEnhance/KSpeeder service.
- Do not rewrite Docker image names manually. Let Docker use the configured registry mirror.
- Do not change global `curl/wget/uclient-fetch` behavior.
- Do not auto-start or install services unless the user has confirmed the specific effect.
- For mise Node.js installs, prefer `MISE_NODE_MIRROR_URL=https://dl-node-unofficial.linkease.net:5443/` through `mise-istore`; do not start a separate download gateway process for the product path.
- For mise Python installs, source `/lib/functions/mise.sh`, run `istore_runtime_env`, then use `mise-istore install python@<version>` so GitHub Release URL replacement can accelerate the Python runtime artifact through `dl-github`.
- For pip package installs, prefer `PIP_INDEX_URL=https://dl-pypi.linkease.net:5443/simple/ python -m pip install <pkg>`; do not use `extra-index-url` for the default product path.
- For npm global package installs, prefer `npm install -g <pkg> --registry=https://dl-npm.linkease.net:5443`; do not use `registry.npmmirror.com` when the user wants KSpeeder-owned adaptive selection.
- For Homebrew installs, prefer `eval "$(iStoreEnhance brew-env --mode free)"` first. Free mode accelerates only Homebrew API metadata through `dl-homebrew-api`; Plus mode may add `HOMEBREW_ARTIFACT_DOMAIN=https://ghcr.linkease.net:5443` for GHCR-backed bottle OCI paths. Do not use `HOMEBREW_BOTTLE_DOMAIN` for GHCR-backed bottles, and do not default bottle/source/cask traffic to DomainFold/admin_proxy.
