# Nelyr Product, Brand, and Commercial Design

Status: Approved for implementation planning
Date: 2026-07-28

## Understanding summary

- Nelyr is a native macOS local-AI input layer.
- It replaces the core Typeless-style workflow: press a global shortcut, speak,
  and insert polished text into any application.
- It also turns voice, selected text, and screenshots into connected Obsidian
  knowledge.
- The product is local-first and remains useful without an account, subscription,
  or network connection.
- The brand should feel precise, minimal, and technical in the way products such
  as Linear do, without copying their identity.
- A useful open-source Community edition drives trust and adoption.
- Paid value comes from the Context Engine and Knowledge Engine, not merely from
  code signing or packaging.

## Assumptions and non-functional requirements

### Product and audience

- Initial users are individual macOS power users, developers, writers, and
  Obsidian users.
- Version one targets Apple Silicon and macOS 14 or newer.
- Nelyr may support knowledge tools other than Obsidian later, so neither the
  product name nor core architecture is Obsidian-specific.

### Performance

- Recording must start immediately after the configured shortcut is pressed.
- Raw transcription must never wait for Pro enrichment.
- Enrichment runs after transcription and must be cancellable.
- A failure in an AI model, license service, or network-dependent feature must
  fall back to the raw transcript or raw capture.

### Privacy and security

- Audio, transcripts, selected text, screenshots, file names, vault contents,
  and frontmost-application names are never sent to the licensing system.
- Ordinary dictation and OCR work locally.
- Network use must be explicit for web research, checkout, license activation,
  updates, or future cloud features.
- License tokens are signed and cached locally so activation can be verified
  offline.

### Reliability and maintenance

- Existing captures are saved before enrichment begins.
- Community builds remain independently buildable and testable without private
  dependencies.
- Official builds remain usable during licensing or payment-provider outages.
- One maintainer must be able to ship the Community and Official builds from
  repeatable scripts.

### Scale

- The first commercial release is designed for individual licenses and a small
  user base.
- Team administration, SSO, enterprise compliance, and hosted inference are
  explicit non-goals for the first release.

## Brand

### Name

**Nelyr**

The name compresses “neural layer.” It is short, abstract, pronounceable, and
does not limit the product to voice or Obsidian.

Primary tagline:

> Your local input layer.

Supporting line:

> Speak anywhere. Keep what matters.

Community description:

> Open-source local voice input for macOS.

Commercial description:

> Turn voice, screenshots, and thoughts into connected knowledge.

### Logo concept

The mark is a single continuous line forming an angular `N`:

1. The left edge begins as a restrained voice waveform.
2. The center forms the neural-layer `N`.
3. The right edge terminates in a knowledge node.

The mark must not use a literal microphone, brain, or Obsidian diamond.

The geometry is identical across paid and free editions. Edition identity comes
from color only:

- **Nelyr Community:** pearl-white tile with the violet-to-cyan signal.
- **Nelyr Pro:** graphite-black tile with the same violet-to-cyan signal.

Pro uses no crown, badge, extra letter, or altered symbol. The black treatment
is the premium expression; Community remains equally recognizable.

### Visual system

| Role | Color |
| --- | --- |
| Graphite background | `#0B0D12` |
| Electric violet | `#7C5CFF` |
| Signal cyan | `#4DE8FF` |
| Cool white | `#F4F5F7` |

- App UI uses SF Pro.
- Web, GitHub, and marketing assets use Inter.
- Gradients are limited to the continuous-line mark.
- The mark must remain identifiable at 16 points.
- The menu-bar version is monochrome.

### Motion

- Recording: the waveform end moves subtly.
- Transcribing: light travels from left to right through the mark.
- Saved: the final knowledge node emits one short pulse.
- Error: the menu-bar mark changes to a restrained exclamation state.
- No animation loops indefinitely when the app is idle.

### Required assets

- Editable vector master
- Community light and Pro dark SVG
- Full-color and monochrome SVG
- 1024-pixel macOS app icon source
- AppIcon asset catalog exports
- Menu-bar template image
- GitHub social preview image
- Wordmark lockup and spacing guide

## Editions and paid value

### Nelyr Community

Nelyr Community is free and MIT-licensed.

- Unlimited local raw dictation
- Global shortcut
- Local Whisper transcription
- System-wide text insertion
- Basic history
- Basic local screenshot OCR
- Simple capture into one Obsidian Inbox
- Local Ollama summaries and classification
- External research CLI bridge
- Source builds and Community releases

Community must remain a useful Typeless alternative rather than a demo.

### Nelyr Pro

Nelyr Pro adds proprietary intelligence and official distribution:

