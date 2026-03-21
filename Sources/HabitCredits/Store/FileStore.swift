import Foundation

struct AppSnapshot: Codable {
    var habits: [Habit]
    var records: [HabitRecord]
}

final class FileStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let isoFormatter: ISO8601DateFormatter

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.isoFormatter = ISO8601DateFormatter()
        self.isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func load() throws -> AppSnapshot {
        let url = try storeUrl()
        guard fileManager.fileExists(atPath: url.path) else {
            return AppSnapshot(habits: [], records: [])
        }
        let data = try Data(contentsOf: url)
        return try decodeSnapshot(from: data)
    }

    func save(snapshot: AppSnapshot) throws {
        let url = try storeUrl()
        let dir = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try encodeSnapshot(snapshot)
        let tmp = dir.appendingPathComponent(".store-\(UUID().uuidString).tmp")
        try data.write(to: tmp, options: [.atomic])
        try replaceItem(at: url, withItemAt: tmp)
    }

    func encodeSnapshot(_ snapshot: AppSnapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    func decodeSnapshot(from data: Data) throws -> AppSnapshot {
        do {
            return try decoder.decode(AppSnapshot.self, from: data)
        } catch {
            // 兼容：部分文件可能缺少 fractionalSeconds 的 ISO8601
            let fallback = JSONDecoder()
            fallback.dateDecodingStrategy = .custom { dec in
                let c = try dec.singleValueContainer()
                let s = try c.decode(String.self)
                if let d = self.isoFormatter.date(from: s) {
                    return d
                }
                let fmt = ISO8601DateFormatter()
                fmt.formatOptions = [.withInternetDateTime]
                if let d = fmt.date(from: s) {
                    return d
                }
                throw error
            }
            return try fallback.decode(AppSnapshot.self, from: data)
        }
    }

    private func storeUrl() throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("HabitCredits", isDirectory: true)
        return dir.appendingPathComponent("store.json", isDirectory: false)
    }

    private func replaceItem(at originalUrl: URL, withItemAt newUrl: URL) throws {
        if fileManager.fileExists(atPath: originalUrl.path) {
            _ = try fileManager.replaceItemAt(originalUrl, withItemAt: newUrl)
        } else {
            try fileManager.moveItem(at: newUrl, to: originalUrl)
        }
    }
}

