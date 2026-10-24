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
│   │               DeckProfile (+ default 15-key portrait profile), DeckProfile+Editing (page/key
│   │               edits, keeps page links valid), ActionDraft (form model), ProfileStore (JSON)
│   ├── Titan/      TitanAction, TitanEndpoints (URL builders), TitanClient (actor)
│   ├── Remote/     RDPSession (Swift side), RDPView (canvas + touch mapping), RemoteView,
│   │               RDPSettings, RDPGeometry, CertificateTrustStore (trust on first use)
│   │   └── Bridge/ titan_rdp.c/.h - the only code that touches FreeRDP's C API
│   ├── Companion/  The lighting companion, rebuilt natively (M12+):
│   │   ├── Model/  Fixture (matches the old app's JSON), FixtureLibrary, CompanionUnits,
│   │   │           GelSearch (+ ColourDistance), FXLibrary (FX index, pure)
│   │   ├── Calc/   Photometry, Dimming, Stops, PowerBudget, Cable, Flicker, Exposure, LetterIndex,
│   │   │           ColourMaths, Sun - pure maths ported from lighting-companion/src/services/calc
│   │   └── Views/  CompanionView (split view), fixture library/detail/compare, one view per tool
│   ├── UniFi/      Wi-Fi tab (M17): UniFiModels (API shapes, channels, ChannelAdvisor - pure),
│   │               UniFiConnection (login, cookies/CSRF, certificate trust on first use),
│   │               UniFiStore, UniFiView, UniFiSetupView
│   ├── FileDrop/   Send to PC (M16): FileDropStore (queue, Host or bookmarked folder),
│   │               FileDropCopier (chunked copy, pure), FileDropView, FileDropSetupView
│   ├── Host/       TitanDeck Host on the PC (M18): HostAPI (models + URLs, pure - mirrors
│   │               TitanDeckHost/src/Core/Api/Messages.cs), HostClient, HostDiscovery
│   │               (Bonjour), HostStore (pairing, health, From PC), pairing + status views
│   ├── Settings/   SettingsView, DeckEditorView (M4), KeyInspectorView (M4)
│   └── Support/    Logger (Log.titan / Log.deck), HexColor
├── FreeRDP/        build.sh (FreeRDP + OpenSSL -> FreeRDPKit.xcframework), fetch.sh, versions.env
├── Vendor/         downloaded FreeRDPKit (gitignored) - never edit or commit
├── Watch/          watchOS app (GoView, WatchModel). Shares Titan/ + WatchCommand with the phone app
├── Tests/          XCTest unit tests (endpoints, profiles, editing, store, client)
├── Resources/Companion/ fixtures.json (251 fixtures; DMX modes from the makers' charts, merged by
│                   Tools/merge_fixture_modes.py), gels.json (LEE/Rosco/GAM,
│                   built by Tools/import_gels.py), flicker.json (researched refresh rates by fixture id)
├── Tools/          fake_titan.py - pretend Titan WebAPI for testing without an AvoKey;
│                   export_companion_data.ts - regenerates Resources/Companion;
│                   merge_fixture_modes.py - checks researched DMX modes (footprints add up,
│                   no clashing slots) and folds them in. Modes carry the maker's number and
│                   brief ("Mode 89 · D CCT GM CRO RGB"); big pixel modes list cell 1 with
│                   repeatCells / cellSize / cellStart;
│                   tag_pixel_cells.py - stamps each pixel-mode channel with its cell (and
│                   cellGroup on multi-set fixtures). Run it after merge_fixture_modes.py.
│                   pixel-layouts.json (by fixture id) holds each pixel fixture's face and
│                   how cells group its pixels, from the manuals; PixelMapView draws it
└── docs/           TESTFLIGHT_SETUP.md, TEST_PLAN.md
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
| M10 | Apple Watch GO button: hold-to-fire or double-tap gesture, via the iPhone app or direct HTTP | Built - needs testing on a Watch |
| M11 | Default deck: 15-key Stream Deck in portrait - Avolites keypad (digits, Exit, Enter, Clear, @), Intensity +/-1/5/10%, Playbacks; Menu key (hold 2 s) opens a menu of layouts; Titan command line shown on the Deck tab | Built - test on Titan |
| M12 | Companion tab, core: fixture library (search, filters, specs, DMX chart, compare), beam/photometry, stops, power + cable, colour + gels (RGB/HSI converter, green/magenta), flicker (per fixture, with fixes), sun on a map with a time slider, units & mains | Built |
| M13 | Companion: shows, patch builder (packer), universe plan, PDF cheat sheet, CSV / MA3 / Titan exports, `.slapp.json` import/export | Next |
| M14 | Companion -> Titan: patch a show into Titan over the WebAPI (`Patch/SelectManufacturer`... `Fixtures/PatchFixturesToVacantHandles`), select / locate / highlight | Planned - DmxAssignment format and patch read-back unconfirmed |
| M15 | Companion: plot tagging with PDFKit, GDTF import | Planned |
| M16 | Send files to the PC, AirDrop style: a Windows shared folder connected in the Files app (iOS's own SMB client), picked once and kept as a security-scoped bookmark; Photos / Files / drag and drop / "Open in TitanDeck" from any app | Built - needs testing against the PC |
| M17 | Wi-Fi tab from the UniFi console's local API (local admin login, no API key or internet): this iPad's AP and signal, channel map with neighbours, quietest channels, AP radios (channel, width, power, utilisation), weak clients, RF scans | Built - needs testing on the show network. Live spectral analysis stays in UniFi (it needs Ubiquiti's cloud) |
| M18 H1 | TitanDeck Host for Windows (`TitanDeckHost/`): one install for the PC side - service, RDP checks and fixes, RDP Wrapper, pairing, files | Built - needs testing on the PC |
| M18 H2 | TitanDeck pairs with the Host (Bonjour + 6-digit code, token in the Keychain), PC health + iPad-allowed fixes, rdpwrap.ini from the iPad, files both ways (Host first, shared folder fallback) | Built - needs testing on the PC |
| M18 H3 | RDP picture presets (Best / Balanced / Weak signal): iPad visual effects (FreeRDP connection type) + PC image quality / graphics mode / 30-60 fps via Host 0.2; Send RDP Wrapper | Built - needs testing on the PC. Signal dashboard and link test next |

## Platform and design decisions

- **Universal app (iPhone + iPad).** Tabs: Remote, Deck (on-screen deck),
  Companion, Settings. Compact width opens on Deck. On iPhone the Remote tab is
  off by default (Settings -> Remote desktop -> "Show the Remote tab"); the app
  opens on the Companion there. That default uses the device idiom on purpose
  (iPhone Duo open is still a phone), unlike layout, which uses size class. While the remote desktop is live the
  tab bar hides; the glass **Menu** button next to the connection pill is the
  way back (Deck / Settings / Disconnect). Connect-on-launch is off by default.
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
  (iPhone/Watch/widgets sharing), iCloud (M8), Access Wi-Fi Information (on: the
  connection details panel shows the Wi-Fi name and access point; it also needs
  precise Location, asked for only when that panel opens). Add them in
  `project.yml` AND on the app ID in the Apple Developer portal.
- **iOS gives apps no Wi-Fi signal strength.** The details panel shows Titan
  reply times (`LatencySummary`) as the link-quality measure instead.

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
| Keypad digit / @ | `Command/AppendStringAndPreview?text=7` (or `@`) |
| Keypad Enter | GET `/titan/get/2/Command/CommandLineText`, then `Command/RunCommand?command=<text>`, then `Command/StartNewCommand` |
| Keypad Clear | `Command/StartNewCommand` if something's typed, else `Playbacks/Editor/ClearAll?presets=false&allProgrammers=false` |
| Keypad Exit | `Menu/ExitRootOrLatched` |
| Intensity +/- | `Programmer/Editor/Fixtures/IncrementDimmer?value=5&timeDelta=1&shiftEnabled=false` (value assumed to be percent - unconfirmed) |
| Version check | `GET /titan/get/System/SoftwareVersion` |
| Colour temp preset | `GET /titan/handles/Colours`, find the palette whose legend says "3200K", then `Palette/ApplyPalette?handle_titanId=N&usePaletteTimes=false` |
| Layout (workspace) | `Workspace/Apply?handle_userNumber=N`; names from `GET /titan/handles/Workspaces` (group name from community sources) |
| One page of playbacks | `GET /titan/handles/Playbacks/<pageIndex>` (0-based); without the index, every page |

Notes from the API research (Oct 2026, `api.avolites.com` 19.2 + Avolites
support posts):
- The WebAPI may run as its own user with its **own programmer and
  selection** (avosupport.de). Fixtures selected at the desk then don't apply
  to API calls; what the deck selects ("102 Enter") does. Test on the console.
- `userNumber` in handle JSON may be an object (`userNumbers` / `hashCode`);
  `TitanHandlesParser` reads those shapes too.
- There's no documented way to read a fixture's current intensity.
- Keypad levels: `@ @` = full; `@ 5` is 5% unless the user setting Channel
  Levels is "Set In Tens" (`GET /titan/get/2/UserSettings/SingleDigitLevels`).

The original build plan had wrong parameter names (`userNumber=`, `level=`,
`bool=`). Don't reintroduce them. Titan versions before v12 use different
syntax. Add new actions as new `TitanAction` cases plus a `TitanEndpoints`
mapping and a test, and never rename existing cases: they're saved in profile
JSON.

## Deck orientation

Profiles store keys by *logical* index - as you look at the deck. `DeckGeometry`
maps those to the hardware's landscape key numbers and says how far to turn
key images. Never index hardware keys with profile indices directly.

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

- No Stream Deck in the iPad Simulator? Settings -> "Show virtual Stream Deck"
  (every build, TestFlight included) opens Stream Deck Kit's virtual deck. It
  goes through the same code path as real hardware.

- No Titan (or no AvoKey)? `python3 Tools/fake_titan.py` on any computer on the
  same network answers every call TitanDeck makes and prints them. Add new
  actions to it when you add them to `TitanEndpoints`.

- **Versions and changelog:** `CHANGELOG.md` is the release notes. Every change
  that goes to `main` adds an entry at the top (`## 0.MINOR.PATCH - YYYY-MM-DD -
  Title`, then `- ` bullets, plain enough for the TestFlight app) and bumps
  `MARKETING_VERSION` in `project.yml` to match (`ChangelogTests` fails
  otherwise). MINOR for features, PATCH for fixes; 1.0 when it's show-ready. The
  build number is the CI run number. The app shows the notes (Settings > About >
  What's New, and once after an update) and the TestFlight job copies the top
  entry into "What to Test" (`Tools/testflight_notes.py`).

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
