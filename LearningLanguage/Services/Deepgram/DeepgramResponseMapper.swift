import Foundation

struct DeepgramUtterance: Equatable {
    let transcript: String
    let startSec: Double?
    let endSec: Double?
}

struct DeepgramTranscriptionResult: Equatable {
    let transcript: String
    let utterances: [DeepgramUtterance]
}

enum DeepgramResponseMapperError: Error {
    case invalidPayload
    case missingTranscript
}

enum DeepgramResponseMapper {
    static func mapListenResponse(data: Data) throws -> DeepgramTranscriptionResult {
        let decoder = JSONDecoder()
        let response = try decoder.decode(DeepgramListenResponse.self, from: data)

        let fallbackTranscript = response
            .results?
            .channels?
            .first?
            .alternatives?
            .first?
            .transcript?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let utterances = response.results?.utterances?
            .compactMap { utterance -> DeepgramUtterance? in
                guard let rawTranscript = utterance.transcript?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawTranscript.isEmpty
                else {
                    return nil
                }

                return DeepgramUtterance(
                    transcript: rawTranscript,
                    startSec: utterance.start,
                    endSec: utterance.end
                )
            } ?? []

        let transcript: String
        if !utterances.isEmpty {
            transcript = utterances.map(\.transcript).joined(separator: " ")
        } else if let fallbackTranscript, !fallbackTranscript.isEmpty {
            transcript = fallbackTranscript
        } else {
            throw DeepgramResponseMapperError.missingTranscript
        }

        return DeepgramTranscriptionResult(transcript: transcript, utterances: utterances)
    }
}

private struct DeepgramListenResponse: Decodable {
    let results: Results?

    struct Results: Decodable {
        let channels: [Channel]?
        let utterances: [Utterance]?

        struct Channel: Decodable {
            let alternatives: [Alternative]?

            struct Alternative: Decodable {
                let transcript: String?
            }
        }

        struct Utterance: Decodable {
            let transcript: String?
            let start: Double?
            let end: Double?
        }
    }
}
