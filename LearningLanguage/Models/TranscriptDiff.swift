import Foundation

struct DiffResult: Codable, Hashable {
    var tokens: [DiffToken]
    var summary: DiffSummary
}

struct DiffSummary: Codable, Hashable {
    var correctCount: Int
    var missingCount: Int
    var wrongCount: Int
    var extraCount: Int
}

struct DiffToken: Codable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case correct
        case missing
        case wrong
        case extra
    }

    var id: UUID
    var sourceWord: String?
    var userWord: String?
    var kind: Kind
}

enum TranscriptDiffer {
    /// Minimum ratio of matching characters for two words to be considered a match.
    static let fuzzyMatchThreshold: Double = 0.7

    static func compare(source: String, user: String) -> DiffResult {
        let sourceWords = normalizedWords(from: source)
        let userWords = normalizedWords(from: user)

        // Find which source words the user said (fuzzy match, order-preserving)
        let matched = findMatches(source: sourceWords, user: userWords)

        var tokens: [DiffToken] = []
        var correctCount = 0
        var missingCount = 0

        for (index, word) in sourceWords.enumerated() {
            if matched.contains(index) {
                correctCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: word, userWord: word, kind: .correct))
            } else {
                missingCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: word, userWord: nil, kind: .missing))
            }
        }

        let summary = DiffSummary(
            correctCount: correctCount,
            missingCount: missingCount,
            wrongCount: 0,
            extraCount: 0
        )

        return DiffResult(tokens: tokens, summary: summary)
    }

    /// Find which source word indices the user matched using LCS (Longest Common Subsequence)
    /// with fuzzy word matching. Returns the maximum set of source words said in order.
    private static func findMatches(source: [String], user: [String]) -> Set<Int> {
        let n = source.count
        let m = user.count
        guard n > 0, m > 0 else { return [] }

        // Build LCS table with fuzzy matching
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        for i in 1...n {
            for j in 1...m {
                if fuzzyMatch(source[i - 1], user[j - 1]) {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        // Backtrack to find which source indices matched
        var matched: Set<Int> = []
        var i = n, j = m
        while i > 0 && j > 0 {
            if fuzzyMatch(source[i - 1], user[j - 1]) && dp[i][j] == dp[i - 1][j - 1] + 1 {
                matched.insert(i - 1)
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        return matched
    }

    /// Two words match if they share at least 70% of characters (longest common subsequence).
    static func fuzzyMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return true }

        let lcsLen = longestCommonSubsequence(Array(a), Array(b))
        return Double(lcsLen) / Double(maxLen) >= fuzzyMatchThreshold
    }

    private static func longestCommonSubsequence(_ a: [Character], _ b: [Character]) -> Int {
        let n = a.count
        let m = b.count
        guard n > 0, m > 0 else { return 0 }

        var prev = Array(repeating: 0, count: m + 1)
        var curr = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            for j in 1...m {
                if a[i - 1] == b[j - 1] {
                    curr[j] = prev[j - 1] + 1
                } else {
                    curr[j] = max(prev[j], curr[j - 1])
                }
            }
            prev = curr
            curr = Array(repeating: 0, count: m + 1)
        }

        return prev[m]
    }

    /// Strip punctuation, lowercase, split into words.
    private static func normalizedWords(from text: String) -> [String] {
        text.lowercased()
            .split { !$0.isLetter && !$0.isNumber && $0 != "'" }
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}
