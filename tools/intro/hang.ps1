param(
	[string[]]$Csak = @(),          # csak ezek a jelenetek (pl. -Csak 03,07); üresen mind a tíz
	[string]$Masolat = "",          # ide WAV és OGG másolat kerül belehallgatáshoz
	[string]$Tempo = "-8%",         # SSML prosody rate
	[string]$Hangmagassag = "-8%",  # SSML prosody pitch
	[int]$Bitrata = 32000,          # az Ogg Vorbis célbitrátája (bit/mp; 16 kHz, mono)
	[switch]$CsakSzoveg,            # csak kiírja, mit olvasna föl (a kiejtési cserék után)
	[string]$Blender = 'C:\Users\student\Downloads\blender-5.2.2-windows-x64\blender.exe'
)
# HEPTARCHIA – a bevezető magyar felolvasása (assets/intro/hang/hu_01.ogg … hu_10.ogg)
#
#   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1
#   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1 -Csak 03,07 -Masolat C:\temp\intro
#   powershell -ExecutionPolicy Bypass -File tools\intro\hang.ps1 -CsakSzoveg
#
# A szöveg a lang\hu.json INTRO_01 … INTRO_10 kulcsa (ugyanaz, ami a felirat); a felolvasás előtt a
# kiejtes.psv cseréi futnak le rajta (évszámok betűvel, óangol nevek magyaros átírással).
# A hang a Windows beépített „Microsoft Szabolcs” (hu-HU) hangja, a WinRT beszédszintetizátorán át –
# ezért Windows PowerShell 5.1 kell hozzá (a PowerShell 7 nem tölti be a WinRT típusokat).
# A WAV-okat a kodol.py (a Blender Pythonja, `aud` modul) vágja, szintezi és kódolja Ogg Vorbisba.
# Utána:  Godot… --headless --path . --import   (az új .ogg fájlok importálása)

$ErrorActionPreference = 'Stop'
$mappa = Split-Path -Parent $MyInvocation.MyCommand.Path
$projekt = Split-Path -Parent (Split-Path -Parent $mappa)
$ki = Join-Path $projekt 'assets\intro\hang'
$munka = Join-Path $env:TEMP 'hep_intro_hang'

# ── a szöveg a nyelvi fájlból (soronként, hogy a 4600 kulcsos JSON-t ne kelljen egészben értelmezni) ──
$szoveg = @{}
foreach ($sor in [IO.File]::ReadAllLines((Join-Path $projekt 'lang\hu.json'), [Text.Encoding]::UTF8)) {
	if ($sor -match '^\s*"INTRO_(\d\d)":\s*(".*"),?\s*$') { $szoveg[$Matches[1]] = ConvertFrom-Json $Matches[2] }
}
if ($szoveg.Count -eq 0) { throw 'a lang\hu.json-ban nincs INTRO_NN kulcs' }

# ── a kiejtési cserék ──
$cserek = @()
foreach ($sor in [IO.File]::ReadAllLines((Join-Path $mappa 'kiejtes.psv'), [Text.Encoding]::UTF8)) {
	if ($sor.Trim() -eq '' -or $sor.StartsWith('#')) { continue }
	$a = $sor.Split('|')
	if ($a.Count -ne 2) { throw "kiejtes.psv: két mező kell: $sor" }
	$cserek += , @($a[0], $a[1])
}
function Kiejtve([string]$s) {
	foreach ($c in $cserek) { $s = $s.Replace($c[0], $c[1]) }
	# a gondolatjel szünet: vesszőként olvassa
	$s = [regex]::Replace($s, '\s*–\s*,?\s*', ', ')
	return $s
}

$sorszamok = @($szoveg.Keys | Sort-Object)
if ($Csak.Count -gt 0) { $sorszamok = @($sorszamok | Where-Object { $Csak -contains $_ }) }
$hiba = 0
foreach ($n in $sorszamok) {
	$k = Kiejtve $szoveg[$n]
	"{0}: {1}" -f $n, $k
	if ($k -match '\d') { "    HIBA: számjegy maradt a felolvasandó szövegben – vedd föl a kiejtes.psv-be"; $hiba++ }
}
if ($hiba -gt 0) { throw "$hiba jelenet szövegében számjegy maradt" }
if ($CsakSzoveg) { return }

# ── a beszédszintetizátor (WinRT) ──
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[void][Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType = WindowsRuntime]
[void][Windows.Storage.Streams.DataReader, Windows.Storage.Streams, ContentType = WindowsRuntime]
$asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
	$_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Megvar($op, $tipus) {
	$t = $asTask.MakeGenericMethod($tipus).Invoke($null, @($op))
	$t.Wait(-1) | Out-Null
	$t.Result
}
$sz = New-Object Windows.Media.SpeechSynthesis.SpeechSynthesizer
$hangok = @([Windows.Media.SpeechSynthesis.SpeechSynthesizer]::AllVoices | Where-Object { $_.Language -eq 'hu-HU' })
if ($hangok.Count -eq 0) { throw 'nincs magyar (hu-HU) hang a gépen' }
$sz.Voice = $hangok[0]
"Hang: $($sz.Voice.DisplayName)  ·  tempó $Tempo, hangmagasság $Hangmagassag"

New-Item -ItemType Directory -Force $munka | Out-Null
New-Item -ItemType Directory -Force $ki | Out-Null
Get-ChildItem $munka -Filter 'hu_*.wav' | Remove-Item -Force
foreach ($n in $sorszamok) {
	$t = [Security.SecurityElement]::Escape((Kiejtve $szoveg[$n]))
	$ssml = "<speak version=`"1.0`" xmlns=`"http://www.w3.org/2001/10/synthesis`" xml:lang=`"hu-HU`"><prosody rate=`"$Tempo`" pitch=`"$Hangmagassag`">$t</prosody></speak>"
	$st = Megvar ($sz.SynthesizeSsmlToStreamAsync($ssml)) ([Windows.Media.SpeechSynthesis.SpeechSynthesisStream])
	$r = New-Object Windows.Storage.Streams.DataReader($st.GetInputStreamAt(0))
	[void](Megvar ($r.LoadAsync([uint32]$st.Size)) ([uint32]))
	$b = New-Object byte[] $st.Size
	$r.ReadBytes($b)
	[IO.File]::WriteAllBytes((Join-Path $munka "hu_$n.wav"), $b)
}

# ── vágás, szintezés, Ogg Vorbis (a Blender Pythonjával) ──
$env:PYTHONIOENCODING = 'utf-8'
$arg = @('-b', '--factory-startup', '--python', "`"$(Join-Path $mappa 'kodol.py')`"", '--', "`"$munka`"", "`"$ki`"", "$Bitrata")
if ($Masolat -ne '') { New-Item -ItemType Directory -Force $Masolat | Out-Null; $arg += "`"$Masolat`"" }
$p = Start-Process -FilePath $Blender -ArgumentList $arg -NoNewWindow -PassThru -Wait -RedirectStandardOutput (Join-Path $munka 'kodol.log')
$null = $p.Handle
Get-Content (Join-Path $munka 'kodol.log') -Encoding UTF8 | Where-Object { $_ -match '^(hu_|ÖSSZESEN|HIBA)' }
if ($p.ExitCode -ne 0) { throw "a kódolás nem sikerült (kilépési kód $($p.ExitCode)) – lásd $munka\kodol.log" }
"Kész: $ki   (utána: Godot --headless --path . --import)"
