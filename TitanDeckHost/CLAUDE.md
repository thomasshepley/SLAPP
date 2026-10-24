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
│                  sACN (Sacn/: E1.31 packet parser + DmxUniverses merge store)
├── src/Service/   net8.0-windows Windows service (LocalSystem): Kestrel API on
│                  0.0.0.0:4431 (paired iPad) and 127.0.0.1:4432 (the Host window),
│                  WindowsProbe (reads the PC), Fixer (applies fixes), Advertiser (mDNS),
│                  SacnListener (joins sACN multicast on every adapter, port shared)
├── src/App/       net8.0-windows WPF tray app + dashboard; talks only to 127.0.0.1:4432
├── tests/Core.Tests/  xunit
└── installer/     Inno Setup script
```

## Rules

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
- Same house rules as the repo: regular hyphens, branch + PR, no secrets in git.

## Build, test

- Everything compiles on Linux/macOS too (`EnableWindowsTargeting`):
  `dotnet build TitanDeckHost.sln`, `dotnet test tests/Core.Tests`.
- The service runs on Linux for API smoke tests (Windows facts read as
  unknown): `dotnet build src/Service -p:RuntimeIdentifier= -p:SelfContained=false -o out`,
  then `dotnet out/TitanDeckHost.Service.dll`.
- CI: `.github/workflows/host.yml` tests on Ubuntu, builds the installer on
  Windows, and on `main` publishes the GitHub release `host-v<version>`.
