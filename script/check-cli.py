#!/usr/bin/env python3
import json
import pathlib
import subprocess
import sys
from schema import schema, validate

binary = sys.argv[1]
output = pathlib.Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
commands = {
    'sky-example.json': ['sky', '--at', '2026-09-08T19:00:00Z', '--json'],
    'events-example.json': ['events', '--from', '2026-09-08T00:00:00Z', '--to', '2026-10-08T00:00:00Z', '--types', 'ingress,square,opposition,station', '--json'],
}
for name, arguments in commands.items():
    result = subprocess.run([binary, *arguments], capture_output=True, text=True, check=True)
    assert not result.stderr, 'Successful CLI diagnostics leaked into stderr'
    document = json.loads(result.stdout)
    validate(document, schema)
    (output / name).write_text(result.stdout)
for arguments in [[], ['unknown'], ['sky', '--at', '2026-02-30T12:00:00Z'], ['sky', '--at', '2026-09-08T12:00:00'],
                  ['sky', '--at', '2026-09-08T12:00:00Z', '--bodies', 'unknown'],
                  ['events', '--from', '2026-01-01T00:00:00Z', '--to', '2027-01-01T00:00:00Z'],
                  ['events', '--from', '2026-10-01T00:00:00Z', '--to', '2026-09-01T00:00:00Z']]:
    result = subprocess.run([binary, *arguments], capture_output=True, text=True)
    assert result.returncode != 0 and not result.stdout
    error = json.loads(result.stderr)
    assert error['schemaVersion'] == 1 and 'error' in error
help_result = subprocess.run([binary, '--help'], capture_output=True, text=True)
assert help_result.returncode == 0 and help_result.stdout and not help_result.stderr
print('Both documented CLI examples, help, and seven invalid-input/error-stream cases verified.')
