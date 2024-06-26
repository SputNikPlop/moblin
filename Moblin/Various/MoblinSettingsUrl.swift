import Foundation

class MoblinSettingsUrlStreamVideo: Codable {
    var codec: SettingsStreamCodec?
}

class MoblinSettingsUrlStreamObs: Codable {
    var webSocketUrl: String
    var webSocketPassword: String
}

class MoblinSettingsUrlStream: Codable {
    var name: String
    var url: String
    var video: MoblinSettingsUrlStreamVideo?
    var obs: MoblinSettingsUrlStreamObs?
}

class MoblinSettingsButton: Codable {
    var type: SettingsButtonType
    var enabled: Bool?
}

class MoblinQuickButtons: Codable {
    var twoColumns: Bool?
    var showName: Bool?
    var enableScroll: Bool?
    // Use "buttons" to enable buttons after disabling all.
    var disableAllButtons: Bool?
    var buttons: [MoblinSettingsButton]?
}

class MoblinSettingsUrl: Codable {
    var streams: [MoblinSettingsUrlStream]?
    var quickButtons: MoblinQuickButtons?

    static func fromString(query: String) throws -> MoblinSettingsUrl {
        let query = try JSONDecoder().decode(
            MoblinSettingsUrl.self,
            from: query.data(using: .utf8)!
        )
        for stream in query.streams ?? [] {
            if let message = isValidUrl(url: cleanUrl(url: stream.url)) {
                throw message
            }
            if let obs = stream.obs {
                if let message = isValidWebSocketUrl(url: cleanUrl(url: obs.webSocketUrl)) {
                    throw message
                }
            }
        }
        return query
    }
}
