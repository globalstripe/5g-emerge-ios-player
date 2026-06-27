import SwiftUI

struct GuideView: View {
    @StateObject private var vm = GuideViewModel()
    @EnvironmentObject private var settings: AppSettings
    @State private var selectedChannel: GuideChannel?
    @State private var selectedStreamURL: String?

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .loading:
                    ProgressView("Loading guide…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure(let msg):
                    UnavailableView(message: msg, systemImage: "calendar.badge.exclamationmark")
                case .success(let channels):
                    List {
                        ForEach(channels) { channel in
                            Section {
                                channelHeader(channel)
                                ForEach(channel.programmes) { prog in
                                    ProgrammeRowView(programme: prog)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("TV Guide")
        }
        .fullScreenCover(item: $selectedChannel) { channel in
            PlayerView(title: channel.name, streamURL: channel.hlsURL)
        }
        .task { await vm.load(epgURL: settings.epgURL) }
    }

    private func channelHeader(_ channel: GuideChannel) -> some View {
        HStack {
            Text(channel.name)
                .font(.headline)
            Spacer()
            Button(action: { selectedChannel = channel }) {
                Label("Watch Live", systemImage: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

struct ProgrammeRowView: View {
    let programme: GuideProgramme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(programme.startHour)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(programme.endHour)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 44)

            if programme.isCurrent {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(programme.title)
                    .font(.subheadline)
                    .fontWeight(programme.isCurrent ? .semibold : .regular)
                if let synopsis = programme.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(programme.isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
    }
}
