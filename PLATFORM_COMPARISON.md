# iOS vs Android Platform Comparison

Reference document for developers and AI agents working across both codebases.
Android source: `~/android-video-app` · iOS source: `~/ios-video-app`

---

## Quick Reference

| Area | Android | iOS |
|---|---|---|
| Language | Kotlin | Swift |
| UI framework | XML layouts + View Binding (Fragments) | SwiftUI |
| Architecture | MVVM · StateFlow · Coroutines | MVVM · @Published · async/await |
| Build system | Gradle (Kotlin DSL) | XcodeGen → .xcodeproj |
| Player engine | ExoPlayer (Media3 1.5.1) | AVPlayer + AVPlayerViewController |
| Supported protocols | HLS + DASH | HLS only |
| CMCD delivery | Query parameters | HTTP headers |
| JSON parsing | Gson + data classes | Codable structs |
| Minimum OS | Android (varies) | iOS 16.0 |

---

## Areas That Are the Same

These can share design decisions, data formats, and logic almost verbatim.

### Content Sources

Both apps consume identical data sources:
- **VOD**: RaiPlay API (`https://www.raiplay.it/…`) with local `raiplay.json` fallback
- **EPG**: Remote EPG JSON with local `rai_epg.json` fallback
- **Live streams**: 5G-EMERGE CloudFront endpoints (`live-cdn-a.media-streaming.testbed.5g-emerge.io`)
- **Fallback live stream**: `https://faredge.5gemerge.arcticspace.com/5G-EMERGE/Live/hls/crits_linear/crits_linear.m3u8`

### Channel-to-Stream Mapping

Both apps use the same key-matching logic: lowercase the channel name and look for substring matches against a hardcoded map. The keys are `"rai scuola"` and `"rai storia"`. This logic is identical in `EpgRepository` on both platforms; any new channels must be added to both.

> **Note**: As of June 2026 the iOS app has the correct `live-cdn-a.` domain; the Android `EpgRepository` still has the old `live.cdn-a.` domain and needs updating.

### EPG JSON Schema

The EPG JSON structure (`EpgResponse` → `EpgChannel` → `EpgEvent` → `EpgProgram`) is identical on both platforms. Changes to the EPG API must be applied to both `EpgModels.kt` and `EpgModels.swift`.

### App Structure / Navigation

Both apps have the same five tabs:
1. **Home** — hero carousel + VOD grid
2. **Live** — channel list
3. **Guide** — EPG programme grid
4. **Network** — network status + public IP
5. **Settings** — EPG URL, theme

### Splash / Loading Behaviour

Both apps:
- Show a white background with the 5G-EMERGE logo at ~45% from the top
- Fade in a linear progress bar ~200 ms after launch
- Pre-fetch VOD and EPG data in parallel during a 2-second minimum hold
- Transition to the main screen with a fade

### Visual Design

- Same logo (`logo_5g_emerge`) and app icon (5G-EMERGE drone)
- Same accent colour (blue/purple from 5G-EMERGE brand)
- Hero carousel with thumbnail, title, description, and play affordance
- Dark mode support toggled via Settings

### Stats / Debug Overlay

Both apps show the same four fields when the stats overlay is enabled:
- Resolution
- Bitrate
- Bandwidth estimate
- Buffer ahead (seconds)

---

## Areas That Required a Different Approach

### 1. Player Engine

**Android — ExoPlayer (Media3)**

ExoPlayer is constructed explicitly, with a `MediaSource` built for each protocol. CMCD is injected via `CmcdConfiguration` attached to the `MediaSource` factory. The player is attached to a `PlayerView` in XML.

```kotlin
val mediaSource = HlsMediaSource.Factory(dataSourceFactory)
    .setCmcdConfigurationFactory(cmcdFactory)
    .createMediaSource(mediaItem)
exoPlayer.setMediaSource(mediaSource)
```

**iOS — AVPlayer + AVPlayerViewController**

AVFoundation has no native CMCD API. CMCD is delivered via a custom HTTP header using the string-literal key `AVURLAssetHTTPHeaderFieldsKey` (no Swift constant exists). AVPlayerViewController is presented as a full-screen cover and handles its own playback UI.

```swift
let headers = ["CMCD-Session": "…", "CMCD-Object": "…"]
let asset = AVURLAsset(url: url, options: [
    "AVURLAssetHTTPHeaderFieldsKey": headers
])
```

**Key difference**: iOS cannot use DASH. Any stream URL ending in `.mpd` will not play. The iOS data model has no `dashURL` field — it was removed intentionally. Android supports both `.m3u8` (HLS) and `.mpd` (DASH) and selects the source type by URL suffix.

---

### 2. CMCD Telemetry

**Android**

