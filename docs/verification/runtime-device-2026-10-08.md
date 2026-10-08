# Authorized iStoreOS device verification

Date: 2026-10-08. Follow-up to the local M1–M5 report. The user supplied one device and authorized replacing Kai skills, mise integration, ks-cli and iStoreEnhance, and running real Agent and dependency tests. No publication, push or upstream merge occurred.

## Scope and deployment

The tested device is iStoreOS 24.10.1, x86_64, musl, with active opkg/is-opkg, mise 2026.8.14 and the existing system-managed persistent Runtime directory. apk, ARM and glibc devices were not tested. Existing integration was installed already: package detection/installed checks ran, but an actual fresh feed/package install did not. No Ubuntu/Linux base pack was replaced.

Kai on this device is OpenCode 1.18.32 (`kai_session`), not Reasonix. The actual Kai/OpenCode loader discovers all 20 exported skills; live model/tool execution selected the runtime and dependency skills. The separate installed KaiPlus/Reasonix consumer was left untouched. The earlier local actual Reasonix loader tests remain the evidence for that consumer, not a live Reasonix/device LLM test.

Before deployment, original Agent bundle/link, binaries, integration scripts, init scripts and UCI configuration were archived in a private test directory under the configured Runtime. The original OpenCode configuration and UCI mise/kai/istoreenhance configuration are byte-for-byte unchanged. Tests use fresh project directories and separate SDK/client caches. Python dependencies are inside venvs; no system Python packages or global pip/npm/Go dependency configuration were changed. No global mise activation was performed by the test harness.

The gateway and CLI were built locally at KSpeeder commit 9eaf7be with `rtk make LOCAL_BUILD_NUMBER=skills-device-test local-build`; actual UI assets and generated version source supplied build prerequisites. Deployed executables identify as 0.8.3. Their device/local SHA-256 hashes match. No release/tag/upload occurred. The mise binary remains 2026.8.14; `/lib/functions/mise.sh` was patched from the isolated plugin-source branch, not installed as a released package. Package metadata still identifies the originally installed package.

Plugin-source fixes live in the isolated istoreos-app-hub branch af/2ce8-mise-probe (head f1d67a6): bounded curl probe with preserved failure exit (7619d0b, test 7c34c72), and Runtime-scoped MISE_DATA_DIR/MISE_CACHE_DIR/MISE_CONFIG_DIR while retaining Agent XDG directories and explicit caller overrides (f1d67a6, test 2c63276). The original source checkout was not modified.

## Real results

| Test | Result and limits |
| --- | --- |
| System facts / package status / health / capabilities | PASS. Actual opkg/is-opkg, musl, executable paths and configured Runtime were observed. Port was read from deployed configuration; 5443 is a fact for this device only. |
| Independent SSH execution / Kai XDG environment | PASS for direct public runner calls. Runtime HOME/shims and default mise storage remain coherent inside Agent XDG environment; explicit isolated MISE directories remain intact. |
| Python 3.13.7 cold SDK installation | PASS. Download, checksum and GitHub artifact attestations verified; exact interpreter path/version plus ssl/sqlite3/bz2/lzma/ctypes/venv and pip module verified. No source compiler fallback. |
| Go 1.27.1 cold SDK installation | PASS. Download/checksum/extract, exact version and isolated GOROOT verified. Separate from Go modules. |
| Node.js 24.21.0 cold SDK installation | FAIL. Partial download/EOF and later 30-second HTTP timeout; native exit 1 and download diagnosis preserved. Existing Node.js 24.21.0 is runnable, but does not prove this installation succeeded. |
| Kai live skill selection/execution | PASS for the corrected-stdin Python/idna case, CLI exit 0. It selected istoreos-download-acceleration, ran actual ks-cli pip/import/check and reported matching logs. The verifier was corrected while this case was running and was rerun on the captured window; this is not an independent new download after the verifier patch. |
| pip + idna 3.10 | One direct run and one Kai run installed/imported successfully with `pip check`, venv and no client cache. However, a later independent repeat failed on wheel metadata HTTP 404. Repeatability acceptance is FAIL; do not report pip universally working. |
| npm + is-number 7.0.0 | PASS using the pre-existing Node SDK. Fresh independent cache, install/ci, lock integrity and actual Node require/run. Final isolated request window has both metadata and tarball gateway completion evidence. |
| Go modules + uuid 1.6.0 | PASS using the newly installed isolated SDK. Explicit require/import, pinned download, sumdb enabled, module verify and actual program run. Final isolated request window has module metadata and zip gateway completion evidence. |
| Gateway evidence helper on BusyBox awk | PASS after an actual parse failure was reproduced. Regression suite and real npm/Go windows return `gateway-confirmed`. Matching positive-byte race completion is valid; client cache-only/direct, failed, zero-byte, unrelated and wrong-port evidence remains rejected. |

