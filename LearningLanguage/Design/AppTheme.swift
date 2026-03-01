import SwiftUI

// MARK: - Color(hex:) Initializer

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App Color Theme
// Fresh, modern palette matching ProjectX design language

extension Color {
    // MARK: - Primary Colors
    /// Main brand color - Fresh emerald green
    static let themePrimary = Color(hex: "10B981")!
    /// Darker variant for contrast
    static let themePrimaryDark = Color(hex: "059669")!

    // MARK: - Secondary Colors
    /// Warm accent - Coral orange
    static let themeSecondary = Color(hex: "F97316")!
    /// Lighter variant
    static let themeSecondaryLight = Color(hex: "FB923C")!

    // MARK: - Semantic Colors
    /// Success - Bright green
    static let themeSuccess = Color(hex: "22C55E")!
    /// Warning - Amber
    static let themeWarning = Color(hex: "F59E0B")!
    /// Error - Rose red
    static let themeError = Color(hex: "EF4444")!
    /// Info - Sky blue
    static let themeInfo = Color(hex: "0EA5E9")!

    // MARK: - Neutral Colors (adaptive for dark/light mode)
    static let themeBackground = Color(.systemGroupedBackground)
    static let themeCardBackground = Color(.systemBackground)
    static let themeBorder = Color(.separator)
    static let themeTextPrimary = Color(.label)
    static let themeTextSecondary = Color(.secondaryLabel)
    static let themeTextTertiary = Color(.tertiaryLabel)

    // MARK: - Diff Token Colors
    static let diffCorrectBg = Color(hex: "D1FAE5")!
    static let diffCorrectText = Color(hex: "065F46")!
    static let diffMissingBg = Color(hex: "FEE2E2")!
    static let diffMissingText = Color(hex: "991B1B")!
    static let diffWrongBg = Color(hex: "FEF3C7")!
    static let diffWrongText = Color(hex: "92400E")!
    static let diffExtraBg = Color(hex: "EDE9FE")!
    static let diffExtraText = Color(hex: "5B21B6")!

    // MARK: - Gradient
    static var themePrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [themePrimary, Color(hex: "14B8A6")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func appCard() -> some View {
        modifier(ThemedCardModifier())
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
        case .correct: return .diffCorrectBg
        case .missing: return .diffMissingBg
        case .wrong:   return .diffWrongBg
        case .extra:   return .diffExtraBg
        }
    }

    private var textColor: Color {
        switch kind {
        case .correct: return .diffCorrectText
        case .missing: return .diffMissingText
        case .wrong:   return .diffWrongText
        case .extra:   return .diffExtraText
        }
    }
}

// MARK: - Diff Summary Chips

struct DiffSummaryChips: View {
    let result: DiffResult

    var body: some View {
        HStack(spacing: 8) {
            if result.summary.missingCount > 0 {
                ChipView(
                    text: "missing \(result.summary.missingCount)",
                    foregroundColor: .diffMissingText,
                    backgroundColor: .diffMissingBg
                )
            }
            if result.summary.wrongCount > 0 {
                ChipView(
                    text: "wrong \(result.summary.wrongCount)",
                    foregroundColor: .diffWrongText,
                    backgroundColor: .diffWrongBg
                )
            }
            if result.summary.extraCount > 0 {
                ChipView(
                    text: "extra \(result.summary.extraCount)",
                    foregroundColor: .diffExtraText,
                    backgroundColor: .diffExtraBg
                )
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
        VStack(alignment: .trailing, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.themePrimary)
                        .frame(width: max(0, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            Text("\(completed)/\(total)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.themeTextTertiary)
        }
    }
}

// MARK: - Relative Time Formatter

enum RelativeTimeFormatter {
    static func string(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(seconds / 60) min ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 172800 { return "Yesterday" }
        return "\(seconds / 86400) days ago"
    }
}

// MARK: - File Size Formatter

enum FileSizeFormatter {
    static func string(from bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1_048_576 { return "\(bytes / 1024) KB" }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576.0)
    }
}

// MARK: - Chip Component

struct ChipView: View {
    let text: String
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor, in: Capsule())
    }
}

