import assert from 'node:assert/strict';
import { readFile, stat } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const dist = resolve(here, 'dist');
execFileSync(process.execPath, [resolve(here, 'build.mjs')], { stdio: 'inherit' });
const changelog = await readFile(resolve(root, 'CHANGELOG.md'));
const info = JSON.parse(await readFile(resolve(dist, 'build-info.json'), 'utf8'));
const published = JSON.parse(await readFile(resolve(dist, 'changelog.json'), 'utf8'));
assert.equal(info.changelogSHA256, createHash('sha256').update(changelog).digest('hex'));
assert.equal(info.entries, published.entries.length);
for (const page of ['index.html', 'changelog/index.html']) {
  const html = await readFile(resolve(dist, page), 'utf8');
  assert.equal((html.match(/<h1[ >]/g) ?? []).length, 1);
  assert(!/\{\{[A-Z_]+\}\}/.test(html));
  assert(html.includes('https://github.com/theleoking-astrology/hypergate-bar'));
  assert(!/<script[^>]+src=["']https?:/i.test(html));
  const header = html.match(/<header\b[\s\S]*?<\/header>/)?.[0] ?? '';
  assert(header.includes('src="/assets/hypergate-wordmark.webp"'), 'The full Hypergate AI logo must appear in the header.');
  for (const match of html.matchAll(/(?:href|src)="(\/[^"#]*)/g)) {
    const path = match[1].endsWith('/') ? `${match[1]}index.html` : match[1];
    assert((await stat(resolve(dist, `.${path}`))).isFile(), `Missing ${path}`);
  }
}
assert((await readFile(resolve(dist, 'styles.css'), 'utf8')).includes('prefers-reduced-motion'));
assert(!/fetch\s*\(|XMLHttpRequest|sendBeacon/.test(await readFile(resolve(dist, 'site.js'), 'utf8')));
console.log('Website checks passed: generated changelog provenance, routes, local assets, and no runtime requests.');
