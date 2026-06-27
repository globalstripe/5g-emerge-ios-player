import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    static let defaultEpgURL = "https://rai.gcdn.co/5G-EMERGE/metadata/rai_epg.json"

    @Published var themeAccent: String {
        didSet { defaults.set(themeAccent, forKey: "theme_accent") }
    }
    @Published var vodSource: String {
        didSet { defaults.set(vodSource, forKey: "vod_source") }
    }
    @Published var epgURL: String {
        didSet { defaults.set(epgURL, forKey: "epg_url") }
    }

    private init() {
        themeAccent = defaults.string(forKey: "theme_accent") ?? "green"
        vodSource = defaults.string(forKey: "vod_source") ?? "local"
        epgURL = defaults.string(forKey: "epg_url") ?? AppSettings.defaultEpgURL
    }
}
