import SwiftUI

// MARK: - Color Tokens (derived from V2 SVG mockups)

enum AppColors {
    // Primary palette
    static let primaryDark = Color(red: 0.075, green: 0.239, blue: 0.353)       // #133D5A
    static let primaryTeal = Color(red: 0.059, green: 0.416, blue: 0.455)       // #0F6A74
    static let tealAccent = Color(red: 0.102, green: 0.431, blue: 0.510)        // #1A6E82
    static let deepTeal = Color(red: 0.059, green: 0.404, blue: 0.459)          // #0F6775

    // Text
    static let textPrimary = Color(red: 0.063, green: 0.129, blue: 0.173)       // #10212C
    static let textSecondary = Color(red: 0.353, green: 0.451, blue: 0.502)     // #5A7380
    static let textHeading = Color(red: 0.106, green: 0.239, blue: 0.290)       // #1B3D4A

    // Chips
    static let chipActive = Color(red: 0.059, green: 0.388, blue: 0.447)        // #0F6372
    static let chipInactiveBg = Color(red: 0.918, green: 0.945, blue: 0.965)    // #EAF1F6
    static let chipInactiveText = Color(red: 0.180, green: 0.325, blue: 0.380)  // #2E5361

    // Progress
    static let progressTrack = Color(red: 0.851, green: 0.906, blue: 0.929)     // #D9E7ED
    static let progressFill = Color(red: 0.055, green: 0.416, blue: 0.471)      // #0E6A78

    // Diff tokens
    static let diffCorrectBg = Color(red: 0.875, green: 0.953, blue: 0.902)     // #DFF3E6
    static let diffCorrectText = Color(red: 0.122, green: 0.416, blue: 0.263)   // #1F6A43
    static let diffMissingBg = Color(red: 0.992, green: 0.918, blue: 0.906)     // #FDEAE7
    static let diffMissingText = Color(red: 0.718, green: 0.282, blue: 0.220)   // #B74838
    static let diffWrongBg = Color(red: 1.0, green: 0.945, blue: 0.871)         // #FFF1DE
    static let diffWrongText = Color(red: 0.671, green: 0.412, blue: 0.075)     // #AB6913
    static let diffExtraBg = Color(red: 0.925, green: 0.918, blue: 1.0)         // #ECEAFF
    static let diffExtraText = Color(red: 0.369, green: 0.298, blue: 0.780)     // #5E4CC7

    // Recording
    static let recordStart = Color(red: 0.078, green: 0.263, blue: 0.361)       // #14435C
    static let recordEnd = Color(red: 0.055, green: 0.478, blue: 0.486)         // #0E7A7C

    // Validation
    static let validSuccessBg = Color(red: 0.918, green: 0.965, blue: 0.933)    // #EAF6EE
    static let validSuccessText = Color(red: 0.137, green: 0.412, blue: 0.278)  // #236947
    static let validSuccessIcon = Color(red: 0.169, green: 0.541, blue: 0.325)  // #2B8A53

    // Status chips
    static let chipGreenBg = Color(red: 0.894, green: 0.957, blue: 0.918)       // #E4F4EA
    static let chipGreenText = Color(red: 0.176, green: 0.416, blue: 0.286)     // #2D6A49
    static let chipBlueBg = Color(red: 0.902, green: 0.941, blue: 0.965)        // #E6F0F6
    static let chipPurpleBg = Color(red: 0.953, green: 0.929, blue: 0.976)      // #F3EDF9
    static let chipPurpleText = Color(red: 0.439, green: 0.341, blue: 0.553)    // #70578D

    // Borders & surfaces
    static let cardBorder = Color(red: 0.843, green: 0.898, blue: 0.918)        // #D7E4EA
    static let inputBg = Color(red: 0.957, green: 0.980, blue: 0.992)           // #F4FAFC
    static let inputBorder = Color(red: 0.808, green: 0.882, blue: 0.922)       // #CEE1EB
}

// MARK: - Theme

