# Latest fixes: device deployment and verification

Follow-up: the user approved scoped task entrypoints and receipt-based acceptance instead of a Kai executor constraint. See [the subsequent implementation and device verification](scoped-runtime-entrypoints-2026-10-08.md); the observations below remain historical for this earlier run.

This is a new test run, not a reuse of earlier device evidence. The authorized target is iStoreOS 24.10.1, x86_64/musl, with opkg/is-opkg, integrated mise 2026.8.14 and Kai's OpenCode CLI 1.18.32. Device addresses, credentials and machine-specific paths remain in private execution artifacts.

## Deployment

KSpeeder and ks-cli were built from `6fa3cc21b6e7` with build number `skills-review-fixes`:

```sh
rtk make LOCAL_BUILD_NUMBER=skills-review-fixes LOCAL_GOOS=linux LOCAL_GOARCH=amd64 local-build
```

Both binaries were copied through staging and atomically replaced, retaining backups. Kai's final iStoreOS on-device bundle uses skills code commit `5a12b7f0ec4d` and was exported through the repository tool and selected through its existing Agent symlink. The original OpenCode configuration was copied unchanged. Every staged binary/test file and all 98 final bundle files were SHA-256 checked on the target.

The resident service's live status and `/api/v1/capabilities` reported the new commit and required download routes. The actual TLS port came from current UCI configuration; no universal port assumption was tested.

## Device regression tests

Linux/amd64 test executables were compiled locally with `CGO_ENABLED=0` and run on the target, not merely compiled:

```sh
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go test -c -o "$OUT/$PACKAGE.test" "./$PACKAGE"
ssh "$SSH_TARGET" "$TEST_STAGE/tests/$PACKAGE.test -test.v -test.run '$PATTERN' -test.count=1 -test.timeout=60s"
```

PASS: 49 test/subtest results across seven packages:

| Package | Behavior verified |
| --- | --- |
| domainfold | Preserve 401/403/404/416/503 without disabling the whole source; abort truncated Git responses |
| multisourcefetcher | Accept matching and case-insensitive ranges; reject wrong ranges/offsets |
| splitcache_proxy | Accept legal range units; reject invalid Content-Range; preserve correct cached bytes |
| downloadcmd | Cached mirror error before fallback, partial-body abort, candidate isolation, truncated passthrough |
| chunkio | Closing one completed handle preserves other readers |
| docker_proxy | Abort truncated upstream responses |
| ks_ctl | Abort truncated upstream responses |

These controlled HTTP tests ran on the device. They do not imply a real Docker image pull or an authenticated fast-channel test. The cached-mirror 404 case was exercised by these controlled tests; the current real pip requests succeeded without encountering that particular cached 404.

## Real runtimes and dependencies

Two independent SSH calls through `istoreos-mise-runtime/scripts/exec.sh` produced identical HOME, PATH and mise directory facts. The HOME matched the system's configured Runtime directory. Explicit SDK provenance/version checks passed for Python 3.13.7, Node 24.21.0/npm 11.19.0 and Go 1.27.1.

Python 3.13.7 also passed a fresh installation with separate mise data/cache/config directories inside the integrated shell:

```sh
MISE_PYTHON_COMPILE=0 \
MISE_PYTHON_PRECOMPILED_OS=unknown-linux-musl \
MISE_PYTHON_PRECOMPILED_ARCH=x86_64 \
ks-cli mise install python@3.13.7
sh "$SKILLS/istoreos-mise-runtime/scripts/verify.sh" python 3.13.7
```

PASS: precompiled download, GitHub artifact attestations, extraction, exact interpreter provenance, ssl/sqlite3/bz2/lzma/ctypes/venv and pip. No compiler installation or global activation was performed. Node/Go SDKs were reused and verified; this run does not claim another cold installation of those SDKs.

