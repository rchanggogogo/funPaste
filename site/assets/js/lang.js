/* Follow the visitor's saved language choice, or use the browser preference
 * until the visitor explicitly chooses from a language toggle.
 *
 * The toggle remains a normal link, so navigation still works without JS.
 * No data leaves the browser; only the explicit en/zh choice is persisted.
 */
(function () {
  "use strict";

  var current = document.documentElement.getAttribute("data-lang");
  if (!current) return;

  var toggles = document.querySelectorAll(".lang-toggle[hreflang]");
  var saved = null;
  try { saved = localStorage.getItem("funPasteLang"); } catch (e) { /* ignore */ }

  var preferred = saved;
  if (preferred !== "en" && preferred !== "zh") {
    var langs = navigator.languages || [navigator.language || ""];
    preferred = Array.prototype.some.call(langs, function (lang) {
      return typeof lang === "string" && lang.toLowerCase().indexOf("zh") === 0;
    }) ? "zh" : "en";
  }

  if (preferred !== current && toggles.length) {
    window.location.replace(toggles[0].href + window.location.search + window.location.hash);
    return;
  }

  Array.prototype.forEach.call(toggles, function (toggle) {
    toggle.addEventListener("click", function () {
      var target = toggle.getAttribute("hreflang");
      var choice = target && target.toLowerCase().indexOf("zh") === 0 ? "zh" : "en";
      try { localStorage.setItem("funPasteLang", choice); } catch (e) { /* ignore */ }
    });
  });
})();
