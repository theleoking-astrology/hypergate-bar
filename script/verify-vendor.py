#!/usr/bin/env python3
"""Verify committed C sources offline; --update downloads the already-pinned revision."""
import hashlib
import json
from pathlib import Path
import sys
import urllib.request

root = Path(__file__).resolve().parents[1] / "Packages/HypergateCore"
manifest = json.loads((root / "provenance.json").read_text())
for entry in manifest["files"]:
    target = root / entry["path"]
    if "--update" in sys.argv:
        url = f'https://raw.githubusercontent.com/cosinekitty/astronomy/{manifest["revision"]}/{entry["upstream"]}'
        data = urllib.request.urlopen(url, timeout=30).read()
        if hashlib.sha256(data).hexdigest() != entry["sha256"]:
            raise SystemExit(f'Upstream hash mismatch: {entry["upstream"]}')
        target.write_bytes(data)
    if hashlib.sha256(target.read_bytes()).hexdigest() != entry["sha256"]:
        raise SystemExit(f'Vendor hash mismatch: {entry["path"]}')
print("Verified Astronomy Engine revision and all 3 SHA-256 hashes.")
