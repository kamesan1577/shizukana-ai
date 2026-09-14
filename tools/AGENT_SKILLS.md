# Agent skills

## Project-local skills

Already part of this starter pack:

- `quiet-ai-dogma`
- `quiet-ai-cognition`
- `quiet-ai-design-contract`
- `quiet-ai-data-safety`

These are the permanent project contract.

## External design skills to install

### Apple Design Skill

Source:
`dickwu/apple-design-skill`

Purpose:

- Apple Human Interface Guidelines
- native iOS patterns
- Liquid Glass
- typography
- accessibility
- platform components

Install from the repository root:

```bash
npx skills add dickwu/apple-design-skill
```

### anti-slop

Source:
`miqdadbadjuber/anti-slop`

Purpose:

- generic AI UI detection
- UI anti-slop
- accessibility/human checks
- mobile layout checks
- delivery gate

Project-local install:

```bash
npx skills add miqdadbadjuber/anti-slop
```

The upstream package supports Codex's `.codex/skills/` location.

## Rule

These external skills do not override `DESIGN.md` or Apple HIG.

Priority:

1. project dogma
2. Apple HIG
3. project DESIGN.md
4. anti-slop
