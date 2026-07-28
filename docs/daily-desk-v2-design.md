# Daily Desk v2 — Design

## Understanding summary

- Daily Desk is a private, native macOS utility for morning planning, protected focus, and instant idea capture.
- The product stays lightweight: no account, analytics, cloud inference, or project-management overhead.
- A configurable global shortcut opens capture from any app.
- Captures are stored as ordinary Markdown in a user-selected Obsidian vault.
- Ollama enriches notes locally with a title, summary, normalized tags, a possible next step, and verified links to related ideas.
- A Desk Tile provides an always-available compact view, complemented by signed small and medium WidgetKit extensions using a shared App Group snapshot.
- Notifications are restrained to morning planning, focus completion, and an optional evening review.

## Assumptions and non-functional requirements

- Single-user, local-first operation on this Apple Silicon Mac.
- Raw capture must feel instant and never wait for inference.
- The original thought is always preserved verbatim before AI work begins.
- Atomic file writes prevent partial or corrupted Markdown.
- Ollama failure, model absence, or malformed model output never loses a capture.
- The idea index should remain responsive with thousands of notes by caching embeddings and refreshing only modified files.
- The chosen vault is the durable source of truth; app-local state is replaceable metadata.
- No calendar integration, collaboration, or mobile companion in v2.

## Accepted interaction design

1. First run selects an Obsidian vault, verifies Ollama, installs models, chooses notification times, and explains the capture shortcut.
2. Morning planning carries unfinished priorities forward and helps select up to three meaningful outcomes.
3. The global capture panel saves immediately, closes, and enriches the note in the background.
4. Focus mode shows the current priority and remaining time in the menu bar and Desk Tile.
5. The idea inbox distinguishes captured, processing, enriched, and failed states.
6. The Desk Tile shows priorities, timer controls, and quick capture.

## Obsidian note contract

```markdown
---
id: "UUID"
created: 2026-07-17T16:30:00-04:00
type: idea
status: inbox
summary: "One-sentence description"
tags:
  - idea
  - topic/productivity
related:
  - "[[Existing Idea Name]]"
source: daily-desk
ai_model: gemma3:12b
---

# Clear idea title

## Original thought

The exact, unedited capture.

## Summary

A concise explanation preserving the original intent.

## Connections

- [[Existing Idea Name]] — semantically related idea

## Next step

- [ ] One small action, when the idea implies one
```

The template and AI instruction are editable in Settings. Generated output is decoded through a fixed JSON schema before rendering. Tags are normalized to lowercase Obsidian tags. Wikilinks are emitted only for filenames that exist in the vault.

## Architecture

- **SwiftUI/AppKit shell:** main dashboard, menu-bar popover, capture panel, morning planner, Settings, and Desk Tile.
- **Global hotkey:** a system hotkey registration that does not inspect keystrokes or require Accessibility permission.
- **Vault service:** folder selection, stored vault path, atomic Markdown rendering, safe filename generation, and note scanning.
- **Ollama client:** localhost-only HTTP client for health checks, model installation, schema-constrained chat, and embeddings.
- **Enrichment pipeline:** save raw note → summarize/tag → update embedding index → select related files → validate links → atomically replace enriched note.
- **Embedding index:** app-local cache keyed by relative path and modification date. `embeddinggemma` vectors are compared with cosine similarity.
- **Notifications:** native local notifications for morning planning and focus completion.
- **Shortcuts:** App Intents for Capture Idea, Start Focus, and Open Morning Plan.

## Error handling and edge cases

- No vault: retain capture in the app inbox and prompt for a folder; retry after configuration.
- Ollama unavailable or model missing: keep `status: needs-enrichment`, show a non-blocking status, and expose Retry.
- Invalid structured output: retry once with a repair instruction, then preserve the raw note.
- Filename collision: append a timestamp and short UUID.
- Vault moved: show a reconnect prompt without deleting the stored path or captures.
- Existing manually edited note: compare modification dates before replacement and write an enriched sibling rather than overwrite unexpected changes.
- Notification permission denied: all features continue without notifications.

## Testing strategy

- Unit tests for template rendering, YAML escaping, tag normalization, filename safety, cosine similarity, state persistence, and failure recovery.
- Mocked URL protocol tests for Ollama health, structured output, malformed output, embeddings, and server absence.
- Filesystem tests use isolated temporary vaults and verify atomic capture/enrichment behavior.
- Manual smoke tests cover hotkey capture, notification permission, menu-bar operation, Desk Tile, Shortcuts discovery, and signed app launch.

## Decision log

1. **Native SwiftUI/AppKit** retained for a small, Mac-like utility with no web runtime.
2. **Obsidian Markdown** selected as the durable store so ideas remain portable and inspectable.
3. **Ollama** accepted instead of an embedded runtime for easier model management and upgrades.
4. **`gemma3:12b` + `embeddinggemma`** selected as separate generation and similarity models.
5. **Capture-before-enrichment** chosen so model latency or failure cannot lose a thought.
6. **Tags plus verified wikilinks** chosen: tags group themes; wikilinks connect individual notes.
7. **Desk Tile plus WidgetKit** delivered: the tile remains the richer interactive surface, while small and medium signed widgets provide ambient status and deep links.
8. **Shared App Group snapshots** selected for widget data so the extension stays lightweight and never opens the vault or Ollama directly.

## Research basis

- Users of comparable Mac tools repeatedly value quick entry, menu-bar access, privacy, shortcuts, and low maintenance.
- Apple supports interactive Mac widgets through WidgetKit and shared data through signed App Groups.
- Ollama supports JSON-schema structured outputs and local embedding APIs.
- Obsidian supports YAML properties, tag lists, and wikilinks in ordinary Markdown.
