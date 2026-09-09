import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve, dirname } from 'node:path';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const output = resolve(here, 'dist');
const escape = value => value.replace(/[&<>"']/g, character => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[character]);
const inline = value => escape(value).replace(/`([^`]+)`/g, '<code>$1</code>');
const changelog = await readFile(resolve(root, 'CHANGELOG.md'), 'utf8');
const entries = changelog.split(/^## /m).slice(1).map(part => {
  const [title, ...lines] = part.trim().split('\n');
  const items = lines.filter(line => line.startsWith('- ')).map(line => line.slice(2));
  const paragraphs = lines.filter(line => line.trim() && !line.startsWith('- '));
  return { title, items, paragraphs };
});
if (!entries.length || entries.some(entry => !entry.items.length)) throw new Error('Changelog requires a heading and change entries.');
const latest = entries[0];
const changes = entries.map((entry, index) => `<article class="release-entry" id="release-${index + 1}"><div class="release-marker" aria-hidden="true"></div><div><p class="eyebrow">${index === 0 ? 'LATEST UPDATE' : 'PREVIOUS UPDATE'}</p><h2>${inline(entry.title)}</h2><ul>${entry.items.map(item => `<li>${inline(item)}</li>`).join('')}</ul>${entry.paragraphs.map(paragraph => `<p class="release-note">${inline(paragraph)}</p>`).join('')}</div></article>`).join('\n');
const replacements = {
  '{{CHANGELOG}}': changes,
  '{{LATEST_TITLE}}': inline(latest.title),
  '{{LATEST_ITEMS}}': latest.items.slice(0, 3).map(item => `<li>${inline(item)}</li>`).join(''),
};
await mkdir(resolve(output, 'changelog'), { recursive: true });
await mkdir(resolve(output, 'hypergate-bar'), { recursive: true });
await mkdir(resolve(output, 'assets'), { recursive: true });
for (const [source, target] of [['portal.html', 'index.html'], ['index.html', 'hypergate-bar/index.html'], ['changelog.html', 'changelog/index.html']]) {
  let html = await readFile(resolve(here, source), 'utf8');
  for (const [key, value] of Object.entries(replacements)) html = html.replaceAll(key, value);
  if (/\{\{[A-Z_]+\}\}/.test(html)) throw new Error('Unresolved site template field');
  await writeFile(resolve(output, target), html);
}
const files = {
  'website/styles.css': 'styles.css',
  'website/portal.css': 'portal.css',
  'website/site.js': 'site.js',
  'website/assets/hypergate-icon.png': 'assets/hypergate-icon.png',
  'website/assets/hypergate-wordmark.webp': 'assets/hypergate-wordmark.webp',
  'docs/screenshots/dashboard-final.png': 'assets/dashboard.png',
  'docs/screenshots/dashboard-upcoming.png': 'assets/upcoming.png',
  'docs/screenshots/dashboard-planets-light.png': 'assets/planets.png',
  'docs/screenshots/menu-popover-updates-macos26.png': 'assets/menu-popover.png',
};
for (const [source, target] of Object.entries(files)) await copyFile(resolve(root, source), resolve(output, target));
await writeFile(resolve(output, 'changelog.json'), JSON.stringify({ entries }, null, 2) + '\n');
await writeFile(resolve(output, 'robots.txt'), 'User-agent: *\nAllow: /\n');
await writeFile(resolve(output, '404.html'), '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Page not found · HypergateBar</title><link rel="stylesheet" href="/styles.css"><main class="container text-page"><p class="eyebrow">404</p><h1>Nothing in this orbit.</h1><p>This page could not be found.</p><a class="button primary" href="/">Back to HypergateBar</a></main></html>');
const manifest = { changelogSHA256: createHash('sha256').update(changelog).digest('hex'), sourceCommit: process.env.VERCEL_GIT_COMMIT_SHA ?? 'local', entries: entries.length };
await writeFile(resolve(output, 'build-info.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Built static HypergateBar site with ${entries.length} changelog entry; no dependencies or runtime requests.`);
