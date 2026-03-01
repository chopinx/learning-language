import Foundation

/// Provides the default base directory for storing files, preferring iCloud Drive when available.
enum iCloudDirectoryProvider {
    /// Returns the iCloud Documents directory if available, otherwise falls back to local Documents.
    ///
    /// Apple documentation: `url(forUbiquityContainerIdentifier:)` can be called from any thread.
    /// It should NOT be forced to the main thread as it may block.
    static func defaultBaseDirectory(fileManager: FileManager = .default) -> URL {
        if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documentsURL = iCloudURL.appendingPathComponent("Documents")
            // Ensure the directory exists before returning
            try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            return documentsURL
        }
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
