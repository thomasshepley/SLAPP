# TitanDeck Host changelog

The Windows companion to TitanDeck. Newest first. Versions are 0.MINOR.PATCH
until it's show-ready (1.0): MINOR for features, PATCH for fixes. Keep
`<Version>` in `Directory.Build.props` in step with the top entry
(ChangelogTests checks). Each version is published as a GitHub release
`host-v<version>` with the installer attached.

## 0.14.3 - 2026-10-28 - Installer can't wait on an old window

- **Fixed: an update could wait forever.** The installer asks the window app to close with `--quit`; a window app older than 0.14.2 doesn't know that, and if no copy was already running it simply opened and the installer waited on it. It no longer waits on it (the forced close afterwards still makes sure it's gone).

## 0.14.2 - 2026-10-28 - Updates that finish properly

- **Fixed: after an update the window couldn't find the service.** The window keeps a request open to the service (waiting for desk keys to type), which held a service stop up for 20 seconds; the installer only gave it 2, so files could still be in use, the update fail and the service be left stopped. The service now stops in about 2 seconds, and the installer waits until it really has stopped (forcing it only after 30 s) and then waits for it to start again.
- **Fixed: extra TitanDeck Host icons in the taskbar.** Updates force-closed the window app, which leaves its tray icon behind until the mouse passes over it. The installer now asks it to close (TitanDeckHost.exe --quit), so the icon goes with it, and no longer has Windows close and reopen it as well. Opening TitanDeck Host when it's already running now brings up the running copy's window.
- **Start the service from the window:** if the window can't find the service, it now has a Start the service button (Windows asks for permission).
- This update itself is installed by the old installer, so you may see one leftover icon once; it goes when the mouse passes over it.

## 0.14.1 - 2026-10-28 - CLEAR types Alt+C on the desk

- **TitanDeck's CLEAR now clears the desk's selection** by typing Titan's own Clear shortcut (Alt+C) on the desk, as it did before 0.24, when the clear through Titan's WebAPI didn't reach the desk.
- **Made safe this time:** Alt and C go down and up as one uninterruptible burst, so Alt can't be left held (the likely reason the desk's own Clear and wheels stopped working after 0.11), and every modifier is let go again straight after.
- **Only with something selected:** it's only typed when CITP shows the desk has a selection, because the desk's Clear clears the selection first and the programmer after. With nothing selected nothing is typed, and without CITP the Host falls back to the WebAPI clears.
- The iPad still can't ask the Host to type any shortcut: only the Host's own CLEAR does.
- Works with TitanDeck 0.32 and later; no app update needed.

## 0.14.0 - 2026-10-28 - Cue fades and Clear for TitanDeck, done here

- **The Host now does TitanDeck's cue fade and CLEAR keys** (TitanDeck 0.32+), through Titan's WebAPI on this PC. A better way of doing either only needs a Host update, not a new TitanDeck.
- **Cue fades:** opens the cue the way the desk's Edit Times does, then tries each way of setting the time in turn (the property setters, then Titan's command line on the connected playback, then the time in Titan's own format). One only counts once the cue reads back the new time after being opened again. It never selects every cue of a cue list.
- **Clear:** clears the selection for every user (never a programmer) and checks over CITP that the desk's selection went.
- Every call is in the Titan log as "Host - Titan actions", with Titan's answer, and TitanDeck shows what worked or what Titan said.

## 0.13.1 - 2026-10-28 - A quieter Titan log

- **The Titan log no longer fills up with CITP's handshake.** Titan goes through the whole CITP hello again every time it reconnects (EnterShow, FixtureListRequest, SetFixtureTransformationSpace and the Host's polite NACKs), which buried everything else. Those are normal, not errors: each one is now listed once and its repeats counted on the line above the log, the way polling already was. The desk's selection and anything red are always listed.
- **Everything / important:** the log shows the important lines by default (TitanDeck's calls, the desk's selection, anything refused). Tick Everything to see the first polling and handshake lines too.

## 0.13.0 - 2026-10-27 - Slate Book

- **Slate Book:** the Host logs the whole of Titan's sACN output for each slate and take, when TitanDeck's NEW SLATE, TAKE + or LETTER is pressed, with Day/Night, FX and the time. In between, a change is logged once the output has been still for 3 seconds, ignoring channels that keep moving (an effect). Each line says what changed since the one before, by fixture and attribute when Titan's patch is known (every attribute in its personality), else by DMX address.
- Kept in Data\SlateBook, one file per day, so it survives restarts; the slate showing carries on into the next day. Read only: nothing is ever sent to Titan.
- Match: what's different on stage now from any line of the book.

## 0.12.0 - 2026-10-26 - Titan's patch over CITP, no more Alt+C

