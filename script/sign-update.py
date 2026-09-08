#!/usr/bin/env python3
import json
import os
import pathlib
import subprocess
import sys

archive, output, derived = map(pathlib.Path, sys.argv[1:])
tool = derived / 'SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update'
secret = os.environ.get('SPARKLE_PRIVATE_ED_KEY')
if not secret:
    sys.exit('Protected SPARKLE_PRIVATE_ED_KEY is required; no unrelated Keychain key will be selected.')
signature = subprocess.run([str(tool), '--ed-key-file', '-', '-p', str(archive)], input=secret,
                           text=True, capture_output=True, check=True).stdout.strip()
subprocess.run(['xcrun', 'swift', 'script/verify-update.swift', str(archive), signature], check=True)
output.write_text(json.dumps({'edSignature': signature, 'length': archive.stat().st_size}, indent=2) + '\n')
