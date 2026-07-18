# Marketing Website Design

> Stage: revised specification, implementation not started.
> This revision narrows the first release to a PH-ready marketing MVP and resolves
> the earlier conflicts around GitHub Pages paths, i18n, downloads, privacy, and
> changelog automation.

## Decisions

1. **Primary goal** — Convert qualified Mac visitors into downloads while building enough trust for an ad-hoc-signed, unnotarized app.
2. **Launch scope** — Bilingual landing page plus a bilingual setup/help page. No independent privacy or changelog page in the MVP.
3. **Privacy** — The landing page explains the app's core privacy and permission behavior, then links to the matching repository policy: `PRIVACY.en.md` for English and `PRIVACY.md` for Chinese.
4. **Language** — English is available at the site root and Simplified Chinese under `zh/`. Both are pre-rendered static HTML.
5. **Hero** — Lightweight static visual on first paint. The interactive panel simulation lives below the fold.
6. **Hosting** — GitHub Pages project site at `https://rchanggogogo.github.io/funPaste/`.
7. **Download** — Primary CTA points directly to the latest universal DMG resolved at deploy time; a secondary link opens all GitHub Releases.

## Goal

In one short visit, a Mac user should be able to:

1. Understand that funPaste is a keyboard-first clipboard, favorites, and prompt panel rather than a flat clipboard list.
2. See how `Shift + Command + V` fits into daily work.
3. Understand why the app requests Accessibility permission and why first launch requires Control-click → Open.
4. Verify that clipboard data stays local and reach the canonical privacy statement.
5. Download the correct universal DMG without having to identify the asset manually.

## Non-goals

- A blog, documentation portal, community forum, changelog mirror, or account system.
- A backend, email capture, analytics, A/B testing, cookies, or third-party runtime services.
- Self-hosting or mirroring release assets outside GitHub Releases.
- An auto-updater.
- Languages beyond English and Simplified Chinese.
- Redesigning the app's visual identity.
- A custom domain, light theme, staging environment, or PR preview for the first launch.

## Audience

- **Primary:** Mac users such as developers, designers, and writers who copy and reuse content frequently.
- **Secondary:** Product Hunt visitors, contributors, and reviewers checking whether the project is legitimate and safe enough to try.
- Compatibility is stated near every download CTA: **macOS 14+ · Apple silicon and Intel · not notarized**.
- The site never implies Windows, Linux, iOS, or App Store availability.

## URLs and GitHub Pages base path

The launch host is a GitHub Pages **project site**, so `/funPaste/` is part of the public path:

```text
https://rchanggogogo.github.io/funPaste/           English landing page
https://rchanggogogo.github.io/funPaste/zh/        Chinese landing page
https://rchanggogogo.github.io/funPaste/help/      English setup guide
https://rchanggogogo.github.io/funPaste/zh/help/   Chinese setup guide
```

- Generated pages use relative internal links and asset URLs so local preview and the GitHub Pages subpath behave the same.
- Do not use root-relative links such as `/privacy`, `/help`, or `/assets/...` while hosted as a project site.
- Generate a conventional `404.html` with a link back to the English and Chinese landing pages. Unknown paths do not masquerade as a successful landing-page response.
- If a custom domain is added later, canonical URLs and base-path configuration can change to root-level paths such as `/privacy/`.

## Information architecture

### Landing page

1. **Hero**
   - Product name and one-line promise: “Copying is only the beginning.”
   - `⇧⌘V` shortcut badge.
   - Primary **Download latest DMG** CTA.
   - Secondary **See how it works** anchor.
   - Visible compatibility and notarization line.
   - Localized still captured from the real app, not a fabricated browser-only UI.

2. **Why funPaste**
   - Stay in flow.
   - Prompts as first-class content.
   - Local-first.

3. **Interactive panel simulation**
   - A browser simulation based on the existing `preview/` prototype.
   - Supports category switching, search, keyboard selection, and prompt-variable completion using mock data.
   - Copy must call it an **interactive simulation**, not “the actual panel.”
   - Do not claim that Enter pastes into another Mac app; in the simulation it selects or previews the chosen item.

4. **Features**
   - Text, image, and file clipboard history.
   - Search and keyboard navigation.
   - Favorites and reusable prompts.
   - Prompt-variable completion.
   - Pause recording and clear history.
   - Menu-bar operation and bilingual UI.