CMCD is appended as a query parameter (`?CMCD=…`) by ExoPlayer automatically. Dynamic values (buffer level `bl`, measured throughput `mtp`, encoded bitrate `br`) are populated per-request by the player. The CMCD panel reads these values back from the `LoadEventInfo.uri` in an `AnalyticsListener.onLoadCompleted` callback — so it shows exactly what was sent.

**iOS**

CMCD fields are set once when the `AVURLAsset` is created as HTTP request headers. There is no per-segment callback equivalent to `onLoadCompleted`. Dynamic fields (buffer level, throughput) are read from `AVPlayerItem.accessLog()` events on a 1-second timer and displayed in the stats panel, but they are not injected into outgoing requests. This means iOS CMCD headers carry static session fields; dynamic fields are display-only.

**Implication**: If the 5G-EMERGE CDN validates CMCD fields, iOS will always send static values. Implementing true dynamic CMCD on iOS requires a custom `AVAssetResourceLoadingDelegate` to intercept each segment request — significantly more complex than the ExoPlayer approach.

---

### 3. Player Stats Collection

**Android — AnalyticsListener**

ExoPlayer fires typed callbacks for each stat change. Values are captured into variables and polled on a 1-second `delay` loop to update the overlay.

```kotlin
override fun onBandwidthEstimate(…, bitrateEstimate: Long) { … }
override fun onVideoSizeChanged(…, videoSize: VideoSize) { … }
override fun onVideoInputFormatChanged(…, format: Format, …) { … }
```

**iOS — AVPlayerItem.accessLog()**

There are no equivalent typed callbacks. Stats are polled from `AVPlayerItem.accessLog().events.last` every second:

```swift
let event = player.currentItem?.accessLog()?.events.last
let bitrate = event?.indicatedBitrate
let bandwidth = event?.observedBitrate
```

Resolution is observed via KVO on `AVPlayerItem.presentationSize`. Buffer is calculated as `player.currentItem?.loadedTimeRanges`.

---

### 4. Track Selection (Quality / Audio / Subtitles)

**Android**

Media3 ships `TrackSelectionDialogBuilder` — a ready-made dialog that shows available tracks grouped by type. Three lines of code:

```kotlin
TrackSelectionDialogBuilder(context, "Video Quality", exoPlayer, C.TRACK_TYPE_VIDEO)
    .build().show()
```

**iOS**

`AVPlayerViewController` includes a built-in tracks menu accessible via the media info button in the player UI — no code required. Custom track overrides (e.g., force a specific subtitle language) are done via `AVPlayerItem.select(_:in:)` but the default UI handles the common cases automatically.

---

### 5. Fullscreen Handling

**Android**

`AVPlayerViewController`'s equivalent does not exist. Fullscreen is implemented manually:
1. `ConstraintSet` is used to re-anchor the `player_container` to fill the screen
2. `systemUiVisibility` flags hide the status and navigation bars
3. `onConfigurationChanged` fires when the device rotates and calls `enterFullscreen(fromRotation: true)` or `exitFullscreen(fromRotation: true)` to avoid double-locking the orientation

**iOS**

`AVPlayerViewController` manages fullscreen and rotation natively. A `.onReceive(NotificationCenter…orientationDidChange)` observer locks orientation to landscape when entering the player and restores it on dismiss. The transition animation and gesture to exit are handled by the system.

---

### 6. Splash Screen (Cold Start to First Frame)

**Android**

A single `SplashActivity` (not using the Android 12 SplashScreen API) sets `android:windowBackground` in the theme to a white drawable, making the window background visible before `setContentView`. The logo is `alpha=1` in the layout XML so it appears immediately with no fade-in delay. Only the progress bar fades in.

**iOS**

Two distinct phases are required:

| Phase | Mechanism | Duration |
|---|---|---|
| OS-managed | `LaunchScreen.storyboard` registered via `UILaunchStoryboardName` in Info.plist | Until first SwiftUI frame |
| App-managed | `SplashView` in SwiftUI fades in from `opacity: 0` | 2 s minimum hold |

The storyboard must centre the logo at `centerY constant="-77"` (not `-60`) to match the SwiftUI `VStack` at `offset(y: -60)`. The 17 pt difference comes from the VStack centring the whole stack (logo + 32 pt gap + 2 pt progress bar), while the storyboard centres the image alone: `(32 + 2) / 2 = 17`.

**Xcode 26 storyboard gotchas** (does not apply to Android):
- `targetRuntime` must be `"IBCocoaTouchFramework"`, not `"AppleCocoa Touch"`
- `toolsVersion` and `plugIn version` must be `"24504"` for Xcode 26.2
- Background colour must use `colorSpace="custom" customColorSpace="sRGB"` — `genericGamma22GrayColorSpace` renders black on device
- Storyboard must be placed at `VideoApp/LaunchScreen.storyboard`, not inside `VideoApp/Resources/`, to avoid XcodeGen double-inclusion
- Run `xcodegen generate` after adding any new file; Xcode does not auto-discover files outside `.xcodeproj`
- Delete the app from the simulator before testing launch screen changes — iOS caches the launch screen per install

