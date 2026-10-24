#!/usr/bin/env python3
"""Revokes the Apple Development certificates earlier TestFlight runs created.

Every TestFlight run archives on a fresh GitHub Mac, so Xcode makes a new
development certificate through the App Store Connect key, and its private key
is thrown away with the runner. Nothing can ever sign with those certificates
again, but they count towards Apple's limit, and once it's reached the archive
fails with "Your account has reached the maximum number of certificates".

Run by the TestFlight job in .github/workflows/titandeck.yml before the archive:

    python3 Tools/revoke_ci_certificates.py [--dry-run]

Only development certificates made through the API ("Created via API") go.
Certificates made in Xcode on someone's own Mac, and distribution certificates,
are left alone. Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH, like
testflight_notes.py.
"""

import argparse
import os

from testflight_notes import Client, token

DEVELOPMENT_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT"}
API_MARKER = "created via api"


def made_by_ci(certificate: dict) -> bool:
    attributes = certificate.get("attributes", {})
    names = f"{attributes.get('name', '')} {attributes.get('displayName', '')}".lower()
    return attributes.get("certificateType") in DEVELOPMENT_TYPES and API_MARKER in names


def describe(certificate: dict) -> str:
    attributes = certificate.get("attributes", {})
    return (f"{attributes.get('certificateType')} | {attributes.get('name')} | "
            f"{attributes.get('displayName')} | expires {attributes.get('expirationDate', '')[:10]}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true", help="list what would go, revoke nothing")
    args = parser.parse_args()

    client = Client(token(os.environ["ASC_KEY_ID"], os.environ["ASC_ISSUER_ID"], os.environ["ASC_KEY_PATH"]))
    certificates = client.call("GET", "/certificates?limit=200")["data"]
    stale = [c for c in certificates if made_by_ci(c)]
    print(f"{len(certificates)} certificates on the account, {len(stale)} made by earlier CI runs")
    for certificate in certificates:
        print(("  revoke: " if certificate in stale else "  keep:   ") + describe(certificate))
    if args.dry_run:
        return
    for certificate in stale:
        client.call("DELETE", f"/certificates/{certificate['id']}")
    if stale:
        print(f"Revoked {len(stale)}")


if __name__ == "__main__":
    main()
