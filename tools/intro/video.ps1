param(
	[string]$Ki = 'C:\Users\student\Documents\játékaim\Birodalom_Godot\docs\video\heptarchia-bevezeto.mp4',   # a borítókép ugyanide, .jpg
	[int]$Bitrata = 900,            # a videó bitrátája (kbit/s); a hang 112 kbit/s AAC
	[int]$BoritoKocka = 0,          # a borítókép kockája (0 = az 5. másodperc)
	[string]$Kockak = '',           # a képkockák mappája (alapból a TEMP-ben; a futás végén megmarad)
	[switch]$KepNelkul,             # próbához: akkor is fusson, ha hiányzik festmény (a helyén sötét háttér)
	[switch]$CsakVagas,             # a felvétel már megvan a -Kockak mappában: csak a Blender-vágás
	[string]$Godot = 'C:\Users\student\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
	[string]$Blender = 'C:\Users\student\Downloads\blender-5.2.2-windows-x64\blender.exe'
)
# HEPTARCHIA – a bevezető képsor videója a honlapra (1280×720, 30 kép/mp, H.264 MP4, magyar hang, beégetett felirat)
#
#   powershell -ExecutionPolicy Bypass -File tools\intro\video.ps1
#   powershell -ExecutionPolicy Bypass -File tools\intro\video.ps1 -KepNelkul -Ki C:\temp\proba.mp4
#
# 1. a játék saját képsorát a felvevo.gd képkockánként JPG-be menti (--fixed-fps 30: kockára pontos idő;
#    közben kb. két percre megjelenik a játék ablaka – ne takard el és ne tedd le a tálcára);
# 2. a video.py a Blender videószerkesztőjével alávágja a felolvasást (assets\intro\hang\hu_NN.ogg) és
#    Wessex zenéjét, és MP4-be kódolja; mellé borítóképet ment.
# Előtte: a tíz festmény legyen meg (assets\intro\01_alfred.jpg … 10_hajnal.jpg), a hang legyen
# legenerálva (hang.ps1).

$ErrorActionPreference = 'Stop'
$mappa = Split-Path -Parent $MyInvocation.MyCommand.Path
$projekt = Split-Path -Parent (Split-Path -Parent $mappa)
$jelenetek = '01_alfred', '02_het_kiralysag', '03_lindisfarne', '04_nagy_sereg', '05_york', '06_ashdown', '07_athelney', '08_edington', '09_burh', '10_hajnal'
$hianyzik = @($jelenetek | Where-Object { -not (Test-Path -LiteralPath (Join-Path $projekt "assets\intro\$_.jpg")) })
if ($hianyzik.Count -gt 0) {
	"Hiányzó festmény: $($hianyzik -join ', ')"
	if (-not $KepNelkul) { throw 'nincs meg mind a tíz kép (próbához: -KepNelkul)' }
}
$hangok = @(Get-ChildItem (Join-Path $projekt 'assets\intro\hang') -Filter 'hu_*.ogg' -ErrorAction SilentlyContinue)
if ($hangok.Count -ne 10) { throw "a felolvasásból $($hangok.Count) fájl van meg a tízből – előbb: tools\intro\hang.ps1" }
if ($Kockak -eq '') { $Kockak = Join-Path $env:TEMP 'hep_intro_kockak' }
$naplo = Join-Path $env:TEMP 'hep_intro_video'
New-Item -ItemType Directory -Force $naplo | Out-Null

function Futtat([string]$exe, [string[]]$argok, [string]$nev, [int]$mp) {
	$p = Start-Process -FilePath $exe -ArgumentList $argok -NoNewWindow -PassThru -RedirectStandardOutput "$naplo\$nev.log" -RedirectStandardError "$naplo\$nev.err"
	$null = $p.Handle
	if (-not $p.WaitForExit($mp * 1000)) {
		& taskkill.exe /PID $p.Id /T /F *> $null      # csak a saját magunk indította folyamatot
		throw "${nev}: időtúllépés ($mp mp) – lásd $naplo\$nev.log"
	}
	if ($p.ExitCode -ne 0) { throw "${nev}: kilépési kód $($p.ExitCode) – lásd $naplo\$nev.log és .err" }
}

if (-not $CsakVagas) {
	if (Test-Path -LiteralPath $Kockak) { Get-ChildItem -LiteralPath $Kockak -Filter 'k*.jpg' | Remove-Item -Force }
	$env:HEP_KI = $Kockak.Replace('\', '/')
	$env:HEP_NYELV = 'hu'
	"1/2  Felvétel: $Kockak"
	Futtat $Godot @('--path', "`"$projekt`"", '--fixed-fps', '30', '--resolution', '1280x720', '-s', 'tools/intro/felvevo.gd') 'felvevo' 900
	Get-Content "$naplo\felvevo.log" -Encoding UTF8 | Where-Object { $_ -match '^(\[felvevo\]|JEL|KESZ|HIBA)' }
}
if (-not (Test-Path -LiteralPath (Join-Path $Kockak 'idovonal.json'))) { throw "nincs idovonal.json a $Kockak mappában" }

$borito = [IO.Path]::ChangeExtension($Ki, '.jpg')
New-Item -ItemType Directory -Force (Split-Path -Parent $Ki) | Out-Null
"2/2  Vágás: $Ki"
$env:PYTHONIOENCODING = 'utf-8'
Futtat $Blender @('-b', '--factory-startup', '--python', "`"$(Join-Path $mappa 'video.py')`"", '--',
	"`"$Kockak`"", "`"$(Join-Path $projekt 'assets\intro\hang')`"", "`"$(Join-Path $projekt 'assets\audio\nepek\wessex.ogg')`"",
	"`"$Ki`"", "`"$borito`"", "$Bitrata", "$BoritoKocka") 'video' 3600
Get-Content "$naplo\video.log" -Encoding UTF8 | Where-Object { $_ -match '^(KOCKÁK|hang |zene |FIGYELEM|BORÍTÓ|KÉSZ|HANG)' }
Get-Item -LiteralPath $Ki, $borito | ForEach-Object { "{0,10:N0} bájt  {1}" -f $_.Length, $_.FullName }
