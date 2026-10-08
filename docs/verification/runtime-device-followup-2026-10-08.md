# Device follow-up: reproducible pip failure and resolution

Date: 2026-10-08. Continuation explicitly requested after the user confirmed their Python installation, venv/pip/npm/go get results. The prior report is historical evidence of those test runs; this follow-up records new tests and corrections.

## Why the previous results differed

The Python precompiled command supplied by the user was already successful in the prior cold SDK test. gcc is absent, so this remains the scoped x86_64/musl recipe in the integrated mise-exec environment:

```sh
MISE_PYTHON_COMPILE=0 \
MISE_PYTHON_PRECOMPILED_OS=unknown-linux-musl \
MISE_PYTHON_PRECOMPILED_ARCH=x86_64 \
ks-cli mise install python@3.13.7
```

The command also exits 0 in this follow-up against the previously verified isolated Python data/cache; it is an already-installed check, not another cold installation. Architecture/libc selection still must match each target. npm and Go modules had passed previously; the failures reported were pip repeatability and a separate cold Node SDK download, not all dependencies or Python installation.

A minimal real HTTP reproduction produced: wheel 200 → metadata 404 → second metadata 200; canonical metadata 200. This rules out gcc, venv activation and interpreter selection as the direct cause of that 404. The cached preferred PyPI mirror had the wheel but lacked `.whl.metadata`. The gateway committed its 404 before racing another source, then appended valid metadata while retaining status 404. Cached 503 errors had the same defect. A later request could succeed after route state changed.

The public handler regressions failed before implementation with the original status/error prefix plus valid metadata. Fix 2bfdc79 (tests 3536ce8, 1f69f96) defers failures until route reselection finishes if no response has begun. Once headers/body have started, failures still abort instead of mixing archive bytes. Authentication, TLS, signatures and checksum verification are retained; no mirror, device port or global dependency configuration was changed.

## New real-device results

The same authorized iStoreOS 24.10.1 x86_64/musl/opkg device received locally built gateway and CLI 0.8.3, commit 2bfdc795fbb5, build-number skills-cache-fix. Both local/device binary SHA-256 values match. Previous binaries/init/UCI were backed up privately before replacement. No release/publication or upstream merge occurred.

Three sequential rounds passed, each with new project directories and independent client caches:

| Case per round | Actual operations | Result |
| --- | --- | --- |
| Python venv / pip | Python 3.13.7 venv, actual ks-cli pip no-cache wheel/metadata install, idna 3.10 import, pip check | 3/3 PASS |
| npm | Existing Node 24.21.0, is-number 7.0.0 install and ci using separate caches, integrity-bearing lockfile, actual Node require/run | 3/3 PASS |
| Go modules | Verified isolated Go 1.27.1, explicit uuid requirement/import, download, module verify, program run | 3/3 PASS |
| go get | New module/source and separate GOMODCACHE/GOCACHE/GOPATH, ks-cli go get -x github.com/google/uuid@v1.6.0, generated requirement/checksum, mod verify, actual import/run | 3/3 PASS |

All 12 client cases exit 0. Their separate current-instance request windows each return `gateway_metadata=matched`, `gateway_artifact=matched`, `result=gateway-confirmed`. Go sumdb remained enabled, GOTOOLCHAIN=local and GOENV=off; Python dependencies stayed in fresh venvs. No successful direct-client fallback is mislabeled as gateway success.

The new real gateway logs reproduce the original trigger: cached aliyun-pypi metadata request fails 404, then the *same request* races and successfully fetches canonical metadata (10158 bytes). The pip client succeeds without manual retry. This is direct evidence that the fix recovers the bug, not merely that a different cached source avoided it.

Node 24.21.0 also passed a separate **cold installation** into new mise data/cache: gateway delivered 60046506 bytes, SHA-256 checksum and extraction completed, exact Node version/provenance and npm 11.19.0 verified, no global activation. The Node code was not changed. Previous logs show a slow transfer interrupted by unexpected EOF, followed by 30-second response timeouts; range probes now return 206 and the complete stable-instance repeat succeeded. This narrows the previous failure to that transfer/service/network episode, not gcc or an inherently incompatible Node backend. The available logs do not establish the exact upstream cause of the earlier EOF.

