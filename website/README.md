# HypergateBar website

A dependency-free static product site, built with Node.js 20 or newer and hosted separately from the native application. The repository-root `vercel.json` builds `website/dist/`. No runtime API, account, tracking script, or analytics is included.

```sh
node website/check.mjs
python3 -m http.server 4173 --directory website/dist
```

Open http://localhost:4173. Check desktop and narrow screens, screenshot tabs, enlargement and Escape, copy feedback, FAQ disclosure, keyboard focus, and the changelog route.

## Updating the site

Edit the root `CHANGELOG.md`, keeping one `##` heading per version and `- ` bullets for changes. The build generates the homepage's latest changes, `/changelog/`, and `/changelog.json` from that single file. Commit and push to the Git-linked production branch to trigger Vercel. `build-info.json` records the source commit and changelog SHA-256 for deployment verification.

Keep unfinished versions labeled Unreleased. Add a binary download only after its signed, notarized release assets are verified. A website deployment does not distribute a native app update; that requires a higher application build and a verified, signed archive in the publisher's Sparkle feed. See [the release runbook](../docs/release-runbook.md).

## Assets and attribution

The owner explicitly authorized these existing Hypergate brand assets for this public website:

| Asset | SHA-256 |
| --- | --- |
| `assets/hypergate-icon.png` | `5bfd2ed6b93564e0c7daebcac0bf961ce5a59cf5295ae6f7ce423b1604126759` |
| `assets/hypergate-wordmark.webp` | `9155f8a484c1a4db89c4feccfb0e569eda9d5da67b548142610890bc5615be02` |

App screenshots come from this repository's actual running native application. The menu screenshot is cropped for presentation with CSS; source pixels are unchanged. Screenshots show dated examples, not a live sky feed. No private product code or operational material is included.

The original website code is MIT-licensed. Hypergate identity assets remain brand identifiers; forks should replace them and avoid implying endorsement. CodexBar was a visual reference for a compact utility product site; no CodexBar code or assets are included.
