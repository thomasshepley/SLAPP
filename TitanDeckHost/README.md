# TitanDeck Host

The Windows half of TitanDeck. Install it on the Titan PC and it:

- keeps **Remote Desktop** working, with a plain-English checklist and one-click
  fixes (including RDP Wrapper on Windows Home after Windows updates);
- **pairs** with TitanDeck on the iPad or iPhone using a 6-digit code;
- moves **files both ways**: TitanDeck sends to `Public Documents\TitanDeck\To PC`,
  and anything you put in `To iPad` shows up on the iPad.

Coming next: picture-quality presets for weak signal on set, a live signal
dashboard and a link test.

## Install

1. Download `TitanDeckHost-Setup-<version>.exe` from the newest
   [`host-v...` release](https://github.com/thomasshepley/SLAPP/releases).
2. Copy it to the Titan PC (USB stick), run it, and accept the admin prompt.
   Windows SmartScreen may say "unknown publisher": **More info > Run anyway**.
3. The Host opens. Work down the checklist, pressing any **Fix** buttons.
4. Press **Show a pairing code** and type it into TitanDeck.

On Windows Home, Remote Desktop needs RDP Wrapper. If it isn't installed yet,
put the official release zip (`RDPWrap-v1.6.2.zip` from
github.com/stascorp/rdpwrap) in `To PC` and press **Install** in the checklist.
Windows Defender calls RDP Wrapper a "HackTool", so the Host adds an exclusion
for its folder first (you'll see it in Windows Security). Windows Pro needs
none of this.

Developer notes: [CLAUDE.md](CLAUDE.md).
