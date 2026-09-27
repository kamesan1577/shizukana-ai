# MVP v0.1 acceptance record

This record maps `spec/current/README.md` §22 to evidence. Simulator evidence does not establish real-device behavior, Apple account entitlements, or permission behavior against a personal library.

| §22 | Evidence | Remaining verification |
| --- | --- | --- |
| 1 | iPhone 16 simulator build, unit and UI tests in the iOS workflow | iOS 27 on a physical iPhone 16 |
| 2, 8, 10, 11 | `CoreTests.gateAcceptsOrSilences`, `AppTests.testGroundedWakeThenThreeHourSilence`, and `testResetAndNoCloudFallback`; `LocalModel` uses a fresh Foundation Models session | Natural-language quality with an available on-device model |
| 3 | Independent adapters in `App/Sources/Senses.swift`; progressive controls in Settings | Real permissions, WeatherKit entitlement, and device signals |
| 4, 5, 16 | `retentionAndPurge`, `consolidationRetainsEverySourceForPurge`, `purgingOneSourceCancelsQueuedDream` | Revocation and deletion on a device library |
| 6 | `prenatalSamplingIsBoundedAndReproducible` covers 48 sources and 12–20 fragments | Representative photo library and interruption/resume on device |
| 7 | `recallIsSeededAndIncludesNoise` covers five unique selections with a fixed seed | Longer-term diversity in real use |
| 9 | `BudgetPolicy.limit` encodes 20/55/20/5 percent for 0/1/2/3; gate tests zero and interval; budget persists in SwiftData | Multi-day notification behavior on device |
| 12, 13 | App refresh and Visits opportunities, local Dream reservation and reconciliation in `CreatureRuntime` | Background delivery timing, termination and deep link on device |
| 14, 15, 18 | iPhone 16 UI test covers home, settings, specimen entry, and absence of text input; attached screenshots in the workflow artifact | Touch response and accessibility on device |
| 17 | `resetRemovesEntireIndividual`, `testSwiftDataRoundTripAndErase`, and `testResetAndNoCloudFallback` | OS notifications and permissions after reset on device |
| 19 | Seven taps unlock bounded in-memory Debug Brain trace; fixed-seed Recall test | Full multi-day trace inspection with real model |
| 20 | Native SwiftUI and iPhone 16 simulator screenshots reviewed | VoiceOver, Dynamic Type, Reduce Motion and HIG review on device |
| 21 | `scripts/privacy-guard.sh` runs in CI; no app-controlled networking or cloud AI dependency | Network-off device run and external review of new transfer paths |

The CI run and its `iphone16-test-results` artifact are linked from PR #15. A green simulator run is the automated gate; the physical iPhone 16 and entitlement-dependent scenarios remain open under Issue #13.
