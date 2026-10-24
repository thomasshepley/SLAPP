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
press **Download & install** in the checklist: the Host fetches the official
v1.6.2 release from github.com/stascorp/rdpwrap, checks its fingerprint, and
installs it. If the PC has no internet, use TitanDeck: Settings > TitanDeck
Host > Send RDP Wrapper, then press **Install** on the PC. Windows Defender
calls RDP Wrapper a "HackTool", so the Host adds an exclusion for its folders
first (you'll see it in Windows Security). Windows Pro needs none of this.

**Remote desktop picture:** Best, Balanced or Weak signal, in the Host window
or from TitanDeck. They change what Windows sends (image quality, bandwidth
mode, 30 or 60 fps) and apply on the next connection.

Developer notes: [CLAUDE.md](CLAUDE.md).
