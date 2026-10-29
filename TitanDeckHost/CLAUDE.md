# TitanDeck Host - notes for Claude

The Windows companion to TitanDeck (the iPad app in `../TitanDeck`). One
install on the Titan PC that keeps Remote Desktop working, pairs with
TitanDeck and moves files both ways. The owner is a lighting tech, not a
Windows developer: plain English in the UI, short explanations in chat.

## Layout

```
TitanDeckHost/
├── Directory.Build.props   version (keep in step with CHANGELOG.md) + shared settings
├── src/Core/      net8.0, platform-neutral, unit tested on any OS:
│                  PairingStore, RdpWrapIni, RdpDiagnosis (facts -> plain-English checks
│                  with fixes), SafeFileName, API messages (Api/Messages.cs),
│                  sACN (Sacn/: E1.31 packet parser + DmxUniverses merge store),
│                  TitanUiConfig (Titan's UI WebAPI config, checklist line, proxy allowlist),
│                  TitanLog (every Titan call, polls counted), Update/HostUpdate (GitHub releases),
│                  TitanPatch (patch report CSV/XML/HTML), TitanPersonality + PersonalityLibrary (.d4),
│                  Citp/ (CITP packets, PINF/FSEL/CAEX codecs, CitpAllowlist, CitpSession),
│                  Slate/ (SlateNumbers, LookDiff, LookWatcher, SlateBook),
│                  TitanRecipes (the ways TitanDeck's cue fade / Clear are tried on Titan 19)
├── src/Service/   net8.0-windows Windows service (LocalSystem): Kestrel API on
│                  0.0.0.0:4431 (paired iPad) and 127.0.0.1:4432 (the Host window),
│                  WindowsProbe (reads the PC), Fixer (applies fixes), Advertiser (mDNS),
│                  SacnListener (joins sACN multicast on every adapter, port shared),
│                  DeskLink (finds/edits Titan.dll.config / .exe.config, /titan proxy on 0.0.0.0:4434),
│                  HostUpdater (checks GitHub every 6 h, downloads + verifies the installer),
│                  PatchReader (newest patch report + personalities),
│                  CitpService (CITP visualiser: UDP 4809 PLoc, TCP 4435; Test and Show),
│                  SlateService (Slate Book from sACN, Data\SlateBook\<day>.json),
│                  TitanActions (runs TitanRecipes on 4430, checks each, POST /api/v1/actions/*)
├── src/App/       net8.0-windows WPF tray app + dashboard; talks only to 127.0.0.1:4432
├── tests/Core.Tests/  xunit
└── installer/     Inno Setup script
```

## Rules

- **Updates (0.14.2):** the installer closes the window app with `TitanDeckHost.exe --quit` (named events
  `Local\TitanDeckHost.App.Quit` / `.Show`; a force-kill leaves a dead tray icon), stops the service and
  waits for Stopped (PowerShell, 30 s) before taskkill, `CloseApplications=no`, then `net start` (waits).
  The service must stop fast: `HostOptions.ShutdownTimeout` 5 s, and long-polls (`/local/desk/keys/wait`)
  end on `ApplicationStopping`. With the service down, the window's Start the service button runs
  `net start TitanDeckHost` elevated (UAC), as Update runs the installer: the one admin step the window asks for.
- **Anything that needs admin happens in the service**, never the window app.
- **The iPad's API is paired.** Only `/api/v1/hello` and `/api/v1/pair` work
  without a token; match them exactly. Fixes that weaken the PC (Defender
  exclusion, network profile, installing RDP Wrapper) are PC-only:
  `Fixer.AllowedFromIPad`.
- **File names from the iPad go through `SafeFileName.Clean`.** No exceptions.
- **Each probe fact fails on its own** (`WindowsProbe.Try`), so the checklist
  still shows when one thing can't be read.
- **RDP Wrapper binaries are never bundled.** Defender flags them, which would
  quarantine the installer. Only `rdpwrap.ini` ships (fetched at build time from
  github.com/sebaxakerhtc/rdpwrap.ini). The binaries are the official v1.6.2
  release only (`RdpWrapperRelease`, pinned SHA-256): downloaded by Install, or
  sent by the iPad to `rdpwrap/package`. Any other zip is ignored.
- Picture quality (`RdpServerQuality`) writes ImageQuality / GraphicsProfile
  policies and DWMFRAMEINTERVAL. The iPad's FreeRDP has no H.264, so the AVC
  policies are deliberately left alone.
- The API shapes are shared with `TitanDeck/Sources/Host` (iPad side). Change
  both together; bump `Protocol.ApiVersion` for breaking changes.
