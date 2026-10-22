/* ==UserScript==
 * @name         Tab Scroll Memory
 * @description  Keep the expanded tab list's scroll position across hover collapse.
 * @version      2026.10.22
 * ==/UserScript==
 */

(function () {
  "use strict";

  function attach() {
    const bar = document.getElementById("tabs-tabbar-container");
    if (!bar) return setTimeout(attach, 500);
    if (bar.hasAttribute("data-shine-scroll-memory")) return;
    bar.setAttribute("data-shine-scroll-memory", "");

    const positions = new WeakMap();
    let inside = bar.matches(":hover");
    let restoring = false;
    let frame = 0;
    let finishTimer = 0;
    let targets = [];
    const strips = () => [...bar.querySelectorAll(".tab-strip")];
    // A reused strip belongs to a different workspace if its first tab changes.
    const context = (strip) => strip.querySelector(".tab-wrapper")?.id || "";

    function position(strip) {
      let saved = positions.get(strip);
      const key = context(strip);
      if (!saved || saved.key !== key) {
        saved = { key, top: strip.scrollTop };
        positions.set(strip, saved);
      }
      return saved;
    }

    function remember(strip) {
      position(strip).top = strip.scrollTop;
    }

    function stop() {
      restoring = false;
      cancelAnimationFrame(frame);
      clearTimeout(finishTimer);
      observer.disconnect();
      targets = [];
    }

    function restore() {
      frame = 0;
      if (!restoring) return;
      for (const { strip, saved } of targets) {
        if (!strip.isConnected || context(strip) !== saved.key) continue;
        const top = Math.min(saved.top, Math.max(0, strip.scrollHeight - strip.clientHeight));
        if (Math.abs(strip.scrollTop - top) > 1) strip.scrollTop = top;
      }
    }

    const observer = new ResizeObserver(() => {
      if (restoring && !frame) frame = requestAnimationFrame(restore);
    });

    function enter() {
      inside = true;
      stop();
      targets = strips().map((strip) => ({ strip, saved: position(strip) }));
      restoring = true;
      for (const { strip } of targets) observer.observe(strip);
      // Restore before paint, then once more after the 140ms expansion settles.
      restore();
      frame = requestAnimationFrame(restore);
      finishTimer = setTimeout(() => {
        restore();
        const settled = targets.map(({ strip }) => strip);
        stop();
        for (const strip of settled) remember(strip);
      }, 250);
    }

    function userInput() {
      // Let wheel, keyboard navigation and scrollbar dragging win immediately.
      if (!restoring) return;
      const current = targets.map(({ strip }) => strip);
      stop();
      for (const strip of current) remember(strip);
    }

    for (const strip of strips()) remember(strip);
    bar.addEventListener("scroll", (event) => {
      const strip = event.target;
      if (inside && !restoring && bar.matches(":hover") && strip.matches?.(".tab-strip")) remember(strip);
    }, true);
    bar.addEventListener("pointerenter", enter);
    bar.addEventListener("pointerleave", () => {
      inside = false;
      stop();
    });
    for (const type of ["wheel", "pointerdown", "keydown"]) {
      bar.addEventListener(type, userInput, { capture: true, passive: true });
    }
  }

  attach();
})();
