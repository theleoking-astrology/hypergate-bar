#!/usr/bin/env python3
"""Focused public-tree audit; this does not claim exhaustive secret detection."""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
excluded = {'.git', '.build', '.venv', '.swiftpm', 'build', 'dist', '__pycache__', 'xcuserdata'}
patterns = [r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----', r'gh[pousr]_[A-Za-z0-9]{30,}', r'AKIA[A-Z0-9]{16}',
            r'linear\.app/', r'/Users/[^/]+/', r'api[_-]?key\s*[:=]\s*["\']sk-[A-Za-z0-9]{20,}']
checked = 0
for path in root.rglob('*'):
    relative = path.relative_to(root)
    if any(part in excluded for part in relative.parts) or not path.is_file() or path.suffix in {'.png', '.jpg', '.icns'}:
        continue
    try:
        content = path.read_text()
    except UnicodeDecodeError:
        continue
    if relative.as_posix() == 'script/audit-public.py':
        continue
    for pattern in patterns:
        assert not re.search(pattern, content), 'Potential confidential material in ' + str(relative)
    checked += 1
print(f'Focused public-tree audit passed for {checked} text files; manually inspect screenshots and the selective Git diff before publication.')
