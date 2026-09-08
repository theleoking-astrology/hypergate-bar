#!/usr/bin/env python3
"""Sample only the specified HypergateBar PID for five minutes with windows closed."""
import datetime
import json
import pathlib
import subprocess
import sys
import time

pid = int(sys.argv[1])
output = pathlib.Path(sys.argv[2])
def sample():
    fields = subprocess.check_output(['ps', '-p', str(pid), '-o', 'time=,rss=,comm='], text=True).strip().split(maxsplit=2)
    assert fields[2].endswith('/HypergateBar'), 'Unexpected process identity'
    parts = [float(value) for value in fields[0].split(':')]
    cpu = sum(value * 60 ** index for index, value in enumerate(reversed(parts)))
    return cpu, int(fields[1]) * 1024
before, memory = sample()
start = time.perf_counter()
samples = []
for index in range(10):
    time.sleep(30)
    cpu, resident = sample()
    samples.append({'elapsedSeconds': time.perf_counter() - start, 'cpuSeconds': cpu - before, 'residentBytes': resident})
elapsed = time.perf_counter() - start
result = {'measuredAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'durationSeconds': elapsed,
          'cpuSeconds': cpu - before, 'averageOneCoreCPUPercent': (cpu - before) / elapsed * 100,
          'maximumObservedResidentBytes': max([memory] + [row['residentBytes'] for row in samples]),
          'conditions': 'App running with Dashboard, Settings, and menu popover closed; forecast completed; alerts and updater disabled', 'samples': samples}
output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