---

### 7. Network & Carrier Information

**Android**

`TelephonyManager.networkOperatorName` returns the carrier name reliably. `TelephonyManager.dataNetworkType` (API 30+) or `networkType` (deprecated, API 29−) returns the radio access technology. Both work on physical devices.

**iOS**

`CTCarrier.carrierName` and `CTTelephonyNetworkInfo.serviceSubscriberCellularProviders` are **deprecated as of iOS 16** and return `"--"` on real devices. They have been removed from `NetworkMonitor.swift`. The radio access technology (`CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology`) still works and is used to derive 5G/4G/3G generation. Carrier name is not available without a private entitlement.

---

### 8. UI Gesture Conflicts

**Android**

Fragment and View click listeners have no gesture-conflict issue. `RecyclerView` touch handling is well-established.

**iOS — Known Pitfall**

A `Button` inside a `TabView` with `.tabViewStyle(.page)` (the paged carousel style) does not reliably fire because the `UIPageViewController` swipe gesture takes priority. The fix is to remove the `Button` and put `.onTapGesture { }` directly on the card container, combined with `.contentShape(Rectangle())` to make the full card area hit-testable.

This pattern applies anywhere a `Button` is nested inside a gesture-driven scroll container in SwiftUI.

---

### 9. JSON Parsing

**Android — Gson**

Requires a `Context` to open assets. Fields are mapped by reflection; `@SerializedName` needed when JSON key differs from property name. Parsing must happen on a background dispatcher.

```kotlin
val json = context.assets.open("rai_epg.json").bufferedReader().use { it.readText() }
Gson().fromJson(json, EpgResponse::class.java)
```

**iOS — Codable**

No library required. `JSONDecoder` is built-in. Asset files are loaded via `Bundle.main.url(forResource:withExtension:)`. Property names must match JSON keys (or use `CodingKeys`). Works on any thread with `async/await`.

```swift
let data = try Data(contentsOf: Bundle.main.url(forResource: "rai_epg", withExtension: "json")!)
try JSONDecoder().decode(EpgResponse.self, from: data)
```

---

### 10. Project / Build Configuration

**Android — Gradle KTS**

`app/build.gradle.kts` controls dependencies, `minSdk`, `targetSdk`, signing config. Adding a new file just requires placing it in the correct source set directory — Gradle picks it up automatically.

**iOS — XcodeGen**

`project.yml` is the source of truth. After adding any file that isn't inside a directory already covered by a glob source rule, run:

```
xcodegen generate
```

This regenerates `VideoApp.xcodeproj`. Forgetting this step means Xcode cannot see the file even if it exists on disk. Key `project.yml` fields:
- `DEVELOPMENT_TEAM: D6HWM95RTY` — required for device signing
- `deploymentTarget: iOS: "16.0"` — minimum iOS version
- `entitlements: com.apple.developer.networking.wifi-info: true` — required for SSID access

---

## Feature Parity Status

| Feature | Android | iOS | Notes |
|---|---|---|---|
| VOD catalogue | ✅ | ✅ | |
| Hero carousel tap-to-play | ✅ | ✅ | iOS: whole card tappable, not just button |
| Live stream (HLS) | ✅ | ✅ | |
| Live stream (DASH) | ✅ | ❌ | AVPlayer has no DASH support |
| EPG programme guide | ✅ | ✅ | |
| CMCD telemetry | ✅ dynamic | ⚠️ static | iOS headers; dynamic values display-only |
| Stats overlay | ✅ | ✅ | Different APIs, same fields |
| Track selection | ✅ | ✅ | Android: custom dialog; iOS: built-in player UI |
| Auto-fullscreen on rotate | ✅ | ✅ | Different mechanisms |
| Network status screen | ✅ | ✅ | |
| Carrier name | ✅ | ❌ | CTCarrier deprecated iOS 16 |
| Radio tech (5G/4G/3G) | ✅ | ✅ | |
| WiFi SSID + signal | ✅ | ✅ | iOS requires `wifi-info` entitlement |
| Public IP lookup | ✅ | ✅ | |
| Dark mode | ✅ | ✅ | |
| Configurable EPG URL | ✅ | ✅ | |
| Splash screen (OS phase) | ✅ window bg | ✅ storyboard | |
| Live stream domain | ⚠️ old domain | ✅ updated | Android `EpgRepository` needs `live-cdn-a.` update |
