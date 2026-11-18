# A first look at a Windows build on CI's runner, before anyone tries it on a
# real PC: installs the setup silently, starts LecCheck, checks it keeps
# running (with a screenshot), that a second start leaves only the first one,
# that closing the window saves its place, and that uninstalling removes the
# app but keeps the data.
#
#   pwsh scripts/windows_smoke_test.ps1 -Setup <LecCheck-...-windows-setup.exe> [-Out smoke]
#
# -Out gets the screenshots, the setup's log, LecCheck's own log and
# window.ini, whether the test passed or not.
param(
  [Parameter(Mandatory = $true)][string]$Setup,
  [string]$Out = 'smoke'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\LecCheck'
$exe = Join-Path $installDir 'leccheck.exe'
# path_provider's folder (Runner.rc's CompanyName\ProductName), and the
# runner's window.ini.
$dataDir = Join-Path $env:APPDATA 'com.leccheck\LecCheck'
$windowIni = Join-Path $env:LOCALAPPDATA 'com.leccheck\LecCheck\window.ini'
$shortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\LecCheck.lnk'

function Save-Screenshot([string]$name) {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    $bitmap.Save((Join-Path $Out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
  } catch {
    Write-Host "::warning::No screenshot ($name): $_"
  }
}

function Assert-True([bool]$condition, [string]$message) {
  if (-not $condition) { throw $message }
}

# Inno's uninstaller hands over to a copy of itself and returns at once.
function Wait-Until([scriptblock]$condition, [int]$seconds) {
  $deadline = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $deadline) {
    if (& $condition) { return $true }
    Start-Sleep -Milliseconds 500
  }
  return [bool](& $condition)
}

$app = $null
try {
  Write-Host '1. Install'
  $install = Start-Process -FilePath $Setup -PassThru -Wait -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=$(Join-Path $Out 'setup.log')")
  Assert-True ($install.ExitCode -eq 0) "The setup failed (exit code $($install.ExitCode))"
  foreach ($file in @($exe, (Join-Path $installDir 'unins000.exe'), (Join-Path $installDir 'vcruntime140.dll'),
      (Join-Path $installDir 'flutter_windows.dll'), (Join-Path $installDir 'data\app.so'), $shortcut)) {
    Assert-True (Test-Path $file) "Not installed: $file"
  }

  Write-Host '2. Start'
  $app = Start-Process -FilePath $exe -PassThru
  Start-Sleep -Seconds 20
  Save-Screenshot 'running.png'
  Assert-True (-not $app.HasExited) "LecCheck quit by itself (exit code $($app.ExitCode))"
  Assert-True (Test-Path (Join-Path $dataDir 'leccheck.sqlite')) "No database in $dataDir"

  Write-Host '3. A second start'
  $second = Start-Process -FilePath $exe -PassThru
  Assert-True ($second.WaitForExit(15000)) 'A second LecCheck stayed open'
  Assert-True (-not $app.HasExited) 'The first LecCheck quit when a second one started'

  Write-Host '4. Close the window'
  $app.Refresh()
  Assert-True ($app.MainWindowHandle -ne [IntPtr]::Zero) 'LecCheck has no window'
  [void]$app.CloseMainWindow()
  Assert-True ($app.WaitForExit(20000)) "LecCheck didn't close"
  Assert-True (Test-Path $windowIni) "The window's place wasn't saved ($windowIni)"
  $app = $null

  Write-Host '5. Uninstall'
  Start-Process -FilePath (Join-Path $installDir 'unins000.exe') -Wait -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART')
  Assert-True (Wait-Until { -not (Test-Path $exe) } 60) "Uninstalling left $exe"
  Assert-True (-not (Test-Path $shortcut)) 'Uninstalling left the Start menu shortcut'
  Assert-True (Test-Path (Join-Path $dataDir 'leccheck.sqlite')) 'Uninstalling deleted the data'

  Write-Host 'Windows smoke test: OK'
} catch {
  Save-Screenshot 'failed.png'
  Write-Host "::error::$_"
  exit 1
} finally {
  if ($app -and -not $app.HasExited) { Stop-Process -Id $app.Id -Force }
  foreach ($file in @((Join-Path $dataDir 'dev_log.txt'), (Join-Path $dataDir 'last_error.txt'), $windowIni)) {
    if (Test-Path $file) { Copy-Item $file $Out -Force }
  }
}
