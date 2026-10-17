<#
  Shine's mod for Vivaldi — installer (Windows, PowerShell 5.1+)

  Install / reinstall (also after every Vivaldi update):
    irm https://raw.githubusercontent.com/bichoanh201698-collab/shines-mod-for-vivaldi/main/install.ps1 | iex

  Uninstall:
    $env:SHINE_UNINSTALL = 1; irm https://raw.githubusercontent.com/bichoanh201698-collab/shines-mod-for-vivaldi/main/install.ps1 | iex

  Options (environment variables):
    SHINE_YES=1        don't ask before closing Vivaldi
    SHINE_UNINSTALL=1  remove the mod
    SHINE_NO_AUTO=1    don't set up the auto-repair task (re-applies the mod after Vivaldi updates)
#>

$ErrorActionPreference = 'Stop'
$Repo      = 'bichoanh201698-collab/shines-mod-for-vivaldi'
$ShineHome = Join-Path $env:LOCALAPPDATA 'ShineMod'      # survives Vivaldi updates
$FilesHome = Join-Path $env:LOCALAPPDATA 'ShineMod-files' # copy of the JS part, for auto-repair
$TaskName  = "Shine's mod auto-repair"
$Marker    = '<script src="injectMods.js"></script>'

function Say($msg, $color = 'Gray') { Write-Host "  $msg" -ForegroundColor $color }

function Find-Vivaldi {
  $roots = @(
    (Join-Path $env:LOCALAPPDATA 'Vivaldi\Application'),
    (Join-Path $env:ProgramFiles 'Vivaldi\Application'),
    (Join-Path ${env:ProgramFiles(x86)} 'Vivaldi\Application')
  )
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    $ver = Get-ChildItem $root -Directory | Where-Object { $_.Name -match '^\d+(\.\d+){3}$' } |
      Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if ($ver -and (Test-Path (Join-Path $ver.FullName 'resources\vivaldi\window.html'))) {
      return [pscustomobject]@{
        Exe      = Join-Path $root 'vivaldi.exe'
        Version  = $ver.Name
        Res      = Join-Path $ver.FullName 'resources\vivaldi'
        UserData = Join-Path (Split-Path $root -Parent) 'User Data'
      }
    }
  }
  throw 'Vivaldi not found.'
}

function Get-Source {
  if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'css\Import.css'))) { return $PSScriptRoot }
  $tmp = Join-Path $env:TEMP 'shine-mod-download'
  if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
  New-Item -ItemType Directory $tmp | Out-Null
  $zip = Join-Path $tmp 'mod.zip'
  Say 'Downloading the mod...'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip $tmp -Force
  return (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
}

function Stop-Vivaldi {
  if (-not (Get-Process vivaldi -ErrorAction SilentlyContinue)) { return }
  if (-not $env:SHINE_YES) {
    Read-Host '  Vivaldi will be closed (your tabs are restored on restart). Press Enter to continue' | Out-Null
  }
  Get-Process vivaldi -ErrorAction SilentlyContinue | Stop-Process -Force
  for ($i = 0; $i -lt 20 -and (Get-Process vivaldi -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
}

function Read-Utf8($path) { [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) }
function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false)) }

