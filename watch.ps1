<#
  Shine's mod for Vivaldi — auto-repair after Vivaldi updates.
  Run every few minutes by the "Shine's mod auto-repair" scheduled task (registered by install.ps1).
  If the newest Vivaldi version folder has no mod yet, copies the JS part into it (from
  %LOCALAPPDATA%\ShineMod-files) without closing Vivaldi. If Vivaldi was started only minutes ago
  (i.e. it just restarted into the update), it is restarted once more so the mod shows right away.
  install.ps1 fills in __VIVALDI_ROOT__.
#>

$ErrorActionPreference = 'Stop'
$Root   = '__VIVALDI_ROOT__'
$Files  = Join-Path $env:LOCALAPPDATA 'ShineMod-files'
$Log    = Join-Path $Files 'auto-repair.log'
$Marker = '<script src="injectMods.js"></script>'

function Log($msg) { Add-Content $Log "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" -Encoding UTF8 }
function Read-Utf8($path) { [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) }
function Write-Utf8($path, $text) { [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false)) }

try {
  $ver = Get-ChildItem $Root -Directory | Where-Object { $_.Name -match '^\d+(\.\d+){3}$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
  if (-not $ver) { return }
  $res  = Join-Path $ver.FullName 'resources\vivaldi'
  $html = Join-Path $res 'window.html'
  if (-not (Test-Path $html)) { return }
  if ((Read-Utf8 $html).Contains($Marker)) { return }   # already modded: nothing to do

  # 1) JS part
  $um = Join-Path $res 'user_mods'
  if (Test-Path $um) { Remove-Item $um -Recurse -Force }
  Copy-Item (Join-Path $Files 'user_mods') $um -Recurse -Force
  Copy-Item (Join-Path $Files 'injectMods.js') $res -Force

  # 2) loader in window.html
  $bak = "$html.shine-bak"
  if (-not (Test-Path $bak)) { Copy-Item $html $bak }
  $text = ([regex]'<body[^>]*>').Replace((Read-Utf8 $html), { param($m) "$($m.Value)`n  $Marker" }, 1)
  Write-Utf8 $html $text
  Log "patched Vivaldi $($ver.Name)"

  # 3) Vivaldi just restarted into the update: restart it once more (tabs are restored)
  $exe   = Join-Path $Root 'vivaldi.exe'
  $procs = Get-Process vivaldi -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe }
  if ($procs) {
    $started = ($procs | Measure-Object StartTime -Minimum).Minimum
    if ((Get-Date) - $started -lt (New-TimeSpan -Minutes 6)) {
      $procs | Stop-Process -Force
      for ($i = 0; $i -lt 20 -and (Get-Process vivaldi -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
      Start-Process $exe
      Log 'restarted Vivaldi'
    }
  }
} catch {
  Log "error: $_"
}
