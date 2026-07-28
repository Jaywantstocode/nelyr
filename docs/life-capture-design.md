# Daily Desk — Life Capture Design

## Understanding summary

- Daily Desk captures the user's whole life rather than treating every entry as a business idea.
- Every enriched note has one fixed type and one to three fixed life areas.
- The type vocabulary is `idea`, `goal`, `reflection`, `memory`, `learning`, and `question`.
- The area vocabulary is `self`, `relationships`, `health`, `work`, `finance`, `creativity`, `home`, `travel`, and `community`.
- Flexible topic tags add specificity without expanding the controlled taxonomy.
- Every note consistently separates the original words, essence, significance, connections, and an optional next step.
- Local Ollama enrichment remains private, asynchronous, and subordinate to lossless Markdown capture.

## Assumptions and non-functional requirements

- This is a single-user, local-first personal knowledge system, not a CRM, therapy tool, or full task manager.
- Capturing must feel instant; AI categorization may complete afterward.
- The original thought is always preserved verbatim before inference starts.
- Unknown types or areas are rejected instead of silently expanding the taxonomy.
- The system should remain responsive with thousands of notes by retaining the embedding cache.
- Model absence, invalid output, interruption, and filesystem errors must not corrupt or discard the raw capture.
- Existing enriched notes remain unchanged; automatic migration applies only to the known bundled template, never a genuinely customized template.
- Categories remain deliberately compact and manually maintained.

## Approaches considered

### 1. Strict metadata with flexible content — accepted

Ollama chooses from fixed types and life areas while flexible topic tags describe specific subjects. All notes remain in one Obsidian folder and can be filtered through properties or namespaced tags. This preserves instant capture and handles notes spanning several parts of life.

### 2. Manual classification during capture

This improves immediate human control but adds friction at the moment of capture and was rejected for the default workflow.

### 3. Folder routing by category

Separate folders are visually simple but make cross-cutting notes and later reclassification awkward. This was rejected in favor of metadata.

## Final note contract

```markdown
---
id: "UUID"
created: 2026-07-17T16:30:00-04:00
type: reflection
areas:
  - relationships
  - self
status: inbox
summary: "A faithful one- or two-sentence essence."
tags:
  - type/reflection
  - area/relationships
  - area/self
  - boundaries
related:
  - "[[Existing Note]]"
source: daily-desk
ai_model: gemma3:12b
---

# A clear, neutral title

## Original thought

The exact, unedited capture.

## Essence

A faithful condensation that preserves intent.

## Why it matters

A restrained statement of relevance without diagnosis, invented emotions, or motivational filler.

## Connections

- [[Existing Note]] — related by meaning

## Possible next step

No action needed.

## Topics

#type/reflection #area/relationships #area/self #boundaries
```

Raw notes temporarily use `type: unclassified`, an empty `areas` list, and `status: needs-enrichment`. `unclassified` is a processing state, not part of the final type vocabulary.

## Structured enrichment contract

The model returns:

- `title`: a clear, neutral title under ten words.
- `summary`: a faithful one- or two-sentence essence.
- `significance`: why the capture may matter, without unsupported interpretation.
- `type`: exactly one allowed type.
- `areas`: one to three unique allowed areas.
- `tags`: zero to five specific reusable topic tags; no type or area tags.
- `next_step`: one concrete action only when naturally implied, otherwise an empty string.

The Ollama JSON schema constrains the output first. Swift validation independently enforces the same enum, count, uniqueness, and content rules. The renderer deterministically constructs `type/<value>` and `area/<value>` tags so taxonomy does not depend on model spelling.

## Few-shot prompt design

Three short examples guide semantics while the JSON schema remains the enforcement boundary. Examples cover action versus non-action, multi-area classification, and non-business subject matter.

### Goal with an action

Capture: `I want to see the northern lights with my sister before we are both forty.`

```json
{
  "title": "See the northern lights together",
  "summary": "A personal goal to experience the northern lights with the user's sister before they are both forty.",
  "significance": "It combines a meaningful shared experience with a clear life milestone.",
  "type": "goal",
  "areas": ["travel", "relationships"],
  "tags": ["northern-lights", "sister", "shared-experiences"],
  "next_step": "Research suitable destinations and seasons"
}
```

### Reflection without a forced action

Capture: `I notice I often agree too quickly because silence feels uncomfortable.`

```json
{
  "title": "Agreeing to avoid silence",
  "summary": "A reflection on agreeing quickly when conversational silence feels uncomfortable.",
  "significance": "Recognizing this pattern may clarify how discomfort influences communication and boundaries.",
  "type": "reflection",
  "areas": ["self", "relationships"],
  "tags": ["communication", "boundaries", "discomfort"],
  "next_step": ""
}
```

### Memory without optimization

Capture: `Grandma always cut mangoes at the kitchen window and gave me the sweetest pieces.`

```json
{
  "title": "Mangoes at Grandma's window",
  "summary": "A memory of the user's grandmother preparing mangoes by the kitchen window and sharing the sweetest pieces.",
  "significance": "The detail preserves a small expression of care and a vivid family memory.",
  "type": "memory",
  "areas": ["relationships", "home"],
  "tags": ["grandmother", "family-memory", "mangoes"],
  "next_step": ""
}
```

The examples are static application resources, contain no user data, and are sent only to the local Ollama service with the current capture.

## Data flow and safeguards

1. Save exact input atomically as a raw Markdown note.
2. Ask Ollama for schema-constrained metadata using the policy and three few-shot examples.
3. Decode and validate the response locally.
4. Generate namespaced taxonomy tags in the app.
5. Embed the original, essence, type, areas, and topic tags.
6. Find related existing notes and validate each wikilink target.
7. Atomically replace the raw note only if it has not changed during enrichment.

Invalid classification, missing models, or unavailable Ollama leaves the raw note intact with `needs-enrichment`. Existing custom templates are preserved. The known old default template may be upgraded automatically through a versioned default-template migration.

## Testing strategy

- Validate every allowed type and area.
- Reject unknown types, unknown areas, empty areas, excessive areas, duplicate areas, and excessive topic tags.
- Verify deterministic namespaced tags and flexible-tag normalization.
- Verify significance rendering and conditional next-step behavior.
- Verify exact original-text preservation and YAML escaping.
- Decode representative few-shot-shaped Ollama responses through mocked HTTP.
- Verify legacy default migration and preservation of custom templates.
- Retain atomic vault and embedding tests.

## Decision log

1. Use both a note type and life areas rather than either dimension alone.
2. Keep a compact controlled vocabulary to reduce drift and maintenance.
3. Use one consistent, life-friendly body structure for every capture.
4. Preserve flexible topic tags for specific subjects.
5. Keep the original capture verbatim and visibly separate from AI interpretation.
6. Do not force reflections, memories, or learnings into action items.
7. Use strict metadata with flexible content rather than manual capture fields or folder routing.
8. Generate namespaced taxonomy tags deterministically in Swift.
9. Use three compact few-shot examples to teach semantic distinctions while retaining schema and application validation as hard boundaries.
10. Do not automatically rewrite existing personal notes or customized templates.
