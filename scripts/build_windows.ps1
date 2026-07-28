# Build Windows Installer Script for Recovery Tool

Write-Host "Step 1: Cleaning previous builds..." -ForegroundColor Cyan
flutter clean

Write-Host "Step 2: Getting dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "Step 3: Building Flutter Windows application (Release)..." -ForegroundColor Cyan
flutter build windows --release --obfuscate --split-debug-info=build/symbols/windows

if ($LASTEXITCODE -ne 0) {
    Write-Host "Flutter build failed. Exiting." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Step 4: Locating Inno Setup Compiler (iscc.exe)..." -ForegroundColor Cyan
$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $searchPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\iscc.exe",
        "$env:LocalAppData\Programs\Inno Setup 6\iscc.exe"
    )
    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $iscc = $path
            break
        }
    }

    if (-not $iscc) {
        Write-Host "Error: Inno Setup (iscc.exe) not found in PATH or standard locations." -ForegroundColor Red
        Write-Host "Please install Inno Setup or add its folder to your PATH." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Step 5: Compiling Installer..." -ForegroundColor Cyan
& $iscc scripts\windows_installer.iss

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nSuccess! Installer created at: build\windows\installer\RecoveryToolInstaller.exe" -ForegroundColor Green
} else {
    Write-Host "`nError: Installer compilation failed." -ForegroundColor Red
    exit $LASTEXITCODE
}
