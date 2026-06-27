import Foundation

struct NetworkInfo {
    var isConnected: Bool
    var type: String
    var ipv4Address: String?
    // Wi-Fi
    var ssid: String?
    var rssiDbm: Int?
    var linkSpeedMbps: Int?
    var frequencyMHz: Int?
    var wifiBand: String?
    var signalQuality: String?
    // Cellular
    var carrierName: String?
    var isRoaming: Bool
    var radioTechnology: String?

    static var disconnected: NetworkInfo {
        NetworkInfo(isConnected: false, type: "Not Connected", isRoaming: false)
    }
}

struct PublicIpInfo {
    let publicIp: String?
    let location: String?
    let latitude: Double?
    let longitude: Double?
    let asn: String?
    let org: String?
}
