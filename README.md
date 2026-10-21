# Shine's mod for Vivaldi

A minimal Arc / Dia-style vertical tab bar for Vivaldi 8.x (Windows): a favicon strip that
expands over the page on hover, soft rounded tabs with breathing room, pinned tabs as a tile
grid, and accordion tab stacks with Dia-style named group headers.

## Install

Open **Windows PowerShell** (no admin needed for a normal per-user Vivaldi install) and run:

```powershell
irm https://raw.githubusercontent.com/bichoanh201698-collab/shines-mod-for-vivaldi/main/install.ps1 | iex
```

Vivaldi is closed and restarted (tabs are restored).

**Vivaldi updates are handled automatically.** Updates wipe the JS part (the CSS lives in
`%LOCALAPPDATA%\ShineMod` and survives). The installer sets up a scheduled task,
*Shine's mod auto-repair*, that checks every 5 minutes and at logon, and puts the JS part back
into a new Vivaldi version without closing Vivaldi. If Vivaldi has just restarted into the update,
the task restarts it once more so the mod shows right away. The log is in
`%LOCALAPPDATA%\ShineMod-files\auto-repair.log`. To skip the task, set `SHINE_NO_AUTO=1` before
installing, and then rerun the install command yourself after each update. The task is only set
up for per-user Vivaldi installs.

Uninstall:

```powershell
$env:SHINE_UNINSTALL = 1; irm https://raw.githubusercontent.com/bichoanh201698-collab/shines-mod-for-vivaldi/main/install.ps1 | iex
```

## What the installer does

1. Copies the CSS to `%LOCALAPPDATA%\ShineMod` and points *Settings → Appearance → Custom UI
   Modifications* at it.
2. Copies the JS mods to `<Vivaldi>\Application\<version>\resources\vivaldi\user_mods\` and adds
   the loader (`injectMods.js`) to `window.html` (original kept as `window.html.shine-bak`).
3. Enables `vivaldi://flags/#vivaldi-css-mods` and `#vivaldi-horizontal-pinned-tabs`.
4. Saves a copy of the JS part plus `watch.ps1` to `%LOCALAPPDATA%\ShineMod-files` and registers
   the auto-repair task (see above).
5. On first start, `ShineSetup.js` sets: tab bar on the right, tab stacking = Accordion,
   tab bar width 300px. Change them freely afterwards (left side is supported too).

## The mods

| File | What it does |
|---|---|
| `css/mods/CollapseTabbar.css` | Tab bar collapses to a favicon strip, expands as an overlay on hover (left or right) |
| `css/mods/ZenLook.css` | Minimal look: pills, spacing, pinned tile grid, accordion stack headers, stack colours, sticky "New Tab" row |
| `js/StackNames.js` | Stack names on the headers (custom name or first tab's domain) + row data the CSS uses |
| `js/ShineSetup.js` | One-time settings (see above) |
| everything else | From [Awesome-Vivaldi / Volante](https://github.com/PaRr0tBoY/Awesome-Vivaldi) (media player, toasts, …) |

Tips: rename or recolour a stack by right-clicking its header tab while the stack is
collapsed → *Edit Stack*. Tweak spacing with the variables at the top of `ZenLook.css`.

Built on [Awesome-Vivaldi](https://github.com/PaRr0tBoY/Awesome-Vivaldi) by PaRr0tBoY and
contributors. Licensed under GPL-3.0.
