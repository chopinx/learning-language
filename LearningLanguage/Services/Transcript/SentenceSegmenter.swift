import Foundation

struct SentenceSlice: Equatable {
    let text: String
    let startSec: Double?
    let endSec: Double?
}

enum SentenceSegmenter {
    /// Sentence-ending punctuation marks.
    private static let sentenceEnders: Set<Character> = [".", "!", "?", "。", "！", "？"]

    static func segment(result: DeepgramTranscriptionResult, minDuration: Double = 0) -> [SentenceSlice] {
        let sentences: [SentenceSlice]

        if !result.utterances.isEmpty {
            // Step 1: Merge utterances at sentence boundaries
            sentences = mergeUtterancesAtSentenceBoundaries(result.utterances)
        } else {
            // Fallback: split full transcript by punctuation (no timing)
            sentences = splitByPunctuation(result.transcript)
                .map { SentenceSlice(text: $0, startSec: nil, endSec: nil) }
        }

        // Step 2: Merge short segments by duration
        guard minDuration > 0 else { return sentences }
        return mergeShortSegments(sentences, minDuration: minDuration)
    }

    // MARK: - Merge utterances at sentence boundaries

    /// Concatenate consecutive utterances until the combined text ends with
    /// sentence-ending punctuation (. ! ? etc.), then start a new segment.
    static func mergeUtterancesAtSentenceBoundaries(_ utterances: [DeepgramUtterance]) -> [SentenceSlice] {
        guard !utterances.isEmpty else { return [] }

        var result: [SentenceSlice] = []
        var currentText = ""
        var currentStart: Double? = nil
        var currentEnd: Double? = nil

        for utterance in utterances {
            let text = utterance.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            if currentText.isEmpty {
                currentStart = utterance.startSec
            }
            currentText += (currentText.isEmpty ? "" : " ") + text
            currentEnd = utterance.endSec

            // Check if the combined text ends at a sentence boundary
            if let lastChar = currentText.last, sentenceEnders.contains(lastChar) {
                result.append(SentenceSlice(
                    text: currentText.trimmingCharacters(in: .whitespacesAndNewlines),
                    startSec: currentStart,
                    endSec: currentEnd
                ))
                currentText = ""
                currentStart = nil
                currentEnd = nil
            }
        }

        // Flush remaining text (didn't end with punctuation)
        let remaining = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            result.append(SentenceSlice(text: remaining, startSec: currentStart, endSec: currentEnd))
        }

        return result
    }

    // MARK: - Merge short segments by duration

    static func mergeShortSegments(_ slices: [SentenceSlice], minDuration: Double) -> [SentenceSlice] {
        guard slices.count > 1 else { return slices }

        var merged: [SentenceSlice] = []
        var pending: SentenceSlice? = nil

        for slice in slices {
            if let p = pending {
                let combined = SentenceSlice(
                    text: p.text + " " + slice.text,
                    startSec: p.startSec ?? slice.startSec,
                    endSec: slice.endSec ?? p.endSec
                )

                if duration(of: combined) < minDuration {
                    pending = combined
                } else {
                    merged.append(combined)
                    pending = nil
                }
            } else if duration(of: slice) < minDuration {
                pending = slice
            } else {
                merged.append(slice)
            }
        }

        if let p = pending {
            if let last = merged.last {
                merged.removeLast()
                merged.append(SentenceSlice(
                    text: last.text + " " + p.text,
                    startSec: last.startSec,
                    endSec: p.endSec ?? last.endSec
                ))
            } else {
                merged.append(p)
            }
        }

        return merged
    }

    // MARK: - Helpers

    private static func duration(of slice: SentenceSlice) -> Double {
        guard let start = slice.startSec, let end = slice.endSec else { return .infinity }
        return end - start
    }

    static func splitByPunctuation(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if sentenceEnders.contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { sentences.append(trimmed) }

        return sentences
    }
}
