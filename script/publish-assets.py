#!/usr/bin/env python3
"""Publish only verified assets, then update the repository-hosted feed atomically."""
import base64
import datetime
import email.utils
import hashlib
import json
import os
import pathlib
import re
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

repository = os.environ['GITHUB_REPOSITORY']
tag = os.environ['HYPERGATE_RELEASE_TAG']
commit = os.environ['HYPERGATE_RELEASE_SHA']
assert re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository)
assert re.fullmatch(r'v\d+\.\d+\.\d+', tag)
assert re.fullmatch(r'[a-f0-9]{40}', commit)
assert os.environ['SPARKLE_FEED_URL'] == f'https://raw.githubusercontent.com/{repository}/main/docs/appcast.xml', 'This publisher supports only its exact repository-hosted feed.'
token = os.environ['GH_TOKEN']
base = f'https://api.github.com/repos/{repository}'

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        assert urllib.parse.urlparse(new_url).scheme == 'https', 'Refusing an insecure asset redirect'
        redirected = super().redirect_request(request, response, code, message, headers, new_url)
        if urllib.parse.urlparse(request.full_url).netloc != urllib.parse.urlparse(new_url).netloc:
            redirected.remove_header('Authorization')
        return redirected

urllib.request.install_opener(urllib.request.build_opener(SafeRedirect()))

def api(method, suffix, payload=None, absent=False, raw=None, media='application/json'):
    url = suffix if suffix.startswith('https://uploads.github.com/') else base + suffix
    data = raw if raw is not None else json.dumps(payload).encode() if payload is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                    headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                                             'Content-Type': media, 'X-GitHub-Api-Version': '2022-11-28'})
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            body = response.read()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        if absent and error.code == 404:
            return None
        raise RuntimeError(f'GitHub {method} failed with HTTP {error.code}; existing assets were preserved.') from None

assert api('GET', '/releases/tags/' + tag, absent=True) is None, 'A release for this tag already exists; never overwrite assets.'
assert api('GET', '/commits/' + tag)['sha'] == commit
output = pathlib.Path('dist') / tag
archive = output / f'HypergateBar-{tag[1:]}-arm64.zip'
signature = json.loads((output / 'update-signature.json').read_text())
assert signature['length'] == archive.stat().st_size
release = api('POST', '/releases', {'tag_name': tag, 'target_commitish': commit, 'name': 'HypergateBar ' + tag,
                                  'draft': True, 'body': 'Developer ID signed, notarized and stapled Apple Silicon build. See bundled notices, SHA256SUMS, and the matching source tag for calculation conventions and limitations.'})
for path in [archive, output / 'LICENSE', output / 'THIRD_PARTY_NOTICES.md', output / 'SHA256SUMS', output / 'update-signature.json']:
    url = release['upload_url'].split('{')[0] + '?name=' + urllib.parse.quote(path.name)
    uploaded = api('POST', url, raw=path.read_bytes(), media='application/octet-stream')
    assert uploaded['size'] == path.stat().st_size
    # Read authenticated draft asset bytes back and compare SHA-256 before making
    # the release public. A successful upload alone is not distribution proof.
    request = urllib.request.Request(base + '/releases/assets/' + str(uploaded['id']),
                                    headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/octet-stream'})
    with urllib.request.urlopen(request, timeout=90) as response:
        downloaded = response.read()
    assert hashlib.sha256(downloaded).digest() == hashlib.sha256(path.read_bytes()).digest(), 'Release asset readback failed'
api('PATCH', '/releases/' + str(release['id']), {'draft': False})
asset_url = f'https://github.com/{repository}/releases/download/{tag}/{archive.name}'
with urllib.request.urlopen(asset_url, timeout=90) as response:
    assert hashlib.sha256(response.read()).digest() == hashlib.sha256(archive.read_bytes()).digest()
feed = api('GET', '/contents/docs/appcast.xml?ref=main')
root = ET.fromstring(base64.b64decode(feed['content']))
channel = root.find('channel')
assert channel is not None
namespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', namespace)
assert all(item.findtext('{' + namespace + '}shortVersionString') != tag[1:] for item in channel.findall('item'))
item = ET.Element('item')
ET.SubElement(item, 'title').text = 'HypergateBar ' + tag
ET.SubElement(item, '{' + namespace + '}shortVersionString').text = tag[1:]
import plistlib
with pathlib.Path('App/Resources/Info.plist').open('rb') as file:
    build = plistlib.load(file)['CFBundleVersion']
ET.SubElement(item, '{' + namespace + '}version').text = str(build)
ET.SubElement(item, '{' + namespace + '}minimumSystemVersion').text = '14.0.0'
ET.SubElement(item, '{' + namespace + '}hardwareRequirements').text = 'arm64'
ET.SubElement(item, 'pubDate').text = email.utils.format_datetime(datetime.datetime.now(datetime.timezone.utc))
ET.SubElement(item, 'enclosure', {'url': asset_url, 'type': 'application/octet-stream',
                                'length': str(signature['length']), '{' + namespace + '}edSignature': signature['edSignature']})
channel.insert(0, item)
content = ET.tostring(root, encoding='utf-8', xml_declaration=True)
api('PUT', '/contents/docs/appcast.xml', {'message': 'Publish verified HypergateBar update ' + tag, 'branch': 'main',
                                      'sha': feed['sha'], 'content': base64.b64encode(content).decode()})
print('Published verified release assets and matching update-feed entry for ' + tag)
