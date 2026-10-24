# TitanDeck changelog

Newest first. Versions are 0.MINOR.PATCH until TitanDeck is show-ready (1.0):
MINOR goes up for new features, PATCH for fixes. The TestFlight build number is
the GitHub Actions run that built it. The top entry is shown in the app
(Settings > About > What's New) and becomes TestFlight's "What to Test" notes,
so add an entry - and bump `MARKETING_VERSION` in `project.yml` to match -
with every change that goes to `main`.

## 0.10.0 - 2026-10-24 - Every DMX mode

- **DMX modes from the manufacturers' own charts:** over 5,000 modes across 179 fixtures (Astera, ARRI, Aputure and amaran, Nanlite, Nanlux, Godox/Knowled, Creamsource, Kino Flo, Litepanels, Quasar, DMG, ETC, Robe, Martin, Claypaky, Chauvet, GLP and more), transcribed from each maker's DMX chart or manual and checked so every footprint adds up.
- **Mode numbers and briefs:** modes show the maker's number and short description, like "Mode 89 · D CCT GM CRO RGB" on Astera or "P4 · ..." on Kino Flo, with a big number badge on the fixture page.
- **Every mode list:** open a fixture and tap Every mode to see them all with their channel counts. Tap one to see its chart.
- **Astera:** all of Astera's numbered modes for each product (165 on the Titan, Helios, Hyperion, AX1 and HydraPanel), plus the AX2 PixelBars, AX7, LunaBulb, SolaBulb and the Quik range.
- **Pixel and zone modes** show every cell, from a 16-pixel tube to a SkyPanel S360's 12 light engines.
- **More fixtures:** 270 in all, including ARRI SkyPanel X, Panalux Sonara, Aputure STORM and NOVA II, and live moving lights, with flicker data for each.
- The Companion loads its library in the background at launch, so opening it doesn't pause.
- Removed a few library entries for lights that don't exist.

## 0.9.0 - 2026-10-24 - Remote desktop picture quality

- **Picture quality presets** for the remote desktop: Best (wired or strong Wi-Fi: sharpest, 60 fps), Balanced (Windows' normal) and Weak signal (bad Wi-Fi on set: lowest bandwidth, plain Windows, stays responsive).
- Switch presets straight from the Remote screen's Menu, or fine-tune them in Settings > Remote desktop > Picture quality: Windows effects on the iPad, and image quality, graphics mode and frame rate on the PC.
- The PC's half is set through TitanDeck Host (needs Host 0.2). TitanDeck reconnects by itself to apply a change.
- **Send RDP Wrapper:** for a Titan PC with no internet, TitanDeck downloads the official RDP Wrapper, checks it, and hands it to the Host to install.

## 0.8.0 - 2026-10-24 - Gel book and FX Library

- **Gels:** the full swatch books, 1,136 filters across LEE, Rosco (E-Colour+, Roscolux, Cinegel) and GAM. Search by number or name and filter by range or type.
- **Gel details:** tap a swatch for its transmission, stops lost and mired shift, and the closest-looking gels in the other ranges.
- **Colour converter:** now shows the nearest gels to whatever colour you dial in.
- **FX Library:** keep your pixel-effect videos and bitmaps (fire, police, fireworks, lightning...) in one place, tagged and previewed, then send them to the PC for Prism through the file uploader.
- **Flicker:** real refresh-rate data where manufacturers publish it (ETC, Astera, Aputure Nova, Martin, Elation, ARRI HMI ballasts), plus their "flicker-free up to" claims.

## 0.7.0 - 2026-10-24 - Wi-Fi from UniFi

- **New Wi-Fi tab:** your UniFi network from the console itself. It uses a local UniFi admin login, so there's no API key and no internet needed.
- **This iPad:** which access point it's on, the channel, and its signal in dBm.
- **Channel map** for 2.4, 5 and 6 GHz: your access points against every neighbouring network they can hear, plus the quietest channels, with DFS ones flagged.
- **Every access point:** channel, width, transmit power, how busy each radio is, and how many clients it has. Weak clients are listed too.
- **RF scans:** see an AP's last RF environment scan, or run a new one (with a warning, as its clients drop off while it scans).
- Live spectral analysis still needs UniFi's own app and Ubiquiti's cloud.

## 0.6.0 - 2026-10-24 - Companion tools

- **Fixture library:** manufacturers in a tidy A-Z list. Tap one to see its fixtures, and drag the letter strip on the right to jump down the alphabet.
- **Colour:** a proper RGB <-> HSI converter. Enter either one with sliders or typed numbers, and get the other back live, plus RGB in % and hex.
- **Green / magenta in plain English:** "the light looks green, put 1/4 Minus Green (LEE 249) on it".
- **New Flicker tool** (replaces Camera): pick a fixture, set the frame rate and shutter, and see if it will flicker, with a frame-by-frame chart.
- Flicker fixes: safe shutter angles (hello 172.8°), safe frame rates, refresh-rate settings and dimmer levels.
- **Sun on a map:** tap to drop a pin, search a place or use your location, then scrub a time slider to watch the sun's direction swing round. Sunrise and sunset directions are drawn too.
- Removed gobo sync.

## 0.5.0 - 2026-10-24 - TitanDeck Host

- **Pair with TitanDeck Host,** the new Windows app for the Titan PC: Settings > TitanDeck Host finds the PC on the network by itself; type the 6-digit code from its window and you're paired.
- **PC health from the iPad:** see whether Remote Desktop will work, and press Fix for the common problems (Remote Desktop off or stuck, firewall, RDP Wrapper out of date after a Windows update).
- **Send newest rdpwrap.ini:** for a Titan PC with no internet, the iPad downloads the fix and hands it over.
- **Files both ways:** Send to PC goes through the Host (no shared folder needed), and anything put in To iPad on the PC shows up under From PC, ready to preview or share. The shared folder still works as a fallback.

## 0.4.2 - 2026-10-24 - Keypad readout

- **Keypad readout on the Remote screen:** what you type on the Stream Deck keypad (like 102@30) shows in the black band under the desktop. Press Enter and it turns green and slides across to the last commands on the right, which keep the last three.
- A command shows red if a key didn't reach Titan, so you know Titan's line might not match.
- The status pill in the top corner no longer shrinks to dots. Tap it any time for network details.

## 0.4.1 - 2026-10-24 - Beam fix

- Fixed a crash opening Companion > Beam & Photometry (and fixture pages with photometry): the falloff chart's log scale now has a safe range.
- The chart is left out, rather than crashing, if the output is set to 0.

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
