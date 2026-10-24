#!/usr/bin/env python3
"""Fake Titan: pretends to be the Avolites Titan WebAPI so TitanDeck can be
tested without Titan (or an AvoKey).

Run it on any computer on the same network as the iPad:

    python3 TitanDeck/Tools/fake_titan.py

then set TitanDeck's Titan PC address to the IP it prints. Every request the
app makes is printed, along with the state it changes: Titan's command line,
selected fixtures and their levels, and which playbacks are live.

It only knows the calls TitanDeck makes (see Sources/Titan/TitanEndpoints.swift),
and its answers are best guesses at what real Titan does. It's for checking the
app's side, not for settling how Titan behaves.

Options:
    --port 4430          port to listen on (Titan's WebAPI port by default)
    --latency 0          extra delay per request in ms; 600+ makes keys flash red
    --no-user-numbers    leave user numbers out of /titan/handles/Playbacks, like
                         the example in Avolites' docs, to test the app's warning
    --fixtures 12        how many fake fixtures are patched
    --playbacks 20       how many fake playbacks exist

Standard library only. Ctrl-C to stop.
"""

import argparse
import json
import re
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlparse

VERSION = "19.2.0 (Fake Titan)"
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
        self.command_line = ""
        self.levels = {n: 0.0 for n in range(1, fixtures + 1)}   # fixture -> percent
        self.selected = []
        self.playbacks = {n: 0.0 for n in range(1, playbacks + 1)}   # user number -> 0-1

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

    def handle(self, path, query):
        """Returns (status, body, note). body is JSON-encoded unless it's None."""
        q = {k: v[0] for k, v in parse_qs(query, keep_blank_values=True).items()}

        if path == "/titan/get/System/SoftwareVersion":
            return 200, VERSION, None
        if path == "/titan/get/2/Command/CommandLineText":
            return 200, self.command_line, None
        if path == "/titan/handles/Playbacks":
            return 200, self.handles(), None

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
        if function == "Playbacks/Editor/ClearAll":
            self.selected = []
            for n in self.levels:
                self.levels[n] = 0.0
            return 200, None, "programmer cleared"
        if function == "Programmer/Editor/Fixtures/IncrementDimmer":
            return self.increment_dimmer(q)

        if function in ("Playbacks/FirePlaybackAtLevel", "Playbacks/ReleasePlayback",
                        "Playbacks/SetPlaybackLevel"):
            return self.playback(function, q)
        if function == "Macros/Run":
            return 200, None, f"ran macro '{q.get('macroId', '')}'"

        return 404, None, "Fake Titan doesn't know this function"

    def increment_dimmer(self, q):
        try:
            value = float(q.get("value", ""))
        except ValueError:
            return 400, None, f"value '{q.get('value')}' isn't a number"
        if not self.selected:
            return 200, None, f"{value:+g} but nothing is selected"
        for n in self.selected:
            self.levels[n] = max(0.0, min(100.0, self.levels[n] + value))
        # The app assumes percent. If real Titan wants 0-1, the same request
        # would be 100x bigger, which is what the test plan asks you to watch for.
        return 200, None, f"{value:+g}% on fixture(s) {self.selected} (assuming percent)"

    def playback(self, function, q):
        key = "srcHandle_userNumber" if function.endswith("SetPlaybackLevel") else "handle_userNumber"
        try:
            n = int(q.get(key, ""))
        except ValueError:
            return 400, None, f"missing {key}"
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
                "handleLocation": {"group": "Playbacks", "index": index, "page": 0},
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

    def status_line(self):
        live = [str(n) for n, level in sorted(self.playbacks.items()) if level > 0]
        lit = [f"{n}:{level:g}%" for n, level in sorted(self.levels.items()) if level > 0]
        sel = ",".join(map(str, self.selected)) or "-"
        return dim(f"    line '{self.command_line}' | selected {sel} | "
                   f"levels {' '.join(lit) or '-'} | live playbacks {' '.join(live) or '-'}")


class Handler(BaseHTTPRequestHandler):
    server_version = "FakeTitan/1"
    quiet = {"/titan/get/2/Command/CommandLineText", "/titan/handles/Playbacks",
             "/titan/get/System/SoftwareVersion"}

    def do_GET(self):
        if ARGS.latency:
            time.sleep(ARGS.latency / 1000)
        url = urlparse(self.path)
        with TITAN.lock:
            status, body, note = TITAN.handle(url.path, url.query)
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

    def log_message(self, format, *args):   # the default logging is too noisy
        pass


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
    ARGS = parser.parse_args()
    TITAN = FakeTitan(ARGS.fixtures, ARGS.playbacks)

    try:
        server = ThreadingHTTPServer(("0.0.0.0", ARGS.port), Handler)
    except OSError as error:
        sys.exit(f"Can't listen on port {ARGS.port}: {error}. Is real Titan (or another "
                 f"Fake Titan) already running?")

    print(bold(f"Fake Titan {VERSION} listening on port {ARGS.port}"))
    ip = local_ip()
    if ip:
        print("In TitanDeck, set Titan PC address to: " + bold(ip))
    else:
        print("Couldn't work out this computer's IP. On a Mac: ipconfig getifaddr en0")
    print("Remote desktop: give it the real PC's address, or it will try this computer.")
    print(f"{ARGS.fixtures} fixtures, playbacks 1-{ARGS.playbacks}"
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
