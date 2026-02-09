//
//  ScriptLoader.swift
//  ScriptFlow
//
//  Loads the ACA script with remote-first strategy:
//  1. Fetch latest from GitHub Releases
//  2. Fall back to local cache
//  3. Fall back to bundled resource
//

import Foundation

enum ScriptSource: Equatable {
    case remote
    case cached(Date)
    case bundled

    var description: String {
        switch self {
        case .remote:
            return "Latest version"
        case .cached(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            let relative = formatter.localizedString(for: date, relativeTo: Date())
            return "Cached \(relative)"
        case .bundled:
            return "Bundled version"
        }
    }
}

struct ScriptLoader {
    static let remoteScriptURL = "https://github.com/ehoyos007/scriptflow/releases/latest/download/aca-script.md"

    private static var cacheURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCache = caches.appendingPathComponent("com.fhe.ScriptFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: appCache, withIntermediateDirectories: true)
        return appCache.appendingPathComponent("cached-aca-script.md")
    }

    static func loadScript() async -> (Script?, ScriptSource) {
        // 1. Try remote fetch
        if let content = await fetchRemote() {
            cacheScript(content)
            let script = ScriptParser.parse(markdown: content)
            return (script, .remote)
        }

        // 2. Fall back to cached version
        if let content = loadCached() {
            let script = ScriptParser.parse(markdown: content)
            let date = getCacheDate() ?? Date.distantPast
            return (script, .cached(date))
        }

        // 3. Fall back to bundled resource
        if let bundlePath = Bundle.main.path(forResource: "aca-script", ofType: "md"),
           let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            let script = ScriptParser.parse(markdown: content)
            return (script, .bundled)
        }

        return (nil, .bundled)
    }

    static func fetchRemote() async -> String? {
        guard let url = URL(string: remoteScriptURL) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let content = String(data: data, encoding: .utf8),
                  !content.isEmpty else {
                return nil
            }
            return content
        } catch {
            return nil
        }
    }

    static func cacheScript(_ content: String) {
        try? content.write(to: cacheURL, atomically: true, encoding: .utf8)
    }

    static func loadCached() -> String? {
        try? String(contentsOf: cacheURL, encoding: .utf8)
    }

    static func getCacheDate() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? Date
    }
}
