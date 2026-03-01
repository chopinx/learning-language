# LearningLanguage V1 Implementation Plan

This plan follows `PRD_LearningLanguage_v1.md` and implements features in milestone order.

## PRD Traceability
- PRD Section 6 (`Must-have`) is the implementation baseline.
- PRD Section 16 (`Acceptance Criteria`) is the verification checklist.

## Current Status (2026-03-01)
- Milestone 1 completed.
- Milestone 2 completed (including FR-13 text-to-audio session creation).
- Milestone 3 completed.
- Milestone 4 completed.
- Milestone 5 completed.
- Acceptance criteria tracking: `docs/ACCEPTANCE_CHECKLIST_V1.md`.
- Automated regression coverage includes:
  - imported-audio session creation pipeline,
  - relaunch restore of workspace/session/sentence index,
  - recording transcription language routing and empty transcript handling,
  - UI smoke coverage for sentence slider/toggle/next flow and workspace management visibility rules.

## Milestone 1: Foundation + Workspace Isolation
PRD mapping:
- FR-9, FR-10, FR-11, FR-12
- NFR-2, NFR-3, NFR-5

Scope:
1. Core models (`LearningSession`, `SentenceItem`, `SentenceAttempt`, diff models, workspace state).
2. Workspace enum and metadata.
3. Workspace-isolated storage paths:
   - `Documents/workspaces/<languageCode>/sessions.json`
   - `Documents/workspaces/<languageCode>/workspace_state.json`
4. App-level state container (`AppViewModel`) for selected workspace, sessions, and persistence actions.
5. Keychain-backed API key manager + Settings screen (`save`, `validate`, `clear`).
6. Home screen shell with workspace switcher and session list.
7. Unit tests for core foundation logic:
   - transcript diff classification
   - workspace-isolated storage behavior

Definition of done:
- Switching workspace reloads isolated sessions.
- No cross-workspace data bleed.
- API key saved/loaded from Keychain.
- Unit tests pass for foundation logic.

## Milestone 2: Import/Text Creation + Source Preparation
PRD mapping:
- FR-1, FR-2, FR-3, FR-13

Scope:
1. Import audio via `fileImporter`.
2. Deepgram source transcription client (`/v1/listen`).
3. Text-input mode to generate practice audio via Deepgram speech generation (`/v1/speak`).
4. Sentence segmentation (provider timing first; punctuation fallback).
5. Create session from imported/transcribed audio or text-generated audio.
6. Unit tests for sentence segmentation, Deepgram response mapping, and text-to-audio session creation logic.

Definition of done:
- User can import audio and get sentence list in active workspace.
- User can input text, generate audio, and enter sentence practice in active workspace.

## Milestone 3: Practice Loop
PRD mapping:
- FR-4, FR-5, FR-7, FR-8

Scope:
1. Practice screen with sentence index, draggable slider, prev/next.
2. Show/hide source sentence toggle.
3. Playback scaffolding and recording scaffolding.
4. User transcription call path integration.
5. Unit tests for sentence navigation state transitions.

Definition of done:
- User can navigate sentences and complete one practice attempt flow.

## Milestone 4: Diff + Feedback UX
PRD mapping:
- FR-6

Scope:
1. Token normalization and alignment algorithm.
2. Highlight missing/wrong/extra/correct tokens.
3. Result summary chips.
4. `Done and Next` updates session progress.
5. Unit tests for diff edge cases (punctuation, casing, empty input).

Definition of done:
- Compare output is visible and usable for sentence-by-sentence progression.

## Milestone 5: Stabilization + Acceptance Validation
PRD mapping:
- NFR-1, NFR-4 + PRD Section 16

Scope:
1. Error states and retry UX.
2. Loading states for pipeline and transcription actions.
3. Persistence and relaunch checks.
4. Acceptance checklist run-through.
5. Regression test sweep for existing unit tests.

Definition of done:
- All PRD acceptance criteria pass for demo scope.

Status:
- Completed on 2026-03-01 with full test suite pass and build validation.
