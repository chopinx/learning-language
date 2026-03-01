# PRD: LearningLanguage iOS App (V1)

## 0) Document Control
- Product: LearningLanguage iOS App
- Version: V1 (Demo)
- Owner: Qinbang Xiao
- Last updated: 2026-03-01
- Status: Ready for implementation
- Platform: iOS (SwiftUI)

Revision notes:
- Refined requirement clarity, priorities, and acceptance checks.
- Added explicit language-workspace isolation rules.
- Added screen-level UX requirements and release gates.
- Added text-input-to-practice flow using Deepgram speech generation.
- Updated workspace UX: workspace switcher is conditional and workspace list is user-managed in Settings.

## 1) Problem Statement
Language learners using audio content (podcasts, lessons, dialogues) lack one focused workflow to:
- import audio,
- create practice audio from typed text,
- convert it into sentence-level practice,
- speak each sentence and get transcript-based feedback,
- resume progress without losing context.

Current alternatives require multiple tools and manual comparison, which reduces practice consistency.

## 2) Product Goals
1. Let users import one audio file and generate source transcription via Deepgram.
2. Enable sentence-by-sentence speaking practice from the source audio.
3. Provide word-level comparison feedback (`missing`, `wrong`, `extra`, `correct`).
4. Support fast sentence navigation with a draggable progress bar.
5. Persist progress and resume reliably.
6. Support user-managed language workspaces with strict data isolation.
7. Provide Settings to manage Deepgram API key securely.
8. Let users input text and generate practice audio with Deepgram.

## 3) Non-Goals (V1)
- Real-time streaming transcription.
- Pronunciation scoring by phoneme.
- Cloud sync or multi-device continuity.
- Full transcript editor.
- Multi-user collaboration.

## 4) Target Users
- Primary: Self-learners practicing listening and speaking with imported audio.
- Secondary: Tutors using short clips for guided speaking drills.

User assumptions:
- User has local audio files (`m4a`, `mp3`, `wav`).
- User can provide a valid Deepgram API key.
- User returns for repeated practice sessions.
- User may create practice sessions directly from typed text.
- Most users practice one language at a time.

## 5) Core User Journeys
## Journey A: First-time setup
1. Open app.
2. Open Settings.
3. Enter Deepgram API key.
4. Save and validate key.
5. Add first learning language workspace.
6. Return to Home.

## Journey B: Create a session
1. Use current workspace (or select one if multiple workspaces are active).
2. Tap `New Session` and keep mode `Import Audio`.
3. Pick file and set session title.
4. Tap `Transcribe with Deepgram`.
5. App stores transcript and sentence list.
6. App opens Practice at sentence 1.

## Journey C: Practice sentence-by-sentence
1. View `Sentence X of Y`.
2. Drag sentence progress slider to jump if needed.
3. Toggle source sentence visibility (show/hide).
4. **Tap to listen**: tap the play button to hear the sentence.
5. **Hold to record**: press and hold the record button to capture voice.
6. **Release to auto-process**: releasing the button automatically transcribes, compares, and scores.
7. **Swipe up to cancel**: during recording, swipe up to cancel (with visual indicator).
8. Review token-level highlights and accuracy score, then move to next sentence.

## Journey D: Resume later
1. Reopen app.
2. App restores last selected workspace.
3. If multiple workspaces are active, user can switch workspace; if only one is active, switcher stays hidden.
4. App restores latest session and sentence index for that workspace.

## Journey E: Create session from typed text
1. Use current workspace (or select one if multiple workspaces are active).
2. Tap `New Session` and switch mode to `Create from Text`.
3. Enter session title and source text.
4. Tap `Generate Audio with Deepgram`.
5. App stores generated audio + source text and creates sentence list.
6. App opens Practice at sentence 1.

## 6) Scope by Priority
## Must-have (V1)
- Audio import.
- Source transcription (Deepgram).
- Text input to audio generation (Deepgram speech generation API).
- Sentence segmentation.
- Sentence playback and user recording.
- User voice transcription (Deepgram).
- Token-level diff highlighting.
- Draggable sentence progress bar.
- Show/hide source sentence.
- Persistence and resume.
- Workspace management in Settings, conditional switcher, and full isolation.
- Settings for Deepgram key: save, validate, clear.

