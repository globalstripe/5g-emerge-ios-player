import Foundation

@MainActor
class NetworkStatusViewModel: ObservableObject {
    @Published var publicIpInfo: PublicIpInfo?
    @Published var isLoadingPublicIp = true

    private let publicIpRepo = PublicIpRepository()

    func fetchPublicIp() async {
        isLoadingPublicIp = true
        publicIpInfo = await publicIpRepo.fetch()
        isLoadingPublicIp = false
    }
}
