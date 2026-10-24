# TitanDeck changelog

Newest first. Versions are 0.MINOR.PATCH until TitanDeck is show-ready (1.0):
MINOR goes up for new features, PATCH for fixes. The TestFlight build number is
the GitHub Actions run that built it. The top entry is shown in the app
(Settings > About > What's New) and becomes TestFlight's "What to Test" notes,
so add an entry - and bump `MARKETING_VERSION` in `project.yml` to match -
with every change that goes to `main`.

## 0.4.2 - 2026-10-24 - Keypad readout

- **Keypad readout on the Remote screen:** what you type on the Stream Deck keypad (like 102@30) shows in the black band under the desktop. Press Enter and it turns green and slides across to the last commands on the right, which keep the last three.
- A command shows red if a key didn't reach Titan, so you know Titan's line might not match.
- The status pill in the top corner no longer shrinks to dots. Tap it any time for network details.

## 0.4.0 - 2026-10-24 - Send to PC

- **Send files to the Titan PC, AirDrop style:** the PC pulses when it's reachable; tap it to send. Add photos, files, or drag them in on iPad.
- **Share > TitanDeck** from Photos, Files, Mail or any app puts the file straight into the send queue.
- Files land in a shared folder on the PC, connected once in the Files app. Settings > File drop > Setup walks you through it - nothing to install on the PC.
- Never overwrites: a second copy is saved as "name (2)".

## 0.3.0 - 2026-10-24 - Companion

- **Companion tab:** the lighting companion, rebuilt natively. Fixture library with all 221 fixtures: search, filter by type or maker, specs, a colour-coded DMX chart for every mode, a distance slider with a falloff chart, and side-by-side compare.
- **On-set tools:** Beam & Photometry, Stops (follows each fixture's dimming curve), Power & Cable (distro gauge, cable derating), Colour & Gels, Camera (aperture, flicker, ND), Sun & Sync (golden and blue hour, gobo tempo), plus Units & Mains.
- **iPhone:** opens on the Companion. The Remote tab is off until you turn it on in Settings > Remote desktop.
- **What's New:** this list, in Settings > About, and shown once after each update.

## 0.2.0 - 2026-10-24 - Remote desktop menu and connection details

- **Menu button** next to the status pill while the remote desktop is live: Deck, Settings or Disconnect. The desktop stays connected in the background.
- **Connect on launch is off** by default (Settings > Remote desktop to turn it back on).
- **Connection details:** tap Wi-Fi/Ethernet in the status pill for the iPad's address, whether Titan and the PC are on the same network, reply times over the last minute, and on Wi-Fi the network name and access point (needs Location).

## 0.1.1 - 2026-10-24 - Remote desktop fix

- **Fixed:** remote desktop failing straight away with "A configuration error prevented a connection to be established".
- **Virtual Stream Deck** is now in TestFlight builds too (Settings > Show virtual Stream Deck).

## 0.1.0 - 2026-10-23 - First TestFlight build

- Stream Deck control of Titan: keypad (digits, @, Enter, Clear, Exit), intensity +/-, playbacks, hold-for-menu, live playback lights.
- Full-screen remote desktop of the Titan PC with touch control and automatic reconnect.
- Deck profile editor, export and import; soak-test connection log.
- iPhone on-screen deck, Siri and Shortcuts, Apple Watch GO button.
