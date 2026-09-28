# iPhone 16 / iOS 27 acceptance record

Issue #13 is the remaining device gate for MVP v0.1. The automated scenarios and simulator screenshots are in [MVP_ACCEPTANCE.md](MVP_ACCEPTANCE.md). This record deliberately contains no claimed device results: a physical iPhone 16 and an Apple signing team are required.

## Setup and evidence

1. On a Mac with Xcode 27, run `make project`, open `App/QuietApp.xcodeproj`, choose the `QuietApp` scheme and a physical iPhone 16 on iOS 27. Set a personal signing team for the app target. Enable WeatherKit for the App ID only if testing weather; use the optional `App/Resources/WeatherKit.entitlements` with a matching team capability. Do not commit credentials or profiles.
2. Install a fresh build. Keep the device's Apple Intelligence model installed and enabled for the model-available run. Record the model availability shown by the app, iOS build, app commit, signing capabilities used, and test date. Use a photo library you control; record only counts and coarse observations in this document, never photos, locations, event titles, prompts, or traces.
3. For each row, replace `Pending` with `Pass`, `Fail`, or `Blocked`, add a dated, redacted observation, and link to a private device test record if evidence contains personal data. Do not close #13 for `Blocked` rows.

| Scenario | Device procedure and expected observation | Result / evidence |
| --- | --- | --- |
| First launch and permissions | Fresh install shows the privacy explanation before any permission prompt. Start with no senses; grant Photos, location, activity, calendar, and notifications one at a time in Settings. Refusing any one sense leaves the app usable. | Pending |
| Fetal memory | With a representative library, allow Photos, resume or relaunch after an interruption, and inspect Debug Brain after seven Version taps. No duplicate memory on resume; sampling stays at most 48 photos and yields about 12–20 coarse fragments with enough sources. | Pending |
| Observation and speech | Across several ordinary days, inspect bounded Debug Brain traces. Recall selects five fragments when available; each accepted one-liner has real provenance, and the gate can record `SILENCE`. Do not add a manual speech control for this test. | Pending |
| Daily budget | Observe natural notification counts over several days; 0 is valid, daily maximum is 3, minimum spacing is 3 hours, and quiet hours suppress immediate speech. The 0/1/2/3 fixture itself is verified in CI. | Pending |
| Model unavailable | Disable Apple Intelligence or use another real unavailable state, then open the app. It shows unavailable status, produces no model utterance, and offers no cloud fallback. Restore the model afterward. | Pending |
| Source revoke and delete | With derived photo and calendar fragments present, remove one photo, then revoke Photos and Calendar access in iOS Settings. Relaunch and check that corresponding derived fragments and links are purged; old specimen text may remain without source links. | Pending |
| Full reset | With specimens, fragments and any pending Dream present, use “この子の記憶をすべて消す”. Confirm the specimen box, trace, memory, individual state and pending notifications are gone; next launch is a new empty individual. | Pending |
| Background and notification | With notifications authorized, leave the app inactive across OS background opportunities. Check that refresh or Visits can collect coarse observations and that any reserved local Dream is delivered no earlier than its scheduled time. OS scheduling is opportunistic; record elapsed time and conditions rather than treating a missed deadline as proof of a bug. Terminate and relaunch to check reconciliation. | Pending |
| Notification deep link | Tap a delivered utterance notification. Its full text matches the specimen detail, and the correct specimen opens even if the app was terminated. | Pending |
| Accessibility and creature | On device, navigate onboarding, home, settings, specimen box and detail with VoiceOver and largest useful Dynamic Type. Enable Reduce Motion and touch the central creature: labels and hit regions remain usable, with a short restrained reflex. | Pending |
| Network-off cognition | First ensure the on-device model is installed and the desired photo assets are available locally. Turn off Wi-Fi and cellular, disable weather, then exercise normal foreground cognition. A model-available run remains local; an unavailable run remains silent. Record only outcome, not personal prompt content. | Pending |
| WeatherKit (optional entitlement) | With a matching signed WeatherKit capability and location access, opt in to weather. Check a coarse weather observation. If the team lacks the capability, mark `Blocked`; all other senses must keep working. | Pending |

## Completion rule

Record the actual observations on a physical iPhone 16 running iOS 27, investigate every `Fail`, and map the results back to [MVP_ACCEPTANCE.md](MVP_ACCEPTANCE.md). A green simulator CI run verifies the automated part only. Close Issue #13 once every required device scenario has evidence; the optional WeatherKit entitlement may remain explicitly blocked if unavailable.