- **Fixed: the desk's own Clear and wheels stopped working** after TitanDeck's Clear. The Host typed Alt+C (Titan's Clear shortcut), and a held Alt is the likely culprit. The Host now never types Alt or any other modifier: only number keys, number-pad @ / Thro / And / Not, Enter and Esc. TitanDeck 0.25 clears through Titan's WebAPI instead. When it starts, the Host also lets go of Alt, Ctrl and Shift in case an older version left one held down.
- **Titan's patch straight from Titan:** with Follow selection via CITP on, the fixture list Titan shares (read only) is used as the patch, so live levels work without saving a patch report, and TitanDeck's +/- keys know each fixture's current level. When the patch changes on the desk, the Host asks for the list again. The newest of Titan's list, the Reports folder and a report picked by hand counts.

## 0.11.0 - 2026-10-26 - CITP in Show mode, Fake Titan retired, Clear on the desk

- **Follow selection via CITP is a full feature now:** no longer experimental or Test-only. The card shows in Show mode too, switching to Show no longer turns it off, and it can be switched on in either mode. It still only ever announces itself, opens a show and asks for the fixture list: never a patch, selection or DMX.
- **Fake Titan is gone,** now testing is on the real Titan: its card, its ports (4430/4433) and its firewall rule (the installer removes the old one). Ask Titan for a patch report goes straight to Titan's WebAPI on 4430.
- **Fixed: Clear typed from the deck didn't clear the desk.** The Host typed Alt+C (Titan's Clear) all in one go; it now presses each key separately with short gaps and Alt held down first, as a hand would. All the deck's keys are typed off the window's own thread.

## 0.10.0 - 2026-10-26 - The deck's keypad types on the desk, quieter CITP

