# Daily Desk — Local Voice Dictation Design

## Implementation status

Implemented in Daily Desk 2.2 on July 18, 2026 with WhisperKit 0.18.0. Audio capture uses WhisperKit's 16 kHz in-memory recorder rather than writing temporary audio files, so recorded samples are discarded immediately after transcription or cancellation. The signed release includes Quick Capture voice input, configurable hold-to-talk or press-to-start/stop activation (default shortcut `Control–Shift–Space`), automatic multilingual detection, Ollama cleanup, secure-field avoidance, direct paste, clipboard fallback, model download progress, and permission guidance.

## Understanding summary

- Daily Desk will embed WhisperKit for fully local speech recognition on Apple silicon.
- It will support voice capture into the existing Obsidian life-note workflow and system-wide dictation into other applications.
- System-wide dictation uses configurable hold-to-talk, defaulting to `Control–Shift–Space`; Quick Capture uses a toggle microphone button suitable for longer thoughts.
- Whisper automatically detects English and Japanese for each recording.
- Light cleanup is the default, with a selectable polished rewrite mode.
- Original transcripts are preserved for Daily Desk captures, while system-wide dictation inserts only the selected cleaned output.
- This release does not include screen reading, autonomous agents, email sending, or general computer control.

## Assumptions and non-functional requirements

- WhisperKit and Whisper model inference remain local after the initial model download.
- First-use download progress, model state and recovery errors are visible.
- Warm dictation should feel near-immediate after shortcut release; final accuracy takes priority over inserting unstable partial text.
- Typical recordings are shorter than five minutes and belong to one local user.
- Temporary audio is deleted after transcription or cancellation by default.
- Microphone permission is required. Accessibility permission is requested only for automatic insertion into other apps.
- Clipboard fallback works when Accessibility is unavailable or an app rejects synthetic paste.
- No audio, transcript, selected text, screen content or app content is sent to a cloud service.
- Ollama cleanup is optional at runtime; raw Whisper output remains usable whenever cleanup fails.
- Secure fields and applications that reject programmatic paste are expected limitations.
- The app remains deployable on macOS 14+, optimized for the current Apple-silicon Mac.

## Approaches considered

### 1. Embedded WhisperKit — accepted

Add WhisperKit as a Swift package and run Core ML inference inside Daily Desk. This gives the lowest integration latency, a single signed app, native lifecycle handling and no helper service to maintain.

### 2. WhisperKit local server

Run Argmax's OpenAI-compatible local server as a separate process and call it over localhost. This isolates the model runtime but adds installation, launch, health-check and recovery complexity.

### 3. whisper.cpp helper

Bundle a C++ library or executable. It is mature and portable but lower-level, less Swift-native and contrary to the explicit WhisperKit preference.

## Interaction design

The existing `Control–Option–Space` shortcut continues to open Quick Capture. Quick Capture adds a microphone button that toggles recording and places the completed transcript into its editor for review before saving.

System-wide dictation uses the selected shortcut, defaulting to `Control–Shift–Space`:

1. Press and hold to record.
2. Release to finish, transcribe, clean and insert.
3. Press Escape while recording to cancel.
4. A non-activating floating pill displays recording, model preparation, transcription, cleanup, insertion and failure states without stealing focus.

Locked double-press recording is attempted only if it does not delay or destabilize normal hold-to-talk. If reliable detection would add latency to every release, it is deferred. Toggle recording remains available in Quick Capture.

## Architecture and data flow

`VoiceDictationController` is a main-actor observable state machine:

`idle → preparingModel → recording → transcribing → cleaning → inserting/saved → idle`

It coordinates:

- `AVAudioEngine` microphone capture and temporary audio-file creation.
- A `SpeechTranscribing` abstraction backed by WhisperKit in production and a fake in tests.
- Whisper model discovery, download, local cache and lazy loading.
- Local cleanup through Ollama with raw-transcript fallback.
- Clipboard and Accessibility insertion.
- A non-activating recording/status panel.

