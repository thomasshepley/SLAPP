# TitanDeck changelog

Newest first. Versions are 0.MINOR.PATCH until TitanDeck is show-ready (1.0):
MINOR goes up for new features, PATCH for fixes. The TestFlight build number is
the GitHub Actions run that built it. The top entry is shown in the app
(Settings > About > What's New) and becomes TestFlight's "What to Test" notes,
so add an entry - and bump `MARKETING_VERSION` in `project.yml` to match -
with every change that goes to `main`.

## 0.20.0 - 2026-10-26 - Change the Host's address

- **Change Address** (Settings > TitanDeck Host): when the PC has more than one network and TitanDeck found the wrong one, point it at the right address without pairing again. Type it, or pick the PC from the ones found on the network.
- **Titan and the remote desktop move too:** Change Address has "Titan uses this address too" and "Remote desktop uses this address too" (both on), so all three switch to the show network's address in one go.
- With TitanDeck Host 0.8 set to one network adapter, pairing and Change Address use the address the Host announces for that adapter.

## 0.19.0 - 2026-10-25 - Test and Show modes

- **Test or Show:** Settings > Mode. Test (as now) has the test tools and an orange TEST badge on the Remote screen, the loading screen and Settings. Show asks first ("All test features will be disabled if you confirm this"), then hides the test tools: the test fire buttons, the virtual Stream Deck, Recent calls and the soak test log (it still records in the background), and turns the experimental "Find addresses with Patch" off. Switch back any time.
- **In Show mode the loading screen warns** if the "Titan" answering is really Fake Titan, or if TitanDeck Host (0.7) is still in Test mode.

## 0.18.0 - 2026-10-25 - Loading screen, patch report, tidier deck

- **Loading screen:** TitanDeck opens with a health check before Continue: Titan answering, the Stream Deck, the PC's remote desktop, TitanDeck Host, sACN levels and the desk link, each ticked or explained. Meanwhile the Stream Deck shows the TitanDeck logo with a shine sweeping across it, so you can see the deck's alive.
- **Live level without nudging first:** Settings > Desk link > Use Titan's patch report (off to start with). With TitanDeck Host 0.6 reading Titan's patch report, the flash key knows each fixture's dimmer channel straight away. A nudge still corrects it if the report and the sACN disagree.
- **Bottom row makes sense between pages:** bottom middle always swaps keypad and Quick Keys (Menu on the keypad, Return to Keypad on Quick Keys and CCT). Bottom right swaps Quick Keys and the colour keys (CCT on Quick Keys, INTENSITY on the colour keys).
- **Nothing Selected:** with nothing selected, the keypad's Menu key says so and a tap does nothing; holding it still opens the menu.
- **Landscape only on iPad,** even with rotation lock off, and the iPad never auto-locks while TitanDeck is open.

## 0.17.0 - 2026-10-25 - Quick Keys

- **Quick Keys:** the Intensity page is now Quick Keys, and it always has the nudges, the hold-for-0% flash and CCT on it, however you get there (a selection, the Menu key or the menu of pages).
- **Menu swaps keypad and Quick Keys:** on the keypad the Menu key reads Quick Keys and a tap goes there. On Quick Keys, Return to Keypad (bottom right) taps back. On any other page a tap goes to the keypad. So after Return to Keypad, one tap gets you back to your fixture's keys.
- **Hold for the menu is a second now** (was 2 s), on Menu and on Return to Keypad.
- **Held keys stay lit:** a key turns the held colour (amber to start with) for the whole time your finger is on it, so you can see the flash key is held. Change it in Settings > Deck > Held key colour. A key's own pressed look still wins.
- **Fixed:** if Titan didn't answer while you held a key, the red flash wiped the held look until you let go. It now goes back to the held colour.
- **Fake Titan is in TitanDeck Host 0.5:** the testing notes now use the Host window's Fake Titan card, with its log of every call. With Host 0.5, fade times set from the deck through the desk link arrive properly (they arrived empty before).

## 0.16.2 - 2026-10-25 - Pairing fixes

- **Fixed:** picking a discovered PC to pair with filled in its address with "%en0" on the end (the iPad's Wi-Fi), so it didn't work until you deleted that. Addresses are cleaned up now, typed or found.
- **Fixed:** after pairing worked, the pairing screen opened again.
- With TitanDeck Host 0.4.1, sending an rdpwrap.ini no longer says it doesn't cover the PC's build when it does.

## 0.16.1 - 2026-10-24 - Quicker back to intensity, plainer GOs

- **Back from CCT:** the colour temperature keys have an INTENSITY key (bottom middle) that goes straight back to the intensity keys.
- **GO keys are just GO keys:** a GO with no cue on it flashes red instead of opening a page. Put cues on with Connect Cue. Fade keys with no cue flash red too.
- **Fade times:** the fade picker now offers 0, 0.1, 0.2, 0.25, 0.3, 0.5, 1, 3 and 5 s.
- **Fixed:** DONE in Connect Cue (and any short word close to the key's width) no longer breaks onto two lines.

## 0.16.0 - 2026-10-24 - Desk link and live intensity

- **Follow the desk's selection:** select fixtures in Layouts, the Fixtures window or on the desk and the deck brings up its intensity keys, just like typing "101 Enter". Currently Selected on the Remote screen shows them ("101-110"). Clear the selection on the desk and the keys go away.
- **The deck acts on the desk's own programmer** while it's linked, so the intensity keys change what you selected on the desk.
- **Set up once on the Titan PC:** TitanDeck Host (0.4) > Desk selection for TitanDeck > Turn on, then restart Titan. This uses Titan's experimental UI WebAPI; if it ever stops answering, the deck quietly goes back to its own WebAPI user.
- **Live intensity on the flash key:** it reads the selected fixture's real level from Titan's sACN, through TitanDeck Host (0.3). The first time you nudge or flash a fixture from the deck, TitanDeck learns which channels are its intensity; after that the key shows "60%".
- **Flash puts it back exactly:** a flash with no fade now uses Titan's own Flash Out and Clear Flash, so the fixture returns to precisely where it was.
- **Everything can be switched off** in Settings > Desk link: following the desk, live intensity, and the experimental "Find addresses with Patch" (off to start with; it never touches your desk's Patch window).

## 0.15.0 - 2026-10-24 - Currently Selected, and tidier keys

- **Currently Selected:** the Remote screen shows the fixture in the programmer in its top left corner, styled like the Menu button and status pill, after "101 Enter" or "101 @ 50 Enter" (Titan keeps 101 selected after setting its level).
- **Keypad Log:** the keypad readout under the remote desktop is now called Keypad Log, without the "Type on the keypad" hint or the blinking cursor.
- **Clear goes back to the keypad:** a Clear that empties the programmer takes the deck back to the keypad and clears Currently Selected. The first Clear, with something typed, still just empties the line.
- **Selection keys moved:** CCT is in the middle column, 4th row, with Hold for 0% above it. Return to Keypad is on the bottom right with a return arrow.
- **Fixed:** CLEAR and ENTER no longer break onto two lines. Labels shrink until every word fits on one line.

## 0.14.0 - 2026-10-24 - Cues on the deck, and a flash key

- **Playbacks page:** three GO keys, with Fade In and Fade Out under each and Connect Cue at the bottom.
- **Connect Cue:** the GOs go red. Tap one and the deck lists Titan's playback pages, then the cues on the page you pick (live ones in green). Pick a cue and the GO shows its name. Connect Cue again offers Unassign under each GO; Done goes back.
- **Fade In / Fade Out:** pick a time from 0 to 60 s and the deck sets that cue's fade in Titan. This one is experimental: Titan doesn't document how the time is sent, so check the cue on the console.
- **Hold for 0%:** after a selection ("45 Enter") there's a flash key. Hold it to take the fixture to 0, let go to bring it back.
- **Flash fades:** Settings > Deck > Flash fades sets a fade for fixture ranges, e.g. 1-99 fade over 5 s. Fixtures outside every range snap.
- Titan's API can't read a fixture's level, so the flash key can't show it, and letting go releases the fixture from the programmer.

## 0.13.0 - 2026-10-24 - Colour, Layouts, and a smarter deck

- **Blank keys stay blank:** keys with nothing on them now go black on the Stream Deck instead of showing the last page's key.
- **Menu shows the page name:** the Menu key reads Keypad, Intensity, Colour... Tap it for the next page; hold it for 2 s for the list of all pages.
- **After a selection:** type a fixture number and Enter (no @) and the deck swaps to the intensity keys, with Return to Keypad. A CCT key there opens the colour temperatures.
- **Colour page:** 2700, 3200, 4000, 4500, 5600, 6000, 6500, 7500 and 10000K, each key in its own colour. Each recalls the Titan colour palette with that temperature in its name, so make global palettes called 2700K, 3200K... once and every fixture type uses its own CCT channel.
- **Layouts page:** twelve keys that bring up Titan's saved workspaces (window layouts). Keys left without a label show the workspace's name from Titan.
- **Bigger numbers:** single digits and @ fill the key in big rounded type, and the keypad's number keys are black. Short labels are bigger too, and pale keys get black text.
- The default deck picks these up by itself if you haven't edited it.

## 0.12.0 - 2026-10-24 - Emoji keys, your own colours, and pressed looks

- **Emoji on keys:** a key's icon can now be an emoji as well as an SF Symbol (Settings > Deck profile > tap a key > Icon > Emoji). On its own, with no label, the emoji fills the key.
- **Save your colours:** pick any custom colour and tap + to keep it in the palette with the built-in swatches, ready for every key. Long-press one of yours to remove it.
- **A second look when pressed:** give a key a different colour, label and icon or emoji, shown while it's held, until it's pressed again (on/off keys), or while its playback is live on Titan. Preview it in the editor with Normal / Pressed.
- Symbol-only keys now draw the symbol bigger, centred on the key.
- **Fixed:** tapping anywhere in the key editor's Label box now brings up the keyboard, not just on the word "Label".

## 0.11.0 - 2026-10-24 - Pixel maps

- **Pixel maps:** pixel and zone modes now show the fixture's face with every cell coloured and numbered, laid out the way the manufacturer's manual draws it. 33 fixtures so far: SkyPanels, Creamsource Vortex, Astera tubes, bars and HydraPanel, PavoTubes, amaran PT, INFINIBAR, MT Pro, GLP X4 Bar and X4 L, JDC1, B-EYE K20, MAC Aura PXL, Spiider, Maverick Storm 1 Wash and Rogue R2X Wash.
- **Vortex Zone Orientation:** Bars and Split modes show both the vertical and horizontal layout, matching the setting on the fixture.
- **Tap a cell** to see which DMX channels drive it. The DMX chart below dims everything else, so you can see at a glance where cell 7 lives.
- Switch modes and the map regroups: 8 zones become 4 or 2, 16 pixels become 8 or 4, just as the fixture does.
- Fixtures with more than one set of pixels (beam and aura, plate and beam) get a switch between them.
- Where a manual doesn't say which end cell 1 is, the map says so, so you know to check it on the rig.
- **Fixed:** FX Library > Add > From Photos now opens the Photos picker. It did nothing before.

## 0.10.1 - 2026-10-24 - Fixture library tidy-up

- Removed 19 library entries for lights that don't exist, so you won't patch a fixture that isn't real: Nanlux Evoke 300, 300B, 600, 600B and 900, Dyno 300C and 1200B, TK-200B, TK-300, TK-450B and TK-600; Nanlite Forza 300C; Knowled M400D and M400Bi; Aputure LS 300x II, LS 1200d and LS 600c (only the Pro versions exist); ARRI SkyPanel X61; Quasar Q50.
- The real models are all still there, with their DMX modes and flicker data.
- TestFlight builds are flowing again: 0.8, 0.9 and 0.10 never reached TestFlight because Apple's signing-certificate limit was full. This build brings all of them, including the Astera mode numbers and every DMX mode from the makers' charts.

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
