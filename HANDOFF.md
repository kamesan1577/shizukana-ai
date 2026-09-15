# HANDOFF

## Status

Requirements: complete
Architecture: initial design complete
Implementation: not started

## Accepted product decisions

- iOS 27 / iPhone 16 target
- native Swift / SwiftUI
- on-device AI cognition; no private-data export to developer / unreviewed third-party systems
- OS-managed backup / restore and normal Apple platform services are allowed
- local bundled small model
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

## Next implementation steps

1. Create the public repository.
2. Install agent skills from `tools/AGENT_SKILLS.md`.
3. Create Xcode 27 SwiftUI app shell.
4. Add privacy/network-boundary CI guard before feature code.
5. Implement local memory schema + fixtures.
6. Implement deterministic Weak Attention with test seed.
7. Benchmark 0.5–1B Core AI model candidates on iPhone 16.
8. Implement a vertical slice:
   fixture memories → attention → model → utterance → specimen box.
9. Add PhotoKit feature-print ingestion.
10. Add background scheduling / local notification.
11. Build first RealityKit creature prototype.
12. Add remaining senses incrementally.

## Unresolved implementation choices

These do not require new product interviews unless they threaten the dogma.

- exact OSS license
- exact small model
- exact 3D asset pipeline
- persistence implementation details
- final attention weights
- exact utterance max token/character cap
- final sideload store
