import Foundation

struct SentenceSlice: Equatable {
    let text: String
    let startSec: Double?
    let endSec: Double?
}

enum SentenceSegmenter {
    static func segment(result: DeepgramTranscriptionResult) -> [SentenceSlice] {
        if !result.utterances.isEmpty {
            return result.utterances
                .map {
                    SentenceSlice(text: $0.transcript, startSec: $0.startSec, endSec: $0.endSec)
                }
                .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }

        return splitByPunctuation(result.transcript)
            .map { SentenceSlice(text: $0, startSec: nil, endSec: nil) }
    }

    static func splitByPunctuation(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for character in text {
            current.append(character)

            if ".!?".contains(character) {
                appendSentenceIfNeeded(&sentences, current)
                current = ""
            }
        }

        appendSentenceIfNeeded(&sentences, current)

        return sentences
    }

    private static func appendSentenceIfNeeded(_ sentences: inout [String], _ rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }

        sentences.append(trimmed)
    }
}
