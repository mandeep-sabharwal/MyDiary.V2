# Pawsie Diary installer for an EXISTING Flutter project.
# Run it from inside your project folder (the one that contains pubspec.yaml and android).
#
#   powershell -ExecutionPolicy Bypass -File "C:\path\to\pawsie_package\apply_pawsie.ps1"
#
# What it does (and nothing else):
#   1. Backs up your current lib, test, pubspec.yaml and AndroidManifest.xml
#      (into a folder NEXT TO your project, so the analyzer ignores it)
#   2. Removes old app code from lib (but KEEPS your lib\firebase_options.dart)
#   3. Copies in the Pawsie files, keeps your project's pubspec "name"
#   4. Runs flutter pub get, then the Android setup step
$ErrorActionPreference = 'Stop'

$pkg  = Split-Path -Parent $MyInvocation.MyCommand.Path
$proj = (Get-Location).Path

if (-not (Test-Path (Join-Path $proj 'pubspec.yaml')) -or -not (Test-Path (Join-Path $proj 'android'))) {
    Write-Host 'STOP: run this from your Flutter project folder (it must contain pubspec.yaml and an android folder).' -ForegroundColor Red
    exit 1
}

Write-Host "Current Directory: $(Get-Location)"
Write-Host "Package Path: $pkg"
Write-Host "Project Path: $proj"

Write-Host "Package Full Path: $([System.IO.Path]::GetFullPath($pkg))"
Write-Host "Project Full Path: $([System.IO.Path]::GetFullPath($proj))"
Write-Host "Are they equal? $($pkg -eq $proj)"

if ($pkg -eq $proj) {
    Write-Host 'STOP: run this from your project folder, not from the unzipped package folder.' -ForegroundColor Red
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host 'STOP: "flutter" is not on your PATH. Open the terminal inside Android Studio (it usually has it), or add your flutter\bin folder to PATH.' -ForegroundColor Red
    exit 1
}
$ErrorActionPreference = 'Continue'

Write-Host "Project : $proj"
Write-Host "Package : $pkg"

# ---- 1. backup ----
$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
# the backup goes NEXT TO the project (not inside it), or the analyzer would scan the old code again
$backup = Join-Path (Split-Path -Parent $proj) ("backup_before_pawsie_" + $stamp)
New-Item -ItemType Directory -Path $backup | Out-Null
foreach ($item in @('lib', 'test', 'pubspec.yaml')) {
    $p = Join-Path $proj $item
    if (Test-Path $p) { Copy-Item $p (Join-Path $backup $item) -Recurse -Force }
}
$manifest = Join-Path $proj 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifest) { Copy-Item $manifest (Join-Path $backup 'AndroidManifest.xml') -Force }
# stray .dart files sitting loose in the project folder (they break the analyzer)
Get-ChildItem -Path $proj -Filter '*.dart' -File | ForEach-Object {
    Move-Item $_.FullName (Join-Path $backup $_.Name) -Force
    Write-Host "Moved stray file to backup: $($_.Name)"
}
Write-Host "Backup  : $backup" -ForegroundColor Green

# ---- 2. clean lib (keep firebase_options.dart) ----
$lib = Join-Path $proj 'lib'
if (-not (Test-Path $lib)) { New-Item -ItemType Directory -Path $lib | Out-Null }
Get-ChildItem -Path $lib -Force | Where-Object { $_.Name -ne 'firebase_options.dart' } | Remove-Item -Recurse -Force

# ---- 3. copy Pawsie files ----
Copy-Item (Join-Path $pkg 'lib\*') $lib -Recurse -Force
if (-not (Test-Path (Join-Path $lib 'firebase_options.dart'))) {
    Copy-Item (Join-Path $pkg 'extras\firebase_options_placeholder.dart') (Join-Path $lib 'firebase_options.dart')
    Write-Host 'No firebase_options.dart found: put a placeholder. Run "flutterfire configure" later to connect Firebase.' -ForegroundColor Yellow
}

# project name (keep yours, so nothing else has to change)
$existing = Get-Content (Join-Path $proj 'pubspec.yaml') -Raw
$m = [regex]::Match($existing, '(?m)^name:\s*(\S+)')
$name = if ($m.Success) { $m.Groups[1].Value } else { 'pawsie_diary' }

$utf8 = New-Object System.Text.UTF8Encoding($false)

$newPub = Get-Content (Join-Path $pkg 'pubspec.yaml') -Raw
$newPub = [regex]::Replace($newPub, '(?m)^name:\s*\S+', "name: $name")
[System.IO.File]::WriteAllText((Join-Path $proj 'pubspec.yaml'), $newPub, $utf8)

# tests
$testDir = Join-Path $proj 'test'
if (Test-Path $testDir) { Get-ChildItem -Path $testDir -Force | Remove-Item -Recurse -Force } else { New-Item -ItemType Directory -Path $testDir | Out-Null }
$t = Get-Content (Join-Path $pkg 'test\widget_test.dart') -Raw
$t = $t.Replace('package:pawsie_diary/', "package:$name/")
[System.IO.File]::WriteAllText((Join-Path $testDir 'widget_test.dart'), $t, $utf8)

# tool (Android setup script + icons)
$toolDir = Join-Path $proj 'tool'
if (Test-Path $toolDir) { Remove-Item $toolDir -Recurse -Force }
Copy-Item (Join-Path $pkg 'tool') $toolDir -Recurse -Force

Write-Host "Files copied. Project name kept as: $name" -ForegroundColor Green

# ---- 4. packages + Android setup ----
$ErrorActionPreference = 'Continue'
Write-Host 'Running flutter pub get ...'
& flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host 'flutter pub get failed. Read the message above.' -ForegroundColor Red; exit 1 }

Write-Host 'Running Android setup ...'
& dart tool/setup_android.dart
if ($LASTEXITCODE -ne 0) { Write-Host 'Android setup failed. Read the message above.' -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host 'DONE. Now: stop the app in Android Studio, then press the green Run button (a full run, not hot reload).' -ForegroundColor Green
Write-Host "Your old files are in: $backup"
