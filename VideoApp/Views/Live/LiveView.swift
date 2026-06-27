import SwiftUI

struct LiveView: View {
    @StateObject private var vm = LiveViewModel()
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedChannel: ChannelItem?

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .loading:
                    ProgressView("Loading channels…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure(let msg):
                    UnavailableView(message: msg, systemImage: "antenna.radiowaves.left.and.right.slash")
                case .success(let channels):
                    List(channels) { channel in
                        ChannelRowView(channel: channel)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedChannel = channel }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Live")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await vm.load(epgURL: settings.epgURL) } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(title: channel.channelName, streamURL: channel.hlsURL, isLive: true)
        }
        .task { await vm.load(epgURL: settings.epgURL) }
    }
}

struct ChannelRowView: View {
    let channel: ChannelItem
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: channel.thumbnailURL) { img in
                img.resizable().aspectRatio(16/9, contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.secondary.opacity(0.3))
                    .overlay(Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundStyle(.secondary))
            }
            .frame(width: 90, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.channelName)
                    .font(.headline)
                Text(channel.currentProgramName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !channel.currentProgramTime.isEmpty {
                    Text(channel.currentProgramTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
        }
    }
}
