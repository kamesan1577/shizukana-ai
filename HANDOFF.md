# HANDOFF

## Status

Requirements: complete
Architecture: initial design complete
Implementation: draft PR #15 contains the MVP vertical slice. iPhone 16 simulator
build, Core/App/UI tests, privacy inventory and screenshots pass in CI. See
`docs/MVP_ACCEPTANCE.md` for evidence and the device-only gate.

Device-only acceptance remains separate from simulator CI: real iPhone 16 permissions,
Foundation Models availability, background opportunities, and UI/accessibility review.

## Accepted product decisions

- iOS 27 / iPhone 16 target
- native Swift / SwiftUI
- on-device AI cognition; no private-data export to developer / unreviewed third-party systems
- OS-managed backup / restore and normal Apple platform services are allowed
- Foundation Models `SystemLanguageModel` for MVP; bundled model remains an adapter option
- weak perception + weak attention + small LM
- 3–7 conscious fragments per utterance
- long-term imperfect recall
- no capability growth
- real-life-grounded ambiguous one-liners
- 0–3 notifications/day, silent days allowed
- no manual generation / no chat
- full utterance in notification
- specimen-box history
- centered 3D deep-sea embryonic creature
- touch = biological reflex, not conversation
- staged permissions
- partial senses supported
- fetal memory from historic local data
- source deletion / permission revoke purges derived memory
- reset wipes the individual
- uninstall = death, reinstall = new individual unless normal OS backup / restore semantics apply
- no Face ID app lock
- no background microphone/camera
- OSS from start
- sideload-first, App Store secondary
- 1–2GB app size acceptable
- Developer Mode exposes internal trace
- Apple HIG mandatory
- anti-slop mandatory for UI review

## Next acceptance steps

1. Sign and run on a physical iPhone 16 with an available on-device model.
2. Record real permission, PhotoKit and source-revocation behavior.
3. Record background and local-notification delivery across termination.
4. Review VoiceOver, Dynamic Type, Reduce Motion and network-off cognition.
5. Resolve Issue #13 and move PR #15 out of draft only after device evidence is recorded.

## Unresolved implementation choices

These do not require new product interviews unless they threaten the dogma.

- final sideload store
- optional WeatherKit signing/entitlement for a paid developer team
