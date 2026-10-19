# Knox Inventory balance overrides - notes for future Claude instances

Project Zomboid (Build 42) + the Steam Workshop mod **Knox Inventory** (id 3816775774, mod id `KnoxInventory`, v0.9.8.x).
The user likes Knox's grid UI but found it unbalanced: item footprints were far bigger than item weight justifies
(a 1 kg lug wrench took 2x3 cells), so bags filled up long before their weight limit. This folder holds the scripts
that fix that WITHOUT editing the mod (Workshop updates overwrite mod files).

## Paths (Windows, user `win10`)
- Game scripts (source of item weights/categories): `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\scripts`
- Knox mod: `C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3816775774\mods\KnoxInventory\42\media\lua\...`
  - `shared\Knox\KnoxFootprint.lua` - sizing rules, overrides parser (`F.parseOverride`), `CELLS_PER_CAPACITY = 2`
  - `shared\Knox\KnoxFootprintData.lua` - precomputed table for every vanilla item: `stack*100 + shortSide*10 + longSide`; `KnoxBagData` = `cols*100 + minRows`
  - `shared\Knox\KnoxGrid.lua` - `isStackable()` (decides by item CLASS, see below)
- **Live output (what the game reads):** `C:\Users\win10\Zomboid\Lua\knox_overrides.txt`
- Companion mod: `C:\Users\win10\Zomboid\mods\KnoxInventoryTweaks` (see below)

## Files in this folder
| File | Purpose |
|---|---|
| `generate-knox-overrides.ps1` | Regenerates the WHOLE live file: shrinks footprints, regrids bags, then runs the stack script, then applies `my-overrides.txt`. Defaults `-ItemCellsPerKg 2 -BagCellsPerCap 3`. `-NoStacks`, `-DryRun`, `-Out` exist. Always saves the previous live file as `knox_overrides.txt.<timestamp>.bak`. |
| `set-knox-stacks.ps1` | Edits stack sizes in the live file in place. Default mode reads `stack-rules.txt`; `-Stack N -DisplayCategory .. -Ids ..` is a flat mode. Raise-only unless `-Force`. |
| `stack-rules.txt` | **User-edited** stack rules (`cat:Name [kg>=x] = N`, `id:Base.X* = N`, last match wins). |
| `my-overrides.txt` | **User-edited** hand overrides in knox syntax, applied LAST (replaces the generated line for the same item). Currently: `show_ids = yes`, FirstAidKit grids, KeyRing grids, ToolRoll grids, `Base.PipeWrench = 1x2`. |
| `my-tweaks-diff.txt` | One-off report of the user's early manual tweaks vs generator output (historical). |

