/* ==UserScript==
 * @name         Shine Setup
 * @description  Applies the settings Shine's mod is designed for. Runs on every start, but the
 *               tab layout settings are applied only once (so you can change them afterwards).
 *               install.ps1 fills in __SHINE_CSS_DIR__.
 * @version      2026.10.5
 * ==/UserScript==
 */

(function () {
  "use strict";

  const CSS_DIR = "__SHINE_CSS_DIR__";
  const ONCE_KEY = "shine-setup-v1";

  function set(path, value) {
    try {
      vivaldi.prefs.set({ path, value });
    } catch (e) {
      console.warn("[ShineSetup] could not set", path, e);
    }
  }

  // Vivaldi's own CSS mods folder lives outside the version folder, so the CSS survives updates.
  if (!CSS_DIR.startsWith("__")) {
    vivaldi.prefs.get("vivaldi.appearance.css_ui_mods_directory", (v) => {
      if (!v || v.value !== CSS_DIR) set("vivaldi.appearance.css_ui_mods_directory", CSS_DIR);
    });
  }

  // (window.html has no localStorage; chrome.storage.local persists across restarts and updates)
  chrome.storage.local.get(ONCE_KEY, (stored) => {
    if (stored && stored[ONCE_KEY]) return;
    set("vivaldi.tabs.bar.position", "right");
    set("vivaldi.tabs.stacking.mode", "accordion");
    set("vivaldi.tabs.bar.width", 300);
    chrome.storage.local.set({ [ONCE_KEY]: new Date().toISOString() });
    console.log("[ShineSetup] tab layout settings applied");
  });
})();
