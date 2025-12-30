# Digital Wellbeing Dashboard Setup
# Save as: Setup-Wellbeing.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Digital Wellbeing Dashboard Setup     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check for main script
$mainScript = "DigitalWellbeing.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Host "ERROR: $mainScript not found!" -ForegroundColor Red
    Write-Host "Make sure both scripts are in the same folder." -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host "Creating shortcuts..." -ForegroundColor Yellow

# Desktop shortcut
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\Digital Wellbeing.lnk"
    
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
    $shortcut.WorkingDirectory = $PWD
    $shortcut.IconLocation = "shell32.dll,13"
    $shortcut.Description = "Digital Wellbeing Dashboard"
    $shortcut.Save()
    
    Write-Host "  Desktop shortcut created" -ForegroundColor Green
}
catch {
    Write-Host "  Could not create desktop shortcut" -ForegroundColor Yellow
}

# Start Menu shortcut
try {
    $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
    if (-not (Test-Path $startMenuPath)) {
        New-Item -ItemType Directory -Path $startMenuPath -Force | Out-Null
    }
    
    $startShortcutPath = "$startMenuPath\Digital Wellbeing.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $startShortcut = $WshShell.CreateShortcut($startShortcutPath)
    $startShortcut.TargetPath = "powershell.exe"
    $startShortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
    $startShortcut.WorkingDirectory = $PWD
    $startShortcut.IconLocation = "shell32.dll,13"
    $startShortcut.Description = "Digital Wellbeing Dashboard"
    $startShortcut.Save()
    
    Write-Host "  Start Menu shortcut created" -ForegroundColor Green
}
catch {
    Write-Host "  Could not create Start Menu shortcut" -ForegroundColor Yellow
}

# Create data directory
$appDataPath = "$env:APPDATA\DigitalWellbeing"
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
    Write-Host "  Data directory created" -ForegroundColor Green
}

# Set execution policy
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    Write-Host "  Execution policy configured" -ForegroundColor Green
}
catch {
    Write-Host "  Note: Execution policy change may require admin rights" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "          SETUP COMPLETE!               " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "How to use:" -ForegroundColor White
Write-Host "  Double-click 'Digital Wellbeing' on Desktop" -ForegroundColor Gray
Write-Host "  Or run: .\DigitalWellbeing.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Features:" -ForegroundColor White
Write-Host "  Screen time tracking" -ForegroundColor Gray
Write-Host "  Activity monitoring" -ForegroundColor Gray
Write-Host "  Parental controls" -ForegroundColor Gray
Write-Host "  Real-time data" -ForegroundColor Gray
Write-Host "  Premium UI" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Start Digital Wellbeing Dashboard now? (Y/N)"
if ($choice -eq 'Y' -or $choice -eq 'y') {
    Write-Host ""
    Write-Host "Starting dashboard..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
}
else {
    Write-Host ""
    Write-Host "You can start the dashboard anytime using the shortcuts." -ForegroundColor Green
}

Write-Host ""
Write-Host "Press any key to exit..."
pause