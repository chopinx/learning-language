# LearningLanguage V1 Acceptance Checklist

Date: 2026-03-01  
Source of truth: `docs/PRD_LearningLanguage_v1.md` section 16

Legend:
- PASS (A): verified with automated tests/integration commands.
- PASS (C): implemented in code; manual UX/device validation still recommended.

| # | PRD Acceptance Criterion | Status | Evidence |
|---|---|---|---|
| 1 | Save/validate/clear API key in Settings | PASS (C) | `SettingsView` actions for Save/Validate/Clear and validation UI; `APIKeyManager` Keychain save/load/clear + `/v1/projects` validation. |
| 2 | Import supported audio and receive source transcription | PASS (A) | Import mode/file picker + `m4a/mp3/wav` enforcement in `WorkspaceAudioStore`; transcription pipeline in `AppViewModel.createSessionFromImportedAudio`; unit test `appViewModelCreatesSessionFromImportedAudioAndCapturesPipeline`; Deepgram STT integration script run succeeded. |
| 3 | Build sentence list and support sentence-level practice | PASS (A) | `SentenceSegmenter` + session sentence creation in `AppViewModel`; practice sentence state in `PracticeView`; segmentation tests pass. |
| 4 | Draggable sentence progress slider | PASS (A) | `PracticeView` slider binding + `jumpToSentence` + persisted index update; UI smoke test `testPracticeSentenceSliderAndDoneNextFlow` exercises slider interaction. |
| 5 | Hide/show original sentence text | PASS (A) | `PracticeView` toggle + persisted preference via `setShowOriginalByDefault`; UI smoke test `testPracticeCanHideAndShowOriginalSentence` passes. |
| 6 | Record speech, transcribe it, and highlight token-level diff | PASS (A) | `PracticeAudioController` recording, `transcribeUserRecording`, diff rendering in `ComparisonResultView`/`FlexibleWordWrap`; unit tests include `appViewModelTranscribesRecordingUsingSelectedWorkspaceLanguage` and `appViewModelRejectsEmptyRecordingTranscript`; diff tests pass. |
| 7 | Move to next sentence after comparison | PASS (A) | `Done and Next` button appears after comparison result and drives `markSentenceDoneAndAdvance`; UI smoke test `testPracticeSentenceSliderAndDoneNextFlow` verifies sentence progression. |
| 8 | Restore workspace/session/sentence index on relaunch | PASS (A) | `WorkspaceConfig` + workspace state persistence in `LearningSessionStore`; relaunch tests `appViewModelRestoresWorkspaceFromSavedConfigOnRelaunch` and `appViewModelRestoresLastSessionAndSentenceIndexOnRelaunch` pass; sentence index persisted via `updateSessionIndex`. |
| 9 | User can add/remove learning language workspaces in Settings | PASS (A) | Settings workspace toggles call `setWorkspaceActive`; UI smoke test `testSettingsCanAddAndRemoveWorkspace` passes. |
| 10 | Workspace switcher is shown only when active workspace count > 1 | PASS (A) | `HomeView` checks `shouldShowWorkspaceSwitcher`; UI smoke test `testWorkspaceSwitcherVisibilityDependsOnActiveWorkspaceCount` passes. |
| 11 | Workspace data is fully isolated with no cross-language mixing | PASS (A) | Workspace-scoped storage paths (`workspaces/<languageCode>/...`) and isolation unit test pass. |
| 12 | User can input text, generate practice audio via Deepgram, and enter practice flow | PASS (A) | Text mode UI + `/v1/speak` integration + text-to-audio session unit test + Deepgram speak/listen integration script success. |

## Validation Runs
- `xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' -derivedDataPath /tmp/LearningLanguageDerivedData test` succeeded on 2026-03-01 (`17` unit tests + `7` UI tests).
- `xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeded on 2026-03-01.
- `scripts/test_deepgram_stt.sh` succeeded on 2026-03-01 (generated English audio, transcribed response, utterances present).

## Final QA Note
Run a manual smoke pass for file picker import flow and microphone permission handling before release sign-off.
