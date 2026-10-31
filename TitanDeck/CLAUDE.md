# TitanDeck - notes for Claude

A native SwiftUI iPad app (iPadOS 26+, landscape only, bundle id
`uk.co.elexproductions.titandeck`) for running an Avolites Titan lighting PC
from a film/TV set. A physical Elgato Stream Deck on the iPad's USB-C hub fires
Titan playbacks over the Titan WebAPI. From M5, a full-screen FreeRDP remote
desktop of the Titan PC fills the screen.

Landscape is enforced three ways (`App/DeviceSetup.swift`): the Info.plist
iPad list, the app delegate's mask, and (0.39) `DeviceSetup.holdLandscape`,
called whenever the root view turns taller than wide or the device turns.
iPadOS 26 can rotate a landscape-only app to portrait with the rotation lock
off, so it requests landscape again (the way the iPad is held). Don't use
`prefersInterfaceOrientationLocked`: it would also stop the 180 degree flip.

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
│   ├── Remote/     RDPSession (Swift side), RDPView (canvas + touch mapping + hardware keyboard), RemoteView,
│   │               RDPSettings, RDPGeometry, RDPKeyboard (HID usage -> set-1 scan code, 0x100 = extended;
│   │               RDPTyping: on-screen keyboard text -> keys or Unicode, `titan_rdp_unicode`),
│   │               CertificateTrustStore (trust on first use)
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
├── Tools/          export_companion_data.ts - regenerates Resources/Companion;
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
| M6 | RDP reconnect with backoff + dimmed last frame, always-visible connection pill (Titan heartbeat, RDP, network interface), Local Network permission check | Built - needs testing on set. Earlier: idle timer, background warning (removed in 0.39.2, the user asked; the connection log still notes it), three-finger settings gesture, Keychain password |
| M7 | 8-hour show-day soak test + in-app connection log (Settings -> Soak test log: totals, events, CSV export) | Log built - the soak test itself is on set |
| M8 | Light keys for live playbacks (polls /titan/handles/Playbacks every 1 s), profile export/import via Files / iCloud Drive | Built - check on the real Titan that handles report user numbers |
| M9 | iPhone + iPhone Duo: on-screen deck drawn from the same profiles (Stream Deck Kit is iPad-only), adaptive layouts, App Intents (Shortcuts, Siri, Action button, Control Center) | Built - needs testing on an iPhone. iPhone Duo simulator needs Xcode 27.1 |
| M10 | Apple Watch GO button: hold-to-fire or double-tap gesture, via the iPhone app or direct HTTP | Built - needs testing on a Watch |
| M11 | Default deck: 15-key Stream Deck in portrait - Avolites keypad (digits, Exit, Enter, Clear, @), Intensity +/-1/5/10%, Playbacks; Menu key (hold 1 s since 0.17) opens a menu of layouts; Titan command line shown on the Deck tab | Built - test on Titan |
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
  Testing on the iPhone Duo simulator needs Xcode 27.1. **CI must build with
  Xcode 27.1 or later** (`runs-on: xcode-27` in `titandeck.yml`, 0.42.2): an
  app built with an older SDK opens letterboxed on the Duo's inner display (a
  phone-sized window, black bars, a rotate button), whatever its layout does.
