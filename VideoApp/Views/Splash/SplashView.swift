import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var settings: AppSettings
    let onComplete: () -> Void

    @State private var progressVisible = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(maxHeight: .infinity)

                // Logo block (sits at ~45% vertical position via spacer ratio below)
                VStack(spacing: 16) {
                    Text("5G-EMERGE")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)

                    Text("Adaptive Video Streaming")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1)
                }

                Spacer()
                    .frame(maxHeight: .infinity)

                // Indeterminate linear progress bar — fades in after 200ms
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 60)
                    .opacity(progressVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.2), value: progressVisible)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { progressVisible = true }
        .task { await prefetchAndWait() }
    }

    private var accentColor: Color {
        switch settings.themeAccent {
        case "red":  return .red
        case "blue": return .blue
        default:     return .green
        }
    }

    private func prefetchAndWait() async {
        await withTaskGroup(of: Void.self) { group in
            // Pre-fetch VOD (local JSON — fast)
            group.addTask { _ = try? await VodRepository.shared.getVodItems() }
            // Pre-fetch EPG
            group.addTask {
                let url = await MainActor.run { settings.epgURL }
                _ = try? await EpgRepository.shared.getChannels(epgURL: url)
            }
            // Minimum visible duration
            group.addTask { try? await Task.sleep(for: .seconds(2)) }
            for await _ in group { }
        }
        await MainActor.run { withAnimation(.easeInOut(duration: 0.4)) { onComplete() } }
    }
}
