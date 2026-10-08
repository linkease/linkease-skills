# Scoped runtime entrypoints: implementation and verification

## Goal, scope and outcome

The approved alternative uses skill-owned task scripts and scoped results instead of intercepting Kai's general shell executor. The goal/task tree and acceptance criteria are in [runtime-task-entrypoints.md](../architecture/runtime-task-entrypoints.md). System-shell observations are allowed; mise SDK and download conclusions require selected-runtime and current-run evidence.

T1–T5 completed. Initial self-check exposed an overly strict selected-child PATH check. Optimization 1 fixed that behavior; its Agent check then exposed an unscoped manual dependency flow and unsupported gateway conclusion. Optimization 2 clarified discovery and per-platform routing. The final self-check passed; no third optimization was needed.

Final deployed skills code: `a64aa5bea6a08ee22dcef7ed4e3949909ab00dcc`. Test commits precede production changes: `5eb1d81` → `60f8803`, `85ad6bd` → `76207fa`, and `a1e809a` → `a64aa5b`. KSpeeder/ks-cli stayed at the existing `6fa3cc21b6e7`, version 0.8.3. No Kai executor, gateway business code, plugin code or ordinary Linux/Ubuntu workflow changed in this task. worker-tinygo tests were not managed.

## Deliverables

- `istoreos-mise-runtime/scripts/check.sh`: explicitly identifies current-shell system facts; never enters mise-exec.
- `environment.sh` / `exec.sh`: check configured writable HOME and shims before the task program runs. No manual HOME replacement; preserve Agent XDG and explicit mise overrides.
- `probe.sh`: establishes integration on each invocation, disables SDK auto-install, verifies exact SDK provenance/version/functionality and returns JSON on stdout, with diagnostic stderr.
- `install.sh`: preserves precompiled Python and SDK integrity/activation rules; appends a scoped runtime-install receipt and preserves failure codes.
- `dependency.sh`: validates the selected Node/Go child's HOME, physical SDK bin directory and exact version. A selected child may legitimately lack shims; a wrong SDK path/version is rejected.
- `smoke.sh`: verifies the SDK before creating/using the actual dependency workflow; writes runtime.json and result.json. Client-only success is partial/pending. Optional current-log mode verifies an unchanged prefix and uses only appended entries for gateway evidence.
- `evidence.sh --json`: structured gateway verdict; original text interface remains compatible.
- Canonical skill/reference/router descriptions and the iStore-only resident routing reminder were reconciled. Both iStoreOS presets were generated through the repository tool. Other platform presets did not change.

## Local verification

The final working tree passed these commands (exit 0):

```sh
sh components/system-packs/istoreos/drills/profile-smoke.sh
sh tools/generate-platforms.sh
sh tools/verify-generated.sh
sh tests/architecture/test-catalog.sh
sh tests/architecture/test-runtime-release-gate.sh
sh tests/context-budget/test-m7-istoreos.sh
sh tests/install/test-agent-bundle-export.sh
sh tests/install/test-reasonix-consumer.sh "$REASONIX_SOURCE_ROOT"
git diff --check
```

The profile includes the new `test_runtime_results.sh` and existing package/environment, runtime install/diagnosis, dependency, gateway and smoke contracts. The release-gate test proves both old environment and new result-contract failures block the profile. Natural-language dependency routing is covered by the architecture fixture; an additional live-routing case was added, but the standalone DeepSeek routing suite was not run. Actual Kai tests below supplied live execution coverage.

Final context budgets: catalog 2605 bytes, routing 1748 bytes, resident prompts 2031 bytes. The actual Reasonix loader consumed on-device and remote-control presets successfully; this is not a live Reasonix model test.

Regression coverage includes bad HOME, missing entry shims, independent repeated calls, explicit mise storage overrides, Agent XDG preservation, missing SDK with auto-install disabled, exact version/source mismatch, JSON escaping, non-iStore rejection, client-only partial results, failed execution codes, stale/replaced gateway logs, wrong ports and client-direct classification. Existing opkg/apk and architecture/libc fixture contracts remain covered.

## Authorized device execution

Device facts observed: iStoreOS 24.10.1, x86_64/musl, opkg/is-opkg, mise 2026.8.14, Kai OpenCode CLI 1.18.32. Addresses, credentials, runtime paths and raw traces remain private.

The current bundle was exported with:

