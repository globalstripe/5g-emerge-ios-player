import Foundation

@MainActor
class LiveViewModel: ObservableObject {
    @Published var state: LoadState<[ChannelItem]> = .loading

    func load(epgURL: String) async {
        state = .loading
        let channels = await EpgRepository.shared.getChannels(epgURL: epgURL)
        state = channels.isEmpty ? .failure("No channels available") : .success(channels)
    }
}
