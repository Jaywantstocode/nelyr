# Nelyr implementation plan

This plan turns Daily Desk into Nelyr without breaking the data, permissions, or
automation already in use.

## Compatibility rules

- Present the product, app, widget, services, documentation, and distributable
  artifacts as **Nelyr**.
- Keep the existing bundle identifiers, App Group identifier, UserDefaults
  keys, Application Support folder, and legacy URL scheme. macOS ties
  permissions and shared containers to these values; changing them would make
  the upgrade look like a different app.
- Add `nelyr://` as the preferred URL scheme while continuing to accept
  `dailydesk://` links.
- Keep stored Obsidian notes and templates in place. A brand change must never
  rewrite or move a user's vault.
- Save the raw capture first. AI, licensing, research, and network failures may
  reduce enrichment but must never lose the original thought.

## Batch 1 — Brand migration

1. Generate and review a Nelyr icon concept.
2. Create a deterministic vector master and 1024 px app icon.
3. Rename the Xcode project, app target, widget target, Swift package product,
   test import, scheme, window titles, menu items, services, and build outputs.
4. Keep legacy persistence identifiers and document why they remain.
5. Rewrite the public README around Nelyr's local-input-layer positioning.
6. Regenerate the Xcode project and run the full test suite.

## Batch 2 — Community and Pro boundary

1. Introduce public capability definitions for capture, transcription, OCR,
   knowledge enrichment, and research.
2. Add a `FeatureProvider` that supplies Community implementations by default.
3. Route optional features through injected capabilities instead of scattered
   build flags.
4. Make the no-Pro-provider path explicit, usable, and testable.
5. Document the future private `NelyrProKit` integration point.

## Batch 3 — Release verification

1. Build the signed Release app and embedded widget.
2. Upgrade over the installed Daily Desk build and confirm settings, widget
   snapshots, vault access, shortcuts, and permissions remain available.
3. Validate both `nelyr://` and legacy `dailydesk://` routes.
4. Re-run secret, private-path, license, and generated-artifact checks.
5. Commit the audited Community source.

## Batch 4 — Public launch

1. Re-authenticate the GitHub CLI for `Jaywantstocode`.
2. Create the public `Jaywantstocode/nelyr` repository.
3. Push `main`, verify the rendered README and license, and confirm CI starts.
4. Publish signed binaries later through a release workflow; keep signing
   credentials and future Pro/payment code out of the public repository.
