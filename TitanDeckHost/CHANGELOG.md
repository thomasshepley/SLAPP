# TitanDeck Host changelog

The Windows companion to TitanDeck. Newest first. Versions are 0.MINOR.PATCH
until it's show-ready (1.0): MINOR for features, PATCH for fixes. Keep
`<Version>` in `Directory.Build.props` in step with the top entry
(ChangelogTests checks). Each version is published as a GitHub release
`host-v<version>` with the installer attached.

## 0.1.0 - 2026-10-24 - First version

- **One install for the Titan PC:** a background service (starts with Windows) and a dashboard in the system tray.
- **Remote Desktop checklist** in plain English, with one-click fixes: Remote Desktop allowed, the service running and listening, firewall rules, Private network, Titan running.
- **RDP Wrapper (Windows Home):** checks it after every Windows update and installs a newer rdpwrap.ini when the old one doesn't know the new Windows build (the "configuration error" problem). A recent rdpwrap.ini ships with the Host; the iPad can send a newer one. Adds the Windows Defender exclusion when you press the button. Can install RDP Wrapper from the official release zip.
- **Pairing:** a 6-digit code on the PC pairs an iPad or iPhone. Codes expire, work once and lock after wrong guesses.
- **Files both ways:** TitanDeck can send to Public Documents\TitanDeck\To PC; files put in To iPad are offered to the iPad.
- **Finds itself:** announces "_titandeck-host._tcp" on the show network so TitanDeck can find the PC.
