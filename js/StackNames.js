/* ==UserScript==
 * @name         Stack Names
 * @description  Accordion tab stacks, Dia-style (works with ZenLook.css / CollapseTabbar.css):
 *               - data-stack-name on each stack's arrow row: the stack's own title if renamed,
 *                 else the first tab's hostname (rendered next to the chevron by ZenLook.css);
 *               - data-zen-g on every tab-strip row: how many stack header rows precede it, and
 *                 data-zen-n on a stack's first row: how many rows the stack has. The CSS uses
 *                 them to give headers breathing room / close the gaps in the collapsed strip.
 *               Only data attributes are written — never Vivaldi's own layout variables.
 * @version      2026.10.4
 * ==/UserScript==
 */

(function () {
  "use strict";

  const STRIP = "#tabs-tabbar-container .tab-strip";
  let nameTimer = null;

  function hostname(url) {
    try {
      return new URL(url).hostname.replace(/^www\./, "");
    } catch {
      return "";
    }
  }

  function extData(tab) {
    try {
      return JSON.parse(tab.vivExtData || "{}");
    } catch {
      return {};
    }
  }

  function isMember(row) {
    const tab = row.tagName === "SPAN" && row.querySelector(".tab");
    return !!tab && /\btab-(in-)?accordion\b/.test(tab.className);
  }

  function setAttr(el, name, value) {
    if (el.getAttribute(name) !== value) el.setAttribute(name, value);
  }

  // Synchronous (runs inside the MutationObserver callback, before paint): no flicker.
  function annotate() {
    for (const strip of document.querySelectorAll(STRIP)) {
      let groups = 0;
      let first = null;
      let count = 0;
      for (const row of strip.children) {
        setAttr(row, "data-zen-g", String(groups));
        if (row.classList.contains("accordion-toggle-arrow")) {
          if (first) setAttr(first, "data-zen-n", String(count));
          groups++;
          first = null;
          count = 0;
        } else if (isMember(row)) {
          const tab = row.querySelector(".tab");
          if (!first || tab.classList.contains("tab-first-in-group") || tab.classList.contains("tab-accordion")) {
            first = row;
            count = 0;
          }
          count++;
        } else {
          first = null;
          count = 0;
        }
      }
    }
  }

  // First row of the stack that this arrow row belongs to (rows directly above it).
  function firstMember(toggle) {
    let first = null;
    for (let e = toggle.previousElementSibling; e && isMember(e); e = e.previousElementSibling) {
      first = e;
      const tab = e.querySelector(".tab");
      if (tab.classList.contains("tab-accordion") || tab.classList.contains("tab-first-in-group")) break;
    }
    return first;
  }

  async function updateNames() {
    const toggles = document.querySelectorAll(`${STRIP} > .accordion-toggle-arrow`);
    if (!toggles.length) return;
    const tabs = await chrome.tabs.query({ currentWindow: true });
    const byId = new Map(tabs.map((t) => [t.id, t]));
    const titles = new Map(); // group id -> custom stack title
    for (const t of tabs) {
      const d = extData(t);
      if (d.group && d.fixedGroupTitle) titles.set(d.group, d.fixedGroupTitle);
    }
    for (const toggle of toggles) {
      // Open stack: the first row is a tab ("tab-<tabId>"); closed stack: the header row is
      // the stack itself ("tab-<groupId>").
      const key = firstMember(toggle)?.querySelector(".tab-wrapper[id^='tab-']")?.id.slice(4);
      if (!key) continue;
      const tab = /^\d+$/.test(key)
        ? byId.get(Number(key))
        : tabs.find((t) => extData(t).group === key);
      if (!tab) continue;
      const name = titles.get(extData(tab).group) || hostname(tab.url || tab.pendingUrl) || "Stack";
      setAttr(toggle, "data-stack-name", name);
    }
  }

  function scheduleNames() {
    clearTimeout(nameTimer);
    nameTimer = setTimeout(() => updateNames().catch(() => {}), 120);
  }

  function onChange() {
    annotate();
    scheduleNames();
  }

  function observe() {
    document.documentElement.setAttribute("data-shine-stacks", "");
    const container = document.querySelector("#tabs-tabbar-container");
    if (!container) return setTimeout(observe, 500);
    // Only structure/class changes: our own data-* writes don't retrigger this.
    new MutationObserver(onChange).observe(container, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["class"],
    });
    chrome.tabs.onUpdated.addListener((id, info) => {
      if (info.url || info.vivExtData) scheduleNames();
    });
    onChange();
  }

  observe();
})();
