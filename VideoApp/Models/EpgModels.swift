import Foundation

struct EpgResponse: Decodable {
    let epg: [EpgChannel]?
}

struct EpgChannel: Decodable {
    let id: String?
    let channel: String?
    let events: [EpgEvent]?
}

struct EpgEvent: Decodable {
    let name: String?
    let date: String?
    let hour: String?
    let duration: String?
    let image: String?
    let has_video: Bool?
    let program: EpgProgram?
}

struct EpgProgram: Decodable {
    let id: String?
    let name: String?
    let description: String?
    let plot: String?
}

struct ChannelItem: Identifiable, Hashable {
    let id: String
    let channelName: String
    let currentProgramName: String
    let currentProgramTime: String
    let thumbnailURL: URL?
    let hlsURL: String
    let dashURL: String?
}

struct GuideChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let hlsURL: String
    let dashURL: String?
    let programmes: [GuideProgramme]
}

struct GuideProgramme: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let synopsis: String?
    let imageURL: URL?
    let startHour: String
    let endHour: String
    let isCurrent: Bool
}
