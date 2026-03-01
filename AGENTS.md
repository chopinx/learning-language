# Repository Guidelines

## Project Structure & Module Organization
- App source lives in `LearningLanguage/`.
- Feature UI is organized under `LearningLanguage/Features/`:
  - `Home/`, `Practice/`, `Import/`, `Settings/`, `Onboarding/`.
- Design system (colors, modifiers, shared components) is in `LearningLanguage/Design/`.
- Shared domain models are in `LearningLanguage/Models/`.
- Persistence and storage code is in `LearningLanguage/Persistence/`.
- Security utilities (Keychain/API key) are in `LearningLanguage/Security/`.
- App-level state is in `LearningLanguage/State/`.
- Unit tests are in `LearningLanguageTests/`; UI tests are in `LearningLanguageUITests/`.
- Product/design docs live in `docs/` (PRD, implementation plan, SVG mockups).
- Archived v1 code lives in `archive/` for reference.

## Build, Test, and Development Commands
- `xcodegen generate`
  - Regenerates `LearningLanguage.xcodeproj` from `project.yml`.
- `xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - CLI build without simulator signing issues.
- `xcodebuild -project LearningLanguage.xcodeproj -scheme LearningLanguage -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
  - Runs unit/UI tests from CLI.

## SwiftUI Design Patterns (CRITICAL)
Follow ProjectX patterns (reference: `~/Workspace/local-repos/ProjectX/`):
- **Standard NavigationStack** with `.navigationTitle()` — NEVER hide nav bar or use `.ignoresSafeArea` hacks.
- **System colors**: `Color(.systemBackground)` for cards, adapts to dark mode.
- **Card modifier**: `.appCard()` — uses `.padding()`, `RoundedRectangle(cornerRadius: 16)`, system shadow.
- **Semantic fonts**: `.headline`, `.subheadline`, `.body`, `.caption` — NEVER `.system(size: X)`.
- **Default padding**: `.padding()` without pixel values.
- **Color tokens**: `Color.themePrimary`, `Color.themeTextPrimary`, etc. via `Color(hex:)`.
- **Buttons**: `.buttonStyle(.borderedProminent)` primary, `.buttonStyle(.bordered)` secondary.

## Coding Style & Naming Conventions
- Language: Swift 5.x, SwiftUI-first, targeting iOS 18.0.
- Indentation: 4 spaces; keep lines readable and avoid deep nesting.
- Naming:
  - Types/protocols: `UpperCamelCase`.
  - Variables/functions/properties: `lowerCamelCase`.
  - File names should match primary type (for example, `AppViewModel.swift`).
- Keep feature logic inside feature folders; keep models/persistence decoupled from UI.
- Follow iOS and SwiftUI best practices:
  - keep views small and composable,
  - keep business logic out of views (use view models/state layer),
  - prefer value types and explicit state flow,
  - use async/non-blocking patterns for I/O/network work.
- Follow clean-code principles:
  - single responsibility per type/function,
  - clear naming over comments,
  - avoid duplication; extract reusable logic,
  - keep functions focused and testable.

## Testing Guidelines
- Use `import Testing` for unit tests; keep tests deterministic and fast.
- Prefer behavior-oriented test names (for example, `transcriptDifferClassifiesMissingWrongAndExtraWords`).
- Add tests for every change to diff logic, workspace isolation, and persistence behavior.
- UI behavior changes should include at least one UI test or documented manual verification.
- Mandatory gate: run the full test suite and confirm it passes before build verification or handoff.

## PRD Alignment & Pre-Build Gate
- Always verify implementation aligns with `docs/PRD_LearningLanguage_v1.md` before build validation.
- Required pre-build checklist:
  - review all code/doc changes in the current diff before attempting a build,
  - confirm changed code maps to PRD requirements/acceptance criteria,
  - run tests and confirm all pass,
  - then run build verification (`xcodebuild ... build`).
- If tests cannot be run, explicitly document why and list the impacted risk.

## Commit & Pull Request Guidelines
- Commit format: `type(scope): summary` (for example, `feat(practice): add sentence slider persistence`).
- Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.
- PRs should include:
  - concise problem/solution summary,
  - linked issue/task,
  - test evidence (commands + result),
  - screenshots for UI changes.

## Security & Configuration Tips
- Never commit API keys or secrets.
- Store Deepgram API key in Keychain only.
- Ignore build artifacts (`DerivedData/`) and local machine metadata.