- Per-application writing style and formatting
- Advanced cleanup and filler removal
- Voice editing of selected text
- Dictation translation
- Personal dictionary, snippets, and custom modes
- Screenshot-to-structured-note workflows
- Deeper knowledge graph and agentic related-note discovery
- Multiple vaults and custom templates
- Voice-triggered web research
- Advanced history, statistics, and workflows
- Signed and notarized releases
- Guided model installation
- Automatic updates
- Priority support

Product promise:

> Free stops the typing. Pro turns input into useful knowledge.

### Pricing

| Plan | Price |
| --- | ---: |
| Monthly | USD 8 |
| Annual | USD 69 |
| Founding Lifetime | USD 129 |

- Annual is the recommended plan.
- Founding Lifetime is limited to the initial launch period or a defined number
  of customers.
- Future hosted transcription, cross-device sync, or managed research may become
  an optional Nelyr Cloud subscription. Cloud is not part of the first release.

## Technical architecture

### Public modules

`NelyrCore` is an MIT-licensed Swift package containing:

- `AudioRecording`
- `VoiceTranscribing`
- `SystemTextInserting`
- `OCRRecognizing`
- `BasicVaultWriting`
- shared capture and voice models
- public feature-provider contracts

`NelyrCore` is an internal technical module name, never a customer-facing
edition. The only public edition names are **Nelyr Community** and
**Nelyr Pro**.

`NelyrCommunity` is the open-source macOS application using only public modules.

### Private module

`NelyrProKit` is a private Swift package containing:

- `ContextEngine`
- `KnowledgeEngine`
- `VoiceActionEngine`
- `ResearchEngine`
- `EntitlementClient`
- `UpdateClient`
- Official-only analytics and support surfaces

The app depends on a `FeatureProvider` interface. Community and Official build
configurations inject different implementations. Conditional compilation must
remain at composition boundaries rather than spread through feature code.

### Capabilities

Features query explicit capabilities such as:

- `contextualRewrite`
- `knowledgeEnrichment`
- `voiceEdit`
- `translation`
- `advancedScreenshotCapture`
- `multipleVaults`
- `webResearch`
- `automaticUpdates`

The UI explains why a capability is unavailable and shows a relevant example.
It must not present disabled controls without explanation.

## Data flows

### Dictation

```text
Shortcut
  -> local recording
  -> local Whisper transcription
  -> raw transcript checkpoint
  -> Community: insert or save
  -> Pro: Context Engine
       -> insert polished text
       -> optional Knowledge Engine
       -> Obsidian
```

### Screenshot

```text
Paste / drop / choose image
  -> Apple Vision OCR
  -> image and OCR checkpoint
  -> Community: basic Inbox note
  -> Pro: structure, classify, tag, relate
  -> attachment and Markdown note in Obsidian
```

### Research

```text
Voice question
  -> local transcription
  -> explicit network confirmation or enabled preference
  -> restricted research client
  -> streaming result
  -> cited Markdown
  -> Obsidian
```

## Licensing and purchase flow

### Entitlement states

- `community`
- `trial`
- `proMonthly`
- `proAnnual`
- `proLifetime`
- `grace`
- `expired`

### Trial

- Official downloads include a 14-day full Pro trial.
- No card is required.
- The onboarding demonstrates the same input as raw Community output and Pro
  output.
- At trial expiry, the app returns safely to Community functionality.
- Existing notes, history, settings, and captures remain accessible.

### Checkout

```text
Upgrade
  -> Paddle or Lemon Squeezy hosted checkout
  -> nelyr://activate callback
  -> signed entitlement token
  -> local Keychain storage
  -> immediate capability refresh
```

Manual license-key entry is a recovery path, not the primary flow.

### Offline behavior

- An activated license works offline using a signed cached token.
- The payment or license provider is never contacted during recording,
  transcription, OCR, insertion, or vault writes.
- Provider outages do not disable a previously activated installation.
- One individual license supports up to three personally owned Macs.

## Onboarding and conversion

The first-run path should take less than five minutes:

1. Explain local processing in one screen.
2. Configure microphone and global shortcut.
3. Install a recommended Whisper model.
4. Run a test dictation.
5. Choose an Obsidian vault.
6. Compare raw and Pro output.
7. Demonstrate tags and one related-note link.

Upgrade prompts appear only:

- after a successful value-producing action,
- on trial day seven,
- on the day before trial expiry, or
- when the user intentionally chooses a Pro capability.

No artificial countdowns, repeated modal interruptions, or destructive
trial-expiry behavior are allowed.

## Analytics

Permitted anonymous events include:

- onboarding completed
- first dictation completed
- vault connected
- Pro comparison viewed
- upgrade screen viewed
- checkout opened
- purchase completed

