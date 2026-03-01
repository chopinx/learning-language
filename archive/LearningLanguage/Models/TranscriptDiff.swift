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
    private enum Operation {
        case match(String, String)
        case substitute(String, String)
        case delete(String)
        case insert(String)
    }

    static func compare(source: String, user: String) -> DiffResult {
        let sourceWords = normalizedWords(from: source)
        let userWords = normalizedWords(from: user)
        let operations = align(source: sourceWords, user: userWords)

        var tokens: [DiffToken] = []
        var summary = DiffSummary(correctCount: 0, missingCount: 0, wrongCount: 0, extraCount: 0)

        for operation in operations {
            switch operation {
            case let .match(sourceWord, userWord):
                summary.correctCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: sourceWord, userWord: userWord, kind: .correct))
            case let .substitute(sourceWord, userWord):
                summary.wrongCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: sourceWord, userWord: userWord, kind: .wrong))
            case let .delete(sourceWord):
                summary.missingCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: sourceWord, userWord: nil, kind: .missing))
            case let .insert(userWord):
                summary.extraCount += 1
                tokens.append(DiffToken(id: UUID(), sourceWord: nil, userWord: userWord, kind: .extra))
            }
        }

        return DiffResult(tokens: tokens, summary: summary)
    }

    private static func align(source: [String], user: [String]) -> [Operation] {
        let n = source.count
        let m = user.count

        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)

        for i in 0...n {
            dp[i][0] = i
        }

        for j in 0...m {
            dp[0][j] = j
        }

        if n > 0, m > 0 {
            for i in 1...n {
                for j in 1...m {
                    if source[i - 1] == user[j - 1] {
                        dp[i][j] = dp[i - 1][j - 1]
                    } else {
                        dp[i][j] = min(
                            dp[i - 1][j] + 1,
                            dp[i][j - 1] + 1,
                            dp[i - 1][j - 1] + 1
                        )
                    }
                }
            }
        }

        var i = n
        var j = m
        var operations: [Operation] = []

        while i > 0 || j > 0 {
            if i > 0, j > 0, source[i - 1] == user[j - 1], dp[i][j] == dp[i - 1][j - 1] {
                operations.append(.match(source[i - 1], user[j - 1]))
                i -= 1
                j -= 1
            } else if i > 0, j > 0, dp[i][j] == dp[i - 1][j - 1] + 1 {
                operations.append(.substitute(source[i - 1], user[j - 1]))
                i -= 1
                j -= 1
            } else if i > 0, dp[i][j] == dp[i - 1][j] + 1 {
                operations.append(.delete(source[i - 1]))
                i -= 1
            } else if j > 0 {
                operations.append(.insert(user[j - 1]))
                j -= 1
            }
        }

        return operations.reversed()
    }

    private static func normalizedWords(from text: String) -> [String] {
        let allowedSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'"))

        return text
            .lowercased()
            .split { $0.isWhitespace }
            .compactMap { segment in
                let filteredScalars = segment.unicodeScalars.filter { allowedSet.contains($0) }
                let cleaned = String(String.UnicodeScalarView(filteredScalars))
                return cleaned.isEmpty ? nil : cleaned
            }
    }
}
