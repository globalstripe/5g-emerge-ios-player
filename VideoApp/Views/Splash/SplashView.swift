import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var settings: AppSettings
    let onComplete: () -> Void

    @State private var contentVisible  = false
    @State private var progressVisible = false

    // Source PNG is 782 × 172 px
    private let logoAspect: CGFloat = 782.0 / 172.0

    var body: some View {
        ZStack {
            Color.white

            VStack(spacing: 32) {
                Image("logo_5g_emerge")
                    .resizable()
                    .aspectRatio(logoAspect, contentMode: .fit)
                    .padding(.horizontal, 48)

                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(accentColor)
                    .padding(.horizontal, 48)
                    .opacity(progressVisible ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.2), value: progressVisible)
            }
            .frame(maxWidth: .infinity)
            // Nudge above centre to match Android's ~45% vertical position
            .offset(y: -60)
            .opacity(contentVisible ? 1 : 0)
            .animation(.easeIn(duration: 0.25), value: contentVisible)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .onAppear {
            contentVisible  = true
            progressVisible = true
        }
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
            group.addTask { _ = try? await VodRepository.shared.getVodItems() }
            group.addTask {
                let url = await MainActor.run { settings.epgURL }
                _ = await EpgRepository.shared.getChannels(epgURL: url)
            }
            group.addTask { try? await Task.sleep(for: .seconds(2)) }
            for await _ in group { }
        }
        await MainActor.run { withAnimation(.easeInOut(duration: 0.4)) { onComplete() } }
    }
}
