import SwiftUI

@main
struct VideoAppApp: App {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if splashDone {
                    ContentView()
                        .transition(.opacity)
                } else {
                    SplashView(onComplete: { splashDone = true })
                        .transition(.opacity)
                }
            }
            .environmentObject(settings)
            .environmentObject(networkMonitor)
            .tint(accentColor(settings.themeAccent))
            .animation(.easeInOut(duration: 0.4), value: splashDone)
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
