#!/usr/bin/env python3
"""Fake Titan: pretends to be the Avolites Titan WebAPI so TitanDeck can be
tested without Titan (or an AvoKey).

Run it on any computer on the same network as the iPad:

    python3 TitanDeck/Tools/fake_titan.py

then set TitanDeck's Titan PC address to the IP it prints. Every request the
app makes is printed, along with the state it changes: Titan's command line,
selected fixtures and their levels, and which playbacks are live.

TitanDeck Host 0.5+ has this built in (Fake Titan card in the Host window, with
a log of every call), so on the Titan PC use that instead. This script is for
testing from a Mac. Keep the two answering the same calls.

It only knows the calls TitanDeck makes (see Sources/Titan/TitanEndpoints.swift),
and its answers are best guesses at what real Titan does. It's for checking the
app's side, not for settling how Titan behaves.

Options:
    --port 4430          port to listen on (Titan's WebAPI port by default)
    --latency 0          extra delay per request in ms; 600+ makes keys flash red
    --no-user-numbers    leave user numbers out of /titan/handles/Playbacks, like
                         the example in Avolites' docs, to test the app's warning
    --fixtures 12        how many fake fixtures are patched
    --playbacks 20       how many fake playbacks exist (10 per page, like Titan)
    --ui-port 4433       also be Titan's UI WebAPI (the desk link) on this port:
                         the operator's own selection and command line. 0 = off
    --sacn               send fixture levels as sACN (universe 1) so TitanDeck
                         Host can read them; fixture n is patched at
                         (n-1)*4+1 as Red, Green, Blue, Dimmer

Pretend to select fixtures on the desk (as if clicked in Layouts):

    curl "http://localhost:4430/fake/desk-select?fixtures=3,4"

Standard library only. Ctrl-C to stop.
"""

import argparse
import json
import re
import socket
import struct
import uuid
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

VERSION = "19.2.0 (Fake Titan)"
# Colour palettes named the way TitanDeck's CCT keys look for them, and some
# workspaces (window layouts) for the Layouts page.
COLOUR_PALETTES = ["2700K", "3200K", "4000K", "4500K", "5600K", "6000K", "6500K", "7500K", "10000K"]
WORKSPACES = ["Programming", "Patch", "Playbacks", "Pixel map", "Shapes", "Output"]
SCRIPT = "/titan/script/2/"

USE_COLOUR = sys.stdout.isatty()


def colour(code, text):
    return f"\033[{code}m{text}\033[0m" if USE_COLOUR else text


def green(text):
    return colour("32", text)


def red(text):
    return colour("31", text)


def dim(text):
    return colour("2", text)


def bold(text):
    return colour("1", text)


