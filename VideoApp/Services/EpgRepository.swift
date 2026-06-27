import Foundation

class EpgRepository {
    static let shared = EpgRepository()

    static let channelStreams: [String: String] = [
        "rai scuola": "https://live-cdn-a.media-streaming.testbed.5g-emerge.io/out/v1/rai-scuola-cmaf/rai-scuola-cmaf-channel/rai-scuola-cmaf-endpoint/index-hls.m3u8",
        "rai storia": "https://live-cdn-a.media-streaming.testbed.5g-emerge.io/out/v1/rai-storia-cmaf/rai-storia-cmaf/rai-storia-cmaf-endpoint/index-hls.m3u8"
    ]
    private static let fallbackHLS = "https://faredge.5gemerge.arcticspace.com/5G-EMERGE/Live/hls/crits_linear/crits_linear.m3u8"

    private var rawCache: EpgResponse?
    private var channelCache: [ChannelItem]?

    func getChannels(epgURL: String) async -> [ChannelItem] {
        if let cached = channelCache { return cached }
        if let url = URL(string: epgURL),
           let data = try? await URLSession.shared.data(from: url).0,
           let response = try? JSONDecoder().decode(EpgResponse.self, from: data) {
            rawCache = response
            let channels = parseChannels(response)
            channelCache = channels
            return channels
        }
        if let url = Bundle.main.url(forResource: "rai_epg", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let response = try? JSONDecoder().decode(EpgResponse.self, from: data) {
            rawCache = response
            let channels = parseChannels(response)
            channelCache = channels
            return channels
        }
        return hardcodedFallback()
    }

    func getRawCache() -> EpgResponse? { rawCache }

    func resolveHLS(channelName: String) -> String {
        let key = channelName.lowercased()
        for (k, url) in Self.channelStreams where key.contains(k) {
            return url
        }
        return Self.fallbackHLS
    }

    private func parseChannels(_ response: EpgResponse) -> [ChannelItem] {
        guard let epgChannels = response.epg, !epgChannels.isEmpty else { return hardcodedFallback() }
        return epgChannels.enumerated().map { (index, ch) in
            let name = ch.channel ?? "Channel \(index + 1)"
            let event = ch.events?.first
            let programName = event?.program?.name ?? event?.name ?? "No program info"
            let programTime: String = {
                var parts: [String] = []
                if let h = event?.hour { parts.append(h) }
                if let d = event?.duration { parts.append("(\(d))") }
                return parts.joined(separator: " ")
            }()
            let thumbURL = event?.image.flatMap { normalizeURL($0) }
            return ChannelItem(
                id: ch.id ?? "channel_\(index)",
                channelName: name,
                currentProgramName: programName,
                currentProgramTime: programTime,
                thumbnailURL: thumbURL,
                hlsURL: resolveHLS(channelName: name)
            )
        }
    }

    private func hardcodedFallback() -> [ChannelItem] {
        Self.channelStreams.map { (name, hlsURL) in
            ChannelItem(
                id: name.replacingOccurrences(of: " ", with: "_"),
                channelName: name.capitalized,
                currentProgramName: "Live Programming",
                currentProgramTime: "",
                thumbnailURL: nil,
                hlsURL: hlsURL
            )
        }
    }

    private func normalizeURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: "https://www.raiplay.it\(path)")
    }
}
