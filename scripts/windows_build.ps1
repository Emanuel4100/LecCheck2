# Builds LecCheck for Windows and its setup (Inno Setup), on Windows only (CI's
# windows-latest): Flutter can't build Windows apps on Linux.
#
#   pwsh scripts/windows_build.ps1 [-BuildName 2.0.0-beta.22] [-BuildNumber 30]
#                                   [-DartDefine API_BASE_URL=https://...]
#
# Without -BuildName or -BuildNumber, pubspec.yaml's version is used. The setup
# lands in app/build/windows/installer/LecCheck-<BuildName>-windows-setup.exe;
# its path is the last line printed (and in $env:GITHUB_OUTPUT as "setup").
param(
  [string]$BuildName = '',
  [string]$BuildNumber = '',
  [string[]]$DartDefine = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Checked([string]$what, [scriptblock]$command) {
  & $command
  if ($LASTEXITCODE -ne 0) { throw "$what failed (exit code $LASTEXITCODE)" }
}

$app = (Resolve-Path (Join-Path $PSScriptRoot '..\app')).Path
Set-Location $app

$pubspec = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)\+(\d+)').Matches[0]
if (-not $BuildName) { $BuildName = $pubspec.Groups[1].Value }
# Always given: with --build-name alone Flutter leaves the build number out of
# the exe's version, and the app's update check would read build 0.
if (-not $BuildNumber) { $BuildNumber = $pubspec.Groups[2].Value }
if ($BuildNumber -notmatch '^\d+$') { throw "Build number '$BuildNumber' isn't a number" }

$flutterArgs = @('build', 'windows', '--release', "--build-name=$BuildName", "--build-number=$BuildNumber")
foreach ($define in $DartDefine) { $flutterArgs += "--dart-define=$define" }
Invoke-Checked 'flutter build windows' { flutter @flutterArgs }

# The Visual C++ runtime next to leccheck.exe: Flutter's engine needs it, and a
# fresh Windows may not have it (Microsoft allows this app-local copy).
$release = Join-Path $app 'build\windows\x64\runner\Release'
$runtime = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$crt = $null
if (Test-Path $vswhere) {
  $vs = & $vswhere -latest -products '*' -property installationPath
  if ($vs) {
    # The folders themselves (Get-Item), not what's in them.
    $crt = Get-Item -Path (Join-Path $vs 'VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT') -ErrorAction SilentlyContinue |
      Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.FullName 'vcruntime140_1.dll')) } |
      Sort-Object FullName | Select-Object -Last 1
  }
}
$from = if ($crt) { $crt.FullName } else { Join-Path $env:SystemRoot 'System32' }
foreach ($dll in $runtime) {
  Copy-Item (Join-Path $from $dll) $release -Force
}
Write-Host "VC++ runtime from $from"

# Inno Setup: on the runner image, or from Chocolatey.
$found = Get-Command iscc.exe -ErrorAction SilentlyContinue
$iscc = if ($found) { $found.Source } else { $null }
if (-not $iscc) {
  $iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
  if (-not (Test-Path $iscc)) {
    Invoke-Checked 'choco install innosetup' { choco install innosetup -y --no-progress }
  }
}

# pubspec's 2.0.0 with build 30 -> 2.0.0.30 (Windows' file versions are
# numbers; from pubspec, since a dry run's build name is the branch's).
$numeric = ($pubspec.Groups[1].Value -replace '[-+].*$', '') + ".$BuildNumber"
$script = Join-Path $app 'windows\installer\leccheck.iss'
Invoke-Checked 'ISCC' { & $iscc /Qp "/DAppVersion=$BuildName" "/DAppNumericVersion=$numeric" $script }

$setup = Join-Path $app "build\windows\installer\LecCheck-$BuildName-windows-setup.exe"
if (-not (Test-Path $setup)) { throw "No setup at $setup" }
if ($env:GITHUB_OUTPUT) { "setup=$setup" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8 }
Write-Output $setup
