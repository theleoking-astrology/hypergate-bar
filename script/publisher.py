#!/usr/bin/env python3
"""Protected publisher entry point. Temporary signing material is always cleaned up."""
import base64
import os
import pathlib
import secrets
import shlex
import signal
import subprocess
import tempfile

def run(*arguments):
    subprocess.run(arguments, check=True, stdout=subprocess.DEVNULL)

def interrupted(signum, frame):
    raise SystemExit('Publisher interrupted; cleaning up temporary signing material.')

assert os.environ.get('GITHUB_ACTIONS') == 'true'
assert os.environ.get('HYPERGATE_PROTECTED_PUBLISHER') == 'verified'
assert pathlib.Path('/usr/bin/trash').is_file(), 'Required recoverable cleanup tool /usr/bin/trash is unavailable.'
subprocess.run(['python3', 'script/validate-publisher.py'], check=True)
for name in ['APPLE_CERTIFICATE_P12_BASE64', 'APPLE_CERTIFICATE_PASSWORD', 'NOTARY_API_KEY_BASE64',
             'NOTARY_KEY_ID', 'NOTARY_ISSUER_ID', 'SPARKLE_PRIVATE_ED_KEY']:
    assert os.environ.get(name), 'Missing protected publisher secret: ' + name
for signum in [signal.SIGINT, signal.SIGTERM]:
    signal.signal(signum, interrupted)
directory = pathlib.Path(tempfile.mkdtemp(prefix='HypergateBar-publisher-')).resolve()
keychain = directory / 'publisher.keychain-db'
certificate = directory / 'certificate.p12'
notary_key = directory / 'notary.p8'
original = shlex.split(subprocess.check_output(['security', 'list-keychains', '-d', 'user'], text=True))
password = secrets.token_urlsafe(40)
try:
    certificate.write_bytes(base64.b64decode(os.environ['APPLE_CERTIFICATE_P12_BASE64'], validate=True))
    notary_key.write_bytes(base64.b64decode(os.environ['NOTARY_API_KEY_BASE64'], validate=True))
    certificate.chmod(0o600)
    notary_key.chmod(0o600)
    run('security', 'create-keychain', '-p', password, str(keychain))
    run('security', 'set-keychain-settings', '-lut', '3600', str(keychain))
    run('security', 'unlock-keychain', '-p', password, str(keychain))
    run('security', 'import', str(certificate), '-k', str(keychain), '-P', os.environ['APPLE_CERTIFICATE_PASSWORD'],
        '-T', '/usr/bin/codesign', '-T', '/usr/bin/security')
    run('security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, str(keychain))
    run('security', 'list-keychains', '-d', 'user', '-s', str(keychain), *original)
    run('xcrun', 'notarytool', 'store-credentials', os.environ['NOTARY_KEYCHAIN_PROFILE'], '--key', str(notary_key),
        '--key-id', os.environ['NOTARY_KEY_ID'], '--issuer', os.environ['NOTARY_ISSUER_ID'], '--keychain', str(keychain))
    subprocess.run(['bash', 'script/release.sh'], check=True)
finally:
    # Restore the search list before locking and moving each verified temporary
    # file to Trash. Never use a permanent-deletion fallback.
    cleanup_errors = []
    def cleanup(arguments):
        try:
            subprocess.run(arguments, check=True, stdout=subprocess.DEVNULL)
        except Exception:
            cleanup_errors.append('Temporary publisher cleanup action failed: ' + arguments[0])
    cleanup(['security', 'list-keychains', '-d', 'user', '-s', *original])
    if keychain.exists():
        cleanup(['security', 'lock-keychain', str(keychain)])
    for path in [certificate, notary_key, keychain]:
        if path.exists():
            assert path.parent == directory and path.is_file()
            cleanup(['/usr/bin/trash', str(path)])
    if directory.exists():
        cleanup(['/usr/bin/trash', str(directory)])
    if cleanup_errors:
        raise RuntimeError('; '.join(cleanup_errors))
subprocess.run(['python3', 'script/publish-assets.py'], check=True)
