/* Interactive panel simulation for the funPaste marketing site.
 *
 * Data source: window.__PANEL_DATA__, emitted by the build step into a
 * per-language assets/js/panel-data.js file (no inline data, no fetch —
 * keeps CSP at connect-src 'none' and works under file://).
 *
 * This is a SIMULATION. It must never claim that Enter pastes into another
 * Mac app. Enter selects/previews the item in the simulation only. All
 * feedback copy is sourced from the data file so it can be localized and
 * audited.
 */
(function () {
  "use strict";

  // Reveal the live simulation (CSS hides it until JS runs, so no-JS
  // visitors see the static fallback instead of an empty deck).
  document.documentElement.classList.add("js");

  var data = window.__PANEL_DATA__;
  if (!data) return;

  var categories = data.categories;
  var clips = data.clips;
  var ui = data.ui;

  var activeCategory = "recent";
  var selectedID = clips[0] ? clips[0].id : null;
  var searchQuery = "";
  var toastTimer;

  var deck = document.querySelector("[data-clip-deck]");
  var titleEl = document.querySelector("[data-deck-title]");
  var labelEl = document.querySelector("[data-category-label]");
  var countEl = document.querySelector("[data-count-pill]");
  var editor = document.querySelector("[data-prompt-editor]");
  var toast = document.querySelector("[data-toast]");
  var searchInput = document.querySelector("[data-search-input]");
  if (!deck) return;

  function itemsForCurrentCategory() {
    var normalized = searchQuery.trim().toLowerCase();
    return clips.filter(function (clip) {
      var inCategory = activeCategory === "recent"
        ? clip.category === "recent" || clip.category === "prompt"
        : clip.category === activeCategory;
      return inCategory && (!normalized ||
        (clip.title + " " + clip.preview + " " + clip.source).toLowerCase().indexOf(normalized) !== -1);
    });
  }

  function escape(text) {
    return String(text).replace(/[&<>"']/g, function (ch) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[ch];
    });
  }

  function renderDeck() {
    var items = itemsForCurrentCategory();
    labelEl.textContent = categories[activeCategory].label;
    titleEl.textContent = categories[activeCategory].title;
    countEl.textContent = items.length + ui.countSuffix;
    if (!items.some(function (item) { return item.id === selectedID; })) {
      selectedID = items[0] ? items[0].id : null;
    }

    if (!items.length) {
      deck.innerHTML =
        '<div class="empty-state"><div><strong>' + escape(ui.emptyTitle) +
        '</strong>' + escape(ui.emptyBody) + '</div></div>';
      return;
    }

    deck.innerHTML = items.map(function (clip) {
      var selected = clip.id === selectedID;
      var body = clip.image
        ? '<div class="image-swatch"></div>'
        : '<p class="card-preview ' + (clip.code ? "code-preview" : "") + '">' + escape(clip.preview) + '</p>';
      var footerHint = selected ? ui.selectHint : ui.clickHint;
      return '<button class="clip-card ' + (selected ? "selected" : "") + '" style="--tone:' + clip.tone + '" data-id="' +
        escape(clip.id) + '" role="listitem" type="button">' +
        '<div><div class="card-meta"><span class="type-icon">' + escape(clip.icon) + '</span><span>' +
        escape(clip.type) + ' · ' + escape(clip.time) + '</span></div>' +
        '<h3 class="card-title">' + escape(clip.title) + '</h3>' + body + '</div>' +
        '<div class="card-footer"><span>' + escape(clip.source) + '</span><span>' + escape(footerHint) + '</span></div>' +
        '</button>';
    }).join("");

    deck.querySelectorAll(".clip-card").forEach(function (card) {
      card.addEventListener("click", function () {
        selectedID = card.dataset.id;
        renderDeck();
        var selected = clips.find(function (c) { return c.id === selectedID; });
        if (selected && selected.prompt) openPromptEditor();
      });
    });
  }

  function showToast(message) {
    if (!toast) return;
    toast.textContent = message;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove("show"); }, 2200);
  }

  function openPromptEditor() {
    if (!editor) return;
    editor.hidden = false;
    var featureInput = document.querySelector("[data-feature-input]");
    if (featureInput) featureInput.focus();
  }
  function closePromptEditor() { if (editor) editor.hidden = true; }

  document.querySelectorAll("[data-ribbon-item]").forEach(function (button) {
    button.addEventListener("click", function () {
      activeCategory = button.dataset.category;
      searchQuery = "";
      if (searchInput) searchInput.value = "";
      document.querySelectorAll("[data-ribbon-item]").forEach(function (item) {
        item.classList.toggle("active", item === button);
      });
      closePromptEditor();
      renderDeck();
    });
  });

  if (searchInput) {
    searchInput.addEventListener("input", function (event) {
      searchQuery = event.target.value;
      renderDeck();
    });
  }

  var closeBtn = document.querySelector("[data-close-editor]");
  if (closeBtn) closeBtn.addEventListener("click", closePromptEditor);

  var copyBtn = document.querySelector("[data-copy-prompt]");
  if (copyBtn) copyBtn.addEventListener("click", function () { showToast(ui.promptCopiedToast); });

  var genBtn = document.querySelector("[data-paste-prompt]");
  if (genBtn) genBtn.addEventListener("click", function () {
    showToast(ui.promptGeneratedToast);
    closePromptEditor();
  });

  document.addEventListener("keydown", function (event) {
    if (event.target.matches("input")) return;
    var items = itemsForCurrentCategory();
    if (!items.length) return;
    var index = items.findIndex(function (item) { return item.id === selectedID; });
    if (index === -1) index = 0;
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      selectedID = items[(index + 1) % items.length].id;
      renderDeck();
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      selectedID = items[(index - 1 + items.length) % items.length].id;
      renderDeck();
    } else if (event.key === "Enter") {
      var selected = clips.find(function (c) { return c.id === selectedID; });
      if (!selected) return;
      if (selected.prompt) {
        openPromptEditor();
      } else {
        showToast(ui.selectedToast.replace("{title}", selected.title));
      }
    }
  });

  renderDeck();
})();
