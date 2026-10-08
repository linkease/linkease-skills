# iStoreOS runtime/download implementation verification

Date: 2026-10-08. Scope: agentflow-3011 / kspeeder; primary delivery is istore-ai-helper/linkease-skills.

M1–M5 implementation and local acceptance completed. These results are from this task checkout, not historical device tests. No target device was supplied/authorized; device acceptance remains unexecuted.

## Delivery and boundaries

| Milestone | Delivered behavior | Local acceptance |
| --- | --- | --- |
| M1 | System/consumer/execution contract and bounded historical evidence in docs/architecture/runtime-download-contract.md | Repository/CLI/integration/consumer sources inspected; catalog and existing smoke baseline passed |
| M2 | Active opkg/is-opkg or apk detection, exact feed candidate/status checks; system integration prerequisite; noninteractive mise-exec program runner preserving HOME/shims, literal arguments and native exit | Fixture tests reject Ubuntu, ambiguous/missing databases, unavailable packages and unauthorized writes; repeated independent runner calls retain the same configured environment |
| M3 | Explicit Python precompiled arch/libc selection; Node legacy environment correction with verification retained; Go SDK provenance; separate install/project/global activation | x86_64/aarch64-musl and x86_64-glibc selection fixtures; unknown libc/arch rejection; wrong system interpreter, disabled checksums and wrong Go version rejected; specific failure diagnoses tested |
| M4 | pip/npm/Go modules routes, isolated real-dependency recipes, venv checks, health gates and metadata/artifact evidence classification | Command-boundary/negative tests and current-port/cache/fallback log fixtures passed; actual PyPI handler success/failure observability regression passed |
| M5 | Generated on-device/remote-control presets, runtime regression gates, actual Reasonix consumer test and generic consumer documentation | Deterministic generation/release, catalog, budgets, install/export/lifecycle/transport tests passed; actual Reasonix loader parses both modes |

Canonical changes are under components/system-packs/istoreos. No Ubuntu workflow was replaced; Linux/OpenWrt base packs, Windows/macOS presets and catalog.json have no diff against e5ba9ec05cc6c1160242084e65277a2723a8539c. Existing six presets remain the public index, so no catalog entry was added. iStoreOS presets were regenerated only with tools/generate-platforms.sh.

Important implementation commits: M1 06c2b2f; M2 1a9dffd; M3 fcfa4c3; M4 60bd045; M5 c252ba1. Separate regression commits precede the relevant behavior changes. Final self-review also fixed exact package availability/installed-state evidence (2c9f032) and version/network diagnostic classification (54720d5), with separate failing tests first.

KSpeeder changes were necessary to prove a successful PyPI index request: test commit 3cf459d and implementation 9eaf7be add completion status/HTTP status/bytes/host/path logging to the existing handler. Query strings are omitted, with a regression test for secret query data. This does not introduce a new route or change service defaults. Older deployed gateways lacking this event cannot receive automatic gateway-confirmed status from this recipe unless matching successful access evidence is captured by another supported mechanism; no upgrade was performed here.

## Exact verification commands and results

Commands below ran from the linkease-skills root unless another working directory is specified. All listed successful tests exited 0. Fixture output deliberately contains failed/blocked messages for asserted rejection cases; these are not test failures.

| Command | Result |
| --- | --- |
| `rtk sh components/system-packs/istoreos/drills/profile-smoke.sh` | PASS, including all new package/runtime/dependency/diagnosis suites and existing architecture/safety/app suites |
| `rtk sh tests/architecture/test-runtime-release-gate.sh` | PASS; deliberately injected runtime-test failure reaches the profile gate |
| `rtk sh tools/generate-platforms.sh` | Generated presets from canonical components |
| `rtk sh tools/verify-generated.sh` | PASS; canonical and generated trees match |
| `rtk sh tests/architecture/test-m4-generated.sh` | PASS; deterministic generation/drift/catalog contracts |
| `rtk sh tests/architecture/test-m2-canonical.sh` | PASS; canonical/on-device/remote-control composition |
| `rtk sh tests/architecture/test-catalog.sh` | PASS |
| `rtk sh tests/context-budget/test-m7-istoreos.sh` | PASS; catalog 2570 bytes, routing 1748 bytes, always-on prompts 1950 bytes |
| `rtk sh tests/install/test-m5-discovery.sh` | PASS; selection/discovery/dry-run/temporary installation |
| `rtk sh tests/install/test-agent-bundle-export.sh` | PASS; OpenCode Agent bundle export |
| `rtk sh tests/install/test-m10-lifecycle.sh` | PASS; lifecycle/ownership handling |
| `rtk sh tests/install/test-m10-release.sh` | PASS; two identical temporary builds, six presets/twelve archives, SHA-256/tree digests and install entrypoints; no publication |
| `rtk sh tests/contracts/test-m3-transports.sh` | PASS; controller/transport contracts |
| `rtk sh components/system-packs/istoreos/tests/test_runtime_install.sh` | PASS, including final glibc/unknown-libc cases |
| `rtk sh components/system-packs/istoreos/tests/test_runtime_diagnosis.sh` | PASS; nine evidence cases |
| `rtk git diff --check` | PASS |

