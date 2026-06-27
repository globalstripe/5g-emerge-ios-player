import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedItem: VodItem?

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .loading:
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure(let msg):
                    UnavailableView(message: msg, systemImage: "exclamationmark.triangle")
                case .success(let (hero, sport, film, horror, comedy)):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            HeroCarouselView(items: hero, onTap: { selectedItem = $0 })
                            vodRow("Sport", items: sport)
                            vodRow("Film", items: film)
                            vodRow("Horror", items: horror)
                            vodRow("Comedy", items: comedy)
                        }
                    }
                }
            }
            .navigationTitle("5G Video")
            .navigationBarTitleDisplayMode(.inline)
        }
        .fullScreenCover(item: $selectedItem) { item in
            PlayerView(title: item.name, streamURL: item.streamURL)
        }
        .task { await vm.load() }
    }

    private func vodRow(_ title: String, items: [VodItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        VodCardView(item: item)
                            .onTapGesture { selectedItem = item }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 12)
    }
}

struct HeroCarouselView: View {
    let items: [VodItem]
    let onTap: (VodItem) -> Void

    var body: some View {
        TabView {
            ForEach(items) { item in
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: item.landscapeImageURL) { img in
                        img.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(.secondary.opacity(0.3))
                    }
                    .clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.8)],
                                   startPoint: .center, endPoint: .bottom)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.white)
                        if let desc = item.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(2)
                        }
                        Button("▶  Play") { onTap(item) }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                    }
                    .padding()
                }
                .frame(height: 220)
                .clipped()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 220)
    }
}

struct VodCardView: View {
    let item: VodItem
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncImage(url: item.landscapeImageURL) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.secondary.opacity(0.3))
                    .aspectRatio(16/9, contentMode: .fill)
            }
            .frame(width: 160)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(item.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)
        }
    }
}