# Enable vivaldi://flags entries in Local State (Vivaldi must be closed)
function Enable-Flags($localState, [string[]]$flags) {
  if (-not (Test-Path $localState)) { Say 'Local State not found, skipping flags' 'Yellow'; return }
  $text = Read-Utf8 $localState
  $missing = $flags | Where-Object { $text -notmatch [regex]::Escape("`"$_@") }
  if (-not $missing) { return }
  $items = ($missing | ForEach-Object { "`"$_@1`"" }) -join ','
  if ($text -match '"enabled_labs_experiments":\[\]') {
    $text = $text -replace '"enabled_labs_experiments":\[\]', "`"enabled_labs_experiments`":[$items]"
  } elseif ($text -match '"enabled_labs_experiments":\[') {
    $text = $text -replace '"enabled_labs_experiments":\[', "`"enabled_labs_experiments`":[$items,"
  } elseif ($text -match '"browser":\{') {
    $text = ([regex]'"browser":\{').Replace($text, "`"browser`":{`"enabled_labs_experiments`":[$items],", 1)
  } else { Say 'Could not enable flags automatically' 'Yellow'; return }
  Copy-Item $localState "$localState.shine-bak" -Force
  Write-Utf8 $localState $text
  Say "Enabled flags: $($missing -join ', ')"
}

Write-Host "`n  Shine's mod for Vivaldi`n" -ForegroundColor Cyan
$viv = Find-Vivaldi
Say "Vivaldi $($viv.Version) at $($viv.Res)"
$html = Join-Path $viv.Res 'window.html'
$bak  = "$html.shine-bak"

try { [IO.File]::OpenWrite($html).Close() } catch {
  throw 'No write access to the Vivaldi folder. Run PowerShell as Administrator (system-wide Vivaldi install).'
}

Stop-Vivaldi

if ($env:SHINE_UNINSTALL) {
  if (Test-Path $bak) { Copy-Item $bak $html -Force; Remove-Item $bak -Force }
  else { Write-Utf8 $html ((Read-Utf8 $html).Replace("`n  $Marker", '').Replace($Marker, '')) }
  foreach ($p in 'injectMods.js', 'user_mods') { $t = Join-Path $viv.Res $p; if (Test-Path $t) { Remove-Item $t -Recurse -Force } }
  if (Test-Path $ShineHome) { Remove-Item $ShineHome -Recurse -Force }
  if (Test-Path $FilesHome) { Remove-Item $FilesHome -Recurse -Force }
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
  Say 'Uninstalled. (Settings > Appearance > Custom UI Modifications can be cleared by hand.)' 'Green'
  Start-Process $viv.Exe
  return
}

$src = Get-Source

# 1) CSS in a folder outside the Vivaldi version folder (Vivaldi's "Custom UI Modifications")
if (Test-Path $ShineHome) { Remove-Item $ShineHome -Recurse -Force }
New-Item -ItemType Directory $ShineHome | Out-Null
Copy-Item (Join-Path $src 'css\*') $ShineHome -Recurse -Force
Say "CSS  -> $ShineHome"

# 2) JS + loader inside the version folder (this part is lost on every Vivaldi update)
$um = Join-Path $viv.Res 'user_mods'
if (Test-Path $um) { Remove-Item $um -Recurse -Force }
New-Item -ItemType Directory (Join-Path $um 'js') | Out-Null
Copy-Item (Join-Path $src 'js\*') (Join-Path $um 'js') -Force
Copy-Item (Join-Path $src 'css') (Join-Path $um 'css') -Recurse -Force   # also loaded by the loader
$setup = Join-Path $um 'js\ShineSetup.js'
Write-Utf8 $setup ((Read-Utf8 $setup).Replace('__SHINE_CSS_DIR__', ($ShineHome -replace '\\', '\\')))
Copy-Item (Join-Path $src 'injectMods.js') $viv.Res -Force

$text = Read-Utf8 $html
if ($text -notmatch [regex]::Escape($Marker)) {
  if (-not (Test-Path $bak)) { Copy-Item $html $bak }
  $text = ([regex]'<body[^>]*>').Replace($text, { param($m) "$($m.Value)`n  $Marker" }, 1)
  Write-Utf8 $html $text
}
Say "JS   -> $um"

# 3) Flags: CSS mods + pinned tabs as a tile grid
Enable-Flags (Join-Path $viv.UserData 'Local State') @('vivaldi-css-mods', 'vivaldi-horizontal-pinned-tabs')

# 4) Auto-repair after Vivaldi updates (per-user installs only: the task runs without admin)
$vivRoot = Split-Path $viv.Exe -Parent
if ($vivRoot.StartsWith($env:LOCALAPPDATA, [StringComparison]::OrdinalIgnoreCase) -and -not $env:SHINE_NO_AUTO) {
  if (Test-Path $FilesHome) { Remove-Item $FilesHome -Recurse -Force }
  New-Item -ItemType Directory $FilesHome | Out-Null
  Copy-Item $um (Join-Path $FilesHome 'user_mods') -Recurse -Force
  Copy-Item (Join-Path $src 'injectMods.js') $FilesHome -Force
  $watch = Join-Path $FilesHome 'watch.ps1'
  Write-Utf8 $watch ((Read-Utf8 (Join-Path $src 'watch.ps1')).Replace('__VIVALDI_ROOT__', $vivRoot))
  # conhost --headless: no console window flashing every few minutes
  $action = New-ScheduledTaskAction -Execute 'conhost.exe' `
    -Argument "--headless powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$watch`""
  $every = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
  $logon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -Priority 10   # idle priority: never competes with games
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $every, $logon -Settings $settings `
    -Description "Re-applies Shine's mod after Vivaldi updates" -Force | Out-Null
  Say "Auto-repair after Vivaldi updates: on (task '$TaskName')"
}

Start-Process $viv.Exe
Write-Host "`n  Done! Vivaldi is restarting with Shine's mod." -ForegroundColor Green
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Say 'Vivaldi updates are handled automatically from now on.'
} else {
  Say 'After a Vivaldi update, run the same command again to restore the JS part.'
}
