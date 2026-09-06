# linkease-skills

Reusable LinkEase/KaiPlus skills organized by runtime profile.

## Profiles

- `istoreos`: KaiPlus runs directly on iStoreOS/OpenWrt.
- `remote-control-istoreos`: AI runs on another machine and controls iStoreOS through SSH or router APIs.
- `asusgo`: ASUSWRT/Koolshare/asusgo profile.

## Install

Install a full profile into KaiPlus config:

```sh
KAIPLUS_HOME=/opt/kaiplus sh linkease-skills/install.sh --profile istoreos --force
```

Install only skills:

```sh
sh linkease-skills/install.sh --profile remote-control-istoreos --target-skills /config/.codex/skills --force
```

## Package

Package all profiles:

```sh
sh linkease-skills/package.sh --all-profiles --all
```

Package one profile:

```sh
sh linkease-skills/package.sh --profile istoreos --zip /tmp/linkease-skills-istoreos.zip
```

Every package writes a matching `.sha256` file. Publish the archive and checksum together.
