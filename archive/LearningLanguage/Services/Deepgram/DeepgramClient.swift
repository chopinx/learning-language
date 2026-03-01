import Foundation

protocol DeepgramTranscribing {
    func transcribeAudio(fileURL: URL, apiKey: String, languageCode: String?) async throws -> DeepgramTranscriptionResult
    func generateSpeechAudio(text: String, apiKey: String, model: String) async throws -> Data
    func validateAPIKey(_ apiKey: String) async throws -> Bool
}

enum DeepgramClientError: LocalizedError {
    case badRequest
    case unsupportedAudioType
    case emptyText
    case emptyAudioResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .badRequest:
            return "Failed to build Deepgram request"
        case .unsupportedAudioType:
            return "Only m4a, mp3, and wav files are supported"
        case .emptyText:
            return "Text input cannot be empty"
        case .emptyAudioResponse:
            return "Deepgram returned empty audio data"
        case let .serverError(statusCode):
            return "Deepgram request failed (\(statusCode))"
        }
    }
}

struct DeepgramClient: DeepgramTranscribing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func transcribeAudio(fileURL: URL, apiKey: String, languageCode: String?) async throws -> DeepgramTranscriptionResult {
        guard let contentType = contentType(for: fileURL) else {
            throw DeepgramClientError.unsupportedAudioType
        }

        var components = URLComponents(string: "https://api.deepgram.com/v1/listen")
        var queryItems = [
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "utterances", value: "true")
        ]

        if let languageCode {
            queryItems.append(URLQueryItem(name: "language", value: languageCode))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw DeepgramClientError.badRequest
        }

        let audioData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: fileURL)
        }.value

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramClientError.badRequest
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw DeepgramClientError.serverError(statusCode: httpResponse.statusCode)
        }

        return try DeepgramResponseMapper.mapListenResponse(data: data)
    }

    func generateSpeechAudio(text: String, apiKey: String, model: String) async throws -> Data {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw DeepgramClientError.emptyText
        }

        var components = URLComponents(string: "https://api.deepgram.com/v1/speak")
        components?.queryItems = [URLQueryItem(name: "model", value: model)]

        guard let url = components?.url else {
            throw DeepgramClientError.badRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(SpeakRequest(text: trimmedText))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramClientError.badRequest
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw DeepgramClientError.serverError(statusCode: httpResponse.statusCode)
        }

        guard !data.isEmpty else {
            throw DeepgramClientError.emptyAudioResponse
        }

        return data
    }

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        guard let url = URL(string: "https://api.deepgram.com/v1/projects") else {
            throw DeepgramClientError.badRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepgramClientError.badRequest
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            return false
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw DeepgramClientError.serverError(statusCode: httpResponse.statusCode)
        }

        return true
    }

    private func contentType(for fileURL: URL) -> String? {
        switch fileURL.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        default:
            return nil
        }
    }
}

private struct SpeakRequest: Encodable {
    let text: String
}
