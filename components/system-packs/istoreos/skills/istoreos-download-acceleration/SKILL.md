---
name: istoreos-download-acceleration
description: iStoreOS 下载加速总入口；区分 Docker 镜像、外部文件/包制品和公开 HTTPS Git 仓库三条链路，不用于宽带测速或普通网络质量诊断。
owner: system-pack/istoreos
systems: istoreos
triggers: 下载慢, 拉取失败, 拉镜像失败, 镜像下载慢, docker pull, GitHub 下载, GitLab 下载, HuggingFace, git clone, 镜像加速, 文件下载失败
negative-triggers: 网速慢, 网络测速, 宽带速度, 延迟测试, 局域网测速
auto-use: prefer
routing-group: istoreos-primary
needs-fresh-data: true
cost: medium
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

## When More Evidence Is Needed

- For Git DNS/TLS/remap failures, private-repository boundaries, legacy `ksget.sh`, or DomainFold route inspection, load the internal `istoreos-kspeeder-domainfold-fetch` helper.
- A registry or package-index mirror does not cover `git+https`, submodules, or other Git protocol dependencies. Those still use the Git lane.
- Check active routes before promising support for a host. In particular, Gitee is not Gitea.

## Boundaries

- Do not use `ks-cli` on iStoreOS for the normal local-router path; iStoreOS uses the resident iStoreEnhance/KSpeeder service.
- Do not rewrite Docker image names manually. Let Docker use the configured registry mirror.
- Do not change global `curl/wget/uclient-fetch` behavior.
- Do not write `git config --global url.*.insteadOf` or send private-repository credentials to an alias host by default.
- Do not auto-start or install services unless the user has confirmed the specific effect.
- Runtime installation belongs to `istoreos-mise-runtime`; do not bypass its integrated paths or certificate policy with ad-hoc environment overrides.