Voice capture flow:

1. Record audio locally.
2. Transcribe through WhisperKit with automatic language detection.
3. Place the exact transcript into Quick Capture.
4. On save, the existing raw-first Obsidian and life-classification pipeline runs unchanged.

System-wide flow:

1. Remember the focused application without reading its content.
2. Record and transcribe locally.
3. Apply light cleanup or polished rewrite through Ollama.
4. Return focus if necessary.
5. Paste through a temporary clipboard value and synthesized Command–V when Accessibility is trusted.
6. Otherwise leave the result on the clipboard and report that Command–V is required.

## Model and cleanup behavior

Daily Desk uses a supported multilingual WhisperKit model capable of English and Japanese detection. It prefers an appropriate turbo model from the installed WhisperKit catalog and falls back to a supported multilingual model with a visible status instead of silently failing.

The model downloads only after explicit user confirmation and is stored under Application Support. Settings expose model state, download progress and removal.

Cleanup policies:

- **Light:** remove filler words, repeated fragments and abandoned self-corrections; fix punctuation and capitalization; preserve wording, language, facts and tone.
- **Polished:** improve structure and concision while preserving meaning and never inventing information.
- Ollama failure, timeout or empty output returns the raw Whisper transcript.
- The cleaner never answers questions contained in dictation; it edits them as dictated text.

## Permissions, privacy and security

- Add a clear microphone usage description to the signed app.
- Request microphone authorization only when voice is first used.
- Request Accessibility only when the user enables direct system-wide insertion.
- Do not request Screen Recording or inspect foreground-window text.
- Use a clipboard-only fallback when direct insertion is unavailable.
- Refuse automatic insertion into detectable secure text fields.
- Delete temporary recordings in success, failure and cancellation paths unless a future explicit keep-audio option is enabled.

## Error handling

- Missing model: show install action and retain any captured audio until the user chooses retry or cancel during that session.
- Download failure: show the underlying error and allow retry; existing non-voice features remain available.
- Microphone denied: link to System Settings and keep typed capture operational.
- Empty/silent recording: do not insert or save an empty capture.
- Transcription failure: preserve the temporary file only for the active retry flow, then delete it on dismissal.
- Cleanup failure: use the raw transcript.
- Accessibility denied: copy the text and show a manual-paste message.
- Focused app exits: leave the result on the clipboard.
- Cancellation: stop audio immediately, cancel active tasks and delete temporary data.

## Testing strategy

- Unit-test state transitions with a fake `SpeechTranscribing` implementation.
- Test light and polished cleanup prompts, timeout, empty response and raw fallback.
- Test English and Japanese transcript preservation.
- Test empty audio, cancellation and temporary-file deletion.
- Test clipboard fallback and insertion-service decisions without synthesizing real keys.
- Test model-load and download error presentation.
- Retain all existing capture, vault, Ollama, widget and signing tests.
- Manually verify microphone authorization, model download, hotkey press/release, Escape cancellation, Quick Capture transcription and insertion into Notes, Mail and a browser.
- Strictly verify the signed app, embedded widget, entitlements and ZIP after packaging.

## Decision log

1. Use WhisperKit and OpenAI Whisper rather than Apple Speech, FluidAudio or whisper.cpp.
2. Embed WhisperKit directly rather than operating a separate local server or helper process.
3. Support both Daily Desk voice capture and system-wide dictation.
4. Keep `Control–Option–Space` for capture and default hold-to-talk to `Control–Shift–Space`, with selectable alternatives in Settings.
5. Attempt locked recording only if it does not compromise the reliable hold path.
6. Automatically detect English and Japanese with a multilingual Whisper model.
7. Make light cleanup the default and polished rewrite optional.
8. Keep the raw transcript as the fallback whenever Ollama is unavailable.
9. Delete audio by default and never send voice or text to cloud inference.
10. Require Accessibility only for direct insertion and retain clipboard fallback.
11. Do not add screen awareness or agent actions in this release.
