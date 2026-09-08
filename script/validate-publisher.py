#!/usr/bin/env python3
"""Fail closed without printing signing material."""
import base64
import os
import re
import sys
import urllib.parse

required = ['DEVELOPER_ID_APPLICATION', 'APPLE_TEAM_ID', 'NOTARY_KEYCHAIN_PROFILE', 'SPARKLE_PUBLIC_ED_KEY', 'SPARKLE_FEED_URL']
missing = [key for key in required if not os.environ.get(key)]
if missing:
    sys.exit('Publisher configuration missing: ' + ', '.join(missing))
identity = os.environ['DEVELOPER_ID_APPLICATION']
team = os.environ['APPLE_TEAM_ID']
if not identity.startswith('Developer ID Application: ') or not re.fullmatch(r'[A-Z0-9]{10}', team) or not identity.endswith('(' + team + ')'):
    sys.exit('Developer ID identity and Apple team do not match the required distribution identity format.')
try:
    key = base64.b64decode(os.environ['SPARKLE_PUBLIC_ED_KEY'], validate=True)
except ValueError:
    sys.exit('SPARKLE_PUBLIC_ED_KEY must be base64 Ed25519 public-key bytes.')
if len(key) != 32:
    sys.exit('SPARKLE_PUBLIC_ED_KEY must decode to 32 bytes.')
feed = urllib.parse.urlparse(os.environ['SPARKLE_FEED_URL'])
if feed.scheme != 'https' or not feed.hostname or feed.username or feed.password or feed.fragment:
    sys.exit('SPARKLE_FEED_URL must be an HTTPS publisher feed without credentials or fragment.')
print('All five publisher configuration values passed structural validation; identity, feed, and notarization access still require live verification.')
