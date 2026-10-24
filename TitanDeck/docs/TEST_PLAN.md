# TitanDeck test plan - home setup

Goal: every feature exercised once against a real Titan PC, on home Wi-Fi,
with the iPad and the on-screen (fake) Stream Deck. Tick things off as you go,
and note anything odd. The **Recent calls** list in Settings shows every
request to Titan with its result and time, which is the first place to look.

Things nobody has been able to check yet, because they need your PC, are
marked **(unconfirmed)**. If one doesn't work, that's useful, not a failure:
tell me what happened and I'll fix it.

## 1. PC (once)

- [ ] Titan running, with a show loaded and a few fixtures patched.
- [ ] Titan **User Settings → WebAPI** on.
- [ ] RDP enabled: RDP Wrapper installed, all green in RDPConf (see the build
      plan's "PC side" section). A Windows user **with a password**.
- [ ] Windows Firewall, **Private** profile: allow TCP **3389** (RDP) and TCP
      **4430** (Titan WebAPI). Set the home Wi-Fi to **Private** in Windows
      network settings, or the rules won't apply.
- [ ] Note the PC's IP: `ipconfig` → IPv4 Address, e.g. 192.168.1.20.
- [ ] Quick check from any browser on the same Wi-Fi:
      `http://<PC-IP>:4430/titan/get/System/SoftwareVersion` shows Titan's version.

## 1b. No AvoKey? Use Fake Titan

Titan won't run without an AvoKey (or another Avolites USB device). Until you
have one, `Tools/fake_titan.py` pretends to be Titan's WebAPI, so everything
except the remote desktop can be tested. Run it on the Mac (same Wi-Fi as the
iPad):

```bash
cd ~/Developer/SLAPP && git pull
python3 TitanDeck/Tools/fake_titan.py
```

- [ ] If macOS asks whether Python may accept incoming connections: **Allow**.
- [ ] It prints the Mac's IP. Put that in TitanDeck's **Titan PC address**.
- [ ] Remote desktop: type the **PC's** IP in its own address box, or it will
      try the Mac.
- [ ] Every key press shows up in the Terminal, with the command line, selected
      fixtures, their levels and the live playbacks after it. Unknown calls
      show in red with a 404.
- [ ] Extras:
  - `--latency 700` makes every reply slow, so keys should flash red.
  - `--no-user-numbers` leaves user numbers out of the playback list, so
    Settings should show its "can't light keys" explanation.

Fake Titan only checks the app's side. The **(unconfirmed)** items below still
need the real Titan.

## 2. Mac: build onto the iPad

TestFlight replaces this section: install TitanDeck from the TestFlight app and
skip to step 3. Use Xcode only for quick fix-and-retry loops.

```bash
cd ~/Developer/SLAPP
git checkout main && git pull
cd TitanDeck
FreeRDP/fetch.sh          # downloads the remote-desktop library (first time ~1 min)
xcodegen generate
open TitanDeck.xcodeproj
```

- [ ] Pick your **iPad** (plugged in, Developer Mode on) → **⌘R**.
- [ ] If you ran an earlier build, go to **Settings → Stream Deck → Reset to
      default profile** to get the new keypad layout.
- [ ] iPad: when asked, **Allow** "find devices on your local network". If you
      tap Don't Allow, the orange "Local Network off" warning appears, with a
      button to fix it.

## 3. Titan connection

- [ ] Settings → Titan PC address → **Test connection** → shows the Titan version.
- [ ] **Fire test playback 1** and **Release playback 1**: playback 1 goes on/off
      in Titan. Times in **Recent calls** (expect well under 100 ms on Wi-Fi).

## 4. Deck: keypad, intensity, menu

Use the **Deck** tab, or Settings → **Show virtual Stream Deck**
(15-key model). The virtual deck is drawn in landscape like the real hardware, so
with portrait mounting its labels are sideways. That's correct for a deck on
its side. The Deck tab shows the portrait layout upright.

The Deck tab shows **Titan's command line** live at the top, so you can see
each key land.

**Real Stream Deck:**
- [ ] Install **Elgato Stream Deck Connect** from the App Store.
- [ ] Open it and follow its steps to switch on the driver in iPad Settings.
- [ ] Plug the deck into the iPad's USB-C (or the hub) with TitanDeck open.
- [ ] Settings → Stream Deck shows its name. Pick how it's mounted under
      **Deck mounted**, so the labels read upright.
- [ ] If it stays dark, Settings says why (driver off, or a missing entitlement).

- [ ] Keypad digits and **@** appear on the command line, e.g. `1 @ 5`.
      **(unconfirmed: whether @ needs spaces around it)**
- [ ] **ENTER** runs the line (e.g. selects fixture 1 at 50%) and clears it.
      **(unconfirmed: Enter is "read the line, RunCommand, start a new one" -
      check it behaves like the console's Enter)**
- [ ] **CLEAR** with something typed: clears the line. Pressed again with an
      empty line: clears the programmer.
- [ ] **EXIT** leaves a Titan menu.
- [ ] **Menu**: a tap does nothing. Hold **2 seconds** and the main menu
      appears with one key per layout (Keypad, Intensity, Playbacks). Tap one to
      open it.
- [ ] Intensity page: select some fixtures, then **+1 / +5 / +10 / -1 / -5 / -10**.
      **(unconfirmed: the API's units - if +5 jumps straight to full, it wants
      0-1 not percent; tell me and it's a one-line fix)**
- [ ] Playbacks page: GO / REL 1-6.
- [ ] A key pointed at something that fails flashes **red**.
- [ ] Settings → Stream Deck → **Deck mounted**: switch between the two
      portrait options and landscape; the virtual deck's images turn to match.
- [ ] **Light keys for live playbacks** (Settings): with Playbacks showing,
      fire playback 1 from Titan itself. GO 1 / REL 1 should get a white frame
      and bar. **(unconfirmed: whether Titan reports playback user numbers -
      Settings says "Working" or explains)**

## 5. Deck editor

- [ ] Settings → **Edit deck profile**: change a key's label, colour, icon and
      action; Save; it shows on the deck straight away.
- [ ] Add, duplicate, rename, move and delete a page. The main menu updates itself.
- [ ] **Export profile** (AirDrop it to the Mac or save to Files), then
      **Import profile** brings it back.

## 6. Remote desktop

- [ ] Settings → Remote desktop: PC address (blank uses the Titan address),
      Windows user and password, then **Connect**.
- [ ] Titan's screen fills the iPad. The connection pill (top right) shows
      Titan ms · RDP Live · Wi-Fi.
- [ ] Touch: tap = click; press and drag a Titan fader; two-finger tap = right
      click; two-finger drag = scroll; three-finger long press = Settings.
- [ ] Pull the PC's network for ~20 s, then put it back: a dimmed "Reconnecting"
      banner appears, then it comes back by itself.
- [ ] **Menu** (top right, next to the status pill) → Deck / Settings takes you
      out of the desktop; the Remote tab brings it back still connected.
      Menu → Disconnect ends it.
- [ ] Close and reopen TitanDeck: it does **not** connect by itself (unless
      Settings → "Connect when TitanDeck opens" is on).
- [ ] Tap the **Wi-Fi / Ethernet** part of the status pill: the connection panel
      shows the iPad's address, whether Titan and the PC are on the same network,
      and reply times. On Wi-Fi, **Allow Location** to see the network name and
      access point (iOS's rule). Signal strength isn't available to apps.
- [ ] Bonus security check: after one good connection, a different PC (or a
      reinstalled one) at that address is refused with a certificate message.
      Settings → **Forget saved PC certificates** clears it.

## 6a. Keypad readout (Remote screen)

- [ ] Connect the remote desktop, Stream Deck on the Keypad page. Type 102@30:
      it appears bottom left in the black band, with a blinking cursor.
- [ ] Enter: the line goes green, then slides to the right. Do 3 more: only the
      last 3 stay, newest on the right and biggest.
- [ ] Clear or Exit throws away the line being typed.
- [ ] Switch the deck to another page: the readout goes once nothing's typed.
- [ ] Unplug the Titan network and type: the line turns red.
- [ ] Tap the status pill top right: it opens network details and never
      shrinks to dots.

## 6b. Companion

- [ ] **Companion** tab: the sidebar (iPad) lists Fixtures and the tools.
- [ ] Fixtures: a list of manufacturers, A-Z. Tap one to open its fixtures.
      Drag down the letter strip on the right: a big letter follows your
      finger and the list jumps. Searching opens every matching maker.
- [ ] Fixtures: search "skypanel", filter by type or maker, open one: specs,
      DMX modes chart (switch modes), the distance slider and falloff chart.
      **Compare** with another fixture.
- [ ] From a fixture, **Open in** Beam / Stops / Power pre-fills that tool.
- [ ] Beam & Photometry, Stops (move the DMX slider, watch the curve chart),
      Power & Cable (add fixtures, change distro, temperature): numbers look sane.
- [ ] Colour & Gels: Enter RGB, move the sliders or type numbers: HSI updates
      live. Switch to Enter HSI: same colour, now set by hue/sat/intensity.
      Hex in and out. Green / magenta: a + Duv says "looks green, use Minus Green".
- [ ] Flicker: pick an HMI, set 24 fps 180°: "Will flicker", and the fix says
      172.8°. Tap 172.8°: "No flicker". Pick an LED, dim it to 10% at 240 fps.
- [ ] Sun: tap the map to move the pin; search a place; the location button.
      Scrub the time slider: the sun line on the map swings round. Sunrise /
      Golden / Noon / Sunset buttons jump the slider.
- [ ] Gels: the swatch book scrolls smoothly with all ranges. Search "201",
      filter Roscolux, filter CTO. Tap a colour: transmission, stops, "Looks
      like" from other ranges. The colour converter shows the nearest gels.
- [ ] FX Library: add a video and a picture from Photos, and one from Files.
      Each gets a thumbnail, size/fps/length and a guessed category. Open one:
      it plays; rename it, change the category. Select two, Send: the Send to
      PC sheet opens with both queued.
- [ ] Flicker: pick an ETC Source Four LED Series 2: refresh setting choices
      appear. Pick an ARRI SkyPanel: the note says high speed mode.
- [ ] Units & Mains: switch to imperial; distances show in ft and lux in fc.
- [ ] iPhone: no Remote tab and it opens on Companion. Settings → Remote desktop
      → "Show the Remote tab" brings it back.

## 6c. Send files to the PC

- [ ] On the PC: share a folder (e.g. Desktop\TitanDeck Drop) with your Windows
      user, Read/Write. Private network: file sharing on.
- [ ] iPad Files app → ⋯ → Connect to Server → `smb://<PC-IP>` → sign in.
- [ ] TitanDeck: Settings → File drop → Send Files to PC → Setup → Choose
      Folder → pick that share.
- [ ] The PC icon pulses when it's reachable. Add a few photos and a file,
      tap the PC: the ring fills, each file ticks, and they appear on the PC.
      Sending the same file again saves "name (2)".
- [ ] From Photos (or Files, Mail): Share → TitanDeck: the Send sheet opens
      with that file queued.
- [ ] iPad: drag a file from Files (Split View) onto the Send sheet.
- [ ] Turn the PC's network off: the status says "PC not reachable" and a send
      fails with a clear message, then works again once it's back.

## 6d. TitanDeck Host

- [ ] Download `TitanDeckHost-Setup-<version>.exe` from the newest `host-v`
      release on GitHub, copy it to the PC and run it (SmartScreen: More info >
      Run anyway). The Host window opens.
- [ ] Every check is green, or has a Fix button that turns it green.
- [ ] Host window: Show a pairing code. TitanDeck: Settings > TitanDeck Host >
      Pair. The PC shows up by name; tap it, type the code, Pair.
- [ ] A wrong code says so; 5 wrong codes kill that code.
- [ ] Settings > TitanDeck Host > the PC: the same checks as the PC window.
      Stop "Remote Desktop Services" on the PC, then Start it from the iPad.
- [ ] Send Newest rdpwrap.ini (with the iPad online): it says it applied, or
      that the newest ini doesn't cover the PC's build yet.
- [ ] Send to PC: the subtitle says TitanDeck Host. Files land in
      Public Documents\TitanDeck\To PC.
- [ ] Put a file in To iPad on the PC: it appears under From PC on the Send
      sheet. Get it, preview it, share it. On the PC it moves to To iPad\Sent.
- [ ] Stop the Host service: the sheet falls back to the shared folder (if set
      up), and Settings shows the Host as not answering.
- [ ] Remove the iPad in the Host window: TitanDeck notices and asks to pair again.

## 6e. Wi-Fi (UniFi)

- [ ] In UniFi: Settings > Admins & Users > Create New Admin, Restrict to Local
      Access Only, role View Only (Site Admin if you want RF scans).
- [ ] TitanDeck: Wi-Fi tab > Set Up UniFi: the console's IP, that username and
      password. Connect: it says Connected (no internet needed).
- [ ] The header counts your APs and Wi-Fi clients. "This iPad" shows the AP
      you're on, its channel and your signal - walk away from it and watch.
- [ ] Channels: each band shows our APs as blue blocks and neighbours in grey.
      Quietest channels lists a few, with DFS marked on 5 GHz.
- [ ] Each AP shows channel, width, utilisation and clients per radio.
- [ ] Show Scan on an AP that's been scanned in UniFi: the per-channel chart.
- [ ] **Not during a show:** RF Scan on a spare AP. It warns first, its clients
      drop for a few minutes, then the chart appears.
- [ ] Wrong password: a clear message. Change the console's certificate (or
      point at a different console at the same address): refused until you
      Forget the Console's Certificate.

## 7. Soak log

- [ ] Settings → **Soak test log** lists the drop-out you caused in step 6,
      with its length.
- [ ] **Export log as CSV** opens in Numbers / Excel.

## 8. iPhone, Watch, Siri (if you have time)

- [ ] Run on an iPhone (pick it in Xcode). It opens on the **Deck** tab, with
      big keys upright and a wider layout sideways.
- [ ] Shortcuts app → new shortcut → TitanDeck → **Fire Titan Playback** →
      playback 1 → run. "Hey Siri, fire a playback in TitanDeck" also works.
- [ ] Apple Watch (paired to that iPhone): install TitanDeck from the Watch app.
      Turn the crown to pick a playback, then **hold GO**: the ring fills and it
      fires. The result shows "via iPhone" with a time. Double tap (Series 9 /
      Ultra 2) fires too.

## Report back

For anything that misbehaves: what you pressed, what happened, and the line
from **Recent calls** (or a screenshot). Unconfirmed items that turn out wrong
are usually a one-line change.
