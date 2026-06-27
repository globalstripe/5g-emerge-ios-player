import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("VOD", systemImage: "film") }
            LiveView()
                .tabItem { Label("Live", systemImage: "antenna.radiowaves.left.and.right") }
            GuideView()
                .tabItem { Label("Guide", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
    }
}
