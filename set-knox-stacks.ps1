# Raises the stack size (items of one type sharing a tile) in Zomboid\Lua\knox_overrides.txt for a whole
# display category of the game's items, WITHOUT touching anything else in the file (your hand edits stay).
#
#   -Stack N            stack size to give (default 20)
#   -DisplayCategory    game category/categories to affect (default Material and Camping = Knox's "mat" tab)
#   -Ids Base.A,Base.B  extra individual items to give the same stack
#   -Force              also lower stacks that are already higher than -Stack (default: only ever raises)
#   -DryRun             show what would change, write nothing
#
# Only items the mod can stack at all are touched: plain and drainable items. Clothing, food, books, bags,
# weapons, fluid containers and moveables (tents...) can't be stacked by the mod, whatever the file says.
# For a single item you can still just write "Base.Plank = stack 30" by hand in knox_overrides.txt.
# NOTE: an item must stay on ONE line there ("Base.X = 1x2 stack 30"): a second line for the same item replaces the first.
#
# DEFAULT MODE (no -Stack): stack sizes come from stack-rules.txt next to this script (see its header).
# -Stack N mode: one size N for -DisplayCategory / -Ids, as described above.
param(
    [int]$Stack = 0,
    [string]$Rules = (Join-Path $PSScriptRoot 'stack-rules.txt'),
    [string[]]$DisplayCategory = @('Material', 'Camping'),
    [string[]]$Ids = @(),
    [switch]$Force,
    [switch]$DryRun,
    [string]$Out = "$env:USERPROFILE\Zomboid\Lua\knox_overrides.txt"
)
$ErrorActionPreference = 'Stop'
if ($Stack -lt 0 -or $Stack -gt 1000) { throw "-Stack must be 1..1000" }
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\scripts"
$knox = "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3816775774\mods\KnoxInventory\42\media\lua\shared\Knox\KnoxFootprintData.lua"

# Knox's own stack sizes (items one tile holds * 100 + short side * 10 + long side)
$knoxStack = @{}
foreach ($l in Get-Content $knox) {
    if ($l -match '^KnoxBagData\s*=') { break }
    if ($l -match '^\["([^"]+)"\]=(\d+)') { $knoxStack[$matches[1]] = [math]::Floor([int]$matches[2] / 100) }
}

# The game's items: category, type, fluid container or not
$items = @{}
foreach ($f in Get-ChildItem $game -Recurse -Filter *.txt) {
    $mod = $null; $cur = $null; $depth = 0; $in = $false
    foreach ($l in [IO.File]::ReadLines($f.FullName)) {
        if ($l -match '^\s*module\s+(\w+)') { $mod = $matches[1]; continue }
        if (-not $in -and $mod -and $l -match '^\s*item\s+(\w+)\s*$') { $cur = @{ id = "$mod.$($matches[1])" }; $in = $true; $depth = 0; continue }
        if ($in) {
            if ($l -match '^\s*\{') { $depth++; continue }
            if ($l -match '^\s*\}') { $depth--; if ($depth -le 0) { $items[$cur.id] = $cur; $in = $false }; continue }
            if ($l -match '^\s*(DisplayCategory|ItemType|Weight)\s*=\s*([^,]+)') { $cur[$matches[1]] = $matches[2].Trim() }
            elseif ($l -match 'FluidContainer') { $cur.Fluid = $true }
        }
    }
}

