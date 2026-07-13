const categories = {
  recent: { label: "最近复制", title: "刚复制，也最应该先看到" },
  prompt: { label: "Prompt", title: "把好问题留在触手可及处" },
  pinned: { label: "收藏", title: "真正值得反复使用的内容" },
  image: { label: "图片", title: "视觉灵感，也能快速找回" },
  file: { label: "文件", title: "文件引用，不再散落在记忆里" }
};

const clips = [
  { id: "brief", category: "recent", type: "文本", icon: "T", title: "产品体验优先的实现原则", preview: "我只负责把控需求；技术方案、架构和实现细节由你决定。首要原则是保证用户体验。", source: "备忘录", time: "刚刚", tone: "#9c79e0" },
  { id: "code", category: "recent", type: "代码", icon: "⌘", title: "SwiftUI 卡片焦点状态", preview: "@State private var selectedID: Clip.ID?", source: "Xcode", time: "2 分钟前", tone: "#67cba7", code: true },
  { id: "url", category: "recent", type: "链接", icon: "↗", title: "Apple Human Interface Guidelines", preview: "设计应该清晰、可预测，并尊重用户已掌握的系统习惯。", source: "Safari", time: "5 分钟前", tone: "#71a7f1" },
  { id: "prompt", category: "prompt", type: "模板", icon: "✦", title: "请帮我完成这个功能", preview: "先阅读现有项目结构，说明准备怎么改，修改代码、运行检查并总结结果。", source: "内置 Prompt", time: "常用", tone: "#ff9f5b", prompt: true },
  { id: "reply", category: "prompt", type: "模板", icon: "✦", title: "把复杂内容说清楚", preview: "请用面向初学者的中文解释以下内容，先给结论，再补充必要的背景。", source: "内置 Prompt", time: "常用", tone: "#e18db8", prompt: true },
  { id: "address", category: "pinned", type: "常用文本", icon: "⌂", title: "常用收件地址", preview: "上海市静安区 · 个人工作室 · 请提前联系确认收件时间", source: "收藏", time: "昨天", tone: "#f3bc70" },
  { id: "image", category: "image", type: "图片", icon: "▧", title: "柔和日落色板", preview: "温暖柑橘、雾紫与深墨蓝的配色参考", source: "截图", time: "昨天", tone: "#ed8875", image: true },
  { id: "file", category: "file", type: "文件", icon: "▤", title: "funPaste 产品想法.md", preview: "剪贴历史、常用内容和 Prompt 模板的一体化整理方案。", source: "Finder", time: "上周", tone: "#93a6f0" }
];

let activeCategory = "recent";
let selectedID = "brief";
let searchQuery = "";
let toastTimer;

const deck = document.querySelector("#clip-deck");
const title = document.querySelector("#deck-title");
const label = document.querySelector("#category-label");
const count = document.querySelector("#count-pill");
const editor = document.querySelector("#prompt-editor");
const toast = document.querySelector("#toast");

function itemsForCurrentCategory() {
  const normalized = searchQuery.trim().toLowerCase();
  return clips.filter((clip) => {
    const inCategory = activeCategory === "recent" ? ["recent", "prompt"].includes(clip.category) : clip.category === activeCategory;
    return inCategory && (!normalized || `${clip.title} ${clip.preview} ${clip.source}`.toLowerCase().includes(normalized));
  });
}

function renderDeck() {
  const items = itemsForCurrentCategory();
  label.textContent = categories[activeCategory].label;
  title.textContent = categories[activeCategory].title;
  count.textContent = `${items.length} 个项目`;
  if (!items.some((item) => item.id === selectedID)) selectedID = items[0]?.id;

  deck.innerHTML = items.length ? items.map((clip) => `
    <button class="clip-card ${clip.id === selectedID ? "selected" : ""}" style="--tone:${clip.tone}" data-id="${clip.id}" role="listitem" type="button">
      <div><div class="card-meta"><span class="type-icon">${clip.icon}</span><span>${clip.type} · ${clip.time}</span></div>
      <h2 class="card-title">${clip.title}</h2>${clip.image ? '<div class="image-swatch"></div>' : `<p class="card-preview ${clip.code ? "code-preview" : ""}">${clip.preview}</p>`}</div>
      <div class="card-footer"><span>${clip.source}</span><span>${clip.id === selectedID ? "回车粘贴" : "点击选择"}</span></div>
    </button>`).join("") : `<div class="empty-state"><div><strong>没有找到相关内容</strong>换个关键词，或回到全部项目继续浏览。</div></div>`;

  deck.querySelectorAll(".clip-card").forEach((card) => card.addEventListener("click", () => {
    selectedID = card.dataset.id;
    renderDeck();
    const selected = clips.find((clip) => clip.id === selectedID);
    if (selected.prompt) openPromptEditor();
  }));
}

function showToast(message) {
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 2200);
}

function openPromptEditor() { editor.hidden = false; document.querySelector("#feature-input").focus(); }
function closePromptEditor() { editor.hidden = true; }

document.querySelectorAll(".ribbon-item").forEach((button) => button.addEventListener("click", () => {
  activeCategory = button.dataset.category;
  searchQuery = "";
  document.querySelector("#search-input").value = "";
  document.querySelectorAll(".ribbon-item").forEach((item) => item.classList.toggle("active", item === button));
  closePromptEditor();
  renderDeck();
}));

document.querySelector("#search-input").addEventListener("input", (event) => { searchQuery = event.target.value; renderDeck(); });
document.querySelector("#close-editor").addEventListener("click", closePromptEditor);
document.querySelector("#copy-prompt").addEventListener("click", () => showToast("Prompt 已复制到剪贴板"));
document.querySelector("#paste-prompt").addEventListener("click", () => { showToast("Prompt 已生成并准备粘贴"); closePromptEditor(); });

document.addEventListener("keydown", (event) => {
  if (event.target.matches("input")) return;
  const items = itemsForCurrentCategory();
  const index = items.findIndex((item) => item.id === selectedID);
  if (event.key === "ArrowRight" || event.key === "ArrowDown") { selectedID = items[(index + 1) % items.length]?.id; renderDeck(); }
  if (event.key === "ArrowLeft" || event.key === "ArrowUp") { selectedID = items[(index - 1 + items.length) % items.length]?.id; renderDeck(); }
  if (event.key === "Enter") { const selected = clips.find((clip) => clip.id === selectedID); selected?.prompt ? openPromptEditor() : showToast(`已粘贴「${selected?.title}」`); }
});

renderDeck();
