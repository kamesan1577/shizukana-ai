---
name: quiet-ai-dogma
description: Mandatory constitutional guardrail for any feature, architecture, UI, model, memory, notification, or product decision in 静かなAI.
---

# Quiet AI Dogma

Before any non-trivial work, read `spec/invariants/README.md`.

Treat it as higher priority than implementation convenience.

Reject or redesign any change that:

- turns the product into a useful assistant;
- adds chat, prompting, regenerate, or manual speaking;
- lets a strong model fully understand the user's life and merely act weak;
- makes the creature grow smarter;
- converts the product into a precise life-log dashboard;
- removes the user's role in interpreting ambiguous language;
- adds cloud inference;
- exports user-derived private data to developer-controlled systems, analytics, ads, or unreviewed third parties;
- makes the creature into a conventional cute mascot or pet game.

Do not reject a design merely because an Apple OS / platform service may use the network.
OS-managed backup / restore, iCloud-backed Apple framework access, MapKit / Apple Maps, geocoding, and similar platform services are compatible with the dogma when they do not become a hidden export path for the creature's private memory or model context.

When uncertain, prefer less capability, less explanation, less UI, and more interpretive space.
For data handling, prefer explicit boundaries and data minimization over a blanket 'zero network' rule.

A successful feature should make the user think:
「何言ってんだこいつ。でも、あれのことかも。」

Not:
「便利になった。」
