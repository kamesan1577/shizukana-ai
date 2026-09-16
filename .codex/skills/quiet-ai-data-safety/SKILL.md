---
name: quiet-ai-data-safety
description: Mandatory safety guardrail when changing any local data source, persistence, permission, background processing, model input, diagnostics, networking, or distribution behavior.
---

# Quiet AI Data Safety

Read `SECURITY.md` before making changes.

## Invariants

- AI memory, attention, association, model input, inference, and utterance generation stay on-device.
- Do not send user-derived private data to developer-controlled servers, cloud AI, analytics, ads, or unreviewed third parties.
- No cloud inference.
- No background mic.
- No background camera.
- Email and message bodies are out of scope.
- Source-derived memory must be purgeable by provenance.
- Revoked permissions remove corresponding derived memory.
- Deleted source data removes corresponding derived memory.
- Full reset removes the whole individual.
- Uninstall must not leave a hidden resurrection identifier.

Network access itself is not forbidden.
OS-managed backup / restore and normal Apple platform services are not privacy violations solely because they may use the network.

## Apple platform services

Photos:
- iCloud-backed PhotoKit asset retrieval is allowed when performed through the user's granted system access.
- do not upload photos, image features, or AI context to a custom endpoint.

Music:
- MusicKit / Apple service use is allowed when useful.
- do not mix unrelated private memory into search requests.

Maps/geocoding:
- MapKit / Apple Maps / geocoding may be used.
- do not attach the creature's memory, prompt, utterance history, or unrelated life-log context to custom network requests.

Backup:
- OS-managed backup / restore is allowed.
- do not force app data out of backup merely to preserve a 'zero network' claim.

## Review-required network paths

A product-level privacy review is required before adding:

- custom `URLSession` / `Network.framework` endpoints;
- developer-controlled backends;
- third-party SDKs that receive identifiers or user data;
- app-managed cloud memory sync;
- remote WebViews that receive user-derived data.

For each reviewed path, document destination, fields, purpose, retention, user control, and whether the feature can work without the transfer.

The goal is not complete network isolation. The goal is preventing unexplained export of the user's life data.
