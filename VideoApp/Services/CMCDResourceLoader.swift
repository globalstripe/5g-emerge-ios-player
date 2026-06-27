import Foundation
import AVFoundation

// Builds CMCD session headers and display params for a single playback session.
// Delivery method: HTTP request headers (CMCD-Session / CMCD-Object / CMCD-Request)
// applied via AVURLAssetHTTPHeaderFieldsKey — no custom URL scheme required.
class CMCDSession {

    let sessionID: String
    let contentID: String
    let streamType: String   // "v" = VOD, "l" = live

    init(streamURL: String, isLive: Bool) {
        sessionID = UUID().uuidString.lowercased()
        contentID = String(format: "%08x", abs(streamURL.hashValue))
        streamType = isLive ? "l" : "v"
    }

    // CMCD-Session header value (cid, sf, sid, st — all fixed for the session)
    var sessionHeader: String {
        [
            "cid=\"\(contentID)\"",
            "sf=h",
            "sid=\"\(sessionID)\"",
            "st=\(streamType)"
        ].joined(separator: ",")
    }

    // Pass this as AVURLAssetHTTPHeaderFieldsKey in AVURLAsset options
    var httpHeaders: [String: String] {
        ["CMCD-Session": sessionHeader]
    }

    // Base display dict shown in the stats panel (static fields only)
    var displayParams: [String: String] {
        [
            "cid": "\"\(contentID)\"",
            "sf" : "h",
            "sid": "\"\(sessionID)\"",
            "st" : streamType
        ]
    }

    // Augments the base display with live metrics from the access log
    func displayParams(bl: Int, br: Int, mtp: Int) -> [String: String] {
        var p = displayParams
        if bl  > 0 { p["bl"]  = "\(bl)" }
        if br  > 0 { p["br"]  = "\(br)" }
        if mtp > 0 { p["mtp"] = "\(mtp)" }
        return p
    }
}
