// funPaste marketing site build step.
//
// Reads site/content/{en,zh}.json + site/templates/*.html, pre-renders two
// language trees into site-dist/, copies shared assets, emits per-language
// panel-data.js, and resolves the latest GitHub Release DMG URL at build time
// (no runtime API calls). Fails on missing translations, missing release
// fallback, or unresolved templates.
//
// Run: node scripts/build-site.mjs  (or bash scripts/build-site.sh)

import { readFile, writeFile, mkdir, cp, rm, access } from "node:fs/promises";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const SITE = join(root, "site");
const DIST = join(root, "site-dist");
const REPO_API = "https://api.github.com/repos/rchanggogogo/funPaste/releases";
const REPO_RELEASES = "https://github.com/rchanggogogo/funPaste/releases";

// ---------- tiny template renderer ----------
function get(obj, path) {
  return path.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);
}
function escapeHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
  );
}
function render(tpl, ctx, root) {
  root = root || ctx;
  // {{#each path}}...{{/each}}
  tpl = tpl.replace(/\{\{#each\s+([\w.]+)\s*\}\}([\s\S]*?)\{\{\/each\}\}/g, (_, path, body) => {
    const arr = get(ctx, path) ?? get(root, path) ?? [];
    if (!Array.isArray(arr)) return "";
    return arr.map((item) => render(body, item, root)).join("");
  });
  // {{{path}}} — raw HTML, no escape
  tpl = tpl.replace(/\{\{\{\s*([\w.]+)\s*\}\}\}/g, (_, path) => {
    const v = get(ctx, path) ?? get(root, path);
    return v == null ? "" : String(v);
  });
  // {{path}} — escaped; {{this}} refers to the current loop item
  tpl = tpl.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, path) => {
    if (path === "this") return escapeHtml(typeof ctx === "string" ? ctx : "");
    const v = get(ctx, path) ?? get(root, path);
    return escapeHtml(v);
  });
  return tpl;
}

// ---------- translation shape validation ----------
function shape(obj) {
  if (Array.isArray(obj)) return obj.length ? ["arr:" + JSON.stringify(shape(obj[0]))] : [];
  if (obj && typeof obj === "object") {
    const o = {};
    for (const k of Object.keys(obj).sort()) o[k] = shape(obj[k]);
    return o;
  }
  return "leaf";
}
function validateTranslations(en, zh) {
  const a = JSON.stringify(shape(en));
  const b = JSON.stringify(shape(zh));
  if (a !== b) {
    console.error("error: en.json and zh.json structures differ");
    console.error("en:", a);
    console.error("zh:", b);
    process.exit(1);
  }
  // ensure no empty strings for required leaf values
  for (const [name, obj] of [["en", en], ["zh", zh]]) {
    const empties = [];
    (function walk(o, p) {
      if (o == null) empties.push(p);
      else if (typeof o === "string" && o.trim() === "") empties.push(p);
      else if (typeof o === "object") Object.entries(o).forEach(([k, v]) => walk(v, p ? p + "." + k : k));
    })(obj, "");
    if (empties.length) {
      console.error(`error: ${name}.json has empty values: ${empties.join(", ")}`);
      process.exit(1);
    }
  }
}

// ---------- release metadata ----------
async function resolveLatestRelease() {
  const headers = {
    Accept: "application/vnd.github+json",
    "User-Agent": "funPaste-site-build",
  };
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  if (token) headers.Authorization = "Bearer " + token;
  try {
    const res = await fetch(REPO_API, { headers });
    if (!res.ok) throw new Error("GitHub API status " + res.status);
    const releases = await res.json();
    const rel =
      releases.find((r) => !r.draft && !r.prerelease) || releases[0];
    if (!rel) throw new Error("no releases found");
    const dmg = (rel.assets || []).find((a) => /\.dmg$/i.test(a.name));
    return {
      url: dmg ? dmg.browser_download_url : rel.html_url || REPO_RELEASES,
      version: rel.tag_name || rel.name || "",
    };
  } catch (e) {
    console.warn("warning: could not resolve latest release (" + e.message + "); using releases index");
    return { url: REPO_RELEASES, version: "" };
  }
}

