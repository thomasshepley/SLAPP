# TitanDeck - notes for Claude

A native SwiftUI iPad app (iPadOS 26+, landscape only, bundle id
`uk.co.elexproductions.titandeck`) for running an Avolites Titan lighting PC
from a film/TV set. A physical Elgato Stream Deck on the iPad's USB-C hub fires
Titan playbacks over the Titan WebAPI. From M5, a full-screen FreeRDP remote
desktop of the Titan PC fills the screen.

The person you're working with is a lighting tech, not a full-time developer
(basic-to-mid HTML/CSS/JS/PHP, new to Swift). Explain Swift and Xcode concepts
briefly when they come up, and keep it conversational.

## Rule 1: never change project settings in Xcode's UI

`TitanDeck.xcodeproj` is **generated** from `project.yml` by XcodeGen and is not
in git. Anything changed in Xcode's target settings, Signing & Capabilities,
Info tab, build settings or package list is **wiped** the next time the project
is regenerated, and CI regenerates it on every build.

- Bundle id, version, deployment target, Info.plist keys, entitlements, Swift
  packages, build settings, signing team: edit `project.yml`.
- `Resources/Info.plist` and `Resources/TitanDeck.entitlements` are generated
  too (and gitignored). Change them through `project.yml`.
- New Swift files: just create them under `Sources/` (or `Tests/`). XcodeGen
  picks up everything in those folders, so they don't need adding to the project.
- After changing `project.yml` or adding/removing files, the project must be
  regenerated: `xcodegen generate` in this folder. If you can't run shell
  commands, ask the user to run it in Terminal, then reopen the project.

## Layout

```
TitanDeck/
├── project.yml   XcodeGen spec - the real project settings
├── Sources/
│   ├── App/        TitanDeckApp, AppState (the only place the layers meet), RootView,
│   │               TitanIntents (App Intents: Fire Playback, Run Macro)
│   ├── Deck/       DeckSessionController (Stream Deck Kit), DeckRenderer, KeyDefinition,
│   │               DeckProfile (+ default 32-key profile), DeckProfile+Editing (page/key
│   │               edits, keeps page links valid), ActionDraft (form model), ProfileStore (JSON)
│   ├── Titan/      TitanAction, TitanEndpoints (URL builders), TitanClient (actor)
│   ├── Remote/     RDPSession (Swift side), RDPView (canvas + touch mapping), RemoteView,
│   │               RDPSettings, RDPGeometry, CertificateTrustStore (trust on first use)
│   │   └── Bridge/ titan_rdp.c/.h - the only code that touches FreeRDP's C API
│   ├── Settings/   SettingsView, DeckEditorView (M4), KeyInspectorView (M4)
│   └── Support/    Logger (Log.titan / Log.deck), HexColor
├── FreeRDP/        build.sh (FreeRDP + OpenSSL -> FreeRDPKit.xcframework), fetch.sh, versions.env
├── Vendor/         downloaded FreeRDPKit (gitignored) - never edit or commit
├── Tests/          XCTest unit tests (endpoints, profiles, editing, store, client)
└── docs/           TESTFLIGHT_SETUP.md
```

The Deck, Titan and Remote layers never reference each other. `AppState` wires
them together (e.g. `deck.onAction` -> `titan.perform`). Keep it that way.

## Milestones

| | Milestone | State |
| --- | --- | --- |
| M1 | PC prep: RDP Wrapper, WebAPI enabled, static IP | On the Titan PC, not code |
| M2 | Project skeleton, Stream Deck Kit, deck draws keys | Done |
| M3 | Titan client, keys fire playbacks, latency log | Done |
| M4 | Profile editor UI: pages, labels, colours, action inspector (`Settings/DeckEditorView.swift`, `Settings/KeyInspectorView.swift`) | Built - needs testing on the iPad |
| M5 | FreeRDP remote view in `Remote/`, touch-to-mouse mapping | Built - needs testing against the Titan PC |
| M6 | RDP reconnect with backoff + dimmed last frame, always-visible connection pill (Titan heartbeat, RDP, network interface), Local Network permission check | Built - needs testing on set. Earlier: idle timer, background warning, three-finger settings gesture, Keychain password |
| M7 | 8-hour show-day soak test + in-app connection log (Settings -> Soak test log: totals, events, CSV export) | Log built - the soak test itself is on set |
| M8 | Light keys for live playbacks (polls /titan/handles/Playbacks every 1 s), profile export/import via Files / iCloud Drive | Built - check on the real Titan that handles report user numbers |
| M9 | iPhone + iPhone Duo: on-screen deck drawn from the same profiles (Stream Deck Kit is iPad-only), adaptive layouts, App Intents (Shortcuts, Siri, Action button, Control Center) | Built - needs testing on an iPhone. iPhone Duo simulator needs Xcode 27.1 |
| M10 | Apple Watch GO button: hold-to-fire or double-tap gesture, via the iPhone app or direct HTTP | **Next** |

## Platform and design decisions

- **Universal app (iPhone + iPad).** Tabs: Remote, Deck (on-screen deck),
  Settings. Compact width opens on Deck.
