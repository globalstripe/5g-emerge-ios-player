import Foundation

enum LoadState<T> {
    case loading, success(T), failure(String)
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var state: LoadState<([VodItem], [VodItem], [VodItem], [VodItem], [VodItem])> = .loading

    func load() async {
        state = .loading
        do {
            let items = try await VodRepository.shared.getVodItems()
            guard !items.isEmpty else { state = .failure("No content available"); return }
            state = .success((
                Array(items.prefix(8)),
                items.shuffled(),
                items.shuffled(),
                items.shuffled(),
                items.shuffled()
            ))
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
