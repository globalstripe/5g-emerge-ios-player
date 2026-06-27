import SwiftUI
import AVKit

struct PlayerView: View {
    let title: String
    let streamURL: String
    var isLive: Bool = false

    @State private var player: AVPlayer?
    @State private var cmcdSession: CMCDSession?
    @State private var showStats = false
    @State private var stats = PlayerStats()
    @State private var cmcdParams: [String: String] = [:]
    @State private var statusMessage = "Loading…"
    @State private var hasError = false
    @State private var statsTimer: Timer?
    @State private var itemObservation: NSKeyValueObservation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                AVPlayerRepresentable(player: player)
                    .ignoresSafeArea()

                VStack(alignment: .leading) {
                    // Top bar
                    HStack(alignment: .top) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if hasError {
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Button(action: { showStats.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding()

                    if showStats {
                        VStack(alignment: .leading, spacing: 8) {
                            StatsOverlayView(stats: stats)
                            if !cmcdParams.isEmpty {
                                CMCDOverlayView(params: cmcdParams)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }

                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text(statusMessage)
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption)
                }
            }
        }
        .statusBarHidden()
        .onAppear { setupPlayer() }
        .onDisappear { teardown() }
    }

    // MARK: - Setup

    private func setupPlayer() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let url = URL(string: streamURL) else {
            statusMessage = "Invalid URL"; hasError = true; return
        }

        statusMessage = "Connecting…"

        let session = CMCDSession(streamURL: streamURL, isLive: isLive)
        cmcdSession  = session
        cmcdParams   = session.displayParams

        // "AVURLAssetHTTPHeaderFieldsKey" adds CMCD headers to every request
        // AVFoundation makes for this asset — no URL-scheme interception needed.
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": session.httpHeaders
        ])
        let item = AVPlayerItem(asset: asset)

        itemObservation = item.observe(\AVPlayerItem.status,
                                       options: NSKeyValueObservingOptions([.new])) { observedItem, _ in
            DispatchQueue.main.async {
                switch observedItem.status {
                case .readyToPlay: statusMessage = ""; hasError = false
                case .failed:
                    statusMessage = observedItem.error?.localizedDescription ?? "Playback failed"
                    hasError = true
                default: break
                }
            }
        }

        let p = AVPlayer(playerItem: item)
        p.play()
        player = p

        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in updateStats() }
        }
    }

    // MARK: - Stats

    private func updateStats() {
        guard let item = player?.currentItem else { return }

        let log       = item.accessLog()?.events.last
        let bitrate   = log?.indicatedBitrate  ?? 0
        let bandwidth = log?.observedBitrate   ?? 0

        let buffer: Double = item.loadedTimeRanges.first.map { range in
            let r = range.timeRangeValue
            return max(0, r.start.seconds + r.duration.seconds - item.currentTime().seconds)
        } ?? 0

        let bufferMs      = Int(buffer * 1000)
        let bitrateKbps   = bitrate   > 0 ? Int(bitrate   / 1000) : 0
        let throughputKbps = bandwidth > 0 ? Int(bandwidth / 1000) : 0

        stats = PlayerStats(
            resolution: resolvedResolution(from: item),
            bitrate:    bitrate   > 0 ? formatBitrate(bitrate)   : "—",
            bandwidth:  bandwidth > 0 ? formatBitrate(bandwidth) : "—",
            buffer:     String(format: "%.1fs", buffer)
        )

        if let session = cmcdSession {
            cmcdParams = session.displayParams(bl: bufferMs,
                                               br: bitrateKbps,
                                               mtp: throughputKbps)
        }
    }

    private func resolvedResolution(from item: AVPlayerItem) -> String {
        guard let track = item.tracks.first(where: { $0.assetTrack?.mediaType == .video }),
              let assetTrack = track.assetTrack else { return "—" }
        let size = assetTrack.naturalSize.applying(assetTrack.preferredTransform)
        let w = Int(abs(size.width)); let h = Int(abs(size.height))
        return w > 0 && h > 0 ? "\(w)×\(h)" : "—"
    }

    private func teardown() {
        statsTimer?.invalidate(); statsTimer = nil
        itemObservation?.invalidate(); itemObservation = nil
        player?.pause(); player = nil
        cmcdSession = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func formatBitrate(_ bps: Double) -> String {
        bps >= 1_000_000 ? String(format: "%.1f Mbps", bps / 1_000_000) : "\(Int(bps / 1000)) kbps"
    }
}

// MARK: - AVPlayerViewController wrapper

struct AVPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = true
        vc.videoGravity = .resizeAspect
        return vc
    }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        vc.player = player
    }
}

// MARK: - Overlay views

struct PlayerStats {
    var resolution = "—"
    var bitrate    = "—"
    var bandwidth  = "—"
    var buffer     = "—"
}

struct StatsOverlayView: View {
    let stats: PlayerStats
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resolution : \(stats.resolution)")
            Text("Bitrate    : \(stats.bitrate)")
            Text("Bandwidth  : \(stats.bandwidth)")
            Text("Buffer     : \(stats.buffer)")
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CMCDOverlayView: View {
    let params: [String: String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CMCD")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white.opacity(0.6))
            ForEach(params.keys.sorted(), id: \.self) { key in
                Text(" \(key.padding(toLength: 3, withPad: " ", startingAt: 0)) = \(params[key]!)")
            }
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
