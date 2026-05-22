import Foundation

/// Fetches and caches bible.helloao.org's catalog of ~1000+ translations.
///
/// The manifest (`/api/available_translations.json`) is ~1–2 MB. We fetch it
/// once, persist the decoded `[TranslationRef]` to disk, and refresh no more
/// than once per `refreshInterval`. The UI reads from the in-memory list;
/// the fetch itself is triggered at app launch (fire-and-forget).
///
/// No API key, MIT license, commercial use permitted — see
/// bible.helloao.org/docs/guide/a-biblical-model-for-licensing-the-bible.html.
@Observable
@MainActor
final class TranslationCatalog {
    static let shared = TranslationCatalog()

    private(set) var translations: [TranslationRef] = []
    private(set) var isRefreshing: Bool = false
    private(set) var lastRefreshError: String?

    /// Refresh at most once per week in normal operation. Manual pulls can
    /// override this via `refresh(force: true)`.
    private static let refreshInterval: TimeInterval = 60 * 60 * 24 * 7

    private static let manifestURL = URL(string: "https://bible.helloao.org/api/available_translations.json")!

    private init() {
        loadFromDisk()
    }

    // MARK: - Public API

    var languages: [(language: String, translations: [TranslationRef])] {
        translations.groupedByLanguage()
    }

    func translation(id: String) -> TranslationRef? {
        translations.first { $0.id == id }
    }

    /// Kick off a background refresh if the cache is stale or missing.
    /// Safe to call from `onAppear` — it no-ops when a refresh is running.
    func refreshIfNeeded() {
        guard !isRefreshing else { return }
        if let stamp = Self.readTimestamp(),
           Date().timeIntervalSince(stamp) < Self.refreshInterval,
           !translations.isEmpty {
            return
        }
        Task { await refresh(force: false) }
    }

    func refresh(force: Bool) async {
        guard !isRefreshing else { return }
        if !force,
           let stamp = Self.readTimestamp(),
           Date().timeIntervalSince(stamp) < Self.refreshInterval,
           !translations.isEmpty {
            return
        }

        isRefreshing = true
        lastRefreshError = nil
        defer { isRefreshing = false }

        do {
            var request = URLRequest(url: Self.manifestURL)
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let decoded = try Self.decodeManifest(data)
            translations = decoded
            Self.writeDisk(data: data, timestamp: Date())
        } catch {
            lastRefreshError = error.localizedDescription
        }
    }

    // MARK: - Decoding

    /// helloao's manifest is either a bare array of entries or an object with
    /// a top-level `translations` key — decode both defensively.
    private static func decodeManifest(_ data: Data) throws -> [TranslationRef] {
        let decoder = JSONDecoder()
        if let wrapper = try? decoder.decode(Wrapper.self, from: data) {
            return wrapper.translations.map(TranslationRef.init(from:))
        }
        let bare = try decoder.decode([TranslationRef.HelloAOEntry].self, from: data)
        return bare.map(TranslationRef.init(from:))
    }

    private struct Wrapper: Decodable {
        let translations: [TranslationRef.HelloAOEntry]
    }

    // MARK: - Disk persistence

    private static var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("TranslationCatalog", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var manifestFileURL: URL { cacheDirectory.appendingPathComponent("available_translations.json") }
    private static var timestampFileURL: URL { cacheDirectory.appendingPathComponent("available_translations.timestamp") }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: Self.manifestFileURL),
              let decoded = try? Self.decodeManifest(data) else {
            return
        }
        translations = decoded
    }

    private static func writeDisk(data: Data, timestamp: Date) {
        try? data.write(to: manifestFileURL, options: .atomic)
        let iso = ISO8601DateFormatter().string(from: timestamp)
        try? iso.write(to: timestampFileURL, atomically: true, encoding: .utf8)
    }

    private static func readTimestamp() -> Date? {
        guard let raw = try? String(contentsOf: timestampFileURL, encoding: .utf8) else { return nil }
        return ISO8601DateFormatter().date(from: raw)
    }
}
