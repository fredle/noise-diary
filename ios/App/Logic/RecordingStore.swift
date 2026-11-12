import Foundation

/// Audio clips live as .m4a files in Application Support/Recordings.
/// Entries store only the file name, so the folder can move between installs.
enum RecordingStore {
    static var directory: URL {
        let url = URL.applicationSupportDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func newFile() -> (name: String, url: URL) {
        let name = "\(UUID().uuidString).m4a"
        return (name, url(for: name))
    }

    static func url(for name: String) -> URL {
        directory.appending(path: name, directoryHint: .notDirectory)
    }

    static func exists(_ name: String?) -> Bool {
        guard let name else { return false }
        return FileManager.default.fileExists(atPath: url(for: name).path(percentEncoded: false))
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }
}
