# Handoff prompt for a Mistral Vibe agent

Paste everything below the line into `vibe` (run it from `C:\Users\win10\Documents\code\knox-inventory-overrides`).

---

You are taking over a small, finished-but-untested modding project for **Project Zomboid (Build 42)** on Windows. Work in
`C:\Users\win10\Documents\code\knox-inventory-overrides`. **Read `CLAUDE.md` in that folder first**: it documents every file, path, rule and gotcha. Do not re-derive what it already says.

## What this project is
The Steam Workshop mod **Knox Inventory** (id 3816775774) turns the inventory into a grid, but its item sizes ignore item weight, so bags fill up long before their weight limit.
We fix the balance WITHOUT editing the mod (Workshop updates overwrite it):
- `generate-knox-overrides.ps1` (run via `regenerate-overrides.bat`) writes the live file `C:\Users\win10\Zomboid\Lua\knox_overrides.txt`: item footprints capped at 2 cells per kg, bag grids at 3 cells per capacity unit,
  then stack sizes from `stack-rules.txt`, then the user's own lines from `my-overrides.txt` (applied last).
- A companion mod, `C:\Users\win10\Zomboid\mods\KnoxInventoryTweaks`, (a) lets Knox stack item classes it refuses (food, literature, maps, keys, weapon parts, "MaterialWeapon" planks/firewood) and
  (b) tweaks the fabric/leather tool rolls (capacity 5, weight reduction 60, max item size 1.5).

## State
Everything above is written and passes the generator's own checks, but **nothing has been tested in the running game** and the Lua was never syntax-checked (no Lua interpreter on this machine).

## Your tasks, in order
1. **Lag investigation (priority).** The user reported the game almost freezing when moving a stack of 100 carrots between grids. We added a 1.5 s per-item cache and `[KnoxTweaks]` debug logging
   (`DEBUG = true` in `KnoxInventoryTweaks.lua`). Read `C:\Users\win10\Zomboid\console.txt` for `[KnoxTweaks]` lines and Lua errors from the latest session. If the lag persists, find the real hot path in Knox's
   Lua (`C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3816775774\mods\KnoxInventory\42\media\lua\...`, especially `KnoxGrid.lua`, `KnoxDrag.lua`, `KnoxActions.lua`, `KnoxGridView.lua`) and fix it
   from inside our mod only. Set `DEBUG = false` when done.
2. **Syntax-check the Lua** in `KnoxInventoryTweaks.lua` by careful reading (or install a Lua checker via `uv` if you can do it safely), and sanity-check every Java method name it calls against how Knox/the game use them.
3. **Modded items.** Items from other mods (the user runs ~100 mods, e.g. VanillaFoodsExpanded) are not in Knox's precomputed table, so `stack-rules.txt` never reaches them and modded food will not stack.
   Design a safe way to give them weight-based stacks (per `CLAUDE.md`: Knox sizes them at runtime in `KnoxFootprint.lua`). Propose first, then implement only if the user approves.

## Rules of engagement
- The user hand-edits `stack-rules.txt` and `my-overrides.txt`. **Re-read them before any edit and keep their changes.** Never edit files under the Steam Workshop folder.
- Re-running the generator overwrites `knox_overrides.txt` (a timestamped `.bak` is saved next to it). Do not run it against the live file without telling the user; use `-Out` with a temp path to test.
- PowerShell 5.1 on Windows: no `&&`, variable names are case-insensitive, and never pipe the stack script into `Select-Object -First`. See "Gotchas" in `CLAUDE.md`.
- Do not claim in-game behavior is verified unless you saw it in `console.txt` or the user confirmed it. Say plainly what is untested.
- Ask before anything destructive, outward-facing, or security-related.

## Report back with
What you found in the console log, what you changed (file and reason), what remains untested, and anything you want the user to decide.
