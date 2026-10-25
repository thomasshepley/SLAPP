# TitanDeck

A native iPad app for running an Avolites Titan PC from set. A physical Stream
Deck on the iPad's USB-C hub fires Titan playbacks over the Titan WebAPI. In M5
a full-screen FreeRDP remote desktop of the Titan PC fills the screen behind it.

Build plan: https://claude.ai/artifact/PXtiepzci194FMHiHaynGM

## Status

| Milestone | State |
| --- | --- |
| M1 - PC prep (RDP Wrapper, WebAPI, static IP) | On the Titan PC - not code |
| M2 - Project skeleton, Stream Deck Kit, deck draws keys | Done |
| M3 - Titan client, keys fire playbacks, latency log | Done |
| M4 - Profile editor UI | Built - needs testing on the iPad |
| M5 - FreeRDP remote view | Built - needs testing against the Titan PC |
| M6 - Reconnect, overlay, settings gesture, Keychain, connection pill | Built - needs testing on set |
| M7 - Show-day soak test | Log built (Settings → Soak test log) - test on set |
| M8 - Live key state, profile export/import | Built - test on the Titan PC |
| M9 - iPhone + iPhone Duo on-screen deck, App Intents | Built - test on an iPhone |
| M11 - Default 15-key portrait keypad / intensity deck, hold-for-menu | Built - test on Titan |
| M10 - Apple Watch GO button | Built - test on a Watch |

Testing everything at home: see [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md).

## How it's built (no Mac needed)

There's no Xcode on iPad, so builds run on GitHub's macOS machines:

- **Every push** touching `TitanDeck/` runs `xcodegen generate`, builds the app,
  and runs the unit tests on an iPad simulator. See
  `.github/workflows/titandeck.yml`.
- **Pushes to `main`** (or a manual run) also sign the app and upload it to
  TestFlight, once the one-off setup in
  [`docs/TESTFLIGHT_SETUP.md`](docs/TESTFLIGHT_SETUP.md) is done.

On a Mac: `FreeRDP/fetch.sh` (downloads the prebuilt FreeRDP library), then
`xcodegen generate`, then open `TitanDeck.xcodeproj`. Rerun both after pulling
changes to `project.yml`, `FreeRDP/` or new files.

## Layout

```
TitanDeck/
├── project.yml            XcodeGen spec (bundle id, entitlements, Info.plist, packages)
├── Sources/
│   ├── App/               TitanDeckApp, AppState (wires the layers), RootView
│   ├── Deck/              Stream Deck Kit session, key renderer, profile model + JSON store
│   ├── Titan/             TitanAction, TitanEndpoints (URL builders), TitanClient (actor)
│   ├── Remote/            FreeRDP wrapper - stubs until M5
│   ├── Settings/          Settings screen
│   └── Support/           Logger, hex colours
├── Resources/             Asset catalog (Info.plist + entitlements are generated)
├── Tests/                 Unit tests: endpoints, profiles, store, client
└── docs/                  TestFlight setup guide
```

## Notes that differ from the build plan

- **Titan WebAPI paths** are taken from the Avolites Titan v19.2 API docs. The
  plan's draft used the wrong parameter names. The correct form is
  `Playbacks/FirePlaybackAtLevel?handle_userNumber=6&level_level=1&alwaysRefire=false`.
  Release uses `Playbacks/ReleasePlayback`, which honours the playback's
  release time, rather than `KillPlayback`. Macros run by macro id
  (`Macros/Run?macroId=...`), not by user number. Titan versions before v12
  use a different syntax.
- **Stream Deck Kit API** is checked against the 1.3.0 source. Key presses come
  through `StreamDeck.inputEventHandler`, and images go out with
  `setKeyImage(_:at:)`.
- **Default profile** is for a 15-key Stream Deck mounted in portrait: Keypad,
  Quick Keys, Colour, Playbacks and Layouts pages. A tap on Menu swaps between
  the keypad and Quick Keys; holding it for a second opens a menu of layouts. If a different-sized deck is plugged in while the profile is
  still the untouched default, it re-flows to fit. Edited profiles are never
  touched.
- **Settings** is a tab next to the remote view for now. A deck key with the
  `openSettings` action also switches to it. The three-finger long-press comes
  with the RDP view in M5/M6.

## Using it

1. Settings → Titan PC address → enter the PC's IP → **Test connection**.
   It should show the Titan version.
2. **Fire test playback 1** / **Release playback 1** check the WebAPI end to
   end. Each call is listed under **Recent calls** with its round-trip time in
   ms. That's the M3 latency measurement.
3. Settings → **Edit deck profile** lays the keys out like the deck. Tap a key
   to set its label, colour, icon and action (Go, Release, fader level, macro,
   page changes, custom WebAPI path). The page menu adds, duplicates, renames,
   moves and deletes pages. Edits save straight away and show on the deck.
4. No Stream Deck to hand, or running in the iPad Simulator? Settings → **Show
   virtual Stream Deck**.
5. Plug in the Stream Deck. Page 1 is the Avolites keypad (1-9, Exit 0 Enter,
   Clear Menu @). Tap Menu for Quick Keys, hold it for a second for the other
   pages. A key
   flashes red if Titan doesn't answer within 500 ms.
