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
  var clips = data.clips.slice();
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
  var ribbon = document.querySelector(".ribbon");
  if (!deck) return;

  var toneClasses = {
    "#9c79e0": "clip-tone-violet",
    "#67cba7": "clip-tone-mint",
    "#71a7f1": "clip-tone-blue",
    "#ff9f5b": "clip-tone-orange",
    "#e18db8": "clip-tone-pink",
    "#f3bc70": "clip-tone-gold",
    "#ed8875": "clip-tone-coral",
    "#93a6f0": "clip-tone-periwinkle"
  };

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

  function renderDeck(focusSelected) {
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
      var toneClass = toneClasses[clip.tone] || "clip-tone-violet";
      return '<button class="clip-card ' + toneClass + (selected ? " selected" : "") + '" data-id="' +
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
        renderDeck(true);
        var selected = clips.find(function (c) { return c.id === selectedID; });
        if (selected && selected.prompt) openPromptEditor();
      });
    });

    if (focusSelected) {
      var selectedCard = deck.querySelector(".clip-card.selected");
      if (selectedCard) selectedCard.focus();
    }
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

  function currentPromptText() {
    var selected = clips.find(function (clip) { return clip.id === selectedID; });
    if (!selected || !selected.prompt) return "";
    var featureInput = document.querySelector("[data-feature-input]");
    var constraintInput = document.querySelector("[data-constraint-input]");
    var parts = [selected.preview];
    var feature = featureInput ? featureInput.value.trim() : "";
    var constraint = constraintInput ? constraintInput.value.trim() : "";
    if (feature) parts.push(ui.featurePrefix + ": " + feature);
    if (constraint) parts.push(ui.constraintPrefix + ": " + constraint);
    return parts.join("\n\n");
  }

  function activateSelection(asPlainText) {
    var selected = clips.find(function (clip) { return clip.id === selectedID; });
    if (!selected) return;
    if (selected.prompt) {
      openPromptEditor();
      return;
    }
    var message = asPlainText ? ui.plainSelectedToast : ui.selectedToast;
    showToast(message.replace("{title}", selected.title));
  }

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

  if (ribbon) {
    var draggedRibbonItem;
    ribbon.addEventListener("dragstart", function (event) {
      var button = event.target.closest("[data-ribbon-item]");
      if (!button) return;
      draggedRibbonItem = button;
      event.dataTransfer.effectAllowed = "move";
    });
    ribbon.addEventListener("dragover", function (event) {
      var target = event.target.closest("[data-ribbon-item]");
      if (!draggedRibbonItem || !target || target === draggedRibbonItem) return;
      event.preventDefault();
      var insertAfter = event.clientX > target.getBoundingClientRect().left + target.offsetWidth / 2;
      ribbon.insertBefore(draggedRibbonItem, insertAfter ? target.nextSibling : target);
    });
    ribbon.addEventListener("dragend", function () { draggedRibbonItem = null; });
  }

  if (searchInput) {
    searchInput.addEventListener("input", function (event) {
      searchQuery = event.target.value;
      renderDeck();
    });
  }

  var closeBtn = document.querySelector("[data-close-editor]");
  if (closeBtn) closeBtn.addEventListener("click", closePromptEditor);

  var copyBtn = document.querySelector("[data-copy-prompt]");
  if (copyBtn) copyBtn.addEventListener("click", function () {
    var text = currentPromptText();
    if (!text || !navigator.clipboard) {
      showToast(ui.promptCopyFailedToast);
      return;
    }
    navigator.clipboard.writeText(text).then(function () {
      showToast(ui.promptCopiedToast);
    }).catch(function () {
      showToast(ui.promptCopyFailedToast);
    });
  });

  var genBtn = document.querySelector("[data-paste-prompt]");
  if (genBtn) genBtn.addEventListener("click", function () {
    var text = currentPromptText();
    if (!text) return;
    var generated = {
      id: "generated-" + Date.now(),
      category: "recent",
      type: ui.generatedType,
      icon: "T",
      title: ui.generatedTitle,
      preview: text,
      source: ui.generatedSource,
      time: ui.generatedTime,
      tone: "#ff9f5b"
    };
    clips.unshift(generated);
    activeCategory = "recent";
    selectedID = generated.id;
    searchQuery = "";
    if (searchInput) searchInput.value = "";
    document.querySelectorAll("[data-ribbon-item]").forEach(function (item) {
      item.classList.toggle("active", item.dataset.category === "recent");
    });
    renderDeck();
    showToast(ui.promptGeneratedToast);
    closePromptEditor();
  });

  deck.addEventListener("keydown", function (event) {
    var items = itemsForCurrentCategory();
    if (!items.length) return;
    if (event.metaKey && /^[1-9]$/.test(event.key)) {
      var shortcutIndex = Number(event.key) - 1;
      if (shortcutIndex >= items.length) return;
      event.preventDefault();
      selectedID = items[shortcutIndex].id;
      renderDeck(true);
      activateSelection(false);
      return;
    }
    var index = items.findIndex(function (item) { return item.id === selectedID; });
    if (index === -1) index = 0;
    if (event.key === "ArrowRight" || event.key === "ArrowDown") {
      event.preventDefault();
      selectedID = items[(index + 1) % items.length].id;
      renderDeck(true);
    } else if (event.key === "ArrowLeft" || event.key === "ArrowUp") {
      event.preventDefault();
      selectedID = items[(index - 1 + items.length) % items.length].id;
      renderDeck(true);
    } else if (event.key === "Enter") {
      event.preventDefault();
      activateSelection(event.shiftKey);
    }
  });

  renderDeck();
})();