The unofficial musl release's GPG signature endpoint returns 404; mise reports `gpg signature not found, skipping verification`. No verification setting was disabled by the test, and SHA-256 succeeds, but **GPG attestation/signature validation is not established**. Do not turn this native warning into a claim that all signatures passed. A further real npm example using the newly installed isolated Node SDK (not the previously existing SDK) completes install/ci, integrity, actual Node require and current-window gateway confirmation.

## Verification commands and limits

KSpeeder checkout:

```sh
# From kspeeder/:
rtk go test ./downloadcmd -run TestGatewayCachedMirror -count=1
rtk go test ./downloadcmd -count=1
# From kspeeder-cli/:
rtk go test ./internal/app -count=1
# From repository root:
rtk make LOCAL_BUILD_NUMBER=skills-cache-fix local-build
```

PASS: four cached-mirror test/subtest results, 119 downloadcmd results, 230 CLI results; build completed. The negative HTTP cases reproduce 404/503 error-prefix contamination before the fix. Partial-body behavior was characterized successfully before and after the fix.

The privately staged repeated program is invoked on every remote session through:

```sh
ssh "$SSH_TARGET" sh "$SKILLS/istoreos-mise-runtime/scripts/exec.sh" "$REPEAT_PROGRAM" "$RUN" "$VERIFIED_SDK_RUN"
```

Inside that same integrated shell it executes the supplied Python command and, for each fresh directory:

```sh
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" pip 3.13.7 "$NEW_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" npm 24.21.0 "$NEW_PROJECT"
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/smoke.sh" go 1.27.1 "$NEW_PROJECT"
# go get uses a separate initialized module and importing program:
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/dependency.sh" go 1.27.1 -- get -x github.com/google/uuid@v1.6.0
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/dependency.sh" go 1.27.1 -- mod verify
KAIPLUS_CONFIRMED=1 sh "$SKILLS/istoreos-download-acceleration/scripts/dependency.sh" go 1.27.1 -- run .
sh "$SKILLS/istoreos-download-acceleration/scripts/evidence.sh" "$TOOL" "$CLIENT_LOG" "$CASE_GATEWAY_LOG" "$ACTUAL_TLS_PORT"
```

SDK caches were separate from global Runtime selection. npm deliberately used the existing Node SDK; the separate cold SDK result above provides installation evidence. The gateway remains stable during all in-flight SDK downloads; logging init changes are restored after tests, preserving current UCI and original Agent configuration. Raw addresses, paths, traces and backups remain outside the repository.

Skills changes add the concrete metadata failure diagnosis, distinguish SDK installation from npm acceptance, describe the tested go get variant, and align documentation with direct-race completion evidence. Canonical iStoreOS documentation and generated on-device/remote-control presets are synchronized. Ubuntu and other system packs remain unchanged. Catalog and generated-consistency checks pass. Real apk/ARM/glibc/other-version coverage is still not established; this follow-up does not claim universal source/mirror behavior.

## Subsequent local compatibility review

The review reproduced a legacy query regression before implementation: `opkg-find.sh <regexp> [limit]` had become a literal search that ignored the result limit. The related info regexp fallback and file query limit were also lost. A shared `legacy-query.sh` now preserves these opkg interfaces without refreshing feeds. Actual apk systems continue to use the detected native `package.sh` actions; legacy opkg queries report that boundary explicitly. Canonical iStoreOS sources and both generated iStoreOS presets were updated; other system packs were not changed.

The following commands passed in the current skills checkout after the fix:

```sh
sh components/system-packs/istoreos/tests/test_legacy_package_queries.sh
sh components/system-packs/istoreos/drills/profile-smoke.sh
sh tools/verify-generated.sh
sh tests/architecture/test-catalog.sh
sh tests/architecture/test-m4-generated.sh
sh tests/architecture/test-runtime-release-gate.sh
sh tests/context-budget/test-m7-istoreos.sh
sh tests/install/test-agent-bundle-export.sh
sh tests/install/test-reasonix-consumer.sh "$REASONIX_SOURCE_ROOT"
```

The Reasonix check uses its actual loader with temporary test resources. These are local checks, not another device run. The earlier device evidence above applies to the previously deployed bundle and gateway; the latest compatibility fixes have not been deployed or validated on that device.
