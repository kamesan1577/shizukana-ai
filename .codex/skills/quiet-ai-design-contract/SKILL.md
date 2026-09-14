---
name: quiet-ai-design-contract
description: Mandatory UI, 3D, motion, and interaction design guardrail for 静かなAI. Enforces Apple-native HIG quality and rejects generic AI slop.
---

# Quiet AI Design Contract

Read:

1. `spec/invariants/README.md`
2. `DESIGN.md`
3. the installed Apple HIG / apple-design skill
4. installed anti-slop skills

Apple HIG is authoritative for platform behavior.

## Required result

The interface should look like it was designed by a professional iOS product designer,
not generated from generic frontend patterns.

The normal app chrome must feel native to iOS.
The creature is the intentional anomaly.

## Hard rejects

- generic AI blue/purple gradients
- dashboard layouts
- chat bubbles
- card soup
- glass on every surface
- decorative glow without purpose
- emoji icons
- arbitrary custom controls where a native control exists
- fake metrics
- gamification
- overly cute pet UI
- unnecessary copy
- UI that explains the AI's internal meaning

## Liquid Glass

Use only where platform hierarchy and function justify it.
Do not confuse iOS 27 visual language with generic glassmorphism.

## Delivery gate

Before completion:

- run on iPhone 16 / iOS 27 simulator or device;
- capture screenshots;
- run Apple HIG review;
- run anti-slop review;
- verify Dynamic Type;
- verify VoiceOver;
- verify Reduce Motion;
- verify touch targets;
- verify the creature remains the only strong visual signature.