The following maintained smoke commands passed in new project directories, with independent client caches or pip caching disabled:

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" pip 3.13.7 "$NEW_PIP_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" npm 24.21.0 "$NEW_NPM_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" go 1.27.1 "$NEW_GO_PROJECT"
sh "$SKILLS/istoreos-download-acceleration/scripts/evidence.sh" "$TOOL" "$CLIENT_LOG" "$CURRENT_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
```

PASS: venv idna 3.10 import and pip check; real is-number 7.0.0 install/ci, Node execution and lockfile integrity; explicit uuid v1.6.0 require/import, module download/verify and Go execution. A separate fresh module also passed `dependency.sh go 1.27.1 -- get -x github.com/google/uuid@v1.6.0`, `mod verify` and `run .`.

For all four recipes, the current-instance gateway window matched both metadata/index and artifact paths and returned `result=gateway-confirmed`. A gateway selecting its canonical origin was counted as gateway traversal. Upstream Go origin timeouts were observed, with successful gateway selection of another source; these were not client direct fallback. TLS/checksum/integrity and Go sumdb verification were retained.

## Findings fixed during this run

Real device/consumer inspection found and corrected three gaps:

1. Kai's resident instruction still prohibited apk, contradicting the supported detected-manager branch. It now delegates manager selection to the package skill. The new contract check reproduced the old prohibition before the fix; the 2 KiB resident prompt budget remains enforced.
2. Native `opkg find` could return empty for a regexp. The helper now falls back to the package list before reporting no candidates. Regression tests failed before the fix and passed afterward. Device regexp/limit, info fallback and file-owner limit checks all passed without refreshing package sources.
3. A live Kai run searched the login-shell mise installation before using the integrated helper. The dependency entrypoint documents the integrated check, the existing program-file contract and pip doctor after venv activation. For an authorized acceptance case with a supplied installed version, it now routes directly to smoke. The underlying helper still rejects command words in place of a program file.

## Kai behavior: functional pass, ordering gate not consistently met

The live CLI used its existing configuration and discovered the deployed runtime, dependency and package skills. A plain natural-language request for Python 3.13.7, a fresh venv and idna 3.10 automatically selected `istoreos-download-acceleration`; it did not specify a skill name.

```sh
OPENCODE_CONFIG=/usr/share/kai/agent/opencode.json \
  /usr/sbin/kai_session run --auto --format json --dir "$TEST_STAGE" "$NATURAL_LANGUAGE_TEST_REQUEST"
```

The initial invocation without `--auto` could not execute tools because the existing Bash policy is `ask`. The authorized test invocation used `--auto`, retaining explicit deny rules and leaving default configuration unchanged.

Final bundle `5a12b7f0ec4d`: CLI exit 0; the deployed smoke script completed. Independent venv checks confirmed Python 3.13.7, idna 3.10 and pip check. The gateway window captured before that CLI invocation matched both index and wheel requests and returned `result=gateway-confirmed`.

However, the strict Agent ordering check FAILED: that same final invocation first queried login-shell Python and ran pip doctor before the helper activated the venv. Three entrypoint guidance improvements were tried. One fresh run took smoke as its first execution command and passed; a subsequent fresh run still took the unnecessary login-shell route. Successful dependency installation is not evidence that every Agent diagnostic command obeyed the mise-exec precondition. Further wording optimization was stopped under the user's three-attempt rule. A deterministic Kai execution-layer constraint would change product behavior and requires the user's decision; it was not implemented in this task.

This is a remaining Agent-behavior limitation, not a failed gateway download or an observed system-package pollution. The existing scripts enter the integration and validate the supplied SDK/venv before performing dependency operations.

## Local checks and limits

The current checkout passed profile-smoke, generated consistency, catalog, context budgets, Agent bundle export and the actual Reasonix loader contract. Reasonix was checked locally; no device Reasonix model invocation is claimed. Actual apk, ARM and glibc devices remain untested. worker-tinygo code and tests were not changed or managed.

Temporary gateway logging was removed after all tests. The init script matched its backup byte-for-byte; hashes of mise/iStoreEnhance/Docker UCI configuration and the mise integration function remained unchanged. The Agent configuration matched the original bundle's configuration. Final status was healthy at commit `6fa3cc21b6e7`, with the final skills bundle selected. Rollback assets were retained; isolated test projects and the separate cold SDK stayed outside system/global dependency configuration.

Raw request logs, Agent traces and rollback assets remain private. No release/tag or remote Git push was performed.
