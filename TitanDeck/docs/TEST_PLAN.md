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
have one, Fake Titan pretends to be Titan's WebAPI, so everything except the
remote desktop can be tested. **Best: on the Titan PC, built into TitanDeck
Host 0.5+**, so the desk link and live intensity work exactly as on the real
rig, and every call shows in the Host's Titan log.

On the Titan PC:

- [ ] Close Titan (they'd both want port 4430).
- [ ] Open TitanDeck Host from the tray, find the **Fake Titan** card, leave
      Desk and sACN ticked and press **Start**.
- [ ] Put the PC's IP in TitanDeck's **Titan PC address**.
- [ ] Press keys on the deck: each call appears in the **Titan log** card with
      Titan's answer, how long it took and the fake desk's state after it. Red
      rows are refused or unknown calls. **Copy** grabs the lot to send over.
- [ ] Desk link: leave **Settings > Desk link > Port** at **4434**. Type `3,4` in
      **Select on the desk** and press Select, as if you'd clicked them in
      Layouts. The deck should pop up the intensity keys and Currently Selected
      should say "3-4". **Clear** deselects.
- [ ] Live intensity: pair TitanDeck with the Host, nudge a fixture once from the
      deck, and the flash key shows its level. Fake Titan sends each fixture as
      Red, Green, Blue, Dimmer from (n-1)*4+1 on universe 1.
- [ ] Slow replies (ms) 700 makes every reply slow, so keys should flash red.
- [ ] Stop Fake Titan before opening the real Titan again.

Mac only, with `Tools/fake_titan.py` (no Host, so no live intensity or log
window; it prints to the Terminal instead):

```bash
cd ~/Developer/SLAPP && git pull
python3 TitanDeck/Tools/fake_titan.py
```

- [ ] If macOS asks whether Python may accept incoming
      connections: **Allow** (Private networks).
- [ ] It prints the computer's IP. Put that in TitanDeck's **Titan PC address**.
- [ ] Running it on the Mac: type the **PC's** IP in the remote desktop's own
      address box, or it will try the Mac.
- [ ] Every key press shows up in the Terminal, with the command line, selected
      fixtures, their levels and the live playbacks after it. Unknown calls
      show in red with a 404.
- [ ] Extras:
  - `--latency 700` makes every reply slow, so keys should flash red.
  - `--no-user-numbers` leaves user numbers out of the playback list, so
    Settings should show its "can't light keys" explanation.
- [ ] Desk link on the Mac: Fake Titan is also "the desk" on port 4433 (on by
      default). There's no Host, so set **Settings > Desk link > Port** to
      **4433**. Status says Linked. Then pretend to click fixtures in Layouts,
      in a second Terminal window:

      ```bash
      curl "http://localhost:4430/fake/desk-select?fixtures=3,4"   # select 3 and 4
      curl "http://localhost:4430/fake/desk-select?fixtures="      # clear
      ```

      The deck should pop up the intensity keys, Currently Selected should say
      "3-4", and the deck's keys now act on the desk's selection (the Terminal
      shows "desk selected 3,4" and the levels). If you changed the port to
      4433 on the Mac, set it back to 4434 for the real rig.

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
- [ ] **Menu**: hold it for **a second** and the main menu appears with one
      key per layout (Keypad, Quick Keys, Colour, Playbacks, Layouts). Tap one
      to open it.
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

## 5b. Key styles (emoji, palette, pressed look)

- [ ] Settings > Deck profile > tap a key > Icon > Emoji: pick 🔥 and clear the
      label. The emoji fills the key on the preview and on the Stream Deck.
- [ ] Colour > Custom colour: pick an orange, tap +. It joins the swatches, and
      shows on another key's palette too. Long-press it > Remove from palette.
- [ ] When pressed: turn it on, red, label "LIVE". While held: the key turns
      red only while your finger is on it. Until pressed again: one press
      turns it red, the next turns it back. While the playback is live (Go key):
      red while the cue runs on Titan.
- [ ] A key with no pressed look turns the held colour (amber to start with,
      Settings > Deck > Held key colour) for as long as it's held (0.17).
- [ ] Hold the flash key when Titan can't answer: it flashes red, then goes back
      to the held colour until you let go.

## 5b2. Loading screen and patch report (0.18)

- [ ] Open TitanDeck: the loading screen checks Titan, the Stream Deck, remote
      desktop, the Host, sACN and the desk link; each row ticks or explains.
      Continue appears when they're done. The deck shows the TitanDeck logo
      with a shine moving across it; its keys do nothing until Continue.
- [ ] Turn the iPad round with rotation lock off: TitanDeck stays landscape.
- [ ] Leave the iPad alone longer than its auto-lock time: it stays on.
- [ ] Host 0.6 with Fake Titan running (or a real patch report): Settings >
      Desk link > Use Titan's patch report on. Select a fixture: the flash key
      shows its level straight away, no nudge first. Settings shows "from the
      patch report".
- [ ] Bottom middle: keypad <-> Quick Keys (and back from CCT). Bottom right:
      Quick Keys <-> CCT. Nothing selected: the keypad's Menu key reads
      Nothing Selected, a tap does nothing, a hold opens the menu.

## 5b3. Test and Show modes (0.19, Host 0.7)

- [ ] Settings > Mode > Show: the confirmation says "All test features will
      be disabled if you confirm this". After it: no Test section, no Show
      virtual Stream Deck, no Recent calls or soak log, no Find addresses with
      Patch; no TEST badge on the Remote screen.
- [ ] Back to Test: all of those return and the TEST badge is back.
- [ ] Host window > Mode > Show (same confirmation): Fake Titan stops and its
      card goes; Ask Titan goes; badge says SHOW. Restart the PC: still Show.
- [ ] iPad in Show, Host in Test: the loading screen warns about the Host.
      iPad in Show with Fake Titan answering: it warns that it's Fake Titan.

## 5c. Deck pages (0.13)

- [ ] Every page: keys with nothing on them are black on the Stream Deck, not
      left over from the page before.
- [ ] Menu key (0.17): on the keypad it reads Quick Keys and a tap goes to
      Quick Keys; there, Return to Keypad (bottom right) taps back. On any
      other page it shows the page's name and a tap goes to the keypad. Hold
      it (or Return to Keypad) for a second: the menu of all pages.
- [ ] Keypad: 1 0 2 Enter. The deck shows Quick Keys: the nudges, the flash key
      (middle column 3rd row), CCT (middle column 4th row) and Return to Keypad
      bottom right. 1 @ 5 Enter does NOT switch.
- [ ] Return to Keypad, type something, then tap Menu: back on Quick Keys.
- [ ] Hold Menu, pick Quick Keys: the same keys, flash and CCT included.
- [ ] Quick Keys > CCT > INTENSITY (bottom middle): straight back to Quick
      Keys.
- [ ] Remote screen, top left: "Currently Selected: 102" after 1 0 2 Enter, and
      101 after 1 0 1 @ 5 0 Enter. Is 101 really still selected on Titan?
- [ ] Clear on the selection page: back to the keypad, Currently Selected gone,
      and Titan's programmer empty. With digits typed, the first Clear only
      empties the line.
- [ ] CLEAR and ENTER each fit on one line.
- [ ] In Titan, record global colour palettes named 2700K, 3200K, 5600K. On the
      deck, select a fixture, CCT, 3200K: the fixture goes to 3200. A preset
      with no palette flashes red (the log says which palette is missing).
- [ ] Layouts page: keys show your workspace names; each brings its workspace
      up on the Titan screen. Does the remote desktop follow?
- [ ] Select on the desk, then nudge intensity on the deck: does it act on the
      desk's selection? (The API may have its own programmer - note what happens.)
- [ ] Numbers on the keypad are big and readable from arm's length.

## 5d. Playbacks page and flash (0.14)

- [ ] Playbacks page: three GO keys reading GO 1 / GO 2 / GO 3, Fade In and
      Fade Out rows under them, Connect Cue below.
- [ ] Connect Cue: the GOs go red (PICK). Tap one: the deck lists Titan pages
      that have playbacks, then the cues on the page you pick, live ones green.
      Pick one: the GO shows its legend. With more pages than keys, MORE pages on.
- [ ] Connect Cue again: Unassign under a filled GO empties it. Done goes back.
- [ ] GO fires the cue (the key lights while it's live). A GO or fade key with
      nothing on it just flashes red. DONE fits on one line.
- [ ] Fade In: the picker offers 0, 0.1, 0.2, 0.25, 0.3, 0.5, 1, 3 and 5 s. Pick 5s. Open the cue in Titan: is its fade in now 5 s? Same for
      Fade Out. **Experimental:** if Titan's time doesn't change, note what the
      log says (the request body format isn't documented).
- [ ] Settings > Deck > Flash fades: add 1-99, 5 s.
- [ ] 1 0 2 Enter, hold HOLD FOR 0%: the fixture snaps to 0 and comes back on
      release.
- [ ] 4 5 Enter, hold: it fades down over 5 s, release fades it back over 5 s.
      Does it come back to where it was, or does release drop it to the
      playbacks' level? (Release is Titan's "release programmer", so a level
      set in the programmer before the flash is lost - note it.)
- [ ] Flash with a fixture selected on the desk (not on the deck): what happens?

## 5e. Desk link and live intensity (0.16, needs Host 0.4)

Before you start: on the Titan PC, back up Titan's .exe.config yourself too.

- [ ] TitanDeck Host > Desk selection for TitanDeck says Off. Turn on. Restart
      Titan. It says On. (Note which .exe.config it changed - tell Claude.)
- [ ] On the PC: `netstat -an | findstr 4433`. Is it 127.0.0.1 or 0.0.0.0?
- [ ] TitanDeck Settings > Desk link: Status says Linked.
- [ ] Select a fixture in a Layout on the desk: within a second the deck
      shows the intensity keys and the Remote screen says Currently Selected.
      Select 10 fixtures: it says "101-110". Clear on the desk: keys go away.
- [ ] Same from the Fixtures window, and from the desk keypad (101 Enter).
- [ ] Does Titan's UI feel any slower with the desk link on? (It polls
      about 3 times a second.)
- [ ] Linked: deck +5% changes the fixture you selected on the desk, and
      the desk's programmer shows it. Clear on the desk clears it.
- [ ] Deck keypad while linked: does 101 @ 50 show on the desk's command line?
- [ ] Live intensity: with the fixture selected, nudge +5% once. The flash
      key changes to its level (e.g. "55%") and follows a fader or cue live.
- [ ] Hold HOLD FOR 0% (no fade rule): fixture goes out, comes back exactly.
- [ ] Settings > Desk link > Find addresses with Patch ON: select a new
      fixture. Does Titan's Patch window open or stop the programmer
      anywhere (desk or deck)? Turn it off again if it does.
- [ ] Unplug the PC's network for 5 s: Status says not answering, the deck
      still works (on its own WebAPI user), and it re-links when plugged back.

## 5e2. Titan 19 calls and the Titan log (TitanDeck 0.21, Host 0.9)

- [ ] TitanDeck Host's checklist: "Titan 19 WebAPI calls" says Problem.
      Turn on (on the PC). It says what it restarted; if it says restart
      Titan, do that.
- [ ] TitanDeck Settings > Connection: turn on Through TitanDeck Host.
      Test connection still shows Titan's version.
- [ ] Keypad 1 @ 5 0 Enter, Clear, Exit, a fade time, the Layouts page:
      each works, and each call shows in the Host's Titan log
      ("TitanDeck - WebAPI"). Anything red: Copy the log and send it over.
- [ ] Playbacks page: GO fires the cue (key lights), GO again releases it.
- [ ] Magic Keyboard on the remote desktop: type in a Titan legend box or
      Notepad. Arrows, Backspace held (repeats), Esc, F-keys, Shift-click,
      Cmd-C / Cmd-V (as Ctrl-C / Ctrl-V). Switch Settings > Remote desktop >
      Keyboard's Command key to Windows key: Cmd opens the Start menu.
      Swipe home mid-keypress: nothing stays held on the PC.
- [ ] Keypad types on the desk (0.22, Host 0.10, Host window open on the PC):
      Settings > Desk link > Keypad types on the desk is on. Type 1 0 1
      Enter on the deck: the desk's command line shows it and fixture 101 is
      selected on the desk. @ 5 0 Enter: it goes to 50% on the desk. +10%
      on the deck moves it too. Clear, Exit. Each key shows in the Host's
      Titan log as Desk keys. Close the Host window (tray > Close): the
      keypad still works over the remote desktop if that's connected.
- [ ] Selection at a glance (0.23): select several fixtures. The Remote
      screen's top bar shows their numbers then "+N more"; tap it for all of
      them. The chevron on the right folds the Menu / keyboard / connection
      controls away and back (green dot = OK). On the deck, Quick Keys' row
      above Clear shows the numbers; tap it for the next ones. The keypad's
      Menu key shows e.g. "901 +18".
- [ ] Intensity on the desk (0.23, keypad types on the desk, live level known
      - nudge once if the flash key doesn't show a %): +10% / -10% move the
      fixture by 10% on the desk's own programmer; Hold for 0% takes it out
      and puts it back.
- [ ] On-screen keyboard (0.22): the keyboard button (top right) shows the
      iPad keyboard with Esc / Tab / Ctrl / Alt / arrows / Del above it. Type
      in a Titan legend box: letters, capitals, numbers, £ @ " #, Backspace,
      Return. Ctrl then A selects all. Tapping the desktop doesn't hide it;
      the button or the keyboard's hide key does.
- [ ] No Windows password: TitanDeck Host > Accounts with no password >
      Allow (on the PC). Leave the password blank in TitanDeck's Remote
      desktop settings and Connect: Titan's screen appears.

## 5f. Desk selection over CITP (Titan 19: TitanDeck 0.21, Host 0.9, experimental)

Titan 19's WebAPI can't see the desk's selection, so this goes the way
Capture does. **Use a copy of your show** (Disk > Save As first), and save
the CITP lines from the Titan log (Copy) for Claude whatever happens.

- [ ] TitanDeck Host in Test mode: the **Follow selection via CITP
      (experimental)** card is there and says Off. Switch on (read the warning).
- [ ] The card says "Waiting for Titan to connect". Does Titan appear in its
      list (LightingConsole "Titan" ..., on this PC)? Note the TCP port.
- [ ] In Titan, look for TitanDeck Host as a visualiser (probably Patch >
      Active Fixtures, or the CITP / visualiser connections). Connect it the
      way you'd connect Capture. Note exactly what Titan shows and asks.
      **Say no to anything that offers to send or sync the patch.**
- [ ] The card says Linked with Titan, and how many fixtures it knows.
      Does that match the show?
- [ ] Select a fixture in a Layout: does the card's "Selected" show its
      number? Select 10, clear, select from the keypad - same each time?
- [ ] With TitanDeck's desk link on: the deck shows the intensity keys,
      Settings > Desk link says Linked over CITP, and +5% moves the fixture
      you selected on the desk.
- [ ] Afterwards, check the patch didn't change at all (same addresses,
      no new or missing fixtures). If anything changed, tell Claude straight away.
- [ ] Switch the Host to Show: the card disappears and CITP stops.


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

## 6a. Keypad Log (Remote screen)

- [ ] Connect the remote desktop, Stream Deck on the Keypad page. The black band
      says KEYPAD LOG. Type 102@30: it appears bottom left, no blinking cursor.
- [ ] Enter: the line goes green, then slides to the right. Do 3 more: only the
      last 3 stay, newest on the right and biggest.
- [ ] Clear or Exit throws away the line being typed.
- [ ] Switch the deck to another page: the Keypad Log goes once nothing's typed.
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
- [ ] DMX modes: open an Astera Titan Tube. The picker reads "Mode 89 · D CCT
      GM CRO RGB" style titles, the yellow badge shows the number, and
      **Every mode** lists all 165 with their footprints. Tap Mode 195: the
      chart shows all 16 cells (Cell 16 at the end).
- [ ] SkyPanel S360-C: Mode 25 shows LE1 to LE12 then Fan at 193. A Kino Flo
      Celeb reads "P1 · ..." and an ARRI mode shows ARRI's description under
      its name.
- [ ] Pixel maps: open a Creamsource Vortex8 and pick an 8-zone mode. The panel
      appears with its zones coloured and numbered. Tap zone 3: its channels
      are listed and the DMX chart below dims everything else. Switch to a
      4-zone mode: the zones regroup. Try a Titan Tube 16-pixel mode and a MAC
      Aura PXL (Beam / Aura switch).
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

## 6d+. Picture quality (needs Host 0.2)

- [ ] Install TitanDeck Host 0.2 over 0.1. Its window has a Remote desktop
      picture card; press Weak signal, then Best.
- [ ] TitanDeck: Settings > Remote desktop > Picture quality. Pick each preset
      and Apply: a live session reconnects. "On the PC" says the PC matches.
- [ ] Remote screen > Menu > Picture > Weak signal: it reconnects; the desktop
      is plainer and softer but snappy on a poor link. Best: sharp, smooth.
- [ ] Without the Host paired, presets still change the iPad's half and say so.
- [ ] Windows Home without RDP Wrapper: the Host checklist offers Download &
      install (online), or TitanDeck > PC health > Send RDP Wrapper (offline),
      then Install on the PC.

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