```sh
sh tools/export-agent-bundle.sh --platform istoreos --mode on-device \
  --consumer opencode --output "$NEW_BUNDLE"
```

Deployment retained the old bundle and copied its OpenCode configuration unchanged. All 101 exported bundle files were SHA-256 checked on the active target. BusyBox directory-symlink replacement required `mv -fT`; the initial `mv -f` mistake was caught before accepting the deployment. The accidental staging link was removed. Installed-default configuration was not edited to enable the new routing reminder: the original configuration already reads `/usr/share/kai/agent/agents/*.md`.

Two independent SSH calls per SDK through probe.sh passed with parseable JSON, matching HOME/mise directories and exact SDK versions:

```sh
sh "$SKILLS/istoreos-mise-runtime/scripts/probe.sh" python 3.13.7
sh "$SKILLS/istoreos-mise-runtime/scripts/probe.sh" node 24.21.0
sh "$SKILLS/istoreos-mise-runtime/scripts/probe.sh" go 1.27.1
```

Final deployed installation entrypoints also passed for all three with default activation `none`:

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" python 3.13.7 none
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" node 24.21.0 none
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" go 1.27.1 none
```

These SDKs were already installed: this run verifies installation entry/selection/provenance and receipts, not cold SDK downloads. The earlier cold Python/attestation result remains historical evidence.

Fresh isolated projects passed the final deployed commands (exit 0):

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" \
  pip 3.13.7 "$NEW_PIP_PROJECT" "$CURRENT_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" \
  npm 24.21.0 "$NEW_NPM_PROJECT" "$CURRENT_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" \
  go 1.27.1 "$NEW_GO_PROJECT" "$CURRENT_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
```

All returned environment/runtime/client validation passed and gateway_validation confirmed. pip ran idna 3.10 import and pip check in a fresh venv, with client cache disabled. npm installed/ci-tested is-number 7.0.0 using separate caches, ran Node and checked lockfile integrity. Go used explicit uuid require/import, fresh module/build caches, download/verify and an actual Go program. TLS/checksum/signature and module sumdb were not disabled. Gateway-selected origin was distinguished from client direct fallback; the actual TLS port came from current UCI state.

The new result test, dependency command test and package/environment test also ran successfully under actual device BusyBox, using staged fixtures and the installed Python only as a JSON test parser. A test-harness inherited integration marker was cleared before the fixture runs; no production change was required for that harness correction.

## Kai behavioral acceptance

Each final test used a fresh natural-language request with the installed SDK version and a new isolated project, without naming a skill or script:

```sh
OPENCODE_CONFIG=/usr/share/kai/agent/opencode.json \
  /usr/sbin/kai_session run --auto --format json --dir "$TEST_STAGE" "$NATURAL_LANGUAGE_REQUEST"
```

`--auto` reused test authorization and retained existing deny rules; the configuration file stayed unchanged.

| Final scenario | Observed execution and acceptance |
| --- | --- |
| Current gateway log available | First loaded download-acceleration, used the dedicated smoke entrypoint, CLI exit 0; result passed / gateway confirmed. An independent window captured before the CLI invocation matched both index and artifact requests through evidence.sh --json. Independent venv import/pip check also passed. |
| Client-only; no gateway-log collection/read requested | Used the smoke entrypoint, CLI exit 0; result partial / gateway pending. Final response explicitly refused to claim confirmed acceleration. Independent venv import/pip check passed. |

Optimization history matters: before the routing reminder, a separate run manually used pip and claimed gateway success from pre-existing logs, without a dependency result receipt. That run FAILED acceptance despite CLI exit 0 and a working dependency. It is not counted as a passed gateway test. The new gate and final scenarios establish the current observed result, not a guarantee that every possible Agent command follows the skill.

## Cleanup and limits

Temporary current-instance logging was removed. SHA-256 checks passed for mise/iStoreEnhance/Docker UCI configuration, mise integration, init script and both gateway/CLI binaries. Original and active Agent configuration compared byte-for-byte. The immediate post-restart health check briefly saw an unopened admin port; the subsequent check returned status ok, service running, summary/mirrors/registry true, commit `6fa3cc21b6e7`, no errors. Isolated projects and rollback bundles were retained outside system/global dependency configuration.

Actual apk, ARM and glibc devices remain untested. No cold Node/Go SDK install, live Reasonix model invocation, authenticated Docker/Git business regression or universal Agent-ordering guarantee is claimed. Local commits were not pushed and no release/tag was created.
