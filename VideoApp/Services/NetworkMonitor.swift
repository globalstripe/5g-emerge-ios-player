import Foundation
import Network
import CoreTelephony
import CoreLocation
import SystemConfiguration.CaptiveNetwork

class NetworkMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = NetworkMonitor()

    @Published var networkInfo: NetworkInfo = .disconnected

    private let monitor = NWPathMonitor()
    private let locationManager = CLLocationManager()
    private var currentPath: NWPath?

    override private init() {
        super.init()
        locationManager.delegate = self
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
            DispatchQueue.main.async { self?.refresh() }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }

    func refresh() {
        guard let path = currentPath else {
            networkInfo = .disconnected
            return
        }
        guard path.status == .satisfied else {
            networkInfo = .disconnected
            return
        }
        var info = NetworkInfo(isConnected: true, type: "Unknown", isRoaming: false)
        info.ipv4Address = localIPv4Address()

        if path.usesInterfaceType(.wifi) {
            info.type = "Wi-Fi"
            info.ssid = currentSSID()
            info.wifiBand = nil
        } else if path.usesInterfaceType(.cellular) {
            let (gen, carrier, roaming, tech) = cellularInfo()
            info.type = gen
            info.carrierName = carrier
            info.isRoaming = roaming
            info.radioTechnology = tech
        } else {
            info.type = "Other"
        }
        networkInfo = info
    }

    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.refresh() }
    }

    private func currentSSID() -> String? {
        var ssid: String?
        if let interfaces = CNCopySupportedInterfaces() as? [String] {
            for interface in interfaces {
                if let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any] {
                    ssid = info[kCNNetworkInfoKeySSID as String] as? String
                }
            }
        }
        return ssid?.isEmpty == false ? ssid : nil
    }

    private func cellularInfo() -> (generation: String, carrier: String?, roaming: Bool, tech: String?) {
        let info = CTTelephonyNetworkInfo()
        var carrier: String?
        var tech: String?
        let roaming = false

        if let providers = info.serviceSubscriberCellularProviders {
            carrier = providers.values.first?.carrierName
        }
        if let techs = info.serviceCurrentRadioAccessTechnology {
            tech = techs.values.first
        }
        let generation = radioTechToGeneration(tech)
        return (generation, carrier, roaming, tech)
    }

    private func radioTechToGeneration(_ tech: String?) -> String {
        guard let tech else { return "Cellular" }
        switch tech {
        case CTRadioAccessTechnologyNRNSA, CTRadioAccessTechnologyNR:
            return "5G NR"
        case CTRadioAccessTechnologyLTE:
            return "4G LTE"
        case CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyHSDPA,
             CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB:
            return "3G HSPA"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyCDMAEVDORev0:
            return "3G"
        case CTRadioAccessTechnologyEdge:
            return "2G EDGE"
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyCDMA1x:
            return "2G"
        default:
            return "Cellular"
        }
    }

    private func localIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            let interface = ptr!.pointee
            let family = interface.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}
