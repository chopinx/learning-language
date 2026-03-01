import Foundation

struct SentenceSlice: Equatable {
    let text: String
    let startSec: Double?
    let endSec: Double?
}

enum SentenceSegmenter {
    static func segment(result: DeepgramTranscriptionResult, minDuration: Double = 0) -> [SentenceSlice] {
        let raw: [SentenceSlice]

        if !result.utterances.isEmpty {
            raw = result.utterances
                .map {
                    SentenceSlice(text: $0.transcript, startSec: $0.startSec, endSec: $0.endSec)
                }
                .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            raw = splitByPunctuation(result.transcript)
                .map { SentenceSlice(text: $0, startSec: nil, endSec: nil) }
        }

        guard minDuration > 0 else { return raw }
        return mergeShortSegments(raw, minDuration: minDuration)
    }

    /// Merge segments shorter than `minDuration` with the following segment.
    static func mergeShortSegments(_ slices: [SentenceSlice], minDuration: Double) -> [SentenceSlice] {
        guard !slices.isEmpty else { return [] }
        guard slices.count > 1 else { return slices }

        var merged: [SentenceSlice] = []
        var pending: SentenceSlice? = nil

        for slice in slices {
            if let p = pending {
                // Combine pending with current slice
                let combined = SentenceSlice(
                    text: p.text + " " + slice.text,
                    startSec: p.startSec ?? slice.startSec,
                    endSec: slice.endSec ?? p.endSec
                )

                // Check if the combined result is still too short
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

        // Flush any remaining pending segment
        if let p = pending {
            if let last = merged.last {
                merged.removeLast()
                merged.append(SentenceSlice(
                    text: last.text + " " + p.text,
                    startSec: last.startSec,
                    endSec: p.endSec ?? last.endSec
                ))
            } else {
                // All segments were too short, return the pending one
                merged.append(p)
            }
        }

        return merged
    }

    private static func duration(of slice: SentenceSlice) -> Double {
        guard let start = slice.startSec, let end = slice.endSec else { return .infinity }
        return end - start
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
