import SwiftUI
import CoreLocation

struct NetworkStatusView: View {
    @EnvironmentObject private var monitor: NetworkMonitor
    @StateObject private var vm = NetworkStatusViewModel()

    var body: some View {
        List {
            // Status header
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text(monitor.networkInfo.type)
                            .font(.title2).fontWeight(.bold)
                        Text(monitor.networkInfo.isConnected ? "CONNECTED" : "DISCONNECTED")
                            .font(.caption.uppercaseSmallCaps())
                            .foregroundStyle(monitor.networkInfo.isConnected ? .green : .red)
                    }
                    Spacer()
                    Image(systemName: connectionIcon)
                        .font(.largeTitle)
                        .foregroundStyle(monitor.networkInfo.isConnected ? .green : .red)
                }
                .padding(.vertical, 4)
            }

            // Wi-Fi card
            if monitor.networkInfo.type == "Wi-Fi" {
                Section("Wi-Fi") {
                    infoRow("Network", monitor.networkInfo.ssid ?? "Unknown")
                    if let band = monitor.networkInfo.wifiBand {
                        infoRow("Band", band)
                    }
                    if let speed = monitor.networkInfo.linkSpeedMbps {
                        infoRow("Speed", "\(speed) Mbps")
                    }
                }
            }

            // Cellular card
            if monitor.networkInfo.isConnected && monitor.networkInfo.type != "Wi-Fi" {
                Section("Cellular") {
                    infoRow("Carrier", monitor.networkInfo.carrierName ?? "Unknown")
                    infoRow("Type", monitor.networkInfo.type)
                    infoRow("Roaming", monitor.networkInfo.isRoaming ? "Yes" : "No")
                }
            }

            // IP addresses
            Section("Address") {
                infoRow("IP Address", monitor.networkInfo.ipv4Address ?? "—")

                if vm.isLoadingPublicIp {
                    HStack {
                        Text("Public IP")
                            .foregroundStyle(.secondary)
                        Spacer()
                        ProgressView()
                    }
                } else if let info = vm.publicIpInfo {
                    infoRow("Public IP", info.publicIp ?? "—")
                    infoRow("Location", info.location ?? "—")
                    if let lat = info.latitude, let lon = info.longitude {
                        infoRow("Coordinates", String(format: "%.4f, %.4f", lat, lon))
                    }
                    infoRow("ASN", info.asn ?? "—")
                    infoRow("ISP / Org", info.org ?? "—")
                }
            }
        }
        .navigationTitle("Network Status")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { monitor.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            monitor.requestLocationPermission()
            Task { await vm.fetchPublicIp() }
        }
    }

    private var connectionIcon: String {
        guard monitor.networkInfo.isConnected else { return "wifi.slash" }
        switch monitor.networkInfo.type {
        case "Wi-Fi": return "wifi"
        case let t where t.contains("5G"): return "cellularbars"
        case let t where t.contains("4G"): return "signal.bars.4"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