- **Minimum OS is iOS/iPadOS 26.** Use iOS 26 APIs directly, without `#available` checks.
- **Liquid Glass:** standard SwiftUI components get it automatically. Use
  `.glassEffect()` / `.buttonStyle(.glass)` for floating controls (connection
  pill, reconnect overlay). Never put glass over the RDP framebuffer.
- **Layout by size class, never by device idiom or orientation.** iPhone Duo's
  inner display is regular x regular and ignores supported orientations. Avoid
  `UIScreen.main`. Use the environment, trait collection or
  `windowScene.screen`. Use `ConcentricRectangle` for corner-fitted shapes.
  Testing on the iPhone Duo simulator needs Xcode 27.1.
- **Network on set:** the iPad reaches the show network through the AirWire,
  USB-C into the hub, so it appears as Ethernet. iPad Wi-Fi should be off on set.
  Don't assume Wi-Fi APIs (SSID etc.) are meaningful on the iPad.
- **Capabilities are added only when a feature needs them:** App Groups
  (iPhone/Watch/widgets sharing), iCloud (M8), Access Wi-Fi Information (iPhone
  only, given the iPad uses Ethernet). Add them in `project.yml` AND on the app ID
  in the Apple Developer portal.

Not yet verified on real hardware: Stream Deck behaviour and Titan calls have
only run in the simulator/tests. Treat the first on-device run as a test.

## Titan WebAPI (checked against Avolites v19.2 docs)

Base: `http://<host>:4430/titan/script/2/<Namespace>/<Function>?...`
Docs: https://api.avolites.com/19.2/api/

Handle parameters carry a suffix saying how the handle is identified. We use
user numbers, so `handle_userNumber=6` (or `srcHandle_userNumber` where the
parameter is named `srcHandle`). Levels are `level_level=` (absolute, 0-1).

| Action | Path |
| --- | --- |
| Go | `Playbacks/FirePlaybackAtLevel?handle_userNumber=N&level_level=1&alwaysRefire=false` |
| Release | `Playbacks/ReleasePlayback?handle_userNumber=N&fadeTime=0&useMasterReleaseTime=true` |
| Fader level | `Playbacks/SetPlaybackLevel?srcHandle_userNumber=N&level_level=0.5` |
| Macro | `Macros/Run?macroId=<id string>` |
| Version check | `GET /titan/get/System/SoftwareVersion` |

The original build plan had wrong parameter names (`userNumber=`, `level=`,
`bool=`). Don't reintroduce them. Titan versions before v12 use different
syntax. Add new actions as new `TitanAction` cases plus a `TitanEndpoints`
mapping and a test, and never rename existing cases: they're saved in profile
JSON.

## Stream Deck Kit (streamdeck-kit-ipad 1.3.x)

- `StreamDeckSession.instance.setUp(stateHandler:newDeviceHandler:)`, called once.
- Key presses: `device.inputEventHandler = { event in ... }`, matching
  `.keyPress(index:pressed:)`.
- Drawing: `device.setKeyImage(UIImage, at: index)`, sized to
  `device.capabilities.keySize`.
- Needs the `com.apple.developer.driverkit.communicates-with-drivers`
  entitlement (set in `project.yml`), the Elgato Stream Deck Connect app on the
  iPad with its driver enabled, and an M1-or-newer iPad. Events only arrive while
  the app is in the foreground.
- Check the package source before trusting any other method name. The API has
  changed between versions.

## FreeRDP

- `FreeRDP/fetch.sh` must run before `xcodegen generate` on a fresh clone: it
  downloads the prebuilt FreeRDPKit matching `FreeRDP/versions.env` + `build.sh`
  into `Vendor/`. CI builds and publishes a package (GitHub release
  `freerdpkit-<version>-<hash>`) whenever that recipe changes. That build takes
  30-60 minutes.
- Swift never calls FreeRDP directly - only through `Remote/Bridge/titan_rdp.h`.
  The bridge runs FreeRDP on its own thread, queues input, and copies frames
  under a lock. Keep it that way.
- Static builds need `CHANNEL_REMDESK=OFF` (FreeRDP 3.32 link bug).

## Build, test, ship

- No Stream Deck in the iPad Simulator? Debug builds have Settings -> "Show
  on-screen Stream Deck (debug)", Stream Deck Kit's virtual deck. It goes through
  the same code path as real hardware.

- Unit tests: run the `TitanDeck` scheme's tests (Cmd-U) on an iPad simulator.
- GitHub Actions (`.github/workflows/titandeck.yml`) regenerates the project,
  builds and runs the tests on every push touching `TitanDeck/`. Pushes to `main`
  also upload to TestFlight (setup in `docs/TESTFLIGHT_SETUP.md`).
- Run the tests before calling something done. If a change can't be tested in
  the simulator (Stream Deck hardware, the real Titan PC), say so plainly.

## House rules

- Use regular hyphens, never em dashes, in code, comments, strings and docs.
- Match the surrounding code's style and comment density.
- Work on a branch, not `main`. Commit with a clear message, then push.
- Pull before starting (Source Control -> Pull), because other Claude sessions
  also work on this repo.
- Don't put secrets (Titan/RDP passwords, App Store Connect keys) in code or
  git. The RDP password goes in the Keychain (M6).
