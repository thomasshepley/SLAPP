#!/usr/bin/env python3
"""Sets a TestFlight build's "What to Test" notes from the top entry of
TitanDeck/CHANGELOG.md, using the App Store Connect API.

Run by the TestFlight job in .github/workflows/titandeck.yml after the upload:

    python3 Tools/testflight_notes.py --build <CFBundleVersion>

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the .p8 file) in the
environment - the same App Store Connect key the upload uses. Standard library
only: the JWT is signed with the openssl command-line tool.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "uk.co.elexproductions.titandeck"
LOCALE = "en-GB"
HERE = Path(__file__).resolve().parent


def latest_notes(changelog: Path) -> str:
    """Plain text for the newest "## version - date - title" entry."""
    header, notes = None, []
    for raw in changelog.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("## "):
            if header:
                break
            parts = [p.strip() for p in line[3:].split(" - ")]
            version = parts[0]
            title = " - ".join(parts[2:]) if len(parts) > 2 else ""
            header = f"{version} - {title}" if title else version
        elif line.startswith("- ") and header:
            notes.append("- " + line[2:].replace("**", ""))
    if not header:
        sys.exit("CHANGELOG.md has no '## version' entry")
    return "\n".join([header] + notes)[:4000]


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(signature: bytes) -> bytes:
    """openssl gives an ASN.1 DER ECDSA signature; JWT wants r || s, 32 bytes each."""
    def read_int(data: bytes, pos: int):
        assert data[pos] == 0x02, "expected INTEGER"
        length = data[pos + 1]
        value = data[pos + 2:pos + 2 + length]
        return value.lstrip(b"\x00").rjust(32, b"\x00"), pos + 2 + length

    assert signature[0] == 0x30, "expected SEQUENCE"
    pos = 2 if signature[1] < 0x80 else 3
    r, pos = read_int(signature, pos)
    s, _ = read_int(signature, pos)
    return r + s


def token(key_id: str, issuer: str, key_path: str) -> str:
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    now = int(time.time())
    claims = b64url(json.dumps({"iss": issuer, "iat": now, "exp": now + 1100,
                                "aud": "appstoreconnect-v1"}).encode())
    signing_input = f"{header}.{claims}".encode()
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=signing_input,
                         capture_output=True, check=True).stdout
    return f"{header}.{claims}.{b64url(der_to_raw(der))}"


class Client:
    def __init__(self, jwt: str):
        self.jwt = jwt

    def call(self, method: str, path: str, body=None):
        request = urllib.request.Request(API + path, method=method,
                                         data=json.dumps(body).encode() if body is not None else None,
                                         headers={"Authorization": f"Bearer {self.jwt}",
                                                  "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                text = response.read().decode()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as error:
            sys.exit(f"{method} {path} -> {error.code}: {error.read().decode()[:500]}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", required=True, help="CFBundleVersion of the uploaded build")
    parser.add_argument("--wait-minutes", type=float, default=15)
    parser.add_argument("--print-only", action="store_true", help="just print the notes")
    args = parser.parse_args()

    notes = latest_notes(HERE.parent / "CHANGELOG.md")
    print(notes)
    if args.print_only:
        return

    client = Client(token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"]))
    apps = client.call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}&limit=1")["data"]
    if not apps:
        sys.exit(f"No App Store Connect app with bundle id {BUNDLE_ID}")
    app_id = apps[0]["id"]

    # The build shows up in the API a few minutes after the upload, while Apple processes it.
    deadline = time.time() + args.wait_minutes * 60
    build_id = None
    while time.time() < deadline:
        builds = client.call("GET", f"/builds?filter[app]={app_id}&filter[version]={args.build}&limit=1")["data"]
        if builds:
            build_id = builds[0]["id"]
            break
        print(f"Waiting for build {args.build} to appear in App Store Connect...")
        time.sleep(30)
    if not build_id:
        sys.exit(f"Build {args.build} didn't appear within {args.wait_minutes} minutes - set the notes by hand")

    existing = client.call("GET", f"/builds/{build_id}/betaBuildLocalizations")["data"]
    mine = next((loc for loc in existing if loc["attributes"].get("locale") == LOCALE), None)
    if mine:
        client.call("PATCH", f"/betaBuildLocalizations/{mine['id']}",
                    {"data": {"type": "betaBuildLocalizations", "id": mine["id"],
                              "attributes": {"whatsNew": notes}}})
    else:
        client.call("POST", "/betaBuildLocalizations",
                    {"data": {"type": "betaBuildLocalizations",
                              "attributes": {"locale": LOCALE, "whatsNew": notes},
                              "relationships": {"build": {"data": {"type": "builds", "id": build_id}}}}})
    print(f"TestFlight notes set for build {args.build}")


if __name__ == "__main__":
    main()