Event payloads must never contain captured content, transcripts, file paths,
application names, dictionary entries, or vault metadata. Analytics are
disclosed during onboarding and can be disabled in Settings.

## Error handling

- Recorder failure preserves any recoverable audio buffer.
- Transcription failure offers retry and never inserts an empty result.
- Pro rewrite failure returns the raw transcript.
- Knowledge enrichment failure keeps the raw Obsidian note.
- Screenshot OCR failure still permits image-only capture and manual text.
- A missing Ollama or Whisper model produces a direct repair action.
- A failed checkout leaves the current entitlement unchanged.
- A failed activation offers retry, manual key entry, and support contact.
- A failed update never replaces the installed working application.

## Testing strategy

### Public repository

- Unit tests for recording state, transcription orchestration, OCR, insertion,
  capture templates, and vault writes
- Contract tests for `FeatureProvider`
- Tests proving all Pro failures fall back to raw output
- Tests proving the Community build contains no private-package dependency
- CI with `swift test` on macOS

### Private package

- Unit tests for every capability and entitlement state
- License-token signature, expiry, grace, and offline tests
- Checkout callback and device-limit tests
- Contract tests shared with the public repository
- Tests ensuring analytics schemas cannot accept user content

### Release verification

- Signed Community and Official smoke tests
- Fresh-install and upgrade tests
- Accessibility, microphone, notifications, Services, WidgetKit, and login-item
  checks
- Japanese and English dictation/OCR checks
- Network-offline test for every ordinary capture workflow

## Rollout

### Phase 1: Brand and public foundation

- Rename the product to Nelyr.
- Produce and validate the new icon system.
- Change repository, documentation, bundle identifiers, services, and user-facing
  strings.
- Publish the useful Community edition.

### Phase 2: Modular separation

- Extract `NelyrCore`.
- Introduce `FeatureProvider` and capabilities.
- Move proprietary engines into `NelyrProKit`.
- Preserve existing behavior with contract and regression tests.

### Phase 3: Official distribution

- Add signing, notarization, updates, checkout, trial, and entitlements.
- Ship the Founding License.
- Keep Cloud out of scope.

### Phase 4: Validate demand

- Measure activation, first successful dictation, vault connection, trial use,
  and purchase conversion.
- Interview purchasers and non-purchasers.
- Build cloud or team features only after clear demand.

## Risks

### Open-source differentiation

Free local dictation alternatives are abundant. Nelyr must sell contextual and
knowledge outcomes, not transcription alone.

### Community trust

Moving too much into Pro would make the open-source claim feel hollow.
Community therefore keeps unlimited local dictation and a working basic
Obsidian path.

### Maintenance load

Two editions can drift. Shared contracts, dependency injection, and common test
suites are required before commercial launch.

### Licensing friction

License checks can conflict with a privacy-first identity. Offline signed tokens,
minimal metadata, and safe grace behavior are mandatory.

### Brand clearance

The preliminary search found no close macOS or local-AI product collision for
Nelyr. This is not formal trademark clearance. A proper trademark search is
required before substantial commercial spend.

## Decision log

1. **Name:** Nelyr.
   - Alternatives: Daily Desk, Nodal, Basalt, Relay.
   - Reason: short, abstract, technical, extensible, and lower adjacent-product
     collision in the preliminary search.
2. **Positioning:** local input layer that connects system-wide input to
   knowledge.
   - Alternative: Obsidian-only voice utility.
   - Reason: larger market and room for additional knowledge destinations.
3. **Brand mark:** continuous waveform-to-N-to-node line.
   - Alternative: microphone, brain, or Obsidian-inspired diamond.
   - Reason: more ownable and less literal.
4. **Open-source model:** useful MIT Community edition plus proprietary ProKit.
   - Alternative: fully MIT with paid binaries only.
   - Reason: packaging alone provides insufficient paid differentiation.
5. **Paid value:** Context Engine and Knowledge Engine.
   - Alternative: transcription limits.
   - Reason: local raw dictation is becoming commoditized.
6. **Pricing:** USD 8 monthly, USD 69 annual, USD 129 Founding Lifetime.
   - Alternative: one-time-only pricing.
   - Reason: recurring maintenance needs a durable revenue path while the
     founding offer rewards early adopters.
7. **Trial:** 14 days, full Pro, no card.
   - Alternative: permanently capped freemium trial.
   - Reason: users need to experience the full voice-to-knowledge workflow.
8. **Failure behavior:** preserve raw output and data in every case.
   - Alternative: block the workflow when Pro processing fails.
   - Reason: capture reliability is the core product promise.
9. **Cloud:** excluded from the first commercial release.
   - Reason: avoid infrastructure, privacy, and support complexity before demand
     is proven.
