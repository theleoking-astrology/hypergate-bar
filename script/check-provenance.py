#!/usr/bin/env python3
import hashlib
import json
import pathlib
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parent.parent
manifest = json.loads((root / 'docs/reference-data/manifest.json').read_text())
assert 'manifest.json' not in manifest['rawFiles'], 'A manifest must not hash itself'
assert hashlib.sha256((root / 'docs/accuracy-gates.json').read_bytes()).hexdigest() == manifest['accuracyGatesSHA256'], 'Frozen accuracy gates changed'
for name, digest in manifest['rawFiles'].items():
    assert hashlib.sha256((root / 'docs/reference-data' / name).read_bytes()).hexdigest() == digest, 'Reference response hash mismatch: ' + name
assert len(json.loads((root / 'Packages/HypergateCore/Tests/HypergateCoreTests/Fixtures/positions.json').read_text())) == manifest['positionCount']
assert len(json.loads((root / 'Packages/HypergateCore/Tests/HypergateCoreTests/Fixtures/events.json').read_text())) == manifest['eventCount']
lock = json.loads((root / 'HypergateBar.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved').read_text())
assert len(lock['pins']) == 1 and lock['pins'][0]['identity'] == 'sparkle'
assert lock['pins'][0]['state']['revision'] == 'ac2def288cbff5cfc7df3ffef6abdf45b72bcb0a'
ET.parse(root / 'HypergateBar.xcodeproj/xcshareddata/xcschemes/HypergateBar.xcscheme')
ET.parse(root / 'docs/appcast.xml')
for path in (root / 'Packages/HypergateCore/Sources/HypergateCore').glob('*.swift'):
    for framework in ['SwiftUI', 'AppKit', 'UserNotifications', 'ServiceManagement', 'Sparkle']:
        assert 'import ' + framework not in path.read_text(), 'Platform framework in calculation library'
print('Reference hashes, frozen gates, dependency lock, scheme, feed, and Foundation-only boundary verified.')
