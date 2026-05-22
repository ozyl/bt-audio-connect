import Foundation

@MainActor
final class ConfigManager: ObservableObject {
    @Published private(set) var config: AppConfig

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = appSupport.appendingPathComponent("BtAudioConnect", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("config.json")

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? decoder.decode(AppConfig.self, from: data) {
            config = loaded
        } else if let bundled = Bundle.main.url(forResource: "default-config", withExtension: "json"),
                  let data = try? Data(contentsOf: bundled),
                  let loaded = try? decoder.decode(AppConfig.self, from: data) {
            config = loaded
            save()
        } else {
            config = .default
            save()
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func update(_ transform: (inout AppConfig) -> Void) {
        var next = config
        transform(&next)
        config = next
        save()
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL),
              let loaded = try? decoder.decode(AppConfig.self, from: data) else {
            return
        }
        config = loaded
    }

    private func save() {
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    var configFilePath: String {
        fileURL.path
    }
}
