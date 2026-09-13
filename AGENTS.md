# LinkEase Skills repository guidance

## Installing for a user

- Treat `catalog.json` as the authoritative public index.
- Resolve exactly one preset from the user's target platform and usage mode.
- `on-device` means the third-party agent already executes on the target device.
- `remote-control` means the third-party agent needs the packaged remote target capability.
- Never install every platform by default.
- If the platform or mode is ambiguous, ask one short user-facing question without exposing System Pack or Transport terminology.
- Run the installer in dry-run mode and show the selected preset, source, destination, and replacement policy before changing an agent's skills directory.
- Do not install from `components/`; those are canonical development sources, not user installation entrypoints.

## Maintaining the repository

- System skills describe target operating-system behavior and remain independent of Local, SSH, WinRM, or helper transport details.
- Transport modules provide target execution and contain no operating-system maintenance policy.
- Files under `platforms/` are generated install presets. Edit canonical files under `components/`, then regenerate and verify them.
- Preserve credentials, target addresses, host fingerprints, and other device-specific data outside this repository.
