---
name: quiet-ai-cognition
description: Use for memory, perception, retrieval, attention, model, prompt, and utterance changes. Prevents accidental over-intelligence.
---

# Quiet AI Cognition Contract

Read `spec/invariants/README.md` and `ARCHITECTURE.md`.

## Required properties

- Weakness must be structural, not roleplay.
- Do not pass the complete life history to a strong LLM.
- Keep conscious context small: normally 3–7 fragments.
- Retrieval should include noise and imperfect recall.
- Old memories decay in recall probability, not necessarily storage.
- Mixed memories are allowed.
- Every utterance must trace to real fragments.
- If nothing meaningful catches attention, silence is valid.
- One-line output only.
- No precise explanation of why the output occurred.
- Model capability must not increase over time.
- Memory may deepen without language competence improving.

## Review questions

- Did this change make recall too accurate?
- Did it make the model understand too much?
- Did it turn ambiguity into explanation?
- Did it improve utility at the expense of presence?
- Could the same experience be achieved with a weaker representation?

If yes, redesign.