Normal workflow: user edits `stack-rules.txt` / `my-overrides.txt` -> runs the generator -> exits to main menu and reloads the save
(the overrides file is read only when the mod's Lua loads). Command:
`powershell -ExecutionPolicy Bypass -File "C:\Users\win10\Documents\code\knox-inventory-overrides\generate-knox-overrides.ps1"`

## The balance model (why 2 / 3)
- Weight limit of the game still applies in parallel to the grid; the grid is a second limit. Goal: weight should be the binding limit.
- Items: footprint is capped at `ceil(weight * 2)` cells (min 1); items are only ever SHRUNK, never grown. 0.5 kg = 1 cell, 1 kg = 2 cells.
- Bags: grid = `capacity * 3` cells (mod default is 2), same column count as Knox, max 15 rows / 8 cols.
- Analysis of the user's weights CSV (1629 items; 92% are <=1 kg): cell rounding means a typical mix needs about `itemRate + 0.4` cells per kg of load,
  so bag rate should be ~itemRate+0.4..1. 4 cells per kg for a 1 kg item was judged too bulky (lug wrench = a hockey helmet).
- Item weights come from the game's script files (`Weight =`), NOT the user's CSV (`C:\Users\win10\Downloads\PZ items weights.csv`, incomplete: lacks e.g. LugWrench).
- Not overridable by file: furniture/car boots/seats (fixed 3 cells per capacity), bags of other mods, clothing/food/books/bag/weapon stacking.

## knox_overrides.txt syntax (parsed by `F.parseOverride`)
`Base.X = 1x2` (cells, short x long), `grid CxR` (bag), `stack N`, `category mat|wpn|...`, `sound ...`, `show_ids = yes`.
**One item = ONE line.** A second line for the same item REPLACES the first (not merged) - combine tokens: `Base.X = 1x2 stack 10`.

## Stacking facts
- Knox decides what CAN stack by item class in `KnoxGrid.isStackable`: never HandWeapon, Clothing, InventoryContainer, Food (except cigarettes), Literature, Moveable, Radio,
  anything with a FluidContainer, or damaged items. Overrides only change HOW MANY stack, not whether.
- `stack-rules.txt` targets only items with `ItemType` normal/drainable (plus `base:weapon` items whose DisplayCategory is in `$weaponCats` = `MaterialWeapon`).
- Planks, firewood, sticks, pipes, bars (22 items, DisplayCategory `MaterialWeapon`) are weapons in the script files -> need the companion mod.
- **Knox Inventory Tweaks** mod (see its section below), `KnoxInventoryTweaks.lua`: wraps `KnoxGrid.isStackable` to allow undamaged `MaterialWeapon` weapons. Must be enabled in the game's Mods list
  (and added to existing saves). Its category list must stay in sync with `$weaponCats` in `set-knox-stacks.ps1`. NOT tested in-game as of writing; if it misbehaves
  (equip/drop from a stack), disable the mod. A Knox update could break the wrap.
- Categories used in rules are the game's `DisplayCategory` (Material, MaterialWeapon, Junk, VehicleMaintenance, Ammo, Tool, ...). Knox's own tab names (mat, wpn...) are different.

## Gotchas learned
- PowerShell variable names are case-insensitive: `$rules` clobbered the `$Rules` parameter once. Don't reuse names that differ only by case.
- `... | Select-Object -First 1` on a script call stops the script early (it never wrote its file). Don't pipe the stack script into Select-Object.
- The user edits `stack-rules.txt` and `my-overrides.txt` by hand between sessions; always re-read before editing and keep their changes.
- Re-running the generator overwrites the live file: hand edits to `knox_overrides.txt` itself are lost (they belong in `my-overrides.txt`).
- Nothing here can be verified without launching the game; say so rather than claiming in-game behavior is confirmed.

## Knox Inventory Tweaks (the companion mod)
C:\Users\win10\Zomboid\mods\KnoxInventoryTweaks (id KnoxInventoryTweaks, equire=\KnoxInventory). It replaced two earlier mods, KnoxStackPatch and ToolRollTweaks (deleted;
if a save still lists them it shows a missing-mod warning - enable this one instead). Must be enabled in the game's Mods list and added to existing saves. Two parts, both UNTESTED in-game:
1. 42\media\lua\shared\KnoxInventoryTweaks.lua - wraps KnoxGrid.isStackable so undamaged MaterialWeapon weapons stack (keep its category list in sync with $weaponCats in set-knox-stacks.ps1).
2. 42\media\scripts\toolroll_tweaks.txt - partial item definitions (the game merges them into the existing items) for Base.ToolRoll_Fabric / Base.ToolRoll_Leather:
   Capacity 5 (vanilla 4), WeightReduction 60 (vanilla 50), MaxItemSize 1.5 (vanilla 1.0 = heaviest single item; 1.5 admits hammers, pipe wrenches, hand axes, not crowbars at 2.0).
   Capacity is deliberately <= 5: Knox treats bags up to NEST_CAPACITY = 5 as small organizers that may lie in a bag with things in them; above 5 a non-empty bag cannot go into another bag.
   Knox side, in my-overrides.txt: Base.ToolRoll_* = 2x2 grid 5x3 = 15 cells (2/3 rule: 5 kg * 3) and an outer footprint of 4 cells (Knox keeps outer ~ inner/4 for organizers so nesting can't multiply room).
   The generator reads capacity from the vanilla scripts, so if the mod's capacity changes, update that line by hand (3 cells per kg, outer = cells/4).

## Stack baseline "B" and opened item classes (added 2026-10-19)
- stack-rules.txt starts with a weight baseline for EVERY stackable item: <0.25 kg 100 (last rule of the file, beats all category rules), <0.5 kg 50, <1 kg 25, 1 kg 10, <=2 kg 5, <=5 kg 3, <=10 kg 2, above 1.
  Category rules for >=0.25 kg override the baseline (last match wins). There is deliberately no cat:Food rule any more.
- The user asked for "everything stacks by weight", so the companion mod's KnoxInventoryTweaks.lua now also opens classes Food, Literature, Key, WeaponPart, MapItem (plus MaterialWeapon weapons).
  Safety: undamaged only, no poison, no fluid container, no writable literature, and the stack key (KnoxGrid.stackKey) and KnoxGrid.mergeRoom are wrapped so only IDENTICAL state shares a tile
  (food freshness quarter/stale/rotten, cooked, burnt, frozen, hunger/thirst left; pages read; key id; map id; custom name; favorite). Clothing, bags, moveables, radios, fluid containers stay unstackable on purpose.
- $stackTypes in set-knox-stacks.ps1 must stay in sync with the mod's OPEN_CLASSES (script ItemTypes food|literature|map|key|weaponpart|normal|drainable).
- UNTESTED in-game and the Lua was not syntax-checked (no Lua interpreter on the machine). Java method names used (getOffAge, getOffAgeMax, getAlreadyReadPages, getKeyId, getMapID, canBeWrite...) are wrapped in pcall so a wrong name degrades to "less strict key", not a crash;
  if a map/key/food state turns out not to separate, look there first. If anything misbehaves, disabling the mod restores Knox's own behavior.

## stack-rules.txt structure (reorganized 2026-10-19)
Five sections in this order, last match wins: (1) weight baseline B, (2) bulk resources cat:Material,MaterialWeapon,Junk tiers (selectors accept a comma list of categories),
(3) flat caps for bulky categories (all use kg>=0.25 so they never touch the light end), (4) individual id: exceptions, (5) id:* kg<0.25 = 100, which must stay LAST.
Keep new category rules in section 3 (or 2 for bulk resources) with kg>=0.25; put one-off items in section 4.

## Lag fix attempt (2026-10-19)
User report: moving a stack of 100 carrots between grids almost froze the game. Suspected cause (NOT profiled): Knox rebuilds grids constantly during a move and calls isStackable/stackKey for every item;
our added checks (many Java calls per item) multiplied that. KnoxInventoryTweaks.lua now caches per item for CACHE_MS = 1500 and, with DEBUG = true, logs [KnoxTweaks] lines to
C:\Users\win10\Zomboid\console.txt (slow KnoxGrid.build calls >= 30 ms, and call/computed counts every 5 s). If lag persists, read those lines first. Set DEBUG = false once it is fine.

## IMPORTANT gotcha: AppData is redirected for Claude's own tool processes (found 2026-10-20)
The Claude desktop app is a Store-packaged app, so files that Claude's tools write under C:\Users\win10\AppData\... (Local and Roaming) land in
C:\Users\win10\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\... and are INVISIBLE to the user's own processes (and vice versa). Paths outside AppData (C:\Users\win10\Tools, Zomboid, Documents, C:\msys64, the registry's HKCU\Environment) are real.
Never install user-facing tools into AppData; use C:\Users\win10\Tools\.... To see the user's real filesystem, run a command in their terminal (un_in_terminal).
Setup on this machine: Windows Terminal (portable) C:\Users\win10\Tools\WindowsTerminal\wt.exe (settings in its settings folder; Desktop shortcut "Terminal (zsh)"), zsh from MSYS2 C:\msys64 (config C:\Users\win10\.zshrc, home = C:\Users\win10),
Mistral Vibe via uv in C:\Users\win10\Tools\uv (in\vibe.exe, on the user PATH and in .zshrc; use UV_TOOL_DIR/UV_TOOL_BIN_DIR/UV_PYTHON_INSTALL_DIR there for any further uv tool installs).