- **iPhone Duo layouts (0.43):** the on-screen deck keeps the profile's
  columns and sizes keys to fit (`OnScreenDeckLayout.grid`, 48-180 pt keys,
  reflowing only when even that won't fit across). Wider than tall with room,
  it's two sides split down the middle with `foldGap` between them (selection
  card and pages leading, keys trailing): Apple says keep controls off the
  fold, except scrolling content. Settings is a `NavigationSplitView` of
  pages (`SettingsView.Page`); the startup checks go side by side when wide.
  The Duo's inner display is regular x regular in both orientations.
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
| Keypad digit / @ / Thru | `Command/AppendStringAndPreview?text=7` (or `@`, or `>` for Thru: unconfirmed, desk typing is the main path) |
| Keypad Enter | GET `/titan/get/2/Command/CommandLineText`, then `Command/RunCommand?command=<text>`, then `Command/StartNewCommand` |
| Keypad Clear | `Command/StartNewCommand` if something's typed, else `Programmer/Editor/ClearAll?presets=false&allProgrammers=false` (Titan 19.2 has Programmer.Editor and the old Playbacks.Editor names; prefer Programmer.Editor where both exist). With Keypad types on the desk: Exit if typing, then `Programmer/Editor/ClearSelection?disable=false&clearAllProgrammers=false` on 4430 and the desk link (selection only) |
| Keypad Exit | `Menu/ExitRootOrLatched` |
| Intensity +/- | `Programmer/Editor/Fixtures/IncrementDimmer?value=5&timeDelta=1&shiftEnabled=false` (value assumed to be percent - unconfirmed) |
| Version check | `GET /titan/get/System/SoftwareVersion` |
| Colour temp preset | `GET /titan/handles/Colours`, find the palette whose legend says "3200K", then `Palette/ApplyPalette?handle_titanId=N&usePaletteTimes=false` |
| Layout (workspace) | `Workspace/Apply?handle_userNumber=N`; names from `GET /titan/handles/Workspaces` (group name from community sources) |
| Fire a picked cue | `Playbacks/FirePlaybackAtLevel?handle_titanId=N&level_level=1&alwaysRefire=false` |
| Rig page (0.33) | `Programmer/Editor/Fixtures/ToggleHighlight`, `Selection/Context/Global/PatternNext` / `PatternPrevious` (on Titan 19: the 4430 user's mirrored selection). `TitanAction.toggleHighlight/nextFixture/previousFixture`, main menu RIG (`DeckChoice.openRig`, `Overlay.rig`) |
| Group masters (0.33) | Page 60 faders 1-10 = `/titan/handles/Playbacks` entries with page 59, index 0-9 (`DeckFlow.groupMasters`). Set: `Group/SetGroupHandleFaderLevel?handle_titanId=N&value_level=L&accuracy=1`, else `Playbacks/SetPlaybackLevel?srcHandle_titanId=N&level_level=L`. No documented level getter: the parser takes any "level" key in the handle (not "...match..."), else the deck shows the level it last set. Main menu MASTERS (`openMasters`, `Overlay.masters` / `.masterLevel`) |
| Groups page (0.38, Host 0.17+) | Keypad's Nothing Selected (`MenuTap.groups`) opens `Overlay.groups(set:)`, or `.groupSets` when no set is chosen yet. `DeckGroups` (pages, `Settings` in UserDefaults `deck.groupSets`: names, firstPage = 2, chosen; pure, tested). Set N = `/titan/handles/Groups/<firstPage-1+N>` (0-based page; falls back to "Group"). A group press: recalled through the WebAPI (`AppState.recallGroup`, 0.41; was Host fixture numbers typed on the desk), deck goes to Quick Keys (`.selection`). Settings > Groups page (`GroupSetsSection`) |
| Sync with Prism (0.39, Host 0.18+) | FX tab toolbar / Prism Setup > Prism media. `AppState.syncPrism` -> `GET /api/v1/fx/media?folder=` -> `PrismSync.merge` (pure, tested) into `FXLibraryStore`. Folder = bank number from its name else index + `firstFolder`; File = same with `firstFile` (`PrismSync.Settings`, UserDefaults `fx.prismSync`, 0 or 1 until checked on a real Titan). Matching: same PC path, else your item with the same name / file stem; your title, category and notes are kept. Clips from Prism have `fileName == ""` (`isOnIPad` false, kept on load), `prismPath`, `prismBank`, `prismMissing`. Removing one only takes it out of the library |
| FX: Prism layers (TitanDeck 0.37+, reworked 0.40 with the user, Host 0.17+, Test mode) | The user records per Prism layer a Prism layer fader (clip / play mode / speed / 100%) and a pixel map fader over an FX group, changes the group on the desk, and keeps fixture intensity in their own programmer. `DeckFX.Settings.Layer`: `fixture`, `group` (FX group number), `prismPage/Fader`, `playbackPage/Fader` (pixel map), `levelPage/Fader` (optional, no UI; RUN fires it at full); decodes pre-0.40 settings. Layer page (`DeckFX.LayerKey` order): CLIP (FX library Folder / File via Host `/api/v1/fx/layer`, then `AppState.selectFXGroup`), RUN / STOP latch (`runFXFaders`: `fireHandle` / `releaseHandle`), SELECT FX GROUP and LEVEL (`selectFXGroup`, 0.41: `recallGroup` through the WebAPI by number, `SetDimmerLevel`, and `deck.selectTyped` so Quick Keys act on it; read afresh every time), BRIGHT / SPEED / CONTRAST / SAT (Prism quick settings in the WebAPI user's programmer via the Host), RESET (releases them). USE SEL / ADD / REMOVE and the zone keys are gone (cases and the zone page code kept, unreachable). RUN state follows Titan's playbacks (`DeckFX.running`, ignored 3 s after a press) |
| Cue fade time / desk Clear (TitanDeck 0.32+, Host 0.14+) | When paired with the Host: `POST /api/v1/actions/cue-fade` {titanId, fadeOut, seconds} and `POST /api/v1/actions/clear-selection`, answering `HostTitanAction` {ok, message, steps}. The Host (`TitanRecipes` in Core, `TitanActions` in Service) holds the ways to try and checks them, so **iterate on these in the Host, not the app** (a Host release is minutes; TestFlight is a build). Older Host / unreachable: the deck's own path below |
| Cue fade time | Always on the 4430 client (never the desk link: it would change the operator's editor). `ActionScript/SetProperty?id=Playbacks.Editor.SelectedPlayback&value_titanId=N` (fallback `Playbacks/Editor/SetSelectedPlaybacks?handles_handleList=N`), `Playbacks/TimesEdit/FillTimes?handle_titanId=N` (the desk's Edit Times), `SelectCueByNumber` cue 1, then `ActionScript/SetProperty?id=Playbacks.Editor.Times.CueFadeInTime&value_time=S` (macros: `time:3`; see avosupport.de "Set fade-in time" macro). Then Float, text, JSON bodies last (a JSON body Titan can't read may zero the time). Each checked by read-back, then the cue reopened (FillTimes + select) and read again: OK only if both match (0.31.0 counted a 200 when the time couldn't be read, and the user saw "OK" with the cue still 0). Success detail goes to Recent events. **Experimental** until confirmed on the desk |
| Flash to 0 | `Programmer/Editor/Fixtures/SetDimmerLevel?level=0` (no time, so a faded flash is 20 `IncrementDimmer` steps of -5); back with `ClearSelectedControls?release=true&releaseTime=S` |
| Desk selection (desk link) | `Selection/Context/Global/GetAllSelectedFixtureIds` on Titan's UI WebAPI (TitanDeck port 4434 via the Host, Titan 4433); returns titan ids, mapped with `/titan/handles/Fixtures` |
| Latching GO (Playbacks page) | live: `Playbacks/ReleasePlayback?handle_titanId=N&fadeTime=0&useMasterReleaseTime=true`, else `FirePlaybackAtLevel?handle_titanId=N` |
| Desk selection (Titan 19, CITP) | Host `GET /api/v1/citp/selection`; then `Selection/Context/Global/Clear` + `SelectFixturesFromHandles` on 4430 so the deck's user has the same selection |
| Intensity nudge | `Programmer/Editor/Fixtures/IncrementDimmer?value=` is wheel steps, 4096 = full (`dimmerStepsPerPercent` 40.96), `timeDelta=1` (no acceleration) |
| Flash, no fade | `Programmer/Editor/Fixtures/FlashOut`, then `ClearFlash` |
| Patch address (experimental, off) | 4430 only: `Selection/Context/Global/SelectFixturesFromHandles?handleList_userNumberList=N` (when linked), `Patch/Repatch/SetDmxAddressesFromSelectedFixture`, `GET /titan/get/2/Patch/CurrentDmxAssignment` (format unknown) |
| One page of playbacks | `GET /titan/handles/Playbacks/<pageIndex>` (0-based); without the index, every page |

Notes from the API research (Oct 2026, `api.avolites.com` 19.2 + Avolites
support posts):
- The WebAPI may run as its own user with its **own programmer and
  selection** (avosupport.de). Fixtures selected at the desk then don't apply
  to API calls; what the deck selects ("102 Enter") does. Test on the console.
- `userNumber` in handle JSON may be an object (`userNumbers` / `hashCode`);
  `TitanHandlesParser` reads those shapes too.
- There's no documented way to read a fixture's current intensity from the
  WebAPI. `IntensityReader` reads it from Titan's sACN through TitanDeck Host
  and learns each fixture's intensity channels from what moves when the deck
  nudges or flashes it (`IntensityLearning`).
- **Desk link** (`App/DeskLink.swift`): port 4430 is its own user with its own
  programmer and selection (Avolites, 2021: selection is "just handled in the
  user interface"). `webapi.enabled` in Titan's .exe.config (Titan 14+,
  documented for all consoles in v17.0) starts a WebAPI inside Titan's UI that
  shares the operator's selection and programmer. TitanDeck Host turns it on
  at 4433 and proxies it on 4434. While linked, `AppState.fire` sends deck
  actions there. **Never send Patch calls to the desk link** (Titan's Patch
  menu holds the programmer); the Host proxy refuses them too.
- **Titan 19.2's WebAPI** only takes the calls TitanDeck uses (keypad, Clear,
  Exit, fade times, workspaces) with `webapi.pre19Compatibility` = true in
  `WebAPI\<version>\WebAPIService.dll.config`; otherwise HTTP 500 (playbacks
  still fire). TitanDeck Host 0.9 checks and fixes it. `TitanClient.errorText`
  keeps Titan's error body for Recent calls.
- **Everything through the WebAPI (0.41, the user asked):** typing on the desk
  glitched (missed keys, once every fixture selected at 100%), so
  `AppState.keypadTypesOnDesk` is always false and the switch is gone.
  `AppState.runKeypad`: digits / @ / THRU / Exit only build the deck's line;
  Enter parses it (`DeskKeys.typedFixtures`, `typedLevel`, two-digit levels
  only) and does `selectFixtures` + `Programmer/Editor/Fixtures/SetDimmerLevel`;
  Clear clears the line, then `clearSelection` + programmer. Groups page and
  FX group: `AppState.recallGroup` (WebAPI `RecallGroupNumeric`, `RecallGroup`,
  `RecallGroupById` until something's selected), fixture numbers read back
  (`selectedFixtureIds` + fixture handles) for `deck.selectTyped`; FX sets
  `SetDimmerLevel`. Intensity, flash and RIG take the old WebAPI paths. On
  Titan 19 that's the 4430 user's own programmer, not the desk's. Host 0.18.2
  puts the 4430 selection back as it was after FX / group actions (it used to
  put the desk's). Don't bring desk typing back without the user asking. The
  notes below describe the unused typing code.
- **Sharing the desk's user (0.42, experimental, untested on a desk):** Titan
  keeps a programmer per user (manual: "Each user (including remotes) has
  their own programmer"); the 4430 WebAPI is its own. Settings > Share the
  desk's user (`SharedUserSection`, `AppState.sharesDeskUser` /
  `sharedUserId`): `Users/SetUser?userId=` to the desk's user, re-applied
  whenever the heartbeat comes back (Titan forgets it), `Users/CurrentUserId`
  / `CurrentUserName` read back; off sets the WebAPI's own user back
  (`ownWebAPIUser`, remembered before the first switch). User list (0.42.1):
  `/titan/handles/Users` (`TitanUsers.fromHandles`), as the user found
  Titan didn't answer `Users/GetUserListMenuItems`, which is the fallback
  (shape undocumented `TitanUsers.parse` reads
  any JSON id + name); a typed Titan id is the last resort. TitanUsers.swift
  is in the Watch target, as TitanClient uses it.
- **Keypad types on the desk (unused since 0.41)** (`DeskKeys`, `AppState.typeOnDesk`,
  `deck.keypadTypesOnDesk`): keypad actions become Titan's PC keyboard shortcuts
  (number keys, number-pad * = @, / = Thro, Enter, Esc = Exit),
  typed by the Host window (`POST /api/v1/desk/keys`) or over RDP, so they reach
  the desk's own command line. On the default keypad, Clear shows as THRU
  (`.keypadThro`, `DeckFlow.keypadKey`) while nothing is selected;
  `KeypadBuffer` turns "1>10 Enter" into a selection of 1-10. **Never Alt or
  any modifier from the app:** Alt+C for Clear left the desk's own Clear and
  wheels dead (0.24), and Titan 19 ignored Alt+C (Host 0.14) and RIG's
  Alt+arrows (0.35). RIG on the desk (0.36, desk linked): FIX +1 / FIX -1 type
  the next fixture of the selection by number and ALL types the selection back
  (`AppState.rigKeys`, `DeskKeys.selecting`, "10 THRU 20 AND 25 Enter"); HI
  LIGHT stays on the WebAPI user, which follows the desk's selection. On Titan 19 the paired Host does CLEAR: since Host 0.15 an
  empty CITP selection, only with a desk selection (see TitanDeckHost/CLAUDE.md).
  Clear types Exit if something's typed, then
  `TitanClient.clearSelection` on the 4430 client AND the desk link client
  (`Programmer/Editor/ClearSelection?disable=false&clearAllProgrammers=false`,
  falling back to `Selection/Context/Global/Clear`): the user wants the deck's
  CLEAR to clear the desk's selection, never the programmers. 0.26-0.28 also
  cleared every programmer; 0.29-0.30 only cleared the 4430 user's selection
  (did nothing on the desk). Titan 19 (CITP, no UI WebAPI): 4430
  `ClearSelection?clearAllProgrammers=true` (every user's selection), then
  `deskLink.selection` (CITP) must go empty within 1 s, else a red key.
  **Desk typing latency (0.34):** presses wait in `AppState.deskPresses` and
  everything pressed while a request is on its way goes in the next one
  (`typeWaitingPresses`, up to `HostClient.maxDeskKeys`); desk keys have their
  own `URLSession` (`keysSession`) so they never queue behind slow Host calls.
  CLEAR keeps its place in the order (later keys wait, so it can't clear their
  selection), so keep CLEAR quick: Host 0.15 answers within about 1 s and no
  longer tries the WebAPI clears after a CITP clear. Keys used to queue behind
  a failing CLEAR's 2 s checks and fallbacks and showed on the desk 3-15 s late.
  **Flash fades on the desk (0.35):** Titan's keyboard has no fade time, so a
  hold-for-0% with a fade (`FlashFadeRule`) is typed as levels in steps
  (`DeskKeys.rampSteps`, about 3 a second, at most 12; `AppState.rampOnDesk`).
  0.23-0.34 typed "@ 0 Enter" at once and the fade was ignored. **Never type
  fast runs of levels:** a missed "@" or Enter turns a level into a fixture
  number ("@ 64 @ 48" = fixture 64), which selected stray fixtures (0.35-0.37).
  `DeskKeys.coalesced` (and the Host's `DeskKeys.Coalesce`) keep only the
  newest of back-to-back "@ n Enter"; the Host types keys held 35 ms, 30 ms
  apart, 90 ms after Enter.
  **Master levels (0.36):** Titan has no getter for a fader's level; MASTERS
  reads each master with `Masters/ConnectToMaster` (on the 4430 user), `GET
  Masters/ConnectedMasterLevel`, `Masters/DisconnectMaster`
  (`TitanClient.masterLevel`); what can't be read goes in Recent events. +/- nudges are current level + nudge (`DeskKeys.nudged`), from
  `currentLevel` (typed in the last 2 s, else sACN live level, else the level
  last typed for the same selection); unknown = refused, never the WebAPI
  wheel. Typing is serial (one Task chain). The WebAPI user
  mirrors the keypad selection so intensity keys still work. Keep the key names
  in step with `TitanDeckHost/src/Core/Titan/DeskKeys.cs`.
- **Desk-typed levels** (`AppState.deskLevelKeys`): with the keypad typing on
  the desk, intensity nudges and Hold for 0% type `@ level Enter` on the desk
  (`DeskKeys.level`), from `deck.liveLevel` (or the level just typed, for 2 s);
  unknown level = the WebAPI as before. 1-9% go as two digits ("@ 0 5"):
  Avolites reads one digit as tens ("@ 5" = 50%). They need
  `deck.selectedFixtures`: anything the deck types to select (a Groups page
  group) must also call `deck.selectTyped`, or the keys fall to the WebAPI. IncrementDimmer accelerates when the
  wheel turns fast, so `TitanEndpoints.wheelSeconds` keeps it at 10 steps/s.
- **Selection strip**: `DeckFlow.selectionTexts` (Remote screen top bar, the
  longest that fits via ViewThatFits), `selectionStrip` (Quick Keys keys 9-11,
  `DeckChoice.selectionStrip`, a tap pages on), `compactSelection` (keypad Menu key).
- **Through TitanDeck Host** (`AppState.titanViaHost`, `titan.viaHost`): the
  shared `TitanClient` uses port 4436 (`TitanEndpoints.viaHostPort`), the
  Host's logged pass-through to 127.0.0.1:4430. App Intents and the Watch still
  go straight to 4430.
- **Slate Book** (`Slate/`: `SlateStore`, `SlateBookView`, pure `SlateText`;
  Host 0.13 `GET/POST /api/v1/slate...`): the Host logs the look (every
  universe of Titan's sACN) per slate and take (UK style: slate per setup,
  letters skip I/O) with D/N and FX, and changes once the output settles
  (moving channels ignored). The deck's Slate page is a built-in overlay
  (`DeckFlow.slatePage`, `.slate(returnTo:)`), reached from the main menu's
  SLATES key (`DeckChoice.openSlates`); its keys are `DeckChoice.slate*`, so
  they never appear in the key editor. Phase 2 (planned): record each slate
  as a Titan cue on playback page 1 for one-tap recall.
- **Desk selection over CITP** (Titan 19, where the 4430 WebAPI is a separate
  service and the UI WebAPI doesn't exist): TitanDeck Host 0.9 joins Titan as
  a CITP visualiser and serves `GET /api/v1/citp/selection`
  (`HostCitpSelection`: enabled, linked, peer, fixtures as user numbers).
  `DeskLink.tick` asks the Host first; while it's linked over CITP the state is
  `.linkedViaCitp`, the deck's own 4430 user selects the same fixtures
  (`TitanClient.selectFixtures`), and `commandClient` stays nil (commands go to
  4430). It's a full feature on the Host (0.11+): on in Test and Show.
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

- Testing is on the real Titan now: Fake Titan (Host) and `fake_titan.py` were
  removed in Host 0.11.0. Don't bring them back. The Host's Titan log shows
  every call that goes through it.

- **Test / Show mode** (`SettingsKeys.showMode`, Settings > Mode): Show hides
  test tools in Settings and forces experimental features off. Anything new
  that's only for testing goes behind `!showMode` too; the TEST badge
  (`Support/ModeBadge`) shows in Test mode.

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