# weapon-class items that the KnoxInventoryTweaks companion mod lets stack (keep in sync with its STACKABLE_WEAPON_CATEGORIES)
$weaponCats = @('MaterialWeapon')
# item types Knox (with the KnoxInventoryTweaks mod) can stack: keep in sync with that mod's OPEN_CLASSES
$stackTypes = '^base:(normal|drainable|food|literature|map|key|weaponpart)$'
$inv = [Globalization.CultureInfo]::InvariantCulture
$want = @{}      # item -> stack size wanted
if ($Stack -gt 0) {
    foreach ($it in $items.Values) {
        if (-not $knoxStack.ContainsKey($it.id)) { continue }
        if (-not (($it.ItemType -match $stackTypes) -or ($it.ItemType -eq 'base:weapon' -and $weaponCats -contains $it.DisplayCategory)) -or $it.Fluid) { continue }
        if ($DisplayCategory -contains $it.DisplayCategory) { $want[$it.id] = $Stack }
    }
    foreach ($id in $Ids) { if ($knoxStack.ContainsKey($id)) { $want[$id] = $Stack } else { Write-Warning "unknown item $id (skipped)" } }
} else {
    # rules file: last matching rule wins
    $ruleList = @()
    foreach ($raw in Get-Content $Rules) {
        $t = ($raw -replace '#.*$', '').Trim()
        if ($t -eq '') { continue }
        if ($t -notmatch '^(.+?)=\s*(\d+)$') { Write-Warning "bad rule: $raw"; continue }
        $tok = $matches[1].Trim() -split '\s+'; $n = [int]$matches[2]
        $rule = @{ n = $n; sel = $tok[0]; conds = @() }
        foreach ($c in $tok[1..($tok.Count)]) { if ($c) { if ($c -match '^kg(>=|<=|>|<)([\d.]+)$') { $rule.conds += , @($matches[1], [double]::Parse($matches[2], $inv)) } else { Write-Warning "bad condition '$c' in: $raw" } } }
        $ruleList += , $rule
    }
    foreach ($it in $items.Values) {
        if (-not $knoxStack.ContainsKey($it.id)) { continue }
        if (-not (($it.ItemType -match $stackTypes) -or ($it.ItemType -eq 'base:weapon' -and $weaponCats -contains $it.DisplayCategory)) -or $it.Fluid) { continue }
        $kg = 1.0; if ($it.Weight) { $kg = [double]::Parse($it.Weight, $inv) }
        $hit = $null
        foreach ($r in $ruleList) {
            if ($r.sel -like 'cat:*') { if (($r.sel.Substring(4) -split ',') -notcontains $it.DisplayCategory) { continue } }
            elseif ($r.sel -like 'id:*') { if ($it.id -notlike $r.sel.Substring(3)) { continue } }
            else { continue }
            $ok = $true
            foreach ($c in $r.conds) {
                switch ($c[0]) { '>=' { if (-not ($kg -ge $c[1])) { $ok = $false } } '<=' { if (-not ($kg -le $c[1])) { $ok = $false } } '>' { if (-not ($kg -gt $c[1])) { $ok = $false } } '<' { if (-not ($kg -lt $c[1])) { $ok = $false } } }
            }
            if ($ok) { $hit = $r.n }
        }
        if ($hit) { $want[$it.id] = $hit }
    }
    $Stack = 0
}
$targets = @($want.Keys)

# Edit the file in place: one line per item, add or raise its "stack N"
$lines = New-Object System.Collections.Generic.List[string]
if (Test-Path $Out) { foreach ($l in Get-Content $Out) { $lines.Add($l) } }
$index = @{}
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*([^#=\s]+)\s*=') { $index[$matches[1]] = $i } }

$changed = 0; $added = 0; $same = 0
foreach ($id in ($targets | Sort-Object)) {
    $S = $want[$id]
    if ($index.ContainsKey($id)) {
        $line = $lines[$index[$id]]
        $cur = $knoxStack[$id]
        if ($line -match '(?i)\bstack\s*(\d+)') { $cur = [int]$matches[1] }
        if ($cur -eq $S -or ($cur -gt $S -and -not $Force)) { $same++; continue }
        if ($line -match '(?i)\bstack\s*\d+') { $new = [regex]::Replace($line, '(?i)\bstack\s*\d+', "stack $S") }
        else { $new = ($line -replace '\s+$', '') + " stack $S" }
        $lines[$index[$id]] = $new; $changed++
    } else {
        if ($knoxStack[$id] -ge $S -and -not $Force) { $same++; continue }
        $lines.Add("$id = stack $S"); $index[$id] = $lines.Count - 1; $added++
    }
}
"{0} items matched; stack lines added: {1}, existing lines updated: {2}, already at or above the wanted size: {3}" -f $targets.Count, $added, $changed, $same
if ($DryRun) { return }
if ($changed + $added -eq 0) { return }
if (Test-Path $Out) { Copy-Item $Out ("$Out." + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak') }
Set-Content -Path $Out -Value $lines -Encoding ASCII
"Wrote $Out"





