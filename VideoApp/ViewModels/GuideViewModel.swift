import Foundation

@MainActor
class GuideViewModel: ObservableObject {
    @Published var state: LoadState<[GuideChannel]> = .loading

    func load(epgURL: String) async {
        if case .success = state { return }
        state = .loading
        await EpgRepository.shared.getChannels(epgURL: epgURL)
        guard let raw = EpgRepository.shared.getRawCache() else {
            state = .failure("No guide data available"); return
        }
        let channels = buildChannels(raw.epg ?? [])
        state = channels.isEmpty ? .failure("No guide data available") : .success(channels)
    }

    private func buildChannels(_ epgChannels: [EpgChannel]) -> [GuideChannel] {
        epgChannels.enumerated().map { (i, ch) in
            let name = ch.channel ?? "Channel \(i + 1)"
            return GuideChannel(
                id: ch.id ?? "ch_\(i)",
                name: name,
                hlsURL: EpgRepository.shared.resolveHLS(channelName: name),
                programmes: buildProgrammes(ch.events ?? [])
            )
        }
    }

    private func buildProgrammes(_ events: [EpgEvent]) -> [GuideProgramme] {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)

        struct Parsed { let event: EpgEvent; let startMin: Int; let endMin: Int }

        let parsed: [Parsed] = events.compactMap { event in
            guard let hour = event.hour,
                  let start = parseMinutes(hour) else { return nil }
            let dur = parseDurationMinutes(event.duration)
            return Parsed(event: event, startMin: start, endMin: start + Int(dur))
        }

        let currentStart = parsed
            .filter { isBetween(nowMinutes, $0.startMin, $0.endMin) }
            .max(by: { $0.startMin < $1.startMin })?.startMin

        return parsed.map { p in
            let endHour = minutesToHour(p.endMin % (24 * 60))
            return GuideProgramme(
                title: p.event.program?.name ?? p.event.name ?? "Unknown",
                synopsis: p.event.program?.description ?? p.event.program?.plot,
                imageURL: p.event.image.flatMap { normalizeURL($0) },
                startHour: p.event.hour!,
                endHour: endHour,
                isCurrent: currentStart != nil && p.startMin == currentStart
            )
        }
    }

    private func parseMinutes(_ hour: String) -> Int? {
        let parts = hour.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    private func parseDurationMinutes(_ duration: String?) -> Int {
        guard let duration else { return 60 }
        let parts = duration.trimmingCharacters(in: .whitespaces).split(separator: ":")
        switch parts.count {
        case 3: return (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0)
        case 2: return (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0)
        default: return Int(duration.filter(\.isNumber)) ?? 60
        }
    }

    private func isBetween(_ now: Int, _ start: Int, _ end: Int) -> Bool {
        end < start ? now >= start || now < end : now >= start && now < end
    }

    private func minutesToHour(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func normalizeURL(_ path: String) -> URL? {
        path.hasPrefix("http") ? URL(string: path) : URL(string: "https://www.raiplay.it\(path)")
    }
}