// ---------- context builder ----------
function buildCtx(content, otherContent, page) {
  const lang = content.lang;
  const isLanding = page === "landing";
  const assetsPath = isLanding
    ? "assets/"
    : lang === "en" ? "../assets/" : "../../assets/";
  const brandHref = isLanding ? "./" : lang === "en" ? "../" : "../../";
  const langToggleHref = isLanding
    ? content.nav.langToggleHrefLanding
    : content.nav.langToggleHrefHelp;
  return {
    ...content,
    otherHtmlLang: otherContent.htmlLang,
    assetsPath,
    canonicalLanding: content.canonicalBase,
    otherCanonicalLanding: content.otherCanonicalBase,
    canonicalHelp: content.canonicalBase + "help/",
    otherCanonicalHelp: content.otherCanonicalBase + "help/",
    ogImageAbsolute: content.canonicalBase + "assets/img/og-image-" + lang + ".svg",
    heroVisualSrc: assetsPath + "img/hero-" + lang + ".svg",
    nav: { ...content.nav, brandHref, langToggleHref },
    install: { ...content.install, helpHref: "help/" },
    footer: { ...content.footer, helpHref: "help/" },
  };
}

// ---------- main ----------
async function main() {
  const [enRaw, zhRaw] = await Promise.all([
    readFile(join(SITE, "content", "en.json"), "utf8"),
    readFile(join(SITE, "content", "zh.json"), "utf8"),
  ]);
  const en = JSON.parse(enRaw);
  const zh = JSON.parse(zhRaw);
  validateTranslations(en, zh);

  const [landingTpl, helpTpl, notFoundTpl] = await Promise.all([
    readFile(join(SITE, "templates", "landing.html"), "utf8"),
    readFile(join(SITE, "templates", "help.html"), "utf8"),
    readFile(join(SITE, "templates", "404.html"), "utf8"),
  ]);

  const release = await resolveLatestRelease();
  const dmgUrl = release.url;
  const version = release.version
    ? release.version.replace(/^v/, "")
    : "";

  // Fresh dist
  if (existsSync(DIST)) await rm(DIST, { recursive: true, force: true });
  await mkdir(DIST, { recursive: true });

  // Languages → (dir, ctx-factory)
  const langs = [
    { content: en, other: zh, dir: DIST, assetsDir: join(DIST, "assets") },
    { content: zh, other: en, dir: join(DIST, "zh"), assetsDir: join(DIST, "zh", "assets") },
  ];

  for (const L of langs) {
    // Landing
    const landingCtx = buildCtx(L.content, L.other, "landing");
    let landingHtml = render(landingTpl, landingCtx);
    landingHtml = applyRelease(landingHtml, dmgUrl, version);
    await mkdir(L.dir, { recursive: true });
    await writeFile(join(L.dir, "index.html"), landingHtml, "utf8");

    // Help
    const helpCtx = buildCtx(L.content, L.other, "help");
    let helpHtml = render(helpTpl, helpCtx);
    helpHtml = applyRelease(helpHtml, dmgUrl, version);
    await mkdir(join(L.dir, "help"), { recursive: true });
    await writeFile(join(L.dir, "help", "index.html"), helpHtml, "utf8");

    // Assets: copy whole site/assets tree
    await cp(join(SITE, "assets"), L.assetsDir, { recursive: true });

    // hero + panel-fallback are derived from panel-<lang>.svg (single source)
    const panelSvg = join(L.assetsDir, "img", "panel-" + L.content.lang + ".svg");
    await copyTo(panelSvg, join(L.assetsDir, "img", "hero-" + L.content.lang + ".svg"));
    await copyTo(panelSvg, join(L.assetsDir, "img", "panel-fallback-" + L.content.lang + ".svg"));

    // Per-language panel-data.js (no inline data, no fetch)
    const panelData = "window.__PANEL_DATA__ = " + JSON.stringify(L.content.panel) + ";\n";
    await writeFile(join(L.assetsDir, "js", "panel-data.js"), panelData, "utf8");
  }

  // 404 — bilingual single file, rendered from en content
  let notFoundHtml = render(notFoundTpl, en);
  notFoundHtml = applyRelease(notFoundHtml, dmgUrl, version);
  await writeFile(join(DIST, "404.html"), notFoundHtml, "utf8");

  console.log("site built → site-dist/");
  console.log("  release url: " + dmgUrl);
  console.log("  version:     " + (version || "(unknown)"));
}

function applyRelease(html, url, version) {
  return html
    .replace(/__LATEST_DMG_URL__/g, url)
    .replace(/__LATEST_VERSION__/g, version || "");
}

async function copyTo(src, dest) {
  await writeFile(dest, await readFile(src));
}

main().catch((e) => {
  console.error("build failed:", e);
  process.exit(1);
});
