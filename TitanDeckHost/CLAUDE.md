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
│                  with fixes), SafeFileName, API messages (Api/Messages.cs)
├── src/Service/   net8.0-windows Windows service (LocalSystem): Kestrel API on
│                  0.0.0.0:4431 (paired iPad) and 127.0.0.1:4432 (the Host window),
│                  WindowsProbe (reads the PC), Fixer (applies fixes), Advertiser (mDNS)
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
  github.com/sebaxakerhtc/rdpwrap.ini); the binaries come from the official
  release zip the user provides.
- The API shapes are shared with `TitanDeck/Sources/Host` (iPad side). Change
  both together; bump `Protocol.ApiVersion` for breaking changes.
- Plain HTTP on the show network for now (isolated network, paired tokens).
- Same house rules as the repo: regular hyphens, branch + PR, no secrets in git.

## Build, test

- Everything compiles on Linux/macOS too (`EnableWindowsTargeting`):
  `dotnet build TitanDeckHost.sln`, `dotnet test tests/Core.Tests`.
- The service runs on Linux for API smoke tests (Windows facts read as
  unknown): `dotnet build src/Service -p:RuntimeIdentifier= -p:SelfContained=false -o out`,
  then `dotnet out/TitanDeckHost.Service.dll`.
- CI: `.github/workflows/host.yml` tests on Ubuntu, builds the installer on
  Windows, and on `main` publishes the GitHub release `host-v<version>`.
