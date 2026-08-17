//
//  JSONStore.swift
//  selectedai
//

import Foundation

/// Generic atomic JSON file store.
final class JSONStore<T: Codable> {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String) {
        let dir = Self.appSupportDirectory()
        fileURL = dir.appendingPathComponent(filename)
    }

    func load() throws -> T {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(T.self, from: data)
    }

    func save(_ value: T) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        // Atomic write via a temp file
        let tempURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.lastPathComponent + ".tmp")
        try data.write(to: tempURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    }

    // MARK: - Private

    private static func appSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("SelectedAI")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
