/* First-visit language redirect.
 *
 * - Only runs on the English root (the pages that load this script).
 * - If the visitor has already chosen a language (localStorage), do nothing —
 *   manual selection always wins.
 * - Otherwise, if the browser prefers Simplified Chinese, redirect to the
 *   Chinese tree. The redirect is a replace() so it does not create a back
 *   button trap.
 * - The language toggle itself is a normal link and works without this
 *   script; this file only smooths the first visit for Chinese visitors.
 *
 * No data leaves the browser. The only stored value is the language key in
 * localStorage, which is also set when the visitor uses the toggle.
 */
(function () {
  "use strict";
  try {
    if (localStorage.getItem("funPasteLang")) return;
  } catch (e) { /* localStorage unavailable — stay put */ }

  var langs = navigator.languages || [navigator.language || ""];
  var prefersZh = langs.some(function (l) {
    return typeof l === "string" && l.toLowerCase().indexOf("zh") === 0;
  });
  if (!prefersZh) return;

  // Derive the Chinese equivalent of the current path.
  // English root  -> /zh/   (and /help/ -> /zh/help/, etc.)
  var path = window.location.pathname.replace(/\/+$/, "") + "/";
  var base = path.replace(/\/funPaste\//, "/funPaste/zh/");
  // Guard: avoid double-prefixing if already under /zh/.
  if (base.indexOf("/zh/") !== -1 && path.indexOf("/zh/") !== -1) return;
  var target = base + window.location.search + window.location.hash;
  window.location.replace(target);
})();

/* Record an explicit language choice when the visitor lands on a localized
 * page via the toggle. Each page sets data-lang on <html>; if present we
 * persist it so the redirect above stops firing on future visits. */
(function () {
  "use strict";
  var lang = document.documentElement.getAttribute("data-lang");
  if (!lang) return;
  try { localStorage.setItem("funPasteLang", lang); } catch (e) { /* ignore */ }
})();
