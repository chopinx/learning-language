import Foundation

enum WorkspaceAudioStoreError: LocalizedError {
    case importFailed
    case unsupportedAudioType
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .importFailed:
            return "Failed to import selected audio file"
        case .unsupportedAudioType:
            return "Only m4a, mp3, and wav files are supported"
        case .writeFailed:
            return "Failed to save generated audio file"
        }
    }
}

final class WorkspaceAudioStore {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL

    init(fileManager: FileManager = .default, baseDirectoryURL: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL ?? iCloudDirectoryProvider.defaultBaseDirectory(fileManager: fileManager)
    }

    func importAudioFile(from sourceURL: URL, sessionID: UUID, workspace: WorkspaceLanguage) throws -> String {
        let extensionName = sourceURL.pathExtension.lowercased()
        guard ["m4a", "mp3", "wav"].contains(extensionName) else {
            throw WorkspaceAudioStoreError.unsupportedAudioType
        }

        let destinationDir = audioDirectory(for: workspace)
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        let fileName = "\(sessionID.uuidString).\(extensionName)"
        let destinationURL = destinationDir.appendingPathComponent(fileName)

        let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return fileName
        } catch {
            throw WorkspaceAudioStoreError.importFailed
        }
    }

    func audioFileURL(fileName: String, workspace: WorkspaceLanguage) -> URL {
        audioDirectory(for: workspace).appendingPathComponent(fileName)
    }

    func saveGeneratedAudioData(_ data: Data, sessionID: UUID, workspace: WorkspaceLanguage, fileExtension: String = "wav") throws -> String {
        let normalizedExtension = fileExtension.lowercased()
        guard ["wav", "mp3", "m4a"].contains(normalizedExtension) else {
            throw WorkspaceAudioStoreError.unsupportedAudioType
        }

        let destinationDir = audioDirectory(for: workspace)
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        let fileName = "\(sessionID.uuidString).\(normalizedExtension)"
        let destinationURL = destinationDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try data.write(to: destinationURL, options: .atomic)
            return fileName
        } catch {
            throw WorkspaceAudioStoreError.writeFailed
        }
    }

    private func audioDirectory(for workspace: WorkspaceLanguage) -> URL {
        baseDirectoryURL
            .appendingPathComponent("workspaces", isDirectory: true)
            .appendingPathComponent(workspace.rawValue, isDirectory: true)
            .appendingPathComponent("audio", isDirectory: true)
    }
}
