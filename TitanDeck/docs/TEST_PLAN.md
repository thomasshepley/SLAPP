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
- [ ] Close and reopen TitanDeck: it reconnects without being asked.
- [ ] Bonus security check: after one good connection, a different PC (or a
      reinstalled one) at that address is refused with a certificate message.
      Settings → **Forget saved PC certificates** clears it.

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