class FakeTitan:
    """The pretend console. One lock, because the server is threaded."""

    def __init__(self, fixtures, playbacks):
        self.lock = threading.Lock()
        # Two users, like Titan: the WebAPI's own (port 4430) and the desk's
        # (the UI WebAPI). Each has its own command line and selection; levels
        # are shared, like one show.
        self.users = {"api": {"line": "", "selected": []}, "desk": {"line": "", "selected": []}}
        self.user = "api"
        self.levels = {n: 0.0 for n in range(1, fixtures + 1)}   # fixture -> percent
        self.flashed = {}       # fixture -> level saved by FlashOut
        self.patch_current = None   # what Patch/Repatch copied into the patch editor
        self.playbacks = {n: 0.0 for n in range(1, playbacks + 1)}   # user number -> 0-1
        self.cue_times = {}     # user number -> {"CueFadeInTime": s, "CueFadeOutTime": s}
        self.editing = None     # the playback SelectCueByNumber picked
        self.held = {}          # fixture -> level saved by a flash, for the release

    @property
    def command_line(self):
        return self.users[self.user]["line"]

    @command_line.setter
    def command_line(self, text):
        self.users[self.user]["line"] = text

    @property
    def selected(self):
        return self.users[self.user]["selected"]

    @selected.setter
    def selected(self, fixtures):
        self.users[self.user]["selected"] = fixtures

    @staticmethod
    def address(n):
        """Fake patch: 4 channels each (R, G, B, Dimmer) on universe 1."""
        return 1, (n - 1) * 4 + 1

    # --- Command line -----------------------------------------------------

    def run_command(self, command):
        """Understands what the TitanDeck keypad can type: '1', '1@5', '1 @ 50'."""
        text = command.replace(" ", "").upper()
        match = re.fullmatch(r"(\d+)?(?:@(\d{1,3}))?", text)
        if not match or not text:
            return f"didn't understand '{command}' (real Titan might)"
        fixture, level = match.groups()
        notes = []
        if fixture:
            n = int(fixture)
            if n not in self.levels:
                return f"fixture {n} isn't patched (1-{len(self.levels)} are)"
            self.selected = [n]
            notes.append(f"selected fixture {n}")
        if level is not None:
            if not self.selected:
                return "@ with nothing selected"
            # Titan style: one digit is tens (@5 = 50%), two or three are literal.
            percent = int(level) * 10 if len(level) == 1 else int(level)
            percent = max(0, min(100, percent))
            for n in self.selected:
                self.levels[n] = float(percent)
            notes.append(f"set to {percent}%")
        return ", ".join(notes)

    # --- Requests ---------------------------------------------------------

    def handle(self, path, query, user="api"):
        """Returns (status, body, note). body is JSON-encoded unless it's None."""
        self.user = user
        q = {k: v[0] for k, v in parse_qs(query, keep_blank_values=True).items()}

        if path == "/fake/desk-select":
            numbers = [int(x) for x in q.get("fixtures", "").replace(" ", "").split(",") if x.isdigit()]
            self.users["desk"]["selected"] = [n for n in numbers if n in self.levels]
            return 200, None, f"desk selection now {self.users['desk']['selected'] or 'empty'} (as if from Layouts)"
        if path == "/titan/handles/Fixtures":
            return 200, [{
                "handleLocation": {"group": "Fixtures", "index": n - 1, "page": 0},
                "properties": [{"Key": "userNumber", "Value": n}],
                "titanId": 5000 + n, "type": "fixtureHandle", "Active": False, "Legend": f"Fixture {n}",
            } for n in sorted(self.levels)], None
        if path == "/titan/get/2/Patch/CurrentDmxAssignment":
            if self.patch_current is None:
                return 200, "", "nothing copied into the patch editor"
            return 200, "%d.%d" % self.patch_current, None

        if path == "/titan/get/System/SoftwareVersion":
            return 200, VERSION, None
        if path == "/titan/get/2/Command/CommandLineText":
            return 200, self.command_line, None
        if path == "/titan/handles/Playbacks":
            return 200, self.handles(), None
        if path == "/titan/handles/Colours":
            return 200, self.simple_handles("Colours", COLOUR_PALETTES, 2000), None
        if path == "/titan/handles/Workspaces":
            return 200, self.simple_handles("Workspaces", WORKSPACES, 3000), None

        if not path.startswith(SCRIPT):
            return 404, None, "unknown path"
        function = path[len(SCRIPT):]

        if function == "Command/AppendStringAndPreview":
            self.command_line += q.get("text", "")
            return 200, None, f"command line now '{self.command_line}'"
        if function == "Command/RunCommand":
            note = self.run_command(q.get("command", ""))
            return 200, None, f"ran '{q.get('command', '')}': {note}"
        if function == "Command/StartNewCommand":
            self.command_line = ""
            return 200, None, "command line cleared"
        if function == "Menu/ExitRootOrLatched":
            return 200, None, "exited menu"
        if function in ("Programmer/Editor/ClearAll", "Playbacks/Editor/ClearAll"):
            self.selected = []
            for n in self.levels:
                self.levels[n] = 0.0
            return 200, None, "programmer cleared"
        if function == "Programmer/Editor/Fixtures/IncrementDimmer":
            return self.increment_dimmer(q)
        if function == "Programmer/Editor/Fixtures/SetDimmerLevel":
            return self.set_dimmer(q)
        if function == "Programmer/Editor/Fixtures/ClearSelectedControls":
            return self.release_selection(q)
        if function == "Playbacks/Editor/CueSelection/SelectCueByNumber":
            try:
                n = self.from_titan_id(q.get("handle_titanId", ""))
            except ValueError:
                return 404, None, f"no playback with titanId {q.get('handle_titanId')}"
            self.editing = n
            return 200, None, f"editing playback {n}, cue {q.get('cueNumber', '1')}"

        if re.fullmatch(r"Selection/Context/(Global|Programmer)/Get(All)?SelectedFixtureIds", function):
            return 200, [5000 + n for n in self.selected], None
        if function == "Selection/Context/Global/Clear":
            self.selected = []
            return 200, None, f"selection cleared ({user} user)"
        if function == "Selection/Context/Global/SelectFixturesFromHandles":
            numbers = [int(x) for x in q.get("handleList_userNumberList", "").split(",") if x.isdigit()]
            self.selected = [n for n in numbers if n in self.levels]
            return 200, None, f"selected {self.selected} ({user} user)"
        if function == "Programmer/Editor/Fixtures/FlashOut":
            for n in self.selected:
                self.flashed.setdefault(n, self.levels[n])
                self.levels[n] = 0.0
            return 200, None, f"flashed {self.selected} to zero"
        if function == "Programmer/Editor/Fixtures/ClearFlash":
            for n in self.selected:
                if n in self.flashed:
                    self.levels[n] = self.flashed.pop(n)
            return 200, None, f"flash cleared on {self.selected}"
        if function == "Patch/Repatch/SetDmxAddressesFromSelectedFixture":
            if user == "desk":
                # TitanDeck must never drive Patch on the operator's own UI.
                return 200, None, red("PATCH CALLED ON THE DESK'S UI - TitanDeck shouldn't do this")
            if not self.selected:
                return 200, None, "patch: nothing selected"
            self.patch_current = self.address(self.selected[0])
            return 200, None, "patch editor now holds fixture %d's address %d.%d" % ((self.selected[0],) + self.patch_current)

        if function in ("Playbacks/FirePlaybackAtLevel", "Playbacks/ReleasePlayback",
                        "Playbacks/SetPlaybackLevel"):
            return self.playback(function, q)
        if function == "Macros/Run":
            return 200, None, f"ran macro '{q.get('macroId', '')}'"
        if function == "Palette/ApplyPalette":
            return self.apply_palette(q)
        if function == "Workspace/Apply":
            n = q.get("handle_userNumber", "")
            name = WORKSPACES[int(n) - 1] if n.isdigit() and 0 < int(n) <= len(WORKSPACES) else None
            if not name:
                return 404, None, f"no workspace {n} (1-{len(WORKSPACES)} exist)"
            return 200, None, f"workspace {n} '{name}' on screen"

        return 404, None, "Fake Titan doesn't know this function"

    def from_titan_id(self, raw):
        n = int(raw) - 1000
        if n not in self.playbacks:
            raise ValueError(raw)
        return n

    def set_property(self, path, body):
        """POST /titan/set/2/Playbacks/Editor/Times/CueFadeInTime (or Out), body
        the seconds. Real Titan's body format isn't documented; this takes a
        bare number, or JSON with one."""
        name = path.rsplit("/", 1)[-1]
        if not path.startswith("/titan/set/2/Playbacks/Editor/Times/") or \
                name not in ("CueFadeInTime", "CueFadeOutTime"):
            return 404, None, "Fake Titan can't set this property"
        if self.editing is None:
            return 409, None, f"{name} with no cue selected (SelectCueByNumber first)"
        text = body.decode(errors="replace").strip()
        try:
            value = json.loads(text)
            seconds = float(value.get("value", value) if isinstance(value, dict) else value)
        except (ValueError, TypeError, AttributeError):
            return 400, None, f"body '{text}' isn't a number of seconds"
        self.cue_times.setdefault(self.editing, {})[name] = seconds
        return 200, None, f"playback {self.editing} {name} = {seconds:g}s"

    def set_dimmer(self, q):
        try:
            level = float(q.get("level", ""))
        except ValueError:
            return 400, None, f"level '{q.get('level')}' isn't a number"
        if not self.selected:
            return 200, None, f"dimmer {level:g}% but nothing is selected"
        for n in self.selected:
            self.held.setdefault(n, self.levels[n])
            self.levels[n] = max(0.0, min(100.0, level))
        return 200, None, f"fixture(s) {self.selected} dimmer at {level:g}%"

    def release_selection(self, q):
        """Release puts the selection back where the playbacks had it. The fake
        has no playback output, so it restores the level from before the flash."""
        if not self.selected:
            return 200, None, "release but nothing is selected"
        for n in self.selected:
            self.levels[n] = self.held.pop(n, self.levels[n])
        return 200, None, f"released fixture(s) {self.selected} over {q.get('releaseTime', '0')}s"

    def increment_dimmer(self, q):
        try:
            # Titan's wheel: 4096 steps = full (TitanEndpoints.dimmerStepsPerPercent).
            value = float(q.get("value", "")) / 40.96
        except ValueError:
            return 400, None, f"value '{q.get('value')}' isn't a number"
        if not self.selected:
            return 200, None, f"{value:+g} but nothing is selected"
        for n in self.selected:
            if value < 0:
                self.held.setdefault(n, self.levels[n])
            self.levels[n] = max(0.0, min(100.0, self.levels[n] + value))
        return 200, None, f"{value:+g}% on fixture(s) {self.selected} ({q.get('value')} wheel steps)"

    def playback(self, function, q):
        key = "srcHandle_userNumber" if function.endswith("SetPlaybackLevel") else "handle_userNumber"
        try:
            n = self.from_titan_id(q["handle_titanId"]) if "handle_titanId" in q else int(q.get(key, ""))
        except (ValueError, KeyError):
            return 400, None, f"missing {key} or handle_titanId"
        if n not in self.playbacks:
            return 404, None, f"no playback {n} (1-{len(self.playbacks)} exist)"
        if function.endswith("FirePlaybackAtLevel"):
            self.playbacks[n] = float(q.get("level_level", "1") or 1)
            return 200, None, f"playback {n} GO"
        if function.endswith("ReleasePlayback"):
            self.playbacks[n] = 0.0
            return 200, None, f"playback {n} released"
        try:
            level = float(q.get("level_level", ""))
        except ValueError:
            return 400, None, "missing level_level"
        self.playbacks[n] = max(0.0, min(1.0, level))
        return 200, None, f"playback {n} fader at {self.playbacks[n]:.0%}"

    def handles(self):
        out = []
        for index, (n, level) in enumerate(sorted(self.playbacks.items())):
            handle = {
                "handleLocation": {"group": "Playbacks", "index": index % 10, "page": index // 10},
                "properties": [{"Key": "lockState", "Value": "Unlocked"}],
                "titanId": 1000 + n,
                "type": "playbackHandle",
                "Active": level > 0,
                "Legend": f"Playback {n}",
            }
            if ARGS.user_numbers:
                handle["properties"].append({"Key": "userNumber", "Value": n})
            out.append(handle)
        return out

    def apply_palette(self, q):
        try:
            index = int(q.get("handle_titanId", "")) - 2000
        except ValueError:
            return 400, None, "missing handle_titanId"
        if not 0 <= index < len(COLOUR_PALETTES):
            return 404, None, f"no palette with titanId {q.get('handle_titanId')}"
        if not self.selected:
            return 200, None, f"palette '{COLOUR_PALETTES[index]}' but nothing is selected"
        return 200, None, f"palette '{COLOUR_PALETTES[index]}' on fixture(s) {self.selected}"

    def simple_handles(self, group, legends, first_id):
        return [{
            "handleLocation": {"group": group, "index": i, "page": 0},
            "properties": [{"Key": "userNumber", "Value": i + 1}],
            "titanId": first_id + i,
            "type": "paletteHandle" if group == "Colours" else "workspaceHandle",
            "Active": False,
            "Legend": legend,
        } for i, legend in enumerate(legends)]

    def status_line(self):
        live = [str(n) for n, level in sorted(self.playbacks.items()) if level > 0]
        lit = [f"{n}:{level:g}%" for n, level in sorted(self.levels.items()) if level > 0]
        sel = ",".join(map(str, self.users["api"]["selected"])) or "-"
        if ARGS.ui_port:
            desk = ",".join(map(str, self.users["desk"]["selected"])) or "-"
            sel += f" | desk line '{self.users['desk']['line']}' desk selected {desk}"
        return dim(f"    line '{self.users['api']['line']}' | selected {sel} | "
                   f"levels {' '.join(lit) or '-'} | live playbacks {' '.join(live) or '-'}")


class Handler(BaseHTTPRequestHandler):
    server_version = "FakeTitan/1"
    quiet = {"/titan/get/2/Command/CommandLineText", "/titan/handles/Playbacks",
             "/titan/get/System/SoftwareVersion", "/titan/handles/Fixtures",
             "/titan/script/2/Selection/Context/Global/GetAllSelectedFixtureIds"}

    def do_GET(self):
        if ARGS.latency:
            time.sleep(ARGS.latency / 1000)
        url = urlparse(self.path)
        user = "desk" if ARGS.ui_port and self.server.server_address[1] == ARGS.ui_port else "api"
        with TITAN.lock:
            status, body, note = TITAN.handle(url.path, url.query, user)
            status_line = TITAN.status_line()

        payload = b"" if body is None else json.dumps(body).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            print(red(f"{stamp()} {self.client_address[0]} gave up waiting for {url.path} "
                      "(timed out)"), flush=True)
            return

        # The app polls these several times a second; only show them once
        # each (or when they fail) so the real presses stand out.
        if url.path in self.quiet and status == 200:
            if url.path not in SEEN_POLLS:
                SEEN_POLLS.add(url.path)
                print(dim(f"{stamp()} {self.client_address[0]} polling {url.path} "
                          "(shown once)"), flush=True)
            return
        mark = green(str(status)) if status == 200 else red(str(status))
        print(f"{stamp()} {self.client_address[0]} {mark} {bold(url.path)}"
              f"{'?' + unquote(url.query) if url.query else ''}", flush=True)
        if note:
            print(f"    {red(note) if status != 200 else note}", flush=True)
        if status == 200:
            print(status_line, flush=True)

    def do_POST(self):
        if ARGS.latency:
            time.sleep(ARGS.latency / 1000)
        url = urlparse(self.path)
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        with TITAN.lock:
            TITAN.user = "desk" if ARGS.ui_port and self.server.server_address[1] == ARGS.ui_port else "api"
            status, _, note = TITAN.set_property(url.path, body)
            status_line = TITAN.status_line()
        try:
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()
        except (BrokenPipeError, ConnectionResetError):
            return
        mark = green(str(status)) if status == 200 else red(str(status))
        print(f"{stamp()} {self.client_address[0]} {mark} POST {bold(url.path)} "
              f"body '{body.decode(errors='replace')}'", flush=True)
        if note:
            print(f"    {red(note) if status != 200 else note}", flush=True)
        if status == 200:
            print(status_line, flush=True)

    def log_message(self, format, *args):   # the default logging is too noisy
        pass


def sacn_packet(universe, levels, sequence):
    """One E1.31 data packet (what Titan sends over sACN)."""
    body = bytes(levels)
    p = bytearray(126 + len(body))
    struct.pack_into(">HH12s", p, 0, 0x10, 0, b"ASC-E1.17\0\0\0")
    struct.pack_into(">HI", p, 16, 0x7000 | (len(p) - 16), 4)
    p[22:38] = uuid.UUID("6d1b2c3a-0000-4000-8000-0000000fa4e0").bytes
    struct.pack_into(">HI", p, 38, 0x7000 | (len(p) - 38), 2)
    name = b"Fake Titan"
    p[44:44 + len(name)] = name
    p[108] = 100
    p[111] = sequence & 255
    struct.pack_into(">H", p, 113, universe)
    struct.pack_into(">HBBHHH", p, 115, 0x7000 | (len(p) - 115), 2, 0xA1, 0, 1, len(body) + 1)
    p[126:] = body
    return bytes(p)


def send_sacn():
    """Universe 1, ten times a second: each fixture as Red, Green, Blue, Dimmer."""
    out = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    out.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_LOOP, 1)
    out.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 1)
    sequence = 0
    while True:
        levels = [0] * 512
        with TITAN.lock:
            for n, level in TITAN.levels.items():
                _, start = FakeTitan.address(n)
                if start + 3 <= 512:
                    levels[start - 1:start + 3] = [255, 180, 120, round(level * 2.55)]
        try:
            out.sendto(sacn_packet(1, levels, sequence), ("239.255.0.1", 5568))
        except OSError:
            pass
        sequence += 1
        time.sleep(0.1)


