#!/usr/bin/env python3
"""Offline fail-closed configuration tests; never imports or uses real signing keys."""
import base64
import os
import subprocess

names = ['DEVELOPER_ID_APPLICATION', 'APPLE_TEAM_ID', 'NOTARY_KEYCHAIN_PROFILE', 'SPARKLE_PUBLIC_ED_KEY', 'SPARKLE_FEED_URL']
clean = {key: value for key, value in os.environ.items() if key not in names}
synthetic = {'DEVELOPER_ID_APPLICATION': 'Developer ID Application: Synthetic Test (TESTTEAM01)',
             'APPLE_TEAM_ID': 'TESTTEAM01', 'NOTARY_KEYCHAIN_PROFILE': 'synthetic-unused',
             'SPARKLE_PUBLIC_ED_KEY': base64.b64encode(bytes(32)).decode(),
             'SPARKLE_FEED_URL': 'https://example.invalid/appcast.xml'}
def check(values, succeeds):
    result = subprocess.run(['python3', 'script/validate-publisher.py'], env=dict(clean, **values), capture_output=True, text=True)
    assert (result.returncode == 0) == succeeds
check({}, False)
check(synthetic, True)
for name in names:
    values = dict(synthetic)
    values.pop(name)
    check(values, False)
for name, value in [('SPARKLE_FEED_URL', 'http://example.invalid/feed'), ('SPARKLE_FEED_URL', 'https://user:password@example.invalid/feed'),
                    ('SPARKLE_PUBLIC_ED_KEY', 'not-a-key'), ('APPLE_TEAM_ID', 'WRONGTEAM1'), ('DEVELOPER_ID_APPLICATION', '-')]:
    check(dict(synthetic, **{name: value}), False)
print('Twelve offline publisher configuration cases passed; no signing/notarization/publication attempted.')