Actual Reasonix consumer verification ran via:

```sh
# REASONIX_SOURCE_ROOT identifies a local read-only checkout, not a device address.
rtk env REASONIX_SOURCE_ROOT=/projects/workspace-linkease-ubuntu/linkease-github/istore-ai-helper/reasonix-kai \
  sh -c 'sh tests/install/test-reasonix-consumer.sh "$REASONIX_SOURCE_ROOT"'
```

Result: PASS, Reasonix revision 65b25b166cbc1e615e1282f609a1b60bba2106c9. The test installs only into temporary directories and uses a Go overlay to exercise the actual internal/skill loader. Both modes preserve description/triggers/owner/systems/auto-use/routing/fresh-data metadata, discover helper scripts, keep detailed data out of eager references and hide manual helpers from the automatic catalog. Reasonix source/config was not edited. Generic consumption uses `[skills].paths` or its actual convention directories; there is no invented installer `--consumer reasonix`.

Skill-creator quick_validate.py was also called from a temporary Python projection for the four changed primary skills: name/description/body PASS. Its schema does not accept the repository's established owner/systems/routing extensions. Those extensions were retained and tested by the repository tests plus the actual Reasonix loader; this is core/body validation, not a claim that the extended file passes the generic schema unchanged.

KSpeeder verification:

| Working directory | Command | Result |
| --- | --- | --- |
| kspeeder/kspeeder | `rtk go test ./downloadcmd -count=1` | PASS, 115 tests |
| kspeeder/kspeeder-cli | `rtk go test ./internal/app -count=1` | PASS, 230 tests |
| kspeeder/kspeeder | `rtk go test ./cmd/multi -run TestCapabilitiesEndpointPublishesVersionedServiceContract -count=1` | PASS, 1 test, after build prerequisites below |
| kspeeder root | `rtk bash scripts/test_ks_cli_docs.sh` | PASS |
| kspeeder root | `rtk bash scripts/test_ks_cli_openwrt_contract_docs.sh` | PASS |

Focused PyPI verification also passed (8 tests), from kspeeder/kspeeder:

```sh
rtk go test ./downloadcmd -run 'TestPyPIIndex|TestGatewayPyPI' -count=1
```

The capabilities test initially could not compile because this task worktree lacked embedded wwwroot assets and generated api/app.go. After adding the same minimal wwwroot/index.html fixture used by the repository non-Docker test target and running `rtk make gen-version-file`, it passed. Those newly created build-only files were removed afterward. No release tag/build/upload was started. Existing pinned docker-registry/gokit submodules were initialized to run tests; their gitlinks were not changed.

## What is and is not established

Local tests establish package/environment/version routing and error behavior using controlled command fixtures, current-port evidence classification using log fixtures, actual gateway handler behavior through HTTP tests, and actual Reasonix loader compatibility. They do not establish real OpenWrt feed availability, real downloads through an installed gateway, or live LLM selection accuracy. Codex/OpenCode installation/export is exercised in temporary directories, not an existing user's Agent configuration.

The maintained device recipes create a new isolated project and pinned third-party dependencies: Python venv + idna==3.10/import/pip check; npm is-number@7.0.0/install/ci/Node require plus lockfile integrity; Go explicit uuid@v1.6.0 require/import/download/verify/run and separate caches. Each successful client run still requires same-instance/time-window index/module and artifact log evidence. Cache-only/client-direct evidence is insufficient; a gateway selecting canonical origin is still gateway traffic.

No post-change real-device validation ran: opkg/apk images, x86_64/aarch64, musl/glibc, actual feeds/storage, SSH persistence, Python/pip, Node/npm and Go SDK/modules remain unverified on devices by this change. Historical user evidence is separately retained in the contract document; Python 3.13.7 is a scoped workaround, not latest, and the earlier Go result is not a current-checkout test. Node/npm has no successful device evidence in this session.

A later device test needs a suitable supplied target and explicit authorization. Keep target addresses/credentials/machine paths out of canonical skills. No system Python/global dependency configuration, device packages, installed Agent directories or default ports were modified. Kai's vendored System Pack snapshots/source locks are a separate consumer synchronization path and were not changed. No push, merge, publication or deployment occurred.