## Should-have (if no schedule risk)
- Clear loading states for each pipeline step.
- Better error messages with retry actions.
- Quick resume shortcut on Home.

## Won't-have (V1)
- Pronunciation score.
- Cloud sync.
- Advanced transcript editing.

## 7) Functional Requirements
- FR-1 Audio import:
  - App must import local `m4a`, `mp3`, `wav` files.
- FR-2 Source transcription:
  - App must call Deepgram to transcribe imported audio.
- FR-3 Sentence segmentation:
  - App must split transcript into sentence items.
  - App should persist sentence timing if returned.
  - App must support a configurable minimum sentence duration (default: 2 seconds).
  - Segments shorter than the minimum duration must be merged with the following segment.
  - The minimum duration setting must be adjustable in Settings.
- FR-4 Sentence practice:
  - App must support per-sentence playback and user recording.
- FR-5 User voice transcription:
  - App must transcribe recorded audio through Deepgram.
- FR-6 Comparison and feedback:
  - App must classify aligned tokens as `correct`, `missing`, `wrong`, `extra`.
- FR-7 Sentence navigation:
  - App must provide `Prev`, `Next`, and draggable sentence slider jump.
- FR-8 Source visibility control:
  - App must allow show/hide original sentence text in Practice.
- FR-9 Persistence:
  - App must persist session state, attempts, and current sentence index.
- FR-10 Resume:
  - App must restore last state on relaunch.
- FR-11 Workspace management and isolation:
  - App must allow user to add/remove active learning language workspaces in Settings.
  - App must show workspace switcher only when active workspace count is greater than 1.
  - App must auto-use the only active workspace when active workspace count is 1.
  - App must keep data fully isolated per language workspace.
- FR-12 API key settings:
  - App must provide Settings screen to save/validate/clear Deepgram API key.
  - API key must be stored in Keychain.
- FR-13 Text-to-practice generation:
  - App must allow user to input source text and generate audio with Deepgram (`POST /v1/speak`).
  - Generated audio + source text must create a practice session equivalent to imported-audio sessions.
  - Note: STT (`/v1/listen`) is for transcription; audio generation uses speech generation (`/v1/speak`).

## 8) Non-Functional Requirements
- NFR-1 Responsiveness:
  - App should stay responsive during upload and transcription.
- NFR-2 Reliability:
  - App should autosave on meaningful state transitions.
- NFR-3 Security:
  - API key must not be stored in plain text files.
- NFR-4 Error UX:
  - Errors should include clear reason + retry action.
- NFR-5 Isolation integrity:
  - No session/progress leakage across language workspaces.

## 9) UX Requirements by Screen
## Screen 1: Home / Sessions
- Conditional language workspace switcher (visible only when active workspace count > 1).
- Session list: each session is a tappable card/row. Tapping a session directly opens Practice (no separate "Start" button needed).
- Session card shows: title, progress bar, completion percentage, last active time.
- Resume card: prominent card for the most recent session at the top.
- `+` floating action button for New Session.
- Settings gear icon in top-right toolbar.

## Screen 2: Import + Transcribe
- Two creation modes: `Import Audio` and `Create from Text`.
- Import mode:
  - file picker + session title input
  - `Transcribe with Deepgram` action
  - progress states: importing, uploading, transcribing, sentence split
- Text mode:
  - text editor + session title input
  - `Generate Audio with Deepgram` action
  - progress states: generating audio, preparing session, sentence split

## Screen 3: Practice
- Header: `Sentence X of Y` with session progress bar.
- Draggable sentence slider.
- `Prev` / `Next` actions.
- Show/hide source sentence toggle.
- **Tap-to-listen**: tap play button to hear sentence audio.
- **Hold-to-record button**: large circular button.
  - Press and hold: starts recording, shows waveform + duration + "Release to compare" hint.
  - Release: auto-stops recording → auto-transcribes via Deepgram → auto-compares → shows score.
  - Swipe up while holding: cancels recording. Show "↑ Swipe up to cancel" indicator ABOVE the button during recording. Show "Release to cancel" when swiped up past threshold. The button follows the finger during drag but stays at its original position on initial press.
- App must support dark mode and light mode, following the system setting.
- Diff-highlighted compare result with accuracy percentage.
- Summary chips: missing/wrong/extra counts.
- `Done and Next` CTA with accuracy score.

