import Foundation

struct VodItem: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let landscapeImageURL: URL?
    let portraitImageURL: URL?
    let streamURL: String
}

struct RaiPlayResponse: Decodable {
    let contents: [RaiPlayBlock]?
}

struct RaiPlayBlock: Decodable {
    let id: String?
    let name: String?
    let type: String?
    let contents: [RaiPlayItem]?
}

struct RaiPlayItem: Decodable {
    let id: String?
    let name: String?
    let vanity: String?
    let description: String?
    let images: RaiPlayImages?
    let path_id: String?
}

struct RaiPlayImages: Decodable {
    let landscape: String?
    let portrait: String?
}