enum AppTheme {
    static let screenBackground = LinearGradient(
        colors: [
            Color(red: 0.965, green: 0.984, blue: 1.0),   // #F6FBFF
            Color(red: 0.949, green: 0.984, blue: 0.961)   // #F2FBF5
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = LinearGradient(
        colors: [
            Color.white,
            Color(red: 0.976, green: 0.988, blue: 1.0)     // #F9FCFF
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryButton = LinearGradient(
        colors: [AppColors.primaryDark, AppColors.primaryTeal],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let recordButton = LinearGradient(
        colors: [AppColors.recordStart, AppColors.recordEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Card Modifier

private struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: Color(red: 0.04, green: 0.17, blue: 0.26).opacity(0.08), radius: 12, x: 0, y: 10)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(AppCardModifier())
    }
}

// MARK: - Workspace Pill Chips

struct WorkspacePillChips: View {
    let workspaces: [WorkspaceLanguage]
    @Binding var selected: WorkspaceLanguage

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(workspaces) { language in
                    Button {
                        selected = language
                    } label: {
                        Text(language.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(language == selected ? .white : AppColors.chipInactiveText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(language == selected ? AppColors.chipActive : AppColors.chipInactiveBg)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("workspaceChip_\(language.rawValue)")
                }
            }
        }
    }
}

// MARK: - Styled Progress Bar

struct StyledProgressBar: View {
    let progress: Double
    let completed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.progressTrack)
                    .frame(height: 10)

                GeometryReader { geo in
                    Capsule()
                        .fill(AppColors.progressFill)
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 10)
                }
                .frame(height: 10)
            }

            HStack {
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.chipInactiveText)
            }
        }
    }
}

// MARK: - Diff Token Chip

struct DiffTokenChip: View {
    let text: String
    let kind: DiffToken.Kind

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var bgColor: Color {
        switch kind {
        case .correct: return AppColors.diffCorrectBg
        case .missing: return AppColors.diffMissingBg
        case .wrong:   return AppColors.diffWrongBg
        case .extra:   return AppColors.diffExtraBg
        }
    }

    private var textColor: Color {
        switch kind {
        case .correct: return AppColors.diffCorrectText
        case .missing: return AppColors.diffMissingText
        case .wrong:   return AppColors.diffWrongText
        case .extra:   return AppColors.diffExtraText
        }
    }
}

// MARK: - Diff Summary Chips

struct DiffSummaryChips: View {
    let result: DiffResult

    var body: some View {
        HStack(spacing: 8) {
            if result.summary.missingCount > 0 {
                summaryChip("missing \(result.summary.missingCount)", bg: AppColors.diffMissingBg, text: AppColors.diffMissingText)
            }
            if result.summary.wrongCount > 0 {
                summaryChip("wrong \(result.summary.wrongCount)", bg: AppColors.diffWrongBg, text: AppColors.diffWrongText)
            }
            if result.summary.extraCount > 0 {
                summaryChip("extra \(result.summary.extraCount)", bg: AppColors.diffExtraBg, text: AppColors.diffExtraText)
            }
        }
    }

    private func summaryChip(_ label: String, bg: Color, text: Color) -> some View {
        Text(label)
            .font(.caption.weight(.bold))
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg, in: Capsule())
    }
}

// MARK: - Styled Pill Button

struct PillButton: View {
    let title: String
    let icon: String?
    let style: PillButtonStyle
    let action: () -> Void

    enum PillButtonStyle {
        case primary
        case secondary
    }

    init(_ title: String, icon: String? = nil, style: PillButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(style == .primary ? .white : AppColors.chipInactiveText)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(style == .primary ? AnyShapeStyle(AppTheme.primaryButton) : AnyShapeStyle(AppColors.chipInactiveBg))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Relative Time Formatter

enum RelativeTimeFormatter {
    static func string(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins) min ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else if seconds < 172800 {
            return "Yesterday"
        } else {
            let days = seconds / 86400
            return "\(days) days ago"
        }
    }
}

// MARK: - File Size Formatter

enum FileSizeFormatter {
    static func string(from bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1_048_576 {
            return "\(bytes / 1024) KB"
        } else {
            let mb = Double(bytes) / 1_048_576.0
            return String(format: "%.0f MB", mb)
        }
    }
}
