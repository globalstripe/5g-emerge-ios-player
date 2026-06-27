# 5G Video — iOS App

SwiftUI companion to the [5G-EMERGE Android video app](../android-video-app), demonstrating adaptive bitrate video streaming (HLS) with CMCD telemetry over 5G networks. Content is sourced from the 5G-EMERGE testbed and RaiPlay VOD catalogue.

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Architecture](#architecture)
3. [Features](#features)
4. [Key Implementation Details](#key-implementation-details)
5. [Build & Run](#build--run)
6. [Known Gotchas & Hard-Won Findings](#known-gotchas--hard-won-findings)
7. [Prompt Context for AI Assistants](#prompt-context-for-ai-assistants)

---

## Project Structure

```
ios-video-app/
├── project.yml                        # XcodeGen project definition
├── VideoApp.xcodeproj/                # Generated — do not edit directly
└── VideoApp/
    ├── LaunchScreen.storyboard        # OS launch screen (white bg + logo)
    ├── App/
    │   ├── VideoAppApp.swift          # @main entry, splash → ContentView routing
    │   └── ContentView.swift          # TabView (VOD / Live / Guide / Settings)
    ├── Models/
    │   ├── VodModels.swift
    │   ├── EpgModels.swift
    │   └── NetworkInfo.swift
    ├── Services/
    │   ├── CMCDResourceLoader.swift   # CMCDSession — builds CMCD headers
    │   ├── VodRepository.swift        # RaiPlay JSON → VodItem list
    │   ├── EpgRepository.swift        # EPG XML/JSON → channel list
    │   ├── AppSettings.swift          # UserDefaults-backed settings singleton
    │   ├── NetworkMonitor.swift       # NWPathMonitor network state
    │   └── PublicIpRepository.swift
    ├── ViewModels/
    │   ├── HomeViewModel.swift
    │   ├── LiveViewModel.swift
    │   ├── GuideViewModel.swift
    │   └── NetworkStatusViewModel.swift
    ├── Views/
    │   ├── Splash/SplashView.swift    # 2s loading screen with prefetch
    │   ├── Home/HomeView.swift        # Hero carousel + genre rows
    │   ├── Live/LiveView.swift        # Live channel list
    │   ├── Guide/GuideView.swift      # EPG programme guide
    │   ├── Player/PlayerView.swift    # AVPlayer + CMCD + stats overlay
    │   ├── Settings/SettingsView.swift
    │   ├── Network/NetworkStatusView.swift
    │   └── UnavailableView.swift
    └── Resources/
        ├── Info.plist
        ├── VideoApp.entitlements
        ├── vod_sport.json             # Bundled RaiPlay VOD catalogue
        ├── rai_epg.json               # Bundled EPG fallback
        └── Assets.xcassets/
            ├── AppIcon.appiconset/    # 1024×1024 universal (from Android xxxhdpi)
            ├── logo_5g_emerge.imageset/   # 782×172 @2x PNG
            ├── LaunchLogo.imageset/       # @1x/@2x/@3x resized variants (300×66pt)
            └── LaunchBackground.colorset/ # sRGB white for launch screen
```

---

## Architecture

- **SwiftUI App lifecycle** (`@main struct VideoAppApp: App`) — no UIApplicationDelegate
- **MVVM** — ViewModels are `@StateObject`, repositories are singletons
- **Navigation** — `TabView` at root; `fullScreenCover` to push `PlayerView`
- **Settings** — `AppSettings.shared` as `@EnvironmentObject`, persisted via `UserDefaults`
- **Network monitoring** — `NetworkMonitor.shared` as `@EnvironmentObject`
- **Project generation** — [XcodeGen](https://github.com/yonaskolb/XcodeGen) v2.45+; edit `project.yml`, run `xcodegen generate`

---

## Features

| Tab | Description |
|-----|-------------|
| **VOD** | Hero carousel + genre rows from bundled RaiPlay JSON; streams cycle through 3 HLS test URLs |
| **Live** | Channel list from EPG source; tap to play HLS live stream |
| **Guide** | EPG programme guide with current-programme highlighting; "Watch Live" button per channel |
| **Settings** | Theme colour (green/blue/red), VOD source toggle, configurable EPG URL, network status |

### Player
- `AVPlayerViewController` wrapped in `UIViewControllerRepresentable`
- Stats overlay: resolution, bitrate, bandwidth, buffer depth
- CMCD overlay: session/content ID, stream format, stream type, buffer length, bitrate, measured throughput
- Stats update every 1 second via `AVPlayerItem.accessLog()`

### Splash Screen
- White background matching Android app
- 5G-EMERGE logo centred at ~45% from screen top
- Indeterminate linear progress bar fades in below logo
- 2-second minimum hold with parallel VOD + EPG prefetch (`withTaskGroup`)
- Seamless handoff from OS launch screen (same logo position)

---

## Key Implementation Details

### CMCD (CTA-5004) — `CMCDResourceLoader.swift`

CMCD telemetry is delivered via **HTTP request headers** (not query parameters). Query-parameter CMCD breaks CDN URL signing and caching on 5G-EMERGE infrastructure (`CoreMediaErrorDomain -12881`).

```swift
// CMCDSession builds the CMCD-Session header value
let asset = AVURLAsset(url: url, options: [
    "AVURLAssetHTTPHeaderFieldsKey": session.httpHeaders
])
```

- `"AVURLAssetHTTPHeaderFieldsKey"` is an iOS 7+ string key — **no Swift constant exists**, must be a string literal
- Headers sent: `CMCD-Session` containing `cid`, `sf`, `sid`, `st`
- Dynamic fields (`bl`, `br`, `mtp`) are display-only (read from `AVPlayerItem.accessLog()`) — they cannot be injected per-request with `AVURLAssetHTTPHeaderFieldsKey`

CMCD fields:

| Field | Meaning | Source |
|-------|---------|--------|
| `sid` | Session UUID | `UUID().uuidString` on `CMCDSession` init |
| `cid` | Content ID (8-char hex hash of URL) | `abs(url.hashValue)` |
| `sf`  | Stream format (`h` = HLS) | hardcoded |
| `st`  | Stream type (`v` = VOD, `l` = live) | `isLive` param |
| `bl`  | Buffer length (ms) | `AVPlayerItem.loadedTimeRanges` |
| `br`  | Encoded bitrate (kbps) | `accessLog.indicatedBitrate` |
| `mtp` | Measured throughput (kbps) | `accessLog.observedBitrate` |

### Video Playback — `PlayerView.swift`

- **AVPlayer** created manually; do **not** use SwiftUI `VideoPlayer` inside `fullScreenCover` (unreliable on iOS 16+)
- **`AVPlayerViewController`** wrapped via `UIViewControllerRepresentable` — required for system playback controls and Picture-in-Picture
- **Audio session** must be set before creating the player:
  ```swift
  try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
  try? AVAudioSession.sharedInstance().setActive(true)
  ```
- **KVO on `AVPlayerItem.status`** — type inference is ambiguous in Xcode 26; must use explicit form:
  ```swift
  item.observe(\AVPlayerItem.status, options: NSKeyValueObservingOptions([.new])) { ... }
  ```
- **VOD streams** — only HLS (`.m3u8`) is supported. DASH (`.mpd`) requires `AVAssetResourceLoaderDelegate` and is not implemented. `sampleVodURLs` must not contain `.mpd` URLs.

### Splash Screen — `SplashView.swift`

Critical layout rules learned through iteration:

1. **Do not use `GeometryReader`** — causes two-pass layout; first frame renders blank (visible white flash)
2. **VStack must have `.frame(maxWidth: .infinity)`** — without it the VStack collapses to the ProgressView's natural width and the logo appears left-aligned
3. **ZStack must have `.ignoresSafeArea()`** — ensures centering uses full screen height, not just safe area
4. **Logo offset** — the VStack offset (`-60`) moves the *entire* VStack. The logo's actual centre is 17pt higher than the VStack centre due to spacing + progress bar height: `(32pt spacing + ~2pt progress) / 2 = 17pt`

### OS Launch Screen — `LaunchScreen.storyboard`

The `UILaunchScreen` Info.plist dictionary approach (`UIImageName`) does **not** work reliably on Xcode 26 / iOS 16+ — the image never appears. Use `UILaunchStoryboardName` pointing to a storyboard instead.

Critical storyboard attributes for Xcode 26:
- `targetRuntime="IBCocoaTouchFramework"` — Xcode 26 changed this from the old `"AppleCocoa Touch"` value; the old string causes `com.apple.InterfaceBuilder error -1`
- `toolsVersion="24504"` and `plugIn version="24504"` — must match the installed Xcode's IB plugin version
- Background colour must use `colorSpace="custom" customColorSpace="sRGB"` — `genericGamma22GrayColorSpace` can render as black

Logo position in storyboard uses `centerY constant="-77"` (not `-60`) to align with SplashView. The difference is the 17pt offset described above — the storyboard centres the image directly, while SplashView centres the whole VStack.

Verify ibtool compiles the storyboard before building:
```bash
ibtool --compile /tmp/out.storyboardc VideoApp/LaunchScreen.storyboard \
  --sdk $(xcrun --show-sdk-path --sdk iphonesimulator) 2>&1
# No output = success
```

---

## Build & Run

### Prerequisites

```bash
brew install xcodegen
```

### First time / after adding files

```bash
xcodegen generate        # Regenerates VideoApp.xcodeproj
open VideoApp.xcodeproj
```

> **Important:** Run `xcodegen generate` every time you add a new file outside of Xcode (storyboards, new asset catalog entries, new Swift files). Xcode will not detect them otherwise and builds will silently exclude them — manifesting as black launch screens, missing assets, etc.

### Build

Select the **VideoApp** scheme, choose an iPhone simulator (iPhone 16 Pro or 17 Pro Max recommended), and press **⌘R**.

### After changing the launch screen

The iOS simulator aggressively caches the launch screen per app install:

1. Delete the app from the simulator (long-press icon → Delete App)
2. **⇧⌘K** Clean Build Folder in Xcode
3. **⌘R** Run

---

## Known Gotchas & Hard-Won Findings

### XcodeGen

- `project.yml` has both `sources: - path: VideoApp` and `resources: - VideoApp/Resources`. Files in `VideoApp/Resources/` are therefore included **twice** unless excluded. Storyboards especially: place them at `VideoApp/LaunchScreen.storyboard` (not inside `Resources/`) to avoid double-inclusion in Copy Bundle Resources.
- Xcode does **not** auto-discover files added to disk after project generation. Always re-run `xcodegen generate` and reopen the `.xcodeproj`.

### AVFoundation / Media

- `AVURLAssetHTTPHeaderFieldsKey` — string literal only, no Swift constant. Adding CMCD as query parameters (`?CMCD=...`) breaks CDN URL signing on the 5G-EMERGE infrastructure, producing `CoreMediaErrorDomain -12881`.
- `AVAssetResourceLoaderDelegate` with a custom URL scheme (e.g. `cmcd-https://`) is fragile on iOS 26 and not needed — use `AVURLAssetHTTPHeaderFieldsKey` instead.
- `AVPlayerItem.status` KVO: the key path `\AVPlayerItem.status` must be fully qualified; `\.status` causes type inference ambiguity in Xcode 26.

### SwiftUI Layout

- `GeometryReader` triggers two-pass layout. The first pass renders a zero-size frame, producing a visible blank frame. Avoid it in splash/loading screens.
- A `resizable()` image inside a `VStack` inside a `ZStack` — without `.frame(maxWidth: .infinity)` on the VStack, the VStack sizes to its minimum width (the ProgressView's natural width ~200pt). The image renders tiny and left-aligned even though ZStack centres the VStack.
- `.ignoresSafeArea()` on a `ZStack` lets its children centre relative to the full screen, not just the safe area. Without it, the vertical centrepoint is ~25pt lower than expected on iPhone Pro models due to the Dynamic Island safe area inset.

### Xcode 26 / Interface Builder

- `targetRuntime` in storyboard XML changed from `"AppleCocoa Touch"` to `"IBCocoaTouchFramework"` in Xcode 26. The old value causes `com.apple.InterfaceBuilder error -1` and a black launch screen.
- IB plugin version for Xcode 26.2 is `24504`. Find it with:
  ```bash
  /usr/libexec/PlistBuddy -c "Print :CFBundleVersion" \
    /Applications/Xcode.app/Contents/PlugIns/IDEInterfaceBuilderCocoaTouchIntegration.framework/Versions/A/Resources/Info.plist
  ```

### Asset Catalog Scales

- An image declared as `@2x` only renders at `782px / 3 = ~261pt` on a `@3x` device (iPhone Pro). Provide all three scale variants or accept the size mismatch.
- `UILaunchScreen` dict with `UIImageName` silently ignores images with no matching scale (e.g. only `@1x` provided for a `@3x` device) — the launch screen shows blank white.

---

## Prompt Context for AI Assistants

Use this section when starting a new AI-assisted session on this codebase.

### Project identity

This is an iOS SwiftUI app (`ios-video-app/`) that is a port of a companion Android app (`android-video-app/`). Both are part of the **5G-EMERGE** research project. The iOS app targets iOS 16+, uses the SwiftUI App lifecycle, and is built with XcodeGen. Xcode version on the developer machine is **Xcode 26.2** (build 17C52).

### Toolchain

| Tool | Version / Notes |
|------|-----------------|
| Xcode | 26.2 (Build 17C52) |
| Swift | 5.9 |
| XcodeGen | 2.45.4 — run `xcodegen generate` after adding files |
| Deployment target | iOS 16.0 |
| Primary test device | iPhone 17 Pro Max simulator (@3x, 430×932pt, 1290×2796px) |

### Media stack

- HLS only via `AVPlayer` + `AVPlayerViewController`
- CMCD via `AVURLAssetHTTPHeaderFieldsKey` (string literal, not Swift constant)
- No DASH support — `sampleVodURLs` must not contain `.mpd` URLs
- Audio session: `.playback` / `.moviePlayback` required for audio

### Stream URLs

**Live (5G-EMERGE testbed):**
- Configured via EPG URL in Settings (default: bundled `rai_epg.json`)

**VOD (cycling through 3 HLS streams):**
```
https://faredge.5gemerge.arcticspace.com/5G-EMERGE/VOD/hls/HQVideo/HQVideo.m3u8
https://faredge.5gemerge.arcticspace.com/5G-EMERGE/VOD/hls/5G-Emerge/5G-Emerge.m3u8
https://vod-testbed.gcdn.co/TOS/CMAF/TearsOfSteel.m3u8
```

### Things to avoid

- Do **not** use `GeometryReader` in any loading/splash view
- Do **not** use SwiftUI `VideoPlayer` inside `fullScreenCover`
- Do **not** add CMCD as query parameters to URLs
- Do **not** use `AVAssetResourceLoaderDelegate` for CMCD — `AVURLAssetHTTPHeaderFieldsKey` is sufficient
- Do **not** write `\.status` for KVO key paths on `AVPlayerItem` — use `\AVPlayerItem.status`
- Do **not** place storyboards in `VideoApp/Resources/` — they get double-included by XcodeGen; place at `VideoApp/` root
- Do **not** use `genericGamma22GrayColorSpace` in storyboard colour specs — use `sRGB`
- Do **not** use `targetRuntime="AppleCocoa Touch"` in storyboards — Xcode 26 requires `IBCocoaTouchFramework`
- Do **not** rebuild without running `xcodegen generate` first when new files have been added

### Things that work well

- `AVURLAssetHTTPHeaderFieldsKey` injects headers into all AVFoundation requests for an asset with zero interception complexity
- `withTaskGroup` for parallel splash prefetch (VOD + EPG + minimum timer)
- `UIViewControllerRepresentable` wrapping `AVPlayerViewController` for reliable fullscreen playback
- `NSKeyValueObservingOptions([.new])` (explicit, not `.new`) for `AVPlayerItem.status` observation
- Storyboard launch screens verified with `ibtool --compile` before building to catch XML errors early
