# CLAUDE.md — LearningLanguage

## Overview

iOS SwiftUI app for language learners — import audio or generate from text, practice sentence-by-sentence with recording, get word-level diff feedback. Uses Deepgram STT/TTS API.

## Build & Test

```bash
xcodegen generate                    # Regenerate .xcodeproj from project.yml
xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Unit tests (Swift Testing framework)
xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run on simulator
xcrun simctl install booted /path/to/DerivedData/.../LearningLanguage.app
xcrun simctl launch booted me.xiao.qinbang.LearningLanguage
```

## Project Structure

```
LearningLanguage/
├── LearningLanguageApp.swift         # @main entry point
├── ContentView.swift                 # Root TabView (Home + Settings)
├── Design/
│   └── AppTheme.swift                # Colors, card modifier, shared components
├── Models/                           # Domain models (no UI dependencies)
│   ├── LearningSession.swift         # Session, SentenceItem, SentenceAttempt
│   ├── TranscriptDiff.swift          # Edit-distance diff: DiffToken, DiffResult
│   ├── WorkspaceConfig.swift         # Active workspaces, default, onboarding flag
│   └── WorkspaceLanguage.swift       # Enum: english, spanish, japanese, german
├── Features/                         # SwiftUI views (one folder per screen)
│   ├── Home/HomeView.swift
│   ├── Practice/PracticeView.swift
│   ├── Import/ImportTranscribeView.swift
│   ├── Settings/SettingsView.swift
│   └── Onboarding/OnboardingGuideView.swift
├── State/
│   ├── AppViewModel.swift            # Central @MainActor ObservableObject
│   └── UITestBootstrapper.swift      # Seeds data for UI tests
├── Persistence/
│   └── LearningSessionStore.swift    # JSON file storage per workspace
├── Security/
│   ├── APIKeyManager.swift           # Keychain-backed API key lifecycle
│   └── KeychainStore.swift           # Keychain protocol + implementation
└── Services/
    ├── Deepgram/                     # STT (/v1/listen), TTS (/v1/speak), validation
    ├── Audio/                        # Playback, recording, file management
    └── Transcript/                   # Sentence segmentation
```

## Architecture

- **Views** call **AppViewModel** which owns all state
- **AppViewModel** uses **LearningSessionStore** (persistence), **DeepgramClient** (API), **WorkspaceAudioStore** (files)
- Data is isolated per workspace: `Documents/workspaces/<languageCode>/sessions.json`
- API key stored in Keychain, never in plain text

## SwiftUI Patterns (follow these)

Based on ProjectX reference app (`~/Workspace/local-repos/ProjectX/`):

1. **Standard NavigationStack** with `.navigationTitle()` — never hide the nav bar or use `.ignoresSafeArea` hacks
2. **System colors**: `Color(.systemBackground)` for cards, `Color(.systemGroupedBackground)` for screen backgrounds
3. **Card modifier**: `.appCard()` → `.padding()`, `Color(.systemBackground)`, `RoundedRectangle(cornerRadius: 16)`, `.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)`
4. **Semantic fonts**: `.headline`, `.subheadline`, `.body`, `.caption` — never `.system(size: X)`
5. **Default padding**: `.padding()` without pixel values — let SwiftUI handle it
6. **Color tokens**: `Color.themePrimary`, `Color.themeTextPrimary`, `Color.themeTextSecondary` via `Color(hex:)`
7. **Buttons**: `.buttonStyle(.borderedProminent)` for primary, `.buttonStyle(.bordered)` for secondary

## Key Design Tokens

```
Primary:     #0F6A74 (teal)      Color.themePrimary
Primary Dark: #133D5A (navy)     Color.themePrimaryDark
Text:        #1E293B             Color.themeTextPrimary
Text Sec:    #64748B             Color.themeTextSecondary
Success:     #22C55E             Color.themeSuccess
Error:       #EF4444             Color.themeError
```

## Testing

- **Unit tests**: `import Testing` framework, 32+ tests covering models, persistence, workspace isolation, diff algorithm, Deepgram response mapping, ViewModel behavior
- **UI tests**: XCTest framework, tests for workspace switching, practice navigation, settings, onboarding
- **Mocks**: `MockDeepgramClient`, `InMemoryKeychainStore` in test file
- Test naming: behavior-oriented (e.g., `transcriptDifferClassifiesMissingWrongAndExtraWords`)

## PRD & Design Reference

- **PRD**: `docs/PRD_LearningLanguage_v1.md` — 12 acceptance criteria, 13 functional requirements
- **SVG mockups**: `docs/ui-svg/` — home, practice, import, settings, app flow
- **Implementation plan**: `docs/IMPLEMENTATION_PLAN.md`
- **Acceptance checklist**: `docs/ACCEPTANCE_CHECKLIST_V1.md`

## Deepgram Integration

- **STT**: `POST /v1/listen` with language code, returns utterances + transcript
- **TTS**: `POST /v1/speak` with model name, returns audio data
- **Validation**: `GET /v1/projects` to check API key
- Auth: `Authorization: Token <key>` header

## Workspace Isolation Rules

1. Session list is workspace-specific (`Documents/workspaces/<languageCode>/sessions.json`)
2. Current sentence index is workspace-specific
3. Resume state is workspace-specific
4. Switching workspace must not mutate another workspace's state
5. Workspace switcher visible only when active count > 1

## Security

- API key in Keychain only (service: `me.xiao.qinbang.LearningLanguage`, account: `deepgram_api_key`)
- Never commit `.env` files or API keys
- Build artifacts (`DerivedData/`) in `.gitignore`
