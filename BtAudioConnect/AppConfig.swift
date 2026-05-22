import Foundation

struct AppConfig: Codable, Equatable {
    var deviceName: String
    var enabled: Bool
    var fallbackCheckIntervalSeconds: Double
    var connectCooldownSeconds: Double

    enum CodingKeys: String, CodingKey {
        case deviceName
        case enabled
        case fallbackCheckIntervalSeconds
        case connectCooldownSeconds
        case pollIntervalSeconds
    }

    init(
        deviceName: String,
        enabled: Bool,
        fallbackCheckIntervalSeconds: Double,
        connectCooldownSeconds: Double
    ) {
        self.deviceName = deviceName
        self.enabled = enabled
        self.fallbackCheckIntervalSeconds = fallbackCheckIntervalSeconds
        self.connectCooldownSeconds = connectCooldownSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        connectCooldownSeconds = try container.decode(Double.self, forKey: .connectCooldownSeconds)

        if let fallback = try container.decodeIfPresent(Double.self, forKey: .fallbackCheckIntervalSeconds) {
            fallbackCheckIntervalSeconds = fallback
        } else if let legacyPoll = try container.decodeIfPresent(Double.self, forKey: .pollIntervalSeconds) {
            fallbackCheckIntervalSeconds = max(legacyPoll, 15)
        } else {
            fallbackCheckIntervalSeconds = 30
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(fallbackCheckIntervalSeconds, forKey: .fallbackCheckIntervalSeconds)
        try container.encode(connectCooldownSeconds, forKey: .connectCooldownSeconds)
    }

    static let `default` = AppConfig(
        deviceName: "xxx",
        enabled: true,
        fallbackCheckIntervalSeconds: 30,
        connectCooldownSeconds: 10.0
    )
}
