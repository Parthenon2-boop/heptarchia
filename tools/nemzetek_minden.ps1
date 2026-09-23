# HEPTARCHIA – a térképek üres földjeinek felosztása a népek között (tools/nemzetek_maszk.gd)
# Minden térképen a nyers maszkból (amit a térképkészítő ír) készül a játék maszkja és a népadat-fájl.
# Futtatás a projekt mappájából:  powershell -ExecutionPolicy Bypass -File tools\nemzetek_minden.ps1
# Ha a scripts/vilag_nemzetek.gd tartományain változtatsz, ezt kell újra futtatni.

param([string]$Godot = "godot")

$ErrorActionPreference = "Stop"
$terkepek = @(
	# be, ki, json, vetület, origó x, origó y, csoportok
	@("res://assets/map/terkep_mask_nyers.png", "res://assets/map/terkep_mask_ext.png", "res://assets/map/nemzetek.json", "base", "0", "0", "base"),
	@("res://dlc/skandinavia/map/terkep_mask_nyers.png", "res://dlc/skandinavia/map/terkep_mask.png", "res://dlc/skandinavia/map/nemzetek.json", "dlc", "-980", "-990", "base,north,balts_ai"),
	@("res://dlc/varegok/map/terkep_mask_nyers.png", "res://dlc/varegok/map/terkep_mask.png", "res://dlc/varegok/map/nemzetek.json", "dlc", "-980", "-990", "base,north,south,scand_ai")
)
foreach ($t in $terkepek) {
	if (-not (Test-Path ($t[0] -replace "^res://", ""))) { Write-Host "kihagyva (nincs meg): $($t[0])"; continue }
	Write-Host "── $($t[1])"
	& $Godot --headless --path . -s res://tools/nemzetek_maszk.gd -- @t
	if ($LASTEXITCODE -ne 0) { throw "hiba: $($t[1])" }
}
