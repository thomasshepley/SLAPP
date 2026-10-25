# TitanDeck Host changelog

The Windows companion to TitanDeck. Newest first. Versions are 0.MINOR.PATCH
until it's show-ready (1.0): MINOR for features, PATCH for fixes. Keep
`<Version>` in `Directory.Build.props` in step with the top entry
(ChangelogTests checks). Each version is published as a GitHub release
`host-v<version>` with the installer attached.

## 0.4.1 - 2026-10-25 - Reads the Windows build right

- **Fixed:** the Host read this PC's Remote Desktop build as "6.2.26100.9549" instead of "10.0.26100.9549" (Windows gives older-style version numbers to programs that don't ask for the real ones), so it said a perfectly good rdpwrap.ini didn't cover this PC, and refused one sent from TitanDeck. Remote desktop itself was never affected: RDP Wrapper reads the build itself.

## 0.4.0 - 2026-10-24 - Desk link

- **TitanDeck can follow the desk's selection:** Titan's normal WebAPI is a separate user and never sees what you select in Layouts or on the desk. Titan has a second, experimental WebAPI inside its own user interface that does. The checklist has a new line, "Desk selection for TitanDeck", with a Turn on button (on the PC only). It finds Titan's settings file, keeps a copy of it, turns the UI WebAPI on at port 4433 (4431 is the Host's) and asks you to restart Titan.
- **Desk link port 4434:** the Host passes TitanDeck's calls through to Titan's UI WebAPI, in case Titan only answers on the PC itself. It only passes the calls TitanDeck makes, and never anything to do with Patch, so the iPad can't open Patch on the desk. Firewall rule added (private networks).

## 0.3.0 - 2026-10-24 - Live levels from sACN

- **Hears Titan's sACN:** the Host listens to the sACN Titan sends (on the same PC, so no extra network setup) and keeps each universe's live levels. This is the groundwork for TitanDeck showing a fixture's real intensity, which Titan's WebAPI can't report.
- Follows the sACN rules: highest priority wins, preview data is ignored, and a source that stops is dropped after 2.5 s. Listens to universes 1-4 from the start, plus any Titan announces or TitanDeck asks for.
- Shares the sACN port, so it doesn't get in the way if Titan listens for sACN input too.

## 0.2.0 - 2026-10-24 - Picture quality and RDP Wrapper download

- **Remote desktop picture presets:** Best (wired or strong link: high quality, 60 fps), Balanced (Windows' normal) and Weak signal (bad Wi-Fi on set: lowest bandwidth). Set them in the Host window or from TitanDeck, which reconnects to apply them.
- **RDP Wrapper in one click:** Download & install fetches the official v1.6.2 release, checks its fingerprint, adds the Defender exclusion and installs it. No internet on the PC? TitanDeck can send it over instead. Any other copy is refused.

## 0.1.0 - 2026-10-24 - First version

- **One install for the Titan PC:** a background service (starts with Windows) and a dashboard in the system tray.
- **Remote Desktop checklist** in plain English, with one-click fixes: Remote Desktop allowed, the service running and listening, firewall rules, Private network, Titan running.
- **RDP Wrapper (Windows Home):** checks it after every Windows update and installs a newer rdpwrap.ini when the old one doesn't know the new Windows build (the "configuration error" problem). A recent rdpwrap.ini ships with the Host; the iPad can send a newer one. Adds the Windows Defender exclusion when you press the button. Can install RDP Wrapper from the official release zip.
- **Pairing:** a 6-digit code on the PC pairs an iPad or iPhone. Codes expire, work once and lock after wrong guesses.
- **Files both ways:** TitanDeck can send to Public Documents\TitanDeck\To PC; files put in To iPad are offered to the iPad.
- **Finds itself:** announces "_titandeck-host._tcp" on the show network so TitanDeck can find the PC.
