# MVP v0.1 acceptance record

This record maps `spec/current/README.md` §22 to evidence. Simulator evidence does not establish real-device behavior, Apple account entitlements, or permission behavior against a personal library.

| §22 | Evidence | Remaining verification |
| --- | --- | --- |
| 1 | iPhone 16 simulator build, unit and UI tests in the iOS workflow | iOS 27 on a physical iPhone 16 |
| 2, 8, 10, 11 | `CoreTests.gateAcceptsOrSilences`, `AppTests.testGroundedWakeThenThreeHourSilence`, `testSyntheticDaysRespectZeroThroughThreeBudgets`, and `testResetAndNoCloudFallback`; `LocalModel` uses a fresh Foundation Models session | Natural-language quality with an available on-device model |
| 3 | Independent adapters in `App/Sources/Senses.swift`; progressive controls in Settings | Real permissions, WeatherKit entitlement, and device signals |
| 4, 5, 16 | `retentionAndPurge`, `consolidationRetainsEverySourceForPurge`, `purgingOneSourceCancelsQueuedDream` | Revocation and deletion on a device library |
| 6 | `prenatalSamplingIsBoundedAndReproducible` covers 48 sources and 12–20 fragments | Representative photo library and interruption/resume on device |
| 7 | `recallIsSeededAndIncludesNoise` covers five unique selections with a fixed seed | Longer-term diversity in real use |
| 9 | `BudgetPolicy.limit` encodes 20/55/20/5 percent for 0/1/2/3; a four-day fixture verifies all limits and persisted use; budget persists in SwiftData | Multi-day notification behavior on device |
| 12, 13 | App refresh and Visits opportunities, local Dream reservation and reconciliation in `CreatureRuntime`; `testDreamReconciliationReschedulesThenRecordsDeliveredSpecimen` checks missing reservation and eventual specimen persistence | Background delivery timing, termination and deep link on device |
| 14, 15, 18 | iPhone 16 UI test covers home, settings, specimen entry, and absence of text input; attached screenshots in the workflow artifact | Touch response and accessibility on device |
| 17 | `resetRemovesEntireIndividual`, `testSwiftDataRoundTripAndErase`, and `testResetAndNoCloudFallback` | OS notifications and permissions after reset on device |
| 19 | Seven taps unlock bounded in-memory Debug Brain trace; fixed-seed Recall test | Full multi-day trace inspection with real model |
| 20 | Native SwiftUI and iPhone 16 simulator screenshots reviewed; automated accessibility audits cover the home screen and settings labels, clipping and hit regions; an accessibility extra-large text launch and screenshot cover settings | VoiceOver, Reduce Motion and HIG review on device; Dynamic Type throughout the full flow on device |
| 21 | `scripts/privacy-guard.sh` runs in CI; no app-controlled networking or cloud AI dependency | Network-off device run and external review of new transfer paths |

The [iPhone 16 / iOS 27 CI run](https://github.com/kamesan1577/shizukana-ai/actions/runs/36410737741) passed, and its [iphone16-test-results artifact](https://github.com/kamesan1577/shizukana-ai/actions/runs/36410737741/artifacts/10964940877) contains screenshots and test results. The merged reconciliation regression also passed in [main CI #26](https://github.com/kamesan1577/shizukana-ai/actions/runs/36414860057). A green simulator run is the automated gate; physical iPhone 16 and entitlement-dependent scenarios remain open under Issue #13. Record actual results in [DEVICE_ACCEPTANCE.md](DEVICE_ACCEPTANCE.md).

## Lifecycle completion pass (2026-10-04)

This pass adds regression coverage for foreground re-entry, reset and source purge
during suspended inference, cancelled cognition, persistence failure before notification,
clock-driven/idempotent Dream reconciliation, quiet-hour changes, bounded daily photo
selection, draft expiry, and provenance across consolidation/capacity eviction.

Local `scripts/privacy-guard.sh` and `git diff --check` passed. Swift/Xcode are
unavailable in the Linux editing environment; the new Swift tests require the exact
PR commit's iPhone 16 / iOS 27 CI result before this automated gate can be marked passed.
Physical-device scenarios in `DEVICE_ACCEPTANCE.md` remain pending.
