# UI V2 Redesign — Design Document

Date: 2026-03-01
Status: Approved

## Goal

Match all SwiftUI views to the V2 SVG mockups (`docs/ui-svg/`) while implementing the underlying functionality (real stats, waveform, file size) and updating tests.

## Design System Tokens (from SVG analysis)

### Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `primaryDark` | #133D5A | Button gradient start, headings |
| `primaryTeal` | #0F6A74 | Button gradient end, active chips |
| `textPrimary` | #10212C | H1 headings |
| `textSecondary` | #5A7380 | Body text, captions |
| `textHeading` | #1B3D4A | H2 headings |
| `chipActive` | #0F6372 | Selected workspace chip |
| `chipInactive` | #EAF1F6 | Unselected workspace chip |
| `chipActiveText` | #FFFFFF | Selected chip text |
| `chipInactiveText` | #2E5361 | Unselected chip text |
| `progressTrack` | #D9E7ED | Progress bar background |
| `progressFill` | #0E6A78 | Progress bar fill |
| `cardBg` | #FFFFFF → #F9FCFF | Card gradient |
| `screenBg` | #F6FBFF → #F2FBF5 | Screen gradient (Home) |
| `diffCorrect` | #DFF3E6 / #1F6A43 | Correct token bg/text |
| `diffMissing` | #FDEAE7 / #B74838 | Missing token bg/text |
| `diffWrong` | #FFF1DE / #AB6913 | Wrong token bg/text |
| `diffExtra` | #ECEAFF / #5E4CC7 | Extra token bg/text |
| `recordButton` | #14435C → #0E7A7C | Record button gradient |
| `sliderThumb` | #FFFFFF / #1A6E82 | Slider handle fill/stroke |
| `validationSuccess` | #EAF6EE / #236947 | Valid key card |

### Typography
- Font: System (closest to Sora) with `.rounded` design where appropriate
- H1: 24pt bold, H2: 14pt bold, H3: 16pt bold
- Body: 12pt medium, Caption: 11pt bold

### Shared Components
- `WorkspacePillChips`: Horizontal scrollable pill chips for workspace selection
- `StyledProgressBar`: Custom progress bar with fraction label
- `StyledCard`: Card with rounded corners, gradient fill, drop shadow

## Screen-by-Screen Changes

### Home
- Replace segmented picker with `WorkspacePillChips`
- Add "Today" summary card (sessions count, total minutes, streak %, accuracy %)
- Redesign session cards: title, "Last active X ago", styled progress bar with fraction, % done chip, Resume/Continue button
- Add header blob gradient decoration
- Move "+" to header area

### Practice
- Add "JP" workspace badge top-right
- Custom slider with styled thumb, 1/N labels, teal track
- Styled Prev/Next pill buttons (gray/teal)
- Original transcript card with bordered text box, translation placeholder, Show toggle as pill with green indicator
- "Play sentence" pill button with play icon
- Large circular mic button (gradient fill, mic icon) with "Tap to record" / "Recording...", clip length, waveform visualization
- Redesigned comparison card with colored word chips (not list)
- "Done and Next" pill button bottom-right

### Import
- Back arrow navigation
- "Key valid"/"Key missing" badge top-right
- Dashed border drop-area for file selection with circle "+" icon
- Selected file card with filename + file size badge
- Session title in styled input card
- Progress bar with percentage (replacing icon list)
- Pipeline step circles with connector lines (already partially implemented)

### Settings
- Replace workspace toggles with pill chips + "+" add button
- Rich validation status card (green bg, checkmark icon, last checked time, status message)
- Add "About" section with version and privacy info in styled cards
- Custom toggle switch styling for "Show original"

### Onboarding
- Light polish to match design system colors

## Functional Additions
- **Session stats**: Track total practice minutes, streak days, accuracy % per workspace
- **Waveform visualization**: Render audio waveform from recording buffer
- **File size display**: Read file size on import
- **Clip length**: Display recording duration in real-time
- **Last active time**: Relative time formatting ("8 min ago", "yesterday")

## Team Structure

### Phase 1: Design System (team lead)
Update `AppTheme.swift` + create shared components

### Phase 2: Parallel Agents
- **home-settings**: Home + Settings screens
- **practice**: Practice screen
- **import**: Import + Onboarding screens

### Phase 3: Integration + Tests
Merge, update tests, build verification

## Test Updates
- Update UI tests for new accessibility identifiers
- Add tests for new stat calculations
- Add tests for waveform data extraction
- Verify all 12 PRD acceptance criteria still pass
