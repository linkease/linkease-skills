# LinkEase Skills repository guidance

## When a user gives you this repository

1. Read `catalog.json`; it is the authoritative public index.
2. Identify the device platform and whether the Agent runs on that device (`on-device`) or controls it from elsewhere (`remote-control`).
3. Resolve exactly one preset by `platform + mode`.
4. Run `sh install.sh --platform PLATFORM --mode MODE --consumer CONSUMER --dry-run` and show the result before changing the Agent's skills directory.
5. Install only after the user has approved the destination and replacement policy.

Never install every platform by default. Never install from `components/`. If the device is missing, ask only: “Which device platform do you want to manage?” If the execution location is missing, ask only: “Will the Agent run on the device, or control it remotely?” Do not ask users to choose a System Pack or Transport.

For Codex use `--consumer codex`; for OpenCode use `--consumer opencode`; for other Agents use `--consumer generic --target-skills DIR`.

## Repository boundaries

- `components/system-packs`: canonical target operating-system behavior.
- `components/transports`: canonical target connection/execution behavior; no operating-system maintenance policy.
- `platforms/<device>/<mode>`: generated, self-contained third-party installation presets. Do not edit them manually.
- Kai consumes canonical System Packs and its own Target Transport, not third-party remote-control presets.

Credentials, target addresses, fingerprints, and device-specific state must remain outside this repository and model context. Unknown or changed SSH host keys are a hard stop.
