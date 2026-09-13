# linkease-skills

Reusable LinkEase/KaiPlus skills organized by runtime profile.

## Design boundary

System skills describe how the target operating system works. They should not
depend on whether commands reach that target through a local shell, SSH, WinRM,
or a helper service.

Planned user-facing `on-device` and `remote-control` directories are installation
presets for third-party agents such as Codex and OpenCode. `on-device` means the
agent already has a shell bound to the target; `remote-control` additionally
packages the required remote-control capability. KaiPlus detects each target's
system and selects the canonical system skills itself, so its SSH targets do
not load a separate copy of remote-specific system skills.

The public repository layout and milestones are documented in the
[LinkEase Skills architecture](https://github.com/linkease/reasonix-kai/blob/main/docs/kaiplus/LINKEASE_SKILLS_FINAL_ARCHITECTURE.zh-CN.md).
The deeper KaiPlus target, transport, System Pack, and session capability
design remains in the
[KaiPlus multi-target architecture guidance](https://github.com/linkease/reasonix-kai/blob/main/docs/kaiplus/MULTI_TARGET_SYSTEM_PACK_GUIDANCE.zh-CN.md#45-system-pack-%E7%9A%84%E7%9B%AE%E6%A0%87%E6%89%A7%E8%A1%8C%E8%AF%AD%E4%B9%89).

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
