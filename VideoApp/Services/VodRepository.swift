import Foundation

class VodRepository {
    static let shared = VodRepository()

    private static let raiBase = "https://www.raiplay.it"
    static let sampleVodURLs = [
        "https://faredge.5gemerge.arcticspace.com/5G-EMERGE/VOD/hls/HQVideo/HQVideo.m3u8",
        "https://faredge.5gemerge.arcticspace.com/5G-EMERGE/VOD/hls/5G-Emerge/5G-Emerge.m3u8",
        "https://vod-testbed.gcdn.co/TOS/CMAF/TearsOfSteel.m3u8",
    ]

    private var cache: [VodItem]?

    func getVodItems() async throws -> [VodItem] {
        if let cached = cache { return cached }
        guard let url = Bundle.main.url(forResource: "vod_sport", withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(RaiPlayResponse.self, from: data)
        let items = (response.contents ?? [])
            .flatMap { $0.contents ?? [] }
            .filter { $0.images?.landscape?.isEmpty == false }
            .enumerated()
            .compactMap { (index, item) -> VodItem? in
                guard let landscape = item.images?.landscape else { return nil }
                let landscapeURL = landscape.hasPrefix("http")
                    ? URL(string: landscape)
                    : URL(string: Self.raiBase + landscape)
                let portraitURL = item.images?.portrait.flatMap { p in
                    p.hasPrefix("http") ? URL(string: p) : URL(string: Self.raiBase + p)
                }
                return VodItem(
                    id: item.id ?? "vod_\(index)",
                    name: item.name ?? "Video \(index + 1)",
                    description: item.description?.nilIfEmpty ?? item.vanity?.nilIfEmpty,
                    landscapeImageURL: landscapeURL,
                    portraitImageURL: portraitURL,
                    streamURL: Self.sampleVodURLs[index % Self.sampleVodURLs.count]
                )
            }
        cache = items
        return items
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
