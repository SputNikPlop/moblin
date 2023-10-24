import Foundation

private struct FfzImages: Codable {
    var onex: String?
    var twox: String?
    var fourx: String?

    private enum CodingKeys: String, CodingKey {
        case onex = "1x", twox = "2x", fourx = "4x"
    }
}

private struct FfzEmote: Codable {
    var code: String
    var images: FfzImages
}

func fetchFfzEmotes(platform: EmotesPlatform,
                    channelId: String) async -> ([String: Emote], String?)
{
    var message: String?
    var emotes: [String: Emote] = [:]
    do {
        emotes = try emotes.merging(await fetchGlobalEmotes()) { $1 }
    } catch {
        message = "Failed to get FFZ emotes"
    }
    do {
        emotes = try emotes.merging(await fetchChannelEmotes(
            platform: platform,
            channelId: channelId
        )) { $1 }
    } catch {
        message = "Failed to get FFZ emotes"
    }
    return (emotes, message)
}

private func makeUrl(emote: FfzEmote) -> URL? {
    guard let url = emote.images.fourx ?? emote.images.twox ?? emote.images.onex else {
        return nil
    }
    guard let url = URL(string: url) else {
        return nil
    }
    return url
}

private func fetchGlobalEmotes() async throws -> [String: Emote] {
    return try await fetchEmotes(
        url: "https://api.betterttv.net/3/cached/frankerfacez/emotes/global"
    )
}

private func fetchChannelEmotes(platform: EmotesPlatform,
                                channelId: String) async throws -> [String: Emote]
{
    if channelId.isEmpty {
        return [:]
    }
    if platform == .kick {
        return [:]
    }
    return try await fetchEmotes(
        url: "https://api.betterttv.net/3/cached/frankerfacez/users/twitch/\(channelId)"
    )
}

private func fetchEmotes(url: String) async throws -> [String: Emote] {
    var emotes: [String: Emote] = [:]
    guard let url = URL(string: url) else {
        return [:]
    }
    let (data, response) = try await httpGet(from: url)
    if !response.isSuccessful {
        throw " Not successful"
    }
    for emote in try JSONDecoder().decode([FfzEmote].self, from: data) {
        guard let url = makeUrl(emote: emote) else {
            logger.error("Failed to create URL for FFZ emote \(emote.code)")
            continue
        }
        emotes[emote.code] = Emote(url: url)
    }
    return emotes
}