# Generates Zomboid\Lua\knox_overrides.txt for Knox Inventory so that item footprints follow item weight.
#   ItemCellsPerKg : an item may take at most ceil(weight * ItemCellsPerKg) cells (min 1). Only ever shrinks items.
#   BagCellsPerCap : every vanilla bag's grid gets capacity * BagCellsPerCap cells (mod default is 2).
# Re-run with different numbers to rebalance, then restart to main menu and reload your save.
param(
    [double]$ItemCellsPerKg = 2,
    [double]$BagCellsPerCap = 3,
    [int]$MaxBagRows = 15,
    [int]$MaxBagCols = 8,
    [switch]$NoStacks,             # skip the stack sizes of stack-rules.txt (leave Knox's own)
    [string]$Tweaks = (Join-Path $PSScriptRoot 'my-overrides.txt'),   # your own lines, applied last
    [string]$Out = "$env:USERPROFILE\Zomboid\Lua\knox_overrides.txt",
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$game = "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid\media\scripts"
$knox = "C:\Program Files (x86)\Steam\steamapps\workshop\content\108600\3816775774\mods\KnoxInventory\42\media\lua\shared\Knox\KnoxFootprintData.lua"

# 1. Knox's own footprints (items one tile holds * 100 + short side * 10 + long side) and bag shapes
$fp = @{}; $bagShape = @{}; $sec = 0
foreach ($l in Get-Content $knox) {
    if ($l -match '^KnoxBagData\s*=') { $sec = 1 }
    if ($l -match '^\["([^"]+)"\]=(\d+)') { if ($sec -eq 0) { $fp[$matches[1]] = [int]$matches[2] } else { $bagShape[$matches[1]] = [int]$matches[2] } }
}

# 2. Item weights / capacities from the game's own scripts
$items = @{}
foreach ($f in Get-ChildItem $game -Recurse -Filter *.txt) {
    $mod = $null; $cur = $null; $depth = 0; $inItem = $false
    foreach ($l in [IO.File]::ReadLines($f.FullName)) {
        if ($l -match '^\s*module\s+(\w+)') { $mod = $matches[1]; continue }
        if (-not $inItem -and $mod -and $l -match '^\s*item\s+(\w+)\s*$') { $cur = @{ id = "$mod.$($matches[1])" }; $inItem = $true; $depth = 0; continue }
        if ($inItem) {
            if ($l -match '^\s*\{') { $depth++; continue }
            if ($l -match '^\s*\}') { $depth--; if ($depth -le 0) { $items[$cur.id] = $cur; $inItem = $false }; continue }
            if ($l -match '^\s*(Weight|Capacity|ItemType)\s*=\s*([^,]+)') { $cur[$matches[1]] = $matches[2].Trim() }
        }
    }
}
$inv = [Globalization.CultureInfo]::InvariantCulture
$NICE = 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100

$lines = New-Object System.Collections.Generic.List[string]
$nItems = 0; $nBags = 0; $saved = 0

foreach ($id in ($fp.Keys | Sort-Object)) {
    $v = $fp[$id]; $stack = [math]::Floor($v / 100); $w = [math]::Floor($v / 10) % 10; $h = $v % 10
    $it = $items[$id]
    $kg = 1.0
    if ($it -and $it.Weight) { $kg = [double]::Parse($it.Weight, $inv) }
    $parts = @()

    if ($bagShape.ContainsKey($id)) {
        # a bag: bigger grid, same shape (columns), capped to what the inventory column can show
        $cap = 0; if ($it -and $it.Capacity) { $cap = [double]::Parse($it.Capacity, $inv) }
        if ($cap -gt 0) {
            $cols = [math]::Floor($bagShape[$id] / 100); $minRows = $bagShape[$id] % 100
            $cells = [math]::Max(2, [math]::Round($cap * $BagCellsPerCap, [MidpointRounding]::AwayFromZero))
            $rows = [math]::Max($minRows, [math]::Round($cells / $cols, [MidpointRounding]::AwayFromZero))
            while ($rows -gt $MaxBagRows -and $cols -lt $MaxBagCols) { $cols++; $rows = [math]::Max($minRows, [math]::Round($cells / $cols, [MidpointRounding]::AwayFromZero)) }
            $rows = [math]::Min($rows, $MaxBagRows)
            $parts += "grid ${cols}x${rows}"
            $nBags++
        }
    }

    $area = $w * $h
    $maxArea = [math]::Max(1, [math]::Ceiling($kg * $ItemCellsPerKg - 1e-9))
    if ($area -gt $maxArea -and -not $bagShape.ContainsKey($id)) {
        # largest nw x nh (nw <= nh) inside the old box and the cell budget; prefer the old aspect, keep length
        $best = $null; $bestScore = $null
        for ($nw = 1; $nw -le $w; $nw++) { for ($nh = $nw; $nh -le $h; $nh++) {
            if ($nw * $nh -gt $maxArea) { continue }
            $score = ($nw * $nh) * 10 - [math]::Abs(($nh / $nw) - ($h / $w))
            if ($null -eq $bestScore -or $score -gt $bestScore) { $best = @($nw, $nh); $bestScore = $score }
        } }
        $nw = $best[0]; $nh = $best[1]
        $parts += "${nw}x${nh}"
        # stacking: recompute for the smaller tile, never more than before
        if ($stack -gt 1 -or ($it -and $it.ItemType -match 'normal|drainable' -and $stack -ge 1 -and $false)) {
            $n = 2.0 * ($nw * $nh) / [math]::Max($kg, 0.001)
            if ($nw * $nh -gt 1) { $n = [math]::Min($n, 4) }
            $s = 1; foreach ($x in $NICE) { if ($x -le $n + 1e-9) { $s = $x } }
            $s = [math]::Min($s, $stack)
            if ($s -ne $stack) { $parts += "stack $s" }
        }
        $nItems++; $saved += ($area - $nw * $nh)
    }
    if ($parts.Count -gt 0) { $lines.Add("$id = $($parts -join ' ')") }
}

$header = @"
# Knox Inventory: your own item sizes. One line per item, then exit to the main menu
# and load your save again (the file is read when the mod's Lua loads).
#
#   Base.Katana = 1x5                 cells the item takes (it still turns)
#   Base.Bag_ALICEpack = grid 8x10    a bag's grid inside, whatever its capacity
#   Base.Nails = stack 50             how many share one tile
#   (category / sound overrides also work - see the mod page)
#
# GENERATED by generate-knox-overrides.ps1  (ItemCellsPerKg=$ItemCellsPerKg, BagCellsPerCap=$BagCellsPerCap)
#   item footprint <= ceil(weight * $ItemCellsPerKg) cells, bags get capacity * $BagCellsPerCap cells.
# Edit freely, or re-run the script. Lines starting with # are notes.

show_ids = no

"@
if ($DryRun) { "items shrunk: $nItems  (cells freed per set of one of each: $saved)  bags regridded: $nBags  lines: $($lines.Count)"; $lines | Select-Object -First 40; return }
if (Test-Path $Out) { Copy-Item $Out ("$Out." + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak') }   # always keep the previous file
Set-Content -Path $Out -Value ($header + ($lines -join "`r`n")) -Encoding ASCII
"Wrote $Out : items shrunk $nItems, bags regridded $nBags"

# stack sizes from stack-rules.txt (edits the file just written)
if (-not $NoStacks) { & (Join-Path $PSScriptRoot 'set-knox-stacks.ps1') -Out $Out }

# your own lines go last: a tweak line replaces the generated line for the same item (whole line, as the mod does)
if (Test-Path $Tweaks) {
    $file = New-Object System.Collections.Generic.List[string]
    foreach ($l in Get-Content $Out) { $file.Add($l) }
    $index = @{}
    for ($i = 0; $i -lt $file.Count; $i++) { if ($file[$i] -match '^\s*([^#=\s]+)\s*=') { $index[$matches[1]] = $i } }
    $replaced = 0; $appended = 0
    foreach ($t in Get-Content $Tweaks) {
        if ($t -notmatch '^\s*([^#=\s]+)\s*=') { continue }
        if ($index.ContainsKey($matches[1])) { $file[$index[$matches[1]]] = $t.Trim(); $replaced++ }
        else { $file.Add($t.Trim()); $index[$matches[1]] = $file.Count - 1; $appended++ }
    }
    Set-Content -Path $Out -Value $file -Encoding ASCII
    "Applied $Tweaks : $replaced lines replaced, $appended appended"
}
