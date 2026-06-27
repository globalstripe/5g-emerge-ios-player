import SwiftUI

@main
struct VideoAppApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(networkMonitor)
                .tint(accentColor(settings.themeAccent))
        }
    }

    private func accentColor(_ accent: String) -> Color {
        switch accent {
        case "red":   return .red
        case "blue":  return .blue
        default:      return .green
        }
    }
}
