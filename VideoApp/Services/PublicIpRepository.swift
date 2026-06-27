import Foundation

class PublicIpRepository {
    func fetch() async -> PublicIpInfo {
        // 1. ipapi.co
        if let info = try? await fetchIpApiCo() { return info }
        // 2. ip-api.com fallback
        if let info = try? await fetchIpApiFallback() { return info }
        // 3. ipify.org — IP only
        if let ip = try? await fetchIpify() {
            return PublicIpInfo(publicIp: ip, location: nil, latitude: nil, longitude: nil, asn: nil, org: nil)
        }
        return PublicIpInfo(publicIp: nil, location: nil, latitude: nil, longitude: nil, asn: nil, org: nil)
    }

    private func fetchIpApiCo() async throws -> PublicIpInfo? {
        let url = URL(string: "https://ipapi.co/json/")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct R: Decodable {
            let ip: String?; let error: Bool?
            let city: String?; let region: String?; let country_name: String?
            let latitude: Double?; let longitude: Double?; let asn: String?; let org: String?
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        guard let ip = r.ip, r.error != true else { return nil }
        let loc = [r.city, r.region, r.country_name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        let asn = r.asn.map { $0.hasPrefix("AS") ? $0 : "AS\($0)" }
        return PublicIpInfo(publicIp: ip, location: loc.isEmpty ? nil : loc,
                            latitude: r.latitude, longitude: r.longitude, asn: asn, org: r.org)
    }

    private func fetchIpApiFallback() async throws -> PublicIpInfo? {
        let url = URL(string: "http://ip-api.com/json/?fields=status,message,query,country,regionName,city,lat,lon,as,org")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct R: Decodable {
            let status: String?; let query: String?
            let city: String?; let regionName: String?; let country: String?
            let lat: Double?; let lon: Double?
            let `as`: String?; let org: String?
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        guard r.status == "success", let ip = r.query else { return nil }
        let loc = [r.city, r.regionName, r.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return PublicIpInfo(publicIp: ip, location: loc.isEmpty ? nil : loc,
                            latitude: r.lat, longitude: r.lon, asn: r.as, org: r.org)
    }

    private func fetchIpify() async throws -> String? {
        let url = URL(string: "https://api.ipify.org?format=json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        struct R: Decodable { let ip: String? }
        return try JSONDecoder().decode(R.self, from: data).ip
    }
}
