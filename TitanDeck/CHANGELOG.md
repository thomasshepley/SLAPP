# TitanDeck changelog

Newest first. Versions are 0.MINOR.PATCH until TitanDeck is show-ready (1.0):
MINOR goes up for new features, PATCH for fixes. The TestFlight build number is
the GitHub Actions run that built it. The top entry is shown in the app
(Settings > About > What's New) and becomes TestFlight's "What to Test" notes,
so add an entry - and bump `MARKETING_VERSION` in `project.yml` to match -
with every change that goes to `main`.

## 0.37.0 - 2026-10-29 - FX: Prism video from the deck (Test mode)

- **FX on the main menu (Test mode only for now):** FIRE, CANDLE, LIGHTNING, POLICE, FIREWORKS and TV, each with your versions from the FX tab. Pick one, then LAYER 1 or LAYER 2, and it goes onto that Prism layer (its Folder and File in Titan).
- **Each layer's page:** the clip (press it to pick another), BRIGHT, SPEED, CONTRAST and SAT (each a 0-100% picker, like MASTERS), GO and STOP for the layer's pixel map playback, FIXTURES, and RELEASE.
- **FIXTURES:** select fixtures on the desk, then USE SEL (the layer is just those), ADD or REMOVE. Your Titan groups whose names start with FXZone are one-press zones underneath ("FXZone Bar" shows as Bar). It changes the group the layer's pixel map uses, and TitanDeck Host checks it took.
- **The FX tab:** the FX Library has moved out of the Companion into its own tab. Give an effect a Fire / Candle / Lightning / Police / Fireworks / TV category and its Prism Folder and File, and it's on the deck. **Prism Setup** in the FX tab is where each layer's Prism fixture, pixel map group and pixel map playback go, and **Check the Prism fixture** shows which control names Titan has.
- The deck's FX changes are held in Titan's WebAPI user's programmer, not the desk's: they aren't recorded into your cues, and they hold the layer until RELEASE (or RELEASE ALL on the FX page).
- Needs TitanDeck Host 0.16.

## 0.36.0 - 2026-10-28 - RIG by fixture number, master levels from Titan

- **RIG works on the desk:** the Alt shortcuts in 0.35 did nothing on Titan 19, so FIX +1 and FIX -1 now type the next fixture of your selection by number ("12 Enter"), and the desk shows just that one selected. The new **ALL** key under them types your whole selection back ("10 THRU 20 AND 25 Enter"). Select something new on the desk and FIX +1 starts on that instead.
- **HI LIGHT works again:** it's back on Titan's WebAPI, as in 0.33, which follows the desk's selection, so it highlights the fixture FIX +1 / -1 is on.
- **MASTERS shows each master's level from Titan** as soon as the page opens, not just after you've set one from the deck. If Titan won't give a level, Settings > Recent events says why.
- **After CLEAR the deck shows nothing selected** (with TitanDeck Host 0.15.2: Titan doesn't send the cleared selection back, so the Host now empties its copy itself).

## 0.35.0 - 2026-10-28 - RIG steps the desk's own selection, flash fades on the desk

- **Fixed: flash fades snapped.** With the keypad typing on the desk (Titan 19), hold-for-0% typed "@ 0 Enter" straight away and ignored the fade time set for the fixture (Settings > Deck). Titan's keyboard has no fade time, so the level is now typed in steps over the fade, about five a second ("@ 80", "@ 60"... "@ 0"), and back up the same way when you let go. Let go mid-fade and it fades back up from where it got to.

- **RIG's FIX +1, FIX -1 and HI LIGHT now work on the desk itself**, not just Titan's WebAPI user: they're typed on the Titan PC as Titan's own shortcuts (Alt+Right, Alt+Left and Alt+Down), so the desk steps through its selection and shows the fixture it's on, as its own Next, Prev and Highlight do. Needs TitanDeck Host 0.15.1; with an older Host they work as before.
- They're the only Alt shortcuts TitanDeck types, each as one quick burst with Alt let go straight after. If the desk's own buttons ever act oddly afterwards, say so and they go back to the WebAPI.

## 0.34.0 - 2026-10-28 - Snappier keys, the current CCT, grand masters on MASTERS

- **Fixed: keypad and intensity keys sometimes reached the desk 3-15 seconds late.** Three things added up:
  - **Keys after CLEAR waited for it,** and a CLEAR that didn't take could keep them waiting for many seconds. With TitanDeck Host 0.15 CLEAR answers within about a second. Keys still wait for CLEAR, so it can never clear what you've just selected.
  - **Keys shared their connections to the PC** with slow Host calls (PC status, cue fades, files) and could wait for a free one. Keys now have their own.
  - **Each key waited for the one before to reach the PC.** Now everything pressed while one lot is on its way goes over together in the next, so typing fast never builds up a queue.
- **The CCT keys show the current colour temperature:** on the colour temperature page the current one says NOW, and the CCT key on Quick Keys carries it ("CCT 3200K"). It's the CCT palette Titan shows as active for the selection when Titan says, else the last one applied from the deck for this selection; a new selection starts blank until one of those is known.
- CLEAR on Titan 19 needs TitanDeck Host 0.15, which clears the desk's selection over CITP.
- **Fixed: MASTERS said "No masters on page 60" with a grand master there.** A grand master isn't a playback, so it wasn't in the playback list the page was built from. MASTERS now asks Titan for page 60 itself (and if that comes back empty, looks through every handle Titan has for page 60), and sets a level with Titan's own master call first (Masters.SetMaster), then the group and playback calls as before.
- Opening MASTERS puts what Titan has on page 60 in Settings > Recent events (each fader's legend, handle type and id), so if one's still missing, that line says why.

## 0.33.1 - 2026-10-28 - Titan keeps working when the Host is down

- **Fixed: no commands reached Titan while TitanDeck Host was down.** With Settings > Through TitanDeck Host on, every call went via the Host, so with the Host stopped (as after a failed update) nothing worked at all. Now, when the Host doesn't answer, calls go straight to Titan's WebAPI instead (and keep doing so for a few seconds before trying the Host again), so GO, intensity and the rest carry on.

- **When the keypad can't be typed on the desk, the key goes red and says why** (TitanDeck Host's window isn't running on the PC, Titan isn't running, the Host can't be reached...), in Settings > Recent calls and Recent events. Before, it quietly sent the key to Titan's WebAPI instead, which on Titan 19 is a separate user, so nothing showed on the desk and the keypad just seemed dead.
- Settings > Desk link > Keypad types on the desk, switched off, still sends the keypad to the WebAPI as before.

## 0.33.0 - 2026-10-28 - Rig and Masters on the deck

- **RIG on the main menu** (hold Menu): FIX -1, HI LIGHT and FIX +1 across the top, like the desk's Prev, Highlight and Next, for checking a rig fixture by fixture. Select the fixtures first; HI LIGHT lights up while it's on. They're also in the key editor, for any page.
- **MASTERS on the main menu:** your group masters on Titan's playback page 60, faders 1 to 10, each key showing the master's name and level. Press one for its level picker, laid out like the keypad: 0%, 10%, 20% up to 100%, the current level lit. Pick one and it's set, and you're back on the masters.
- The level shown is Titan's own when Titan reports it, otherwise the level last set from the deck ("-" until then).
- On Titan 19 these go through Titan's WebAPI, which is its own user: HI LIGHT and FIX +1/-1 step through the selection TitanDeck mirrors from the desk, so the desk's own screen doesn't show the step.

## 0.32.0 - 2026-10-28 - Cue fades and CLEAR done by TitanDeck Host

- **Cue fades and CLEAR are now done by TitanDeck Host (0.14) on the Titan PC** when the iPad is paired with it. The Host tries each way it knows, checks it worked (the time read back from the cue, the desk's selection over CITP) and logs every call in its Titan log. The answer, worked or not, shows here in Recent events.
- **Quicker fixes:** a better way of doing either now only needs a Host update (the Update button in TitanDeck Host, a couple of minutes), not a new TitanDeck through TestFlight.
- Without the Host (or with an older one), the deck does them itself as before.

## 0.31.1 - 2026-10-28 - CLEAR on Titan 19, fade times checked on the cue

- **Fixed: CLEAR saying "the desk link isn't up" on Titan 19.** Titan 19 follows the desk over CITP, which only listens, so there's no desk link to send the Clear down. CLEAR now asks Titan to clear the selection for every user, the desk's included (the selection only, never a programmer). TitanDeck then checks over CITP that the desk's selection really went, and if it didn't, the key goes red and says so.
- **Fade times: no more "OK" when the cue didn't change.** 0.31.0 could report a fade as set when Titan's editor took the time but the cue kept 0. TitanDeck now opens the cue the way the desk's Edit Times does (Titan's FillTimes for the playback), and after setting the time it opens the cue again and reads it back. It only counts as set if the cue really has the new time; otherwise the key goes red and the message says what Titan's editor showed against what the cue still has.
- When a fade does work, Settings > Recent events says which way it was set.

## 0.31.0 - 2026-10-27 - CLEAR on the desk, fade times through the editor

- **Fixed: CLEAR on the deck doing nothing on the desk.** Since 0.29 it cleared the selection of the WebAPI's own separate user, not the desk's. It now goes through the desk link and uses Titan's own "clear the selection" call (the desk's first Clear), so the desk's selection clears and every programmer stays as it is. If the desk link isn't up, the key goes red and says so.
- **Fade times, the way Titan's macros set them:** the playback is now loaded into Titan's editor before its cue 1 is selected, and the time is sent typed as a time (as macros write `time:3`). Without the editor step Titan had no cue to change, which is why every try failed or did nothing. Fades go through the WebAPI's own editor, so the editor on the desk isn't touched.
- If a fade still fails, the message also says which playback Titan's editor had loaded.

## 0.30.0 - 2026-10-27 - Remote bar button fixed

- **Fixed: the Remote screen's top-left button not opening the menu while connected.** With fixtures selected, the selection strip took the whole bar and squeezed Menu, the keyboard and the connection pill to nothing. They now always keep their room and the selection gets what's left. The bar also keeps clear of iPadOS's window controls in the top-left corner, and the whole button takes the tap.

## 0.29.0 - 2026-10-27 - Fade times in Titan 19's shape, Clear clears the selection

- **Fade times on Titan 19:** Titan keeps a cue's time as {TimeType, TimeValue "00:00:00", TotalSeconds...}. TitanDeck now sends it back in exactly that shape with the new time ("00:00:02.5") and the kind of time left as it was. Before, it wrongly changed TimeType as well, and Titan's SetProperty route errors on cue times, so neither worked. A plain-text SetProperty is tried too, and each try is checked by reading the time back.
- **CLEAR on the deck clears the selection only** (as the desk's first Clear does), and no longer clears every programmer as it has since 0.26. Anything typed on the desk is still backed out first.
- If a fade still can't be set, the message lists every way TitanDeck tried and what Titan said to each, so one screenshot shows the whole story.

## 0.28.0 - 2026-10-27 - Remote bar tidy, level on the flash key

- **Remote screen:** the button that folds the top bar's controls away is now at the very left, where TEST was. The controls open out from it, and TEST and the selection follow.
- **The flash key shows the level:** as well as Titan's live level (from sACN, with the patch from Titan over CITP), it now shows the level TitanDeck last typed on the desk for the selection ("@ 50", a nudge), so it isn't blank before the live reading arrives.

## 0.27.0 - 2026-10-27 - Slate Book

- **Slate Book: the look per slate and take, logged for you.** With TitanDeck Host 0.13, the Host keeps a record of the whole of Titan's output for every slate and take, UK style (a slate per setup, letters for pickups, no I or O), with Day/Night, FX and the time.
- **On the deck:** hold Menu, then SLATES. The Slate page shows the slate and take, and has NEW SLATE (next slate, take 1), TAKE +, LETTER (112 → 112A), DAY/NIGHT and FX. Each press logs the look on stage.
- **Changes log themselves:** when you merge a tweak, once the lights have been still for a few seconds it's logged under the current take, in plain words ("101 Dimmer 60 → 45%"), using Titan's patch to name fixtures and attributes. A running effect isn't logged.
- **Slates tab:** the day's slates, newest first, each take with what changed during it. Notes on any line, earlier days from the calendar, the slate or take put right by hand, and a typed slate number (hold New Slate).
- **Match:** pick any line and see what's different on stage now, biggest first. Great for getting back to a look for pickups.
- Nothing is sent to Titan: the Slate Book only listens. Recalling a look as a Titan cue (playback page 1) comes next.

## 0.26.0 - 2026-10-26 - Clear and +10% on the desk, fixed

- **Fixed: the desk's own Clear and wheels stopped working** after the deck's Clear. TitanDeck typed Alt+C (Titan's Clear shortcut) on the PC, and a held Alt is the likely culprit. The deck never types Alt (or any modifier) now: Clear backs out anything typed with Exit, then clears every programmer, the desk's included, through Titan's WebAPI (as the console's Clear all programmers). If the desk still acts oddly after updating, press and let go of Alt on the PC's keyboard once.
- **+10% is your level plus 10:** with Keypad types on the desk, the +/- keys type "@ level Enter" on the desk, taking the selected fixtures' current level and adding (or taking off) the nudge: 40% and +10 is 50%. The current level comes from Titan's live output (sACN through TitanDeck Host), with Titan's patch now coming straight from Titan over CITP (Host 0.12), so no patch report is needed. A level set from the deck's keypad ("101 @ 50") counts too.
- **Hold for 0% on the desk:** it takes the selected fixtures to 0 and back to their level, typed on the desk, now TitanDeck knows the level from Titan's patch over CITP. Before, with no patch report, it quietly went to the WebAPI's separate programmer and nothing happened.
- If TitanDeck doesn't know the level yet, the +/- keys and Hold for 0% flash red and say why, instead of going to the WebAPI's separate programmer (which is what gave odd levels or nothing at all).
- Settings > Desk link: "Use Titan's patch" is on by default.

## 0.25.0 - 2026-10-26 - A clearer Wi-Fi channel map

- **Wi-Fi channel map redrawn:** neighbouring networks are grey hills (taller is louder, with -50/-70/-90 dBm guides) and the loudest are named where there's room. Our access points' channels are shaded in each AP's colour, and every radio gets its own row underneath with its name, channel and width, so two APs on the same or nearby channels no longer write over each other. Channel numbers along the bottom thin out to what fits (1/6/11 and the start of each 5 GHz block first).
- **Overlap warning:** if two of our APs share airtime, it says which, under the map.
- **RF scan chart:** bars sit at each channel's real place in the band, with this AP's channel shaded, interference in red over the Wi-Fi busy share, labels that don't collide, and the quietest channel called out.

## 0.24.0 - 2026-10-26 - THRU on the keypad

- **THRU on the deck's keypad:** while nothing is selected, the keypad's Clear key becomes THRU (Titan's Thro), so "1 THRU 10 Enter" selects 1 to 10, typed on the desk like the rest of the keypad. As soon as something is selected, Clear comes back. The deck knows a typed range is selected, so Quick Keys comes up and the selection strip shows it.
- THRU can also go on any key in the key editor (Keypad Thru).

## 0.23.0 - 2026-10-26 - Selection at a glance, intensity on the desk

- **What's selected, across the top of the Remote screen:** every fixture number that fits ("901, 933-936, 940...") then "+N more", and a tap lists them all. The keyboard, Menu and connection controls fold away behind one button on the right (a dot on it shows the connection is OK) to give the selection the room; tap it to bring them back.
- **And on the Stream Deck:** Quick Keys has a selection strip (the row above Clear) showing the selected fixture numbers, "+N more" when they don't fit, and a tap shows the next ones. The keypad's Menu key shows the first of them too ("901 +18").
- **Intensity and Hold for 0% on the desk:** with Keypad types on the desk, the +/- keys and Hold for 0% now type "@ level Enter" on the desk too, worked out from the fixture's live level, so they act on the desk's programmer where the selection is (they'd been going to the WebAPI's separate one). Before the live level is known they work as before. All the selected fixtures go to the same level.
- **Fixed: +10% jumping about 60%.** Titan's intensity wheel speeds up when turned fast, so a big nudge in one go overshot; it's now "turned" slowly enough to stay in step.
- **Fade times on Titan 19, again:** TitanDeck now sets them the way Titan's own macros do (a number of seconds), checks Titan really took the new time when it can read it back, and never sends a guessed format that Titan could quietly take as 0.
- **Clear on the desk:** TitanDeck Host 0.11.0 types Alt+C (Titan's Clear) holding Alt down first, as a hand would; sent all at once, Titan could miss the Alt.
- **Desk selection over CITP works in Show mode:** with TitanDeck Host 0.11.0 it's a full feature, no longer Test-only. The loading screen's Fake Titan warning is gone with Fake Titan.

## 0.22.0 - 2026-10-26 - On-screen keyboard on the remote desktop

- **Keyboard button** (top right of the remote desktop, next to Menu): shows and hides the iPad's on-screen keyboard, and whatever you type goes to the Titan PC. Letters, numbers, space, Return, Tab and Backspace go as real keys; everything else (£, @, é...) types the right character whatever the PC's keyboard layout.
- **A row of extra keys** above it: Esc, Tab, Ctrl, Alt, the arrows and Del. Ctrl and Alt latch: tap Ctrl, then C, for Ctrl-C.
- Hide it with the button or the keyboard's own hide key. A Magic Keyboard still types key by key as before.
- **Fixed: intensity nudges were tiny.** Titan's intensity nudge is its encoder wheel (4096 steps from 0 to full), not a percentage, so +10% was moving about 0.25%. Each key now sends the right number of wheel steps.
- **The keypad types on the desk:** Settings > Desk link > Keypad types on the desk (on). The deck's keypad (numbers, @, Enter, Clear, Exit) is typed on the Titan PC as if on its keyboard, so it lands on the desk's own command line and what you select shows on the desk, not just in the WebAPI's separate programmer. It goes through TitanDeck Host 0.10 (its window open on the PC), or the remote desktop if that's connected; otherwise the keypad works as before. The deck's own WebAPI user selects the same fixtures, so the intensity, flash and colour keys still act on them, and Clear clears both.
- **Fixed: fade times on Titan 19.** Setting a cue's fade in or out from the deck failed with "could not be converted to AcwTimeSpan": Titan 19 wants a time in its own JSON format, not a plain number. TitanDeck now reads the cue's fade time first and writes the new one in the same format (and tries the likely formats if Titan doesn't say). If it still fails, the error in Settings > Recent calls shows how Titan reads the time, so it can be matched exactly.
- **Fixed: Clear on Titan 19.** Clearing the programmer used the old (pre-19) name for Titan's call, which Titan 19.2 refuses; it now uses the current one (Programmer Editor Clear All), which every Titan with the WebAPI has.
- **Following the desk's selection over CITP:** the deck's own WebAPI user now clears its selection before selecting the desk's fixtures (selecting adds to what's there), and clears it when the desk selects nothing.
- **Remote desktop with no Windows password:** a blank password is now sent as a blank password, rather than as "no password given", so it signs in once TitanDeck Host has allowed accounts with no password.

## 0.21.0 - 2026-10-26 - Titan 19 fixes, desk selection over CITP

- **Titan 19's HTTP 500 errors:** Titan 19.2's WebAPI only takes its new calls unless its "pre19Compatibility" switch is on, so the keypad, Clear, Exit, fade times and Layouts failed while playbacks still fired. TitanDeck Host 0.9 flags it and turns it on with one click on the PC.
- **See what Titan says:** when Titan answers with an error, Settings > Recent calls now shows Titan's own message, not just "HTTP 500".
- **Through TitanDeck Host** (Settings > Connection): sends TitanDeck's Titan calls through the Host (0.9), so the Host's Titan log shows every one, with Titan's answer. Needs the Host running.
- **Magic Keyboard on the remote desktop:** a hardware keyboard now types on the Titan PC while the remote desktop is showing: letters, numbers, F-keys, arrows, Esc, Delete, and Shift/Ctrl/Option held with clicks or keys. Keys repeat when held. Command works as Ctrl (Cmd-C, Cmd-V, Cmd-Z) by default, or as the Windows key: Settings > Remote desktop > Keyboard's Command key. iPadOS keeps a few shortcuts for itself (Cmd-Tab, Cmd-Space, Globe keys).
- **GO latches:** the Playbacks page's GO keys still say GO, but work like a latch button on the desk: press to fire the cue, press again to release it.
- **Remote desktop with no Windows password:** says so plainly. Windows doesn't let an account with no password sign in remotely by default; TitanDeck Host 0.9 can allow it (Accounts with no password > Allow, on the PC), then leave the password blank.

- **Follow the desk's selection on Titan 19:** Titan 19's WebAPI is a separate service that can't see what's selected on the desk, so TitanDeck Host 0.9 can now hear the selection over CITP instead, the way Capture does. Switch on "Follow selection via CITP" in TitanDeck Host (Test mode only) and, with the desk link on, the deck follows what you select in Layouts or on the desk. The deck's own WebAPI user selects the same fixtures, so its keys act on them.
- Settings > Desk link and the loading screen say "Linked over CITP" when that's how it's linked.
- Experimental: try it on a copy of your show first.

## 0.20.0 - 2026-10-26 - Change the Host's address

- **Change Address** (Settings > TitanDeck Host): when the PC has more than one network and TitanDeck found the wrong one, point it at the right address without pairing again. Type it, or pick the PC from the ones found on the network.
- **Titan and the remote desktop move too:** Change Address has "Titan uses this address too" and "Remote desktop uses this address too" (both on), so all three switch to the show network's address in one go.
- **Clearer remote desktop failures:** instead of "The connection was cancelled", TitanDeck checks whether the PC answers on the remote desktop port and says which: nothing answering at that address (wrong address or network, PC off, firewall), or the PC answered but the login didn't finish.
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