## Screen 4: Settings
- Secure Deepgram API key field.
- `Save Key`, `Validate Key`, `Clear Key` actions.
- Validation status (valid/invalid + message).
- Learning language management:
  - add workspace language
  - remove workspace language
  - set default/active workspace

## 10) Data Model and Storage
Core structures:
- `LearningSession`
- `SentenceItem`
- `SentenceAttempt`
- `DiffResult`
- `DiffToken`
- `LanguageWorkspaceState`
- `WorkspaceConfig` (active workspace list + default workspace)
- Session source metadata (`importedAudio` or `generatedFromText`)

Storage layout:
- `Documents/workspaces/<languageCode>/sessions.json`
- `Documents/workspaces/<languageCode>/workspace_state.json`
- `Documents/workspace_config.json`
- Keychain for Deepgram API key (app-level config)

Workspace isolation rules:
1. Session list is workspace-specific.
2. Current sentence index is workspace-specific.
3. Attempts and diff history are workspace-specific.
4. Resume state is workspace-specific.
5. Switching workspace must not mutate another workspace's state.
6. Workspace selector visibility is driven by active workspace count (not hard-coded language list).

## 11) External Integrations
- Deepgram speech-to-text API: `POST /v1/listen`
- Deepgram speech generation API: `POST /v1/speak`
- Auth: `Authorization: Token <DEEPGRAM_API_KEY>`

Potential future config (out of scope for V1 build lock):
- model selection by workspace language
- enhanced punctuation/utterance options per language

## 12) Success Metrics
## Product Metrics
- M1 Setup Success: % users who validate key and complete first source transcription.
- M2 Session Completion: % sessions reaching final sentence.
- M3 Resume Accuracy: % relaunches restoring correct workspace + sentence index.
- M4 Feedback Coverage: % practice attempts producing valid diff output.
- M5 Text-to-Practice Success: % typed-text sessions that successfully generate audio and enter Practice.

## Engineering Metrics
- E1 Crash-free sessions.
- E2 Transcription request failure rate.
- E3 Data loss rate in force-close resume test.
- E4 Workspace leakage defects (target: zero).

## 13) Release Plan
1. Milestone 1: Data model + workspace-isolated persistence + Home shell.
2. Milestone 2: Import/Text creation + Deepgram source preparation.
3. Milestone 3: Practice playback/record/transcribe loop.
4. Milestone 4: Diff highlighting + sentence navigation + slider polish.
5. Milestone 5: Settings key management + resilience + QA sweep.

Release gate checklist:
- All V1 acceptance criteria pass.
- No critical data isolation bugs.
- No blocker crash in 3-5 representative audio files.

## 14) Risks and Mitigations
- Risk: Deepgram latency/quotas slow practice loop.
  - Mitigation: show clear async state and allow retry.
- Risk: noisy audio reduces transcript quality.
  - Mitigation: provide guidance and preserve attempts for repeat.
- Risk: sentence segmentation inconsistency.
  - Mitigation: prefer provider timings; fallback punctuation split.
- Risk: workspace data leakage.
  - Mitigation: namespace all storage paths by workspace code.

## 15) Open Questions
1. Should workspace language drive Deepgram model/language parameters in V1 or V1.1?
2. Should `Next` be locked until comparison exists, or allow skip?
3. What max file size and duration should be enforced for V1?
4. Should source sentence manual edits be allowed in V1.1?
5. Should users select voice/model for text-generated audio in V1, or use one default per workspace?

## 16) Acceptance Criteria (V1)
1. User can save, validate, and clear Deepgram API key in Settings.
2. User can import supported audio and receive source transcription.
3. App builds sentence list and supports sentence-level practice.
4. Practice screen supports draggable sentence progress slider for jump.
5. User can hide/show source sentence text.
6. User can record speech, transcribe it, and see token-level diff highlights.
7. User can move to next sentence after comparison.
8. App restores workspace, session, and sentence index after relaunch.
9. User can add/remove learning language workspaces in Settings.
10. Workspace switcher is shown only when active workspace count is greater than 1.
11. Workspace data is fully isolated, with no cross-language session/progress mixing.
12. User can input text, generate practice audio via Deepgram, and enter sentence practice flow.
