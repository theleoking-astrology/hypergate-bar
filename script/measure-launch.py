#!/usr/bin/env python3
"""Measure process launch to the first real sky snapshot receipt, with 10ms polling."""
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

app = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2]).resolve()
assert subprocess.run(['pgrep', '-x', 'HypergateBar'], capture_output=True).returncode != 0, 'Quit the current HypergateBar before measuring a new process launch.'
directory = pathlib.Path(tempfile.mkdtemp(prefix='HypergateBar-launch-'))
receipt = directory / 'ready.json'
environment = dict(os.environ, HYPERGATE_LAUNCH_RECEIPT=str(receipt))
start = time.perf_counter()
with (directory / 'application.log').open('wb') as log:
    process = subprocess.Popen([str(app / 'Contents/MacOS/HypergateBar'), '--dashboard'], env=environment, stdout=log, stderr=log, start_new_session=True)
while not receipt.exists():
    assert process.poll() is None, 'App exited before the first sky snapshot'
    assert time.perf_counter() - start < 30, 'Launch readiness timeout'
    time.sleep(0.01)
elapsed = time.perf_counter() - start
result = {'launchToFirstRealSkySeconds': elapsed, 'pollingResolutionSeconds': 0.01, 'pid': process.pid,
          'definition': 'Fresh process spawn to an engine-derived sky snapshot receipt; excludes build time and is not pixel-presentation latency',
          'snapshot': json.loads(receipt.read_text())}
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2), flush=True)
if '--hold' in sys.argv[3:]:
    process.wait()