def stamp():
    return time.strftime("%H:%M:%S")


def local_ip():
    """This computer's address on its main network, or None."""
    try:
        # Connecting a UDP socket sends nothing; it just picks the outgoing interface.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 53))
            ip = s.getsockname()[0]
        return None if ip.startswith("127.") else ip
    except OSError:
        return None


def main():
    global ARGS, TITAN
    parser = argparse.ArgumentParser(description="Pretend Titan WebAPI for testing TitanDeck.")
    parser.add_argument("--port", type=int, default=4430)
    parser.add_argument("--latency", type=int, default=0, help="extra delay per request, ms")
    parser.add_argument("--no-user-numbers", dest="user_numbers", action="store_false",
                        help="leave user numbers out of the playback handles")
    parser.add_argument("--fixtures", type=int, default=12)
    parser.add_argument("--playbacks", type=int, default=20)
    parser.add_argument("--ui-port", type=int, default=4433, help="the desk's UI WebAPI; 0 = off")
    parser.add_argument("--sacn", action="store_true", help="send fixture levels as sACN universe 1")
    ARGS = parser.parse_args()
    TITAN = FakeTitan(ARGS.fixtures, ARGS.playbacks)

    try:
        server = ThreadingHTTPServer(("0.0.0.0", ARGS.port), Handler)
    except OSError as error:
        sys.exit(f"Can't listen on port {ARGS.port}: {error}. Is real Titan (or another "
                 f"Fake Titan) already running?")

    if ARGS.ui_port:
        try:
            desk = ThreadingHTTPServer(("0.0.0.0", ARGS.ui_port), Handler)
        except OSError as error:
            sys.exit(f"Can't listen on port {ARGS.ui_port} for the desk's UI WebAPI: {error}. Use --ui-port 0.")
        threading.Thread(target=desk.serve_forever, daemon=True).start()
    if ARGS.sacn:
        threading.Thread(target=send_sacn, daemon=True).start()

    print(bold(f"Fake Titan {VERSION} listening on port {ARGS.port}"
               f"{f', desk UI WebAPI on {ARGS.ui_port}' if ARGS.ui_port else ''}"
               f"{', sending sACN universe 1' if ARGS.sacn else ''}"))
    ip = local_ip()
    if ip:
        print("In TitanDeck, set Titan PC address to: " + bold(ip))
    else:
        print("Couldn't work out this computer's IP. On a Mac: ipconfig getifaddr en0")
    print("Remote desktop: give it the real PC's address, or it will try this computer.")
    print(f"{ARGS.fixtures} fixtures, playbacks 1-{ARGS.playbacks} "
          f"on {(ARGS.playbacks + 9) // 10} page(s)"
          f"{', latency +' + str(ARGS.latency) + ' ms' if ARGS.latency else ''}"
          f"{', no user numbers in handles' if not ARGS.user_numbers else ''}. Ctrl-C to stop.\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")


ARGS = None
TITAN = None
SEEN_POLLS = set()

if __name__ == "__main__":
    main()