5. **Install and first use**
   - Download the universal DMG.
   - Drag funPaste to Applications.
   - Control-click the app and choose Open.
   - Allow Accessibility only if automatic paste is desired.
   - Link to the full help page.

6. **Privacy and trust**
   - Clearly scope claims to **the app**: no account, telemetry, ads, network sync, or clipboard-body logging.
   - State that history is stored locally through macOS preferences without additional app-level encryption.
   - Explain that sensitive-content filtering is heuristic.
   - Link to the matching GitHub policy (`PRIVACY.en.md` or `PRIVACY.md`); do not duplicate either full policy into a website page.
   - Before launch, update `PRIVACY.md` so its data list includes file clipboard history as well as text and images.

7. **Final download and footer**
   - Repeat the direct DMG CTA and compatibility line.
   - Links: GitHub repository, all Releases, Help, `PRIVACY.md`, MIT License, and language switch.
   - No newsletter, social wall, account CTA, or fake testimonial.

### Help page

- Installation steps with current macOS wording.
- Gatekeeper first-open instructions.
- Accessibility permission purpose and the manual-paste fallback.
- First `Shift + Command + V` walkthrough.
- Common problems: panel does not open, automatic paste unavailable, app moved or deleted.
- Links back to Download, GitHub Issues, and the landing page.

### Changelog

- The MVP does not mirror GitHub release notes.
- “Changelog” links directly to GitHub Releases.
- A first-party changelog page may be added only when there is a clear end-user need.

## Language behavior

- Source copy lives in structured English and Simplified Chinese content files.
- A small static build step pre-renders:
  - English landing and help pages at the site root.
  - Chinese landing and help pages under `zh/`.
- Each page is complete without JavaScript and has its own title, description, canonical URL, and `hreflang` links.
- The language switch is a normal link and remains usable with JavaScript disabled.
- A small external script may use `navigator.languages` and `localStorage` to redirect a first-time Chinese-language visitor from the English root to `zh/`.
- Manual selection wins over browser preference and is the only value stored in `localStorage`.
- Missing translations fail the site build instead of silently rendering blank or mixed-language UI.

## Download behavior

- During site deployment, the build step queries the latest non-draft, non-prerelease GitHub Release and selects its `.dmg` asset.
- The resolved asset URL is written into the generated static HTML. Browsers do not call the GitHub API at runtime.
- Primary CTA: direct latest DMG asset.
- Secondary CTA: `https://github.com/rchanggogogo/funPaste/releases`.
- If release metadata cannot be resolved during deployment, the build uses the Releases index as the primary fallback rather than publishing a stale asset link.
- The download block may display the current version and GitHub-provided SHA-256 digest when available.
- No website copy claims Apple notarization or Developer ID signing.

## Visual and interaction direction

- Reuse the established palette from `preview/styles.css`:
  - ink `#121728`
  - citrus `#ff9f5b`
  - lilac `#b9a6ff`
  - mint `#88e2c1`
- Dark-first presentation matching the app panel.
- Use system fonts and self-hosted assets only.
- Hero visual should come from the real app and have localized English and Chinese variants when visible text differs.
- The interactive simulation may reuse behavior from `preview/`, but shared tokens should have one source copied by the site build to avoid manual drift.
- JavaScript-disabled browsers see a static screenshot and explanatory caption.
- `prefers-reduced-motion` disables nonessential animation but does not disable the interactive simulation.
- Create dedicated favicon sizes and a roughly 1200×630 social sharing image; do not use the square app icon as the OG image.

## Privacy and security

- No analytics, tracking pixels, forms, accounts, cookies, comments, remote fonts, or runtime third-party requests.
- The website necessarily loads from GitHub Pages; “no network requests” is an app claim, not a website claim.
- Clean page load should request only same-origin HTML, CSS, JavaScript, and image assets.
- The only persistent browser value is the language preference in `localStorage`.
- All scripts and styles are external files so a CSP meta policy can avoid `unsafe-inline`.
- Suggested resource policy:

```text
default-src 'self';
script-src 'self';
style-src 'self';
img-src 'self' data:;
font-src 'self';
connect-src 'none';
object-src 'none';
base-uri 'self';
form-action 'none';
```

- CSP does not need to allow GitHub as a resource origin merely because users can follow a normal link to GitHub.
- Pin GitHub Actions dependencies by full commit SHA.

## Implementation model

- Source: `site/`.
- Output: `site-dist/`.
- Stack: hand-written semantic HTML, CSS, and small vanilla JavaScript modules.
- Build: `scripts/build-site.sh` pre-renders the two language trees, copies shared assets, resolves release metadata, and validates required translations.
- Local preview:

```sh
bash scripts/build-site.sh
python3 -m http.server --directory site-dist
```

- The build must not modify or commit generated release metadata back to `main`.
- `site-dist/` is generated and remains untracked.

## Deployment

Use a separate `.github/workflows/site.yml`:

- **Triggers**
  - Push to `main` affecting `site/**`, `scripts/build-site.sh`, shared preview tokens, `PRIVACY.md`, or `PRIVACY.en.md`.
  - Successful completion of the `Release` workflow, so the direct download URL advances after a new release.
  - `workflow_dispatch` for manual recovery.
- **Runner:** `ubuntu-latest`.
- **Permissions:** `contents: read`, `pages: write`, `id-token: write`.
- **Steps:** checkout `main` → build `site-dist/` → validate → upload Pages artifact → deploy Pages.
- Do not trigger production deployment for changes limited to `docs/plans/**`.
- GitHub Pages Source must be configured once as **GitHub Actions**.
- Rollback is git-driven: revert the site change on `main` and redeploy, or re-run a known-good Pages deployment.

## SEO and sharing

- Unique English and Chinese titles and descriptions.
- Canonical URLs using the full GitHub Pages project path.
- Reciprocal `hreflang="en"` and `hreflang="zh-Hans"`.
- Open Graph and social card metadata using the dedicated 1200×630 image.
- Semantic headings and landmarks.
- Optional `SoftwareApplication` structured data may describe macOS 14+, price 0, current release, and download URL only when those values are generated from release metadata.

## Performance and accessibility budgets

- LCP < 2.5 seconds on throttled mobile.
- Total JavaScript < 30 KB gzipped.
- Lighthouse mobile: Performance ≥ 95, Accessibility ≥ 95, Best Practices = 100, SEO ≥ 95.
- WCAG 2.1 AA text contrast and visible keyboard focus.
- No layout shift above the fold.
- No autoplay media.
- Latest Safari, Chrome, and Firefox; Safari is primary.
- The mobile layout is usable at 360 px, including touch alternatives for demo interactions.

## Measurement tradeoff

- The MVP intentionally ships without visitor analytics.
- GitHub Release asset download counts are the only rough adoption signal.
- The site cannot reliably measure CTA conversion rate or referral source under this privacy model; this limitation is accepted for launch.

## Acceptance criteria

### Content and flows

- [ ] English and Chinese landing/help pages are complete without JavaScript.
- [ ] Hero shows the promise, direct DMG CTA, `⇧⌘V`, compatibility, and notarization status in the first viewport.
- [ ] Direct CTA resolves to the latest universal DMG; Releases fallback is always present.
- [ ] Install steps match behavior verified on a clean macOS account.
- [ ] Privacy claims match the localized README and privacy policy.
- [ ] No page calls the browser simulation the real app or claims it can paste into another application.

### Paths and language

- [ ] All pages and assets work under `/funPaste/`, not only at domain root.
- [ ] English and `zh/` pages contain reciprocal canonical and `hreflang` metadata.
- [ ] Language switch works without JavaScript; optional preference redirect respects manual choice.
- [ ] Unknown paths render the dedicated 404 page with working relative links.

### Demo and compatibility

- [ ] Simulation supports keyboard and touch category selection, search, item selection, and prompt completion.
- [ ] No-JS fallback shows a static real-app visual.
- [ ] Reduced-motion mode keeps the demo functional while removing nonessential animation.
- [ ] macOS-only compatibility is visible; no Windows or Linux support is implied.

### Privacy and security

- [ ] Clean load makes only same-origin runtime requests.
- [ ] No cookies, analytics, forms, remote fonts, or third-party scripts.
- [ ] `localStorage` contains only the language preference.
- [ ] CSP is present and scripts run without `unsafe-inline`.

### Quality and deployment

- [ ] Site build fails on missing translations, missing release fallback, broken internal links, or stale privacy references.
- [ ] Lighthouse and WCAG budgets pass.
- [ ] GitHub Pages deployment succeeds from `main`.
- [ ] A successful future Release workflow redeploys the site with the new direct DMG link without committing generated data to `main`.

## Deferred decisions

- Custom domain and root-level routes.
- Independent website privacy page.
- First-party changelog.
- PR preview deployments.
- Light theme.
- Privacy-preserving product analytics.