- Plain HTTP on the show network for now (isolated network, paired tokens).
- **sACN:** Titan sends sACN multicast only (no unicast; this rig doesn't use
  Art-Net). `SacnListener` binds 5568 with ReuseAddress and relies on Windows
  looping Titan's multicast back to local sockets. Not yet tested on a real
  Titan PC: if Titan holds 5568 exclusively, `/api/v1/dmx` reports the problem.
  Paired endpoints: `GET /api/v1/dmx` (summary) and
  `GET /api/v1/dmx/{universe}?start=&count=` (levels 0-255). Asking for a
  universe starts listening to it.
- **Desk link:** Titan's WebAPI on 4430 is its own user (own programmer and
  selection). `webapi.enabled` in Titan's settings file (Titan 19: `Titan\<version>\Titan.dll.config`,
  .NET 8; older: `Titan.exe.config`) starts a second WebAPI in
  Titan's UI that shares the operator's selection; TitanDeck uses port 4433 for
  it (4431 is ours) and the Host proxies `/titan/...` on 4434 to
  127.0.0.1:4433. `TitanUiConfig.ProxyAllows` is an allowlist and refuses
  anything with Patch in it: never let the iPad drive the operator's Patch
  menu. Enabling edits Titan's file, so it's PC-only (not in
  `Fixer.AllowedFromIPad`); only files that already contain `webapi.enabled`
  are touched, each backed up as `*.titandeck-backup` first. If a config already
  has it enabled on 4430 (Titan's normal WebAPI port), that's the desk's own
  WebAPI: the proxy targets 4430 (`TitanUiConfig.TargetPort`), the checklist
  says nothing to change, and `Enable` refuses to move it. Titan 19 runs the 4430
  WebAPI as a separate service (`WebAPI\<version>\WebAPIService.dll.config`,
  same keys): it's its own user and never sees the desk's selection, so only
  `Titan.dll.config` / `Titan.exe.config` are read (`IsSettingsFileName`).
- **Accounts with no password** (`RdpFacts.BlankPasswordsCanSignInRemotely`, checklist id
  `blankpassword`, always Ok since the Host can't see whether the account has a password):
  `AllowBlankPasswordSignIn` / `LimitBlankPasswordSignIn` set `LimitBlankPasswordUse` in
  `HKLM\SYSTEM\CurrentControlSet\Control\Lsa` to 0 / 1. PC only: 0 weakens every network sign-in.
- **Titan 19 WebAPI** (`WebApiServiceConfig`, checklist id `webapi19`): Titan 19.2's
  WebAPI service only takes the pre-19 calls TitanDeck uses with
  `webapi.pre19Compatibility` = true (19.2 release notes). `DeskLink` finds
  `WebAPIService.dll.config` alongside Titan's own settings files;
  `FixAction.EnableWebApiCompatibility` (PC only) backs it up, turns it on and
  restarts the Windows service whose ImagePath contains WebAPIService, if any.
- **Desk keys** (`Core/Titan/DeskKeys`, `DeskKeyQueue`, paired `POST /api/v1/desk/keys`,
  window long-polls `GET /local/desk/keys/wait`, `App/DeskTyper` SendInput with
  scan codes): the deck's keypad typed on the PC for Titan, which captures the
  keyboard. Only `DeskKeys.All` keys can be typed (never letters); refused when
  the window isn't polling or Titan isn't running; keys older than 2 s dropped.
  Keep `/desk/keys` instant: `WindowsProbe.IsTitanRunning` answers from its
  last look and refreshes in the background (walking every process took a
  while), and CLEAR (`TitanActions.RunClear`) answers as soon as the CITP clear
  is out, with no WebAPI clears after it, because the deck's keys after CLEAR
  wait for it. Titan clears the desk but doesn't send the empty selection back
  to a visualiser, so `CitpSession.ClearSelection` empties the Host's copy
  itself (0.15.2; before, TitanDeck kept showing the old selection).
  If Titan ever runs elevated, SendInput from the (non-elevated) window can't
  reach it (UIPI): the iPad falls back to typing over RDP. **Never Alt or any
  modifier.** Titan 19 ignores its Alt shortcuts from this PC's keyboard: 0.11
  typed Alt+C for Clear key by key and the desk's own Clear and wheels died;
  0.14.1-0.14.3 typed it as one burst and it didn't clear; 0.15.1's
  Alt+Right / Alt+Left / Alt+Down for RIG did nothing. CLEAR goes over CITP
  (below) since 0.15; RIG's FIX +1 / -1 type fixture numbers (TitanDeck 0.36).
- **FX (0.16, Test mode only; `FxRecipes`, `TitanActions.Fx.cs`):** Prism
  layers are Titan fixtures ("Layer 1", "Layer 2"; Dimmer, XY, Colour Adjust,
  Gobo: Folder / File / Playmode / Speed). `POST /api/v1/fx/layer` selects the
  layer fixture on the 4430 user and `SetControlValueByName` (into its
  programmer; the user agreed, with RELEASE = `ClearSelectedControls`).
  `POST /api/v1/fx/group` changes a pixel map's group (a pixel map follows
  its group): members read by `RecallGroupNumeric` + `GetAllSelectedFixtureIds`,
  then `ReplaceGroupOnHandle` (else `StoreGroupReplace`), read back to check;
  never emptied. `GET /api/v1/fx/probe` asks `GetControlIdFromName` for each
  name. Every FX action puts the 4430 user's selection back to the desk's
  (CITP). 409 in Show mode.
- **Groups (0.17; `TitanActions.Groups.cs`):** `GET /api/v1/groups/{titanId}/fixtures`
  recalls the group on the 4430 user (`Group/RecallGroup?handle_titanId=`),
  reads `GetAllSelectedFixtureIds`, and numbers them from CITP's FixtureList
  (`CitpService.UserNumbers`, assumes CITP fixture ids are Titan ids) or
  `/titan/handles/Fixtures` (`FxRecipes.FixtureNumbers`). Refuses if any
  fixture is unnumbered. Puts the 4430 selection back. Show mode too.
- **Prism media (0.18; `PrismLibrary` in Core/Prism, `PrismMediaFinder`):**
  `GET /api/v1/fx/media?folder=` for the iPad's Sync with Prism. Prism's
  project format is undocumented and unseen, so `PrismLibrary.Parse` reads
  any JSON or XML generically: the innermost lists whose entries point at
  media files (directly, in a nested object, or by a media id) are banks,
  preferring lists under a "bank" / "playlist" key; XML becomes objects
  (attributes, children as lists by name, "_text"). `FromFolder` reads a
  media folder (subfolder = bank, leading digits = numbers). The finder
  scans `Documents\Avolites\Prism`, AppData and ProgramData Avolites\Prism
  (exported banks in Playlists only as a last resort), newest file wins,
  and lists every candidate in the steps: ask the user for those steps when
  it picks the wrong file. Read only, any mode.
- **Cue fade checks must read the cue, not the editor** (0.15.1): Titan's
  `Playbacks.Editor.Times.*` read back whatever was just set even when the
  cue kept 0 (0.14-0.15 reported OK wrongly). `TitanActions.ReadFromCue` lets
  go of the cue (`CueSelection/Clear`), opens another playback
  (`TitanRecipes.OtherPlayback`) and then the cue again before reading.
- **Patch from CITP** (`Core/Citp/CitpPatch`, `PatchReader.UseCitp`): Titan's
  CAEX FixtureList (read only, asked for again after a FixtureModify) becomes the
  patch, so live levels need no report. Universe/channel are taken as 0-based
  only if a patched fixture sits at 0 (the spec doesn't say). Newest of CITP,
  the Reports folder and a picked report wins.
- **Pass-through** (port 4436, `DeskLink.PassThrough`): `/titan/...` to
  127.0.0.1:4430, logged as "TitanDeck - WebAPI" with Titan's error text. It's
  the same API the iPad could call directly, so nothing is refused; Patch calls
  are flagged in the log.
- **Network for TitanDeck** (`NetworkChoice`, Data\network.json, `GET/POST /local/network`;
  pure choice logic in `Core/Net/NetworkAdapters`): with an adapter picked, the
  `Advertiser` restarts mDNS on that NIC only, with only its IPv4 in the A
  records and in a TXT `address` (the iPad prefers it). Kestrel still listens on
  every adapter. A missing/unplugged choice falls back to every adapter.
  (Makaretu's MulticastService needs an IPv6 socket, so mDNS fails in IPv6-less
  Linux containers; fine on Windows.)
- **Test / Show mode** (`HostModeStore`, Data\mode.json, `GET/POST /local/mode`,
  also `mode` in `/status`): Show refuses `PatchReader.AskTitan` and the
  window hides it. CITP isn't a test tool: it carries on in both modes. New test-only
  tools must check `HostModeStore.IsShow` the same way.
- **CITP** (`Core/Citp`, `CitpService`; a full feature since Host 0.11.0,
  works in Test and Show, off by default, Data\citp.json; `GET/POST /local/citp`, paired `GET /api/v1/citp/selection`):
  Titan 19's WebAPI can't see the desk's selection, so the Host joins Titan as
  a CITP visualiser ("TitanDeck Host") and hears CAEX FixtureSelection (or FSEL).
  **Titan auto-applies patch changes from a visualiser, so the Host must never
  send FixtureList, FixtureModify, FixtureRemove, FixtureIdentify, FPTC
  (Ptch/UPtc/SPtc), FSEL Sele, SDMX, or a selection with any fixture in it.**
  `CitpAllowlist` only lets PINF PLoc/PNam, CAEX EnterShow, LeaveShow,
  FixtureListRequest and NACK out, plus (user's call, Host 0.15, for TitanDeck's
  CLEAR) an EMPTY selection: CAEX FixtureSelection and FSEL DeSe whose payload is
  exactly `00 00` (count 0). It can clear, never select. `CitpSession` sends
  everything through `CitpAllowlist.Check`. Never widen it further. Every request from Titan (FixtureListRequest,
  ShowSyncVersion, live view...) gets NACK reason 3 (refused), answering its
  RequestIndex. Titan's FixtureList maps its fixture ids to user numbers
  ("Channel"); without one the ids are taken as user numbers and flagged as a
  guess. Only peers on this PC can link (TCP from other PCs is refused); PLoc
  goes out with TTL 1. The multicast listener only runs while it's switched on,
  so it can't take 4809 from Titan by default. Byte
  layouts: CITP spec (bitbucket.org/lars_wernlund/citp) and Capture's CAEX
  spec G; tests in `CitpTests`. Every message goes to the Titan log as `CITP`.
  Titan opens several TCP links and retries refused ones, so up to
  `CitpService.MaxLinks` (8) are kept; the selection comes from the link that
  heard one last (`CitpSession.SelectionAt`). Only the first link logs fully;
  keep the log rate-limited (Titan reconnects many times a second).
- **No Fake Titan.** It was removed in Host 0.11.0 (and `fake_titan.py` with
  it) now testing is on a real Titan: don't bring it back. The installer only
  deletes its old firewall rule.
- **Titan log** (`TitanLog`): the desk link, pass-through and CITP write to it.
  Poll paths (`TitanLog.IsPoll`) are counted, and only listed again when their
  status changes. Window: `/local/titanlog`; iPad: `/api/v1/titanlog?after=`.
  Calls TitanDeck sends straight to the real WebAPI on 4430 don't pass through
  the Host, so they aren't logged yet (a pass-through port is the plan).
- **Patch report** (`PatchReader`): the patch comes from files Titan writes
  (Disk > Reports > Fixtures, in every user's Documents\Titan\Reports), never
  from Titan's Patch menu. Report columns aren't documented, so `TitanPatch`
  finds the user-number and address columns by name. The dimmer channel comes
  from the fixture's .d4 (`<Mode><Include><Attribute ID="Dimmer"
  ChannelOffset="12,13">`, 1-based, coarse then fine; `Master_Dimmer` in
  multi-cell modes; colour channels when the dimmer is virtual), checked
  against real Avolites files. DMX line N is taken as sACN universe N.
  Paired: `GET /api/v1/patch`. "Ask Titan" (`Reports/GenerateReport` on the
  4430 user) is experimental and logged.
- **Slate Book** (`Core/Slate`, `SlateService`; paired `GET /api/v1/slate`
  (`?summary=true` for just the slate showing), `/slate/day/{day}`,
  `/slate/match/{day}/{id}`, POST `/slate/take|new|letter|set|note`): read
  only, from `DmxUniverses`; it never talks to Titan. TAKE / NEW SLATE / a
  letter log the whole look (base64 per universe) and what changed since the
  line before, named by `PatchFixture.Attributes` (every .d4 attribute with a
  channel) or by address. `LookWatcher` logs a change once the output has been
  still for 3 s, leaving out channels that changed in 3 of the last 6 samples
  (effects). Nothing is logged until the day's first TAKE/NEW SLATE; at most
  `SlateBook.MaxEntries` lines a day. One file per local day, written via a
  temp file; the slate showing carries over in `state.json`.
- **Updates** (`HostUpdate`/`HostUpdater`): only releases tagged `host-v*` with a
  `TitanDeckHost-Setup-*.exe` asset under
  `https://github.com/thomasshepley/SLAPP/releases/download/host-v`, verified
  against the asset's `digest` (sha256) after download, and again by the window
  before it runs the installer with `/SILENT /UPDATE=1` (the installer reopens
  the window when it sees `/UPDATE=1`). Never loosen either check.
- Same house rules as the repo: regular hyphens, branch + PR, no secrets in git.

## Build, test

- Everything compiles on Linux/macOS too (`EnableWindowsTargeting`):
  `dotnet build TitanDeckHost.sln`, `dotnet test tests/Core.Tests`.
- The service runs on Linux for API smoke tests (Windows facts read as
  unknown): `dotnet build src/Service -p:RuntimeIdentifier= -p:SelfContained=false -o out`,
  then `dotnet out/TitanDeckHost.Service.dll`.
- CI: `.github/workflows/host.yml` tests on Ubuntu, builds the installer on
  Windows, and on `main` publishes the GitHub release `host-v<version>`.
