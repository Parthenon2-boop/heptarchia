# A történelmi hadvezérek táblájából (hadvezerek.psv) előállítja:
#   – scripts\hadvezer_adat.gd  (a játék adatfájlja: nép, évek, szint, jelleg, vonások, a személy azonosítója)
#   – a három nyelvi fájl (lang\hu.json, en.json, de.json) _HADVEZER_KEZDETE … _HADVEZER_VEGE blokkját:
#     <KULCS> = a név, <KULCS>_BIO = a rövid ismertető;
#   – a rendszer felületi szövegeit (szovegek.psv: kulcs|hu|en|de) a _HADVEZER_SZOVEG_KEZDETE … _VEGE blokkba.
# Többször futtatható: a régi blokkot kicseréli. A nyelvi fájlok többi sorához nem nyúl.
#   powershell -ExecutionPolicy Bypass -File tools\hadvezer\general.ps1
# Ha egy GEN_ kulcs ütközne egy már meglévő (a blokkon kívüli) nyelvi kulccsal, minden generált kulcs a
# HV_ előtagot kapja (GEN_X -> HV_X), és a szkript ezt kiírja.
# (PowerShell 5.1: ezt a fájlt BOM-mal kell menteni, különben az ékezetek elromlanak benne.)
param([string]$projekt = "")
$ErrorActionPreference = 'Stop'
if ($projekt -eq "") { $projekt = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$utf8 = New-Object System.Text.UTF8Encoding($false)
$psv = Join-Path $PSScriptRoot 'hadvezerek.psv'
$KEZD = '_HADVEZER_KEZDETE'; $VEG = '_HADVEZER_VEGE'
$SZKEZD = '_HADVEZER_SZOVEG_KEZDETE'; $SZVEG = '_HADVEZER_SZOVEG_VEGE'
$JELLEGEK = @('cavalry', 'archers', 'infantry', 'stalwart', 'raider')
$VONASOK = @('siege', 'naval', 'cautious', 'reckless', 'logistics', 'artillery', 'inspiring', 'ruthless', 'ambitious', 'loyal', 'tactician', 'defender')

function Json-Szoveg([string]$s) {
	# (a szövegekben a \n sortörést jelent, az megmarad)
	$s = $s.Replace('\', '\\').Replace('"', '\"').Replace("`t", ' ').Replace('\\n', '\n')
	return '"' + $s + '"'
}

# ── a felületi szövegek ──
$szovegek = @()
$szut = Join-Path $PSScriptRoot 'szovegek.psv'
if (Test-Path -LiteralPath $szut) {
	$n = 0
	foreach ($l in [IO.File]::ReadAllLines($szut, $utf8)) {
		$n++
		if ($l.Trim() -eq '' -or $l.StartsWith('#')) { continue }
		$a = $l.Split('|')
		if ($a.Count -ne 4) { throw "szovegek.psv $n. sor: 4 mező kell, $($a.Count) van" }
		$szovegek += [pscustomobject]@{ kulcs = $a[0].Trim(); hu = $a[1]; en = $a[2]; de = $a[3] }
	}
	$d2 = @($szovegek | Group-Object kulcs | Where-Object { $_.Count -gt 1 })
	if ($d2.Count -gt 0) { throw "szovegek.psv: kétszer szereplő kulcs: $($d2[0].Name)" }
}

# ── a tábla beolvasása ──
$sorok = @()
$n = 0
foreach ($l in [IO.File]::ReadAllLines($psv, $utf8)) {
	$n++
	if ($l.Trim() -eq '' -or $l.StartsWith('#')) { continue }
	$a = $l.Split('|')
	if ($a.Count -ne 14) { throw "hadvezerek.psv $n. sor: 14 mező kell, $($a.Count) van" }
	$von = @($a[7].Trim().Split(' ') | Where-Object { $_ -ne '' })
	if ($JELLEGEK -notcontains $a[6]) { throw "$n. sor: ismeretlen jelleg: $($a[6])" }
	foreach ($v in $von) { if ($VONASOK -notcontains $v) { throw "$n. sor: ismeretlen vonás: $v" } }
	if ($a[4] -notmatch '^GEN_[A-Z0-9_]+$') { throw "$n. sor: hibás kulcs: $($a[4])" }
	$sorok += [pscustomobject]@{ nep = $a[0].Trim(); tol = [int]$a[1]; ig = [int]$a[2]; szul = [int]$a[3]; kulcs = $a[4].Trim()
		szint = [Math]::Max(1, [Math]::Min(3, [int]$a[5])); jelleg = $a[6]; von = $von
		hu = $a[8]; en = $a[9]; de = $a[10]; mhu = $a[11]; men = $a[12]; mde = $a[13]; szem = '' }
}
$dupla = @($sorok | Group-Object kulcs | Where-Object { $_.Count -gt 1 })
if ($dupla.Count -gt 0) { throw "kétszer szereplő kulcs: $($dupla[0].Name)" }

# ── ugyanaz a személy több sorban (más népnél, zsoldosként): a név és a születési év azonos ──
# a személy azonosítója a csoport legrövidebb kulcsa (pl. GEN_HANNIBAL a GEN_HANNIBAL_2 sornak is)
foreach ($cs in ($sorok | Group-Object { $_.hu + '|' + $_.szul })) {
	$alap = ($cs.Group | Sort-Object { $_.kulcs.Length }, kulcs | Select-Object -First 1).kulcs
	foreach ($s in $cs.Group) { $s.szem = $alap }
}

# ── ütközik-e valamelyik kulcs a nyelvi fájlok meglévő (blokkon kívüli) kulcsaival? ──
function Kivul-Sorok([string]$ut) {
	$be = [IO.File]::ReadAllLines($ut, $utf8)
	$ki = New-Object System.Collections.Generic.List[string]
	$bent = $false
	foreach ($l in $be) {
		if ($l -match ('^\s*"(' + $KEZD + '|' + $SZKEZD + ')"')) { $bent = $true; continue }
		if ($l -match ('^\s*"(' + $VEG + '|' + $SZVEG + ')"')) { $bent = $false; continue }
		if (-not $bent) { $ki.Add($l) }
	}
	return $ki
}
$nyelvek = @('hu', 'en', 'de')
$kivul = @{}
$foglalt = @{}
foreach ($ny in $nyelvek) {
	$kivul[$ny] = Kivul-Sorok (Join-Path $projekt "lang\$ny.json")
	foreach ($l in $kivul[$ny]) { if ($l -match '^\s*"([^"]+)"\s*:') { $foglalt[$Matches[1]] = $true } }
}
foreach ($s in $szovegek) { if ($foglalt.ContainsKey($s.kulcs)) { throw "szovegek.psv: a kulcs már létezik a nyelvi fájlban: $($s.kulcs)" } }
$elotag = 'GEN_'
foreach ($s in $sorok) {
	if ($foglalt.ContainsKey($s.kulcs) -or $foglalt.ContainsKey($s.kulcs + '_BIO')) { $elotag = 'HV_'; "Ütközés: $($s.kulcs) – a generált kulcsok HV_ előtagot kapnak" }
}
function Kulcs([string]$k) { if ($elotag -eq 'GEN_') { return $k } else { return 'HV_' + $k.Substring(4) } }

# ── az adatfájl ──
$gd = New-Object System.Text.StringBuilder
[void]$gd.Append("extends RefCounted`n`n")
[void]$gd.Append("# GENERÁLT FÁJL – ne szerkeszd kézzel! Forrás: tools/hadvezer/hadvezerek.psv, generátor: tools/hadvezer/general.ps1`n")
[void]$gd.Append("# A történelmi hadvezérek: [nép (vagy `"*kultúra`" = felbérelhető zsoldosvezér), tól, ig, születés, kulcs (a név nyelvi kulcsa;`n")
[void]$gd.Append("# az ismertető: <kulcs>_BIO), szint 1–3, jelleg, [vonások], a személy azonosítója (ugyanaz az ember több sorban)]`n")
[void]$gd.Append("const SOROK := [`n")
foreach ($s in ($sorok | Sort-Object nep, tol, kulcs)) {
	$v = ($s.von | ForEach-Object { '"' + $_ + '"' }) -join ', '
	[void]$gd.Append(("`t[`"{0}`", {1}, {2}, {3}, `"{4}`", {5}, `"{6}`", [{7}], `"{8}`"],`n" -f $s.nep, $s.tol, $s.ig, $s.szul, (Kulcs $s.kulcs), $s.szint, $s.jelleg, $v, (Kulcs $s.szem)))
}
[void]$gd.Append("]`n")
[IO.File]::WriteAllText((Join-Path $projekt 'scripts\hadvezer_adat.gd'), $gd.ToString(), $utf8)

# ── a nyelvi blokkok ──
foreach ($ny in $nyelvek) {
	$ut = Join-Path $projekt "lang\$ny.json"
	$l = New-Object System.Collections.Generic.List[string]
	$l.AddRange([string[]]$kivul[$ny])
	# a záró kapcsos zárójel és az utolsó valódi sor
	$zaro = $l.Count - 1
	while ($zaro -ge 0 -and $l[$zaro].Trim() -ne '}') { $zaro-- }
	if ($zaro -lt 1) { throw "$ny.json: nincs záró kapcsos zárójel" }
	$utolso = $zaro - 1
	while ($utolso -ge 0 -and $l[$utolso].Trim() -eq '') { $utolso-- }
	if (-not $l[$utolso].TrimEnd().EndsWith(',')) { $l[$utolso] = $l[$utolso].TrimEnd() + ',' }
	$blokk = New-Object System.Collections.Generic.List[string]
	if ($szovegek.Count -gt 0) {
		$blokk.Add("`t`"$SZKEZD`": `"`",")
		foreach ($s in $szovegek) { $blokk.Add("`t`"$($s.kulcs)`": " + (Json-Szoveg $s.$ny) + ',') }
		$blokk.Add("`t`"$SZVEG`": `"`",")
	}
	$blokk.Add("`t`"$KEZD`": `"`",")
	foreach ($s in $sorok) {
		$nev = $s.$ny
		$bio = switch ($ny) { 'hu' { $s.mhu } 'en' { $s.men } default { $s.mde } }
		$k = Kulcs $s.kulcs
		$blokk.Add("`t`"$k`": " + (Json-Szoveg $nev) + ',')
		$blokk.Add("`t`"${k}_BIO`": " + (Json-Szoveg $bio) + ',')
	}
	$blokk.Add("`t`"$VEG`": `"`"")
	$l.InsertRange($zaro, $blokk)
	[IO.File]::WriteAllText($ut, (($l -join "`n") + "`n"), $utf8)
}
"Szövegek: $($szovegek.Count) kulcs"
"Kész: $($sorok.Count) hadvezér ($(@($sorok | Where-Object { $_.nep.StartsWith('*') }).Count) zsoldosvezér), előtag: $elotag"
