#!/usr/bin/env python3
"""Copy exact source bytes to a fresh local build snapshot without cloud metadata.

The checkout remains authoritative. Each snapshot records SHA-256 hashes and is
retained for build provenance; no source file is modified or removed.
"""
import hashlib
import json
import pathlib
import sys
import tempfile

root = pathlib.Path(__file__).resolve().parent.parent
parent = pathlib.Path(sys.argv[1]) / "SourceSnapshots"
parent.mkdir(parents=True, exist_ok=True)
destination = pathlib.Path(tempfile.mkdtemp(prefix="build-", dir=parent))
hashes = {}
for folder in ["App", "Packages", "HypergateBar.xcodeproj", "Tests"]:
    source = root / folder
    if not source.exists():
        continue
    for path in source.rglob("*"):
        relative = path.relative_to(root)
        if any(part in {".build", ".swiftpm", "xcuserdata"} for part in relative.parts) or not path.is_file():
            continue
        data = path.read_bytes()
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        hashes[str(relative)] = hashlib.sha256(data).hexdigest()
(destination / "source-manifest.json").write_text(json.dumps(hashes, sort_keys=True, indent=2) + "\n")
print(destination)