- **The deck's keypad on the desk's own command line:** Titan 19's WebAPI is a separate user, so a selection made from the deck never showed on the desk. With TitanDeck 0.22, the Host types the keypad on this PC as if on its keyboard, using Titan's own keyboard shortcuts (number keys, number-pad * for @, Enter, Esc for Exit, Alt+C for Clear), so the selection shows on the desk. The Host window does the typing (the service can't type on the desktop), so it needs to be open (it starts in the tray at login). Only those keypad keys can ever be typed, keys more than 2 seconds old are dropped rather than typed late, and nothing is typed unless Titan is running. Each one shows in the Titan log as "Desk keys".

- **Fixed: "refused: already linked" filling the Titan log** several times a second. Titan opens more than one CITP connection and keeps retrying any that are refused, so the Host now keeps up to 8 links from Titan on this PC and follows the selection from whichever heard it last. Extra links only log selections and problems, a link coming up or going is logged at most every 30 seconds, and anything over 8 is one line a minute.
- Fake Titan: cue fade times behave like Titan 19's (a plain number is refused; a time like 00:00:02.5 or {"Seconds": 2.5} is taken).
- The desk link passes TitanDeck's Clear through under its Titan 19 name (Programmer/Editor/ClearAll).
- Fake Titan: the intensity nudge is Titan's wheel (4096 steps = full), the same as real Titan, and it understands Selection Clear.

## 0.9.0 - 2026-10-26 - Titan 19 WebAPI fix, Titan log for every call, CITP selection

- **Titan 19 WebAPI calls:** a new checklist line. Titan 19.2's WebAPI service only takes its new calls unless "webapi.pre19Compatibility" is on (Titan 19.2 release notes), and it ships off, so TitanDeck's keypad, Clear, Exit, fade times and Layouts got HTTP 500. "Turn on" (on the PC only) switches it on in WebAPI\<version>\WebAPIService.dll.config, keeps a copy of the old file, and restarts Titan's WebAPI service if it is one (otherwise restart Titan).
- **Accounts with no password:** a new checklist line. Windows' default stops a Windows account with no password signing in by remote desktop ("The PC answered but the remote desktop didn't open"). Allow (on the PC only) turns that default off; Undo puts it back. Allowing it means anything on the PC's networks can sign in to a no-password account, so a password is still the safer choice.
- **Every TitanDeck call in the Titan log:** the Host now passes Titan's WebAPI through on port 4436. With TitanDeck 0.21's "Through TitanDeck Host" on, every call shows in the Titan log, and when Titan answers with an error, what Titan said. (Firewall rule added for 4436 on Private and Domain networks.)

- **Follow selection via CITP:** a new card (Test mode only, off until you switch it on). Titan 19's WebAPI can't see the desk's selection, but Titan shares it with CITP visualisers like Capture. Switched on, the Host appears to Titan as a visualiser called TitanDeck Host, opens a "show" with it, asks for Titan's fixture list (to turn Titan's fixture ids into user numbers) and passes the selection on to TitanDeck 0.21.
- **It can't patch Titan:** the Host only ever sends who it is, that its show is open or closed, a request for Titan's fixture list, and "no" to anything Titan asks of it. It never sends a fixture list, patch change, selection, identify or DMX, and every packet is checked against that list before it goes. If Titan offers to sync or change the patch with TitanDeck Host, say no.
- **Only Titan on this PC can link.** Another desk on the show network that tries to connect is refused (and logged).
- Every CITP message, both ways, shows in the Titan log, and the card lists everything announcing CITP on the network.
- Switching to Show mode turns it off.

## 0.8.2 - 2026-10-26 - Not the WebAPI service's settings

- **Fixed:** Titan 19's WebAPI is a separate service with its own settings file (WebAPI\<version>\WebAPIService.dll.config), which has webapi.enabled on at 4430. 0.8.1 took that for a WebAPI inside Titan and said there was nothing to change, but that service is its own user and never sees the desk's selection. The desk-selection check now only reads Titan's own settings file.

## 0.8.1 - 2026-10-26 - Finds Titan 19's settings file

- **Fixed:** the Host looked for Titan's settings in Titan.exe.config, but Titan 19 runs on .NET 8 and keeps them in Titan.dll.config (in the version folder, e.g. Titan\19.2.104.5). It now finds either, so "Desk selection for TitanDeck" reads your real Titan settings, including a WebAPI already on at 4430 (nothing to change then).

## 0.8.0 - 2026-10-26 - Network for TitanDeck

- **Pick the network adapter TitanDeck uses:** a Network for TitanDeck card lists the PC's adapters (Ethernet 1, Ethernet 4...) with their addresses. Pick the one on the show network and the Host only announces that adapter's address, on that adapter, so the iPad stops landing on another network's address. Automatic (every adapter) is the default, as before.
- The card shows the address to type into TitanDeck, for the Host, Titan and the remote desktop alike. (Remote desktop is let through Windows Firewall on Private networks: the checklist flags a show network marked Public, with a fix.)
- If the chosen adapter is unplugged, the Host goes back to every adapter until it's back, and says so.
- **Desk selection when Titan's WebAPI is already in its UI:** if Titan's settings file has its WebAPI turned on at port 4430 (the one TitanDeck uses), that's already the desk's own WebAPI: the desk link now uses 4430, the checklist says there's nothing to change, and it no longer offers to move it to 4433 (which would have moved the WebAPI TitanDeck relies on).
- After switching, on the iPad: Settings > TitanDeck Host > Change Address (TitanDeck 0.20) keeps the pairing.

## 0.7.0 - 2026-10-25 - Test and Show modes

- **Test or Show:** a Mode card at the top of the window, and a TEST or SHOW badge by the headline. Show asks first ("All test features will be disabled if you confirm this"), then stops Fake Titan (it can't be started in Show), hides its card and the experimental "Ask Titan to write one". The checklist, Titan log, patch report, updates and everything for the show stay. Switch back to Test any time; the Host remembers the mode after a restart.
- **New icon:** the TitanDeck keys with HOST on the bottom row, on the window, the tray, the programs, the installer and Add or Remove Programs.
- TitanDeck (0.19) sees the mode, so its loading screen can warn when the iPad is in Show and the Host is still in Test.

## 0.6.0 - 2026-10-25 - Patch report

- **Reads the show's patch from Titan's patch report:** on Titan, Disk > Reports, tick Fixtures, choose CSV (XML and HTML work too) and save it to the PC. The Host picks up the newest report in Documents\Titan\Reports and knows every fixture's user number, DMX line and address. It only reads files: it never opens Patch. Do it again after repatching.
- **Finds each fixture's dimmer channel** in Titan's personalities on the PC (the factory FixtureLibrary and your own Personalities folder), coarse and fine for 16-bit dimmers, or the colour channels for a fixture with no dimmer. TitanDeck 0.18 uses this to show a fixture's live level straight away, without nudging it first.
- **Patch report card** in the Host window: what it read, Read again, Read a report file... (for a report saved somewhere else), and an experimental "Ask Titan to write one" (Titan's WebAPI user, logged in the Titan log; its settings aren't documented, so it may need tuning on a real desk).
- **Fixed:** the Titan log jumped to the oldest line when new ones came in. With Follow ticked it now stays at the bottom, on the newest.
- **Fake Titan has a patch too:** its fixtures (Red, Green, Blue, Dimmer) come with a matching report and personality, so the whole thing can be tried without a desk.

## 0.5.0 - 2026-10-25 - Fake Titan, Titan log and updates

- **Fake Titan is built in:** the Host window has a Fake Titan card. Close Titan, press Start, and the Host pretends to be Titan - the WebAPI on 4430, the desk's own selection on 4433 (through the desk link on 4434) and sACN levels for live intensity. No Python needed any more. Type fixture numbers in "Select on the desk" (3,4 or 1-10) to pretend you clicked them in Layouts.
- **Titan log:** a new card lists every call TitanDeck makes to Fake Titan, and to the real desk through the desk link: who sent it, what Titan answered and how long it took. Red rows are calls that were refused, unknown, or shouldn't happen (anything Patch on the desk). Polls the app repeats every second are counted at the top instead of flooding the list. Copy puts the whole log on the clipboard to send over.
- **Updates from the Host window:** the Host checks GitHub for a newer release every 6 hours (and on Check for updates). Update downloads the installer, checks it against GitHub's SHA-256, installs it quietly and opens the window again. It only ever downloads TitanDeck Host releases from this project.
- **Fix:** fade times set from the deck through the desk link arrived at Titan empty ("body '' isn't a number of seconds"). The desk link now passes them on whole, with their length.
- Firewall rule for Fake Titan's ports (4430, 4433), for the Host service only, private networks.

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
