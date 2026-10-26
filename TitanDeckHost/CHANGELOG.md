# TitanDeck Host changelog

The Windows companion to TitanDeck. Newest first. Versions are 0.MINOR.PATCH
until it's show-ready (1.0): MINOR for features, PATCH for fixes. Keep
`<Version>` in `Directory.Build.props` in step with the top entry
(ChangelogTests checks). Each version is published as a GitHub release
`host-v<version>` with the installer attached.

## 0.8.0 - 2026-10-26 - Network for TitanDeck

- **Pick the network adapter TitanDeck uses:** a Network for TitanDeck card lists the PC's adapters (Ethernet 1, Ethernet 4...) with their addresses. Pick the one on the show network and the Host only announces that adapter's address, on that adapter, so the iPad stops landing on another network's address. Automatic (every adapter) is the default, as before.
- The card shows the address to type into TitanDeck, for the Host, Titan and the remote desktop alike. (Remote desktop is let through Windows Firewall on Private networks: the checklist flags a show network marked Public, with a fix.)
- If the chosen adapter is unplugged, the Host goes back to every adapter until it's back, and says so.
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
