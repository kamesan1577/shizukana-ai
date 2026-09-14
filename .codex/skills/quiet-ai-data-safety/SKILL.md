---
name: quiet-ai-data-safety
description: Mandatory safety guardrail when changing any local data source, persistence, permission, background processing, model input, diagnostics, or distribution behavior.
---

# Quiet AI Data Safety

Read `SECURITY.md` before making changes.

## Invariants

- No user data leaves the device.
- No cloud inference.
- No external API.
- No analytics or telemetry.
- No remote model download.
- No iCloud memory sync.
- No background mic.
- No background camera.
- Email and message bodies are out of scope.
- Source-derived memory must be purgeable by provenance.
- Revoked permissions remove corresponding derived memory.
- Deleted source data removes corresponding derived memory.
- Full reset removes the whole individual.
- Uninstall must not leave a resurrection identifier.

## Network-sensitive Apple APIs

Explicitly prevent implicit downloads where possible.

Photos:
- network access must remain disabled for asset requests.

Music:
- only use data proven available offline.

Maps/geocoding:
- do not introduce remote tile or reverse-geocode dependencies.

Any exception requires a product-level decision because it changes the complete-offline promise.
