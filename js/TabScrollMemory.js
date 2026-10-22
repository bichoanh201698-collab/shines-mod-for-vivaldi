/* ==UserScript==
 * @name         Tab Scroll Memory
 * @description  Keep tab list scroll position with one restore before expansion paints.
 * @version      2026.10.22.1
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
    let frame = 0;
    const context = (strip) => strip.querySelector(".tab-wrapper")?.id || "";

    function position(strip) {
      const key = context(strip);
      let saved = positions.get(strip);
      if (!saved || saved.key !== key) {
        saved = { key, top: strip.scrollTop };
        positions.set(strip, saved);
      }
      return saved;
    }

    function cancel() {
      cancelAnimationFrame(frame);
      frame = 0;
    }

    function enter() {
      inside = true;
      cancel();
      // Let hover styles settle first. A scrollTop write clamps itself, so no
      // scrollHeight/clientHeight reads, resize observer or settling timer is needed.
      const targets = [...bar.querySelectorAll(".tab-strip")].map((strip) => ({
        strip,
        saved: position(strip),
      }));
      frame = requestAnimationFrame(() => {
        for (const { strip, saved } of targets) {
          if (strip.isConnected && context(strip) === saved.key && Math.abs(strip.scrollTop - saved.top) > 1) {
            strip.scrollTop = saved.top;
          }
        }
        frame = 0;
      });
    }

    for (const strip of bar.querySelectorAll(".tab-strip")) position(strip);
    bar.addEventListener("scroll", (event) => {
      const strip = event.target;
      if (inside && !frame && bar.matches(":hover") && strip.matches?.(".tab-strip")) {
        position(strip).top = strip.scrollTop;
      }
    }, true);
    bar.addEventListener("pointerenter", enter);
    bar.addEventListener("pointerleave", () => {
      inside = false;
      cancel();
    });
    // Manual scrolling and tab selection take priority over a queued restore.
    for (const type of ["wheel", "pointerdown", "keydown"]) {
      bar.addEventListener(type, cancel, { capture: true, passive: true });
    }
  }

  attach();
})();