The pip failure has concrete gateway evidence: a cached selected PyPI artifact mirror returns 404 for `.whl.metadata`, while the canonical files source returns 200 for that same path. Wheel and metadata requests share artifact routing in the current gateway; this is a suspected gateway candidate/cache compatibility defect, not proof of a bad Python installation. The successful earlier logs and failed repeat are both retained. No checksum/TLS/signature bypass, global mirror rewrite or silent direct-client fallback was used. The Node network failure and pip repeatability failure remain open; full real-device acceptance has not been achieved.

## Corrections found by device execution

Separate failing regression commits precede behavior changes. Skills corrections include actual mise integrity setting names (02a32e1 → ec30828), explicit Go package checksums and disabled implicit SDK installation (4f7b7e3 → 2db6cd6), effective forbidden-side-effect assertions (d8e98c7), legacy Agent XDG compatibility (c8626ac → d5dacdc), gateway race/BusyBox awk compatibility (067b810 → fe46529), and environment reporting without an unavailable printenv binary (9911d6e → 1400c1a). No other platform's preset or default configuration changed.

The SSH test harness initially allowed Kai to read remaining shell commands from stdin. Those runs are not clean CLI acceptance evidence. Later Kai calls explicitly use `</dev/null`. A failed authorization gate in the final direct smoke harness was also corrected by passing the user's already-granted authorization as KAIPLUS_CONFIRMED=1; it did not install or download before that correction. Native failed logs were retained.

## Reproduction and current-checkout checks

Set SSH_TARGET and RUN privately, deriving RUN from the configured persistent Runtime. Do not paste a target address or machine path into a skill. Stage each PROGRAM first and execute it through the maintained runner in every independent SSH call:

```sh
ssh "$SSH_TARGET" sh "$SKILLS/istoreos-mise-runtime/scripts/exec.sh" "$PROGRAM" "$RUN"
```

The staged SDK program sets separate MISE_DATA_DIR/MISE_CACHE_DIR (without changing HOME), then runs:

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" python 3.13.7 none
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" go 1.27.1 none
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-mise-runtime/scripts/install.sh" node 24.21.0 none
```

Each dependency program runs in that same integrated shell, with a unique fresh project path:

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" pip 3.13.7 "$NEW_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" npm 24.21.0 "$NEW_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" go 1.27.1 "$NEW_PROJECT"
sh "$SKILLS/istoreos-download-acceleration/scripts/evidence.sh" "$TOOL" "$CLIENT_LOG" "$CURRENT_RUN_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
```

The Kai wrapper sets its actual installed OPENCODE_CONFIG, skill directory and Kai XDG roots from UCI/init conventions. Model calls use `kai_session run --auto --format json "$PROMPT" </dev/null`, rather than inventing a Reasonix CLI contract. Prompts authorize only the fresh project and required downloads, prohibit global configuration changes and require truthful failure reporting. Tool traces and final CLI exit are retained privately.

Successful local commands after these corrections:

- `rtk sh components/system-packs/istoreos/drills/profile-smoke.sh`
- `rtk sh components/system-packs/istoreos/tests/test_dependency_gateway_evidence.sh`
- `rtk sh tests/architecture/test-runtime-release-gate.sh`
- `rtk sh tests/architecture/test-catalog.sh`
- `rtk sh tests/architecture/test-m4-generated.sh`
- `rtk sh components/system-packs/istoreos/tests/test_package_runtime_environment.sh`
- `rtk sh tools/generate-platforms.sh`
- `rtk sh tools/verify-generated.sh`
- `rtk sh tests/install/test-agent-bundle-export.sh`
- Plugin-source worktree: `rtk python3 -m unittest discover -s apps/mise/tests -v` (2 tests).
- On device: `sh "$RUN/evidence-fixture/tests/test_dependency_gateway_evidence.sh"` (BusyBox awk).

Only iStoreOS generated presets are synchronized. Raw logs, private model/config output and backups are kept outside the repository. The temporary gateway logging wrapper is removed after collecting evidence; the backed-up service init script is restored, while authorized tested binaries/integration/skills remain installed. No universal platform or network success is claimed.
