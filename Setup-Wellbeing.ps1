# Digital Wellbeing Dashboard Setup
# Save as: Setup-Wellbeing.ps1

Write-Host "Digital Wellbeing Dashboard Setup" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
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

# Create desktop shortcut
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = "$desktopPath\Digital Wellbeing.lnk"
    
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
    $shortcut.WorkingDirectory = $PWD
    $shortcut.Description = "Digital Wellbeing Dashboard"
    $shortcut.Save()
    
    Write-Host "Desktop shortcut created" -ForegroundColor Green
}
catch {
    Write-Host "Could not create desktop shortcut" -ForegroundColor Yellow
}

Write-Host "Creating data directory..." -ForegroundColor Yellow

# Create data directory
$appDataPath = "$env:APPDATA\DigitalWellbeing"
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
    Write-Host "Data directory created" -ForegroundColor Green
}

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "To start the dashboard:" -ForegroundColor White
Write-Host "1. Double-click 'Digital Wellbeing' on your Desktop" -ForegroundColor Gray
Write-Host "2. Or run: .\DigitalWellbeing.ps1" -ForegroundColor Gray
Write-Host ""
Write-Host "Features include:" -ForegroundColor White
Write-Host "- Screen time tracking" -ForegroundColor Gray
Write-Host "- Activity monitoring" -ForegroundColor Gray
Write-Host "- Parental controls" -ForegroundColor Gray
Write-Host "- Charts and graphs" -ForegroundColor Gray
Write-Host "- Real-time updates" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Start Digital Wellbeing Dashboard now? (Y/N)"
if ($choice -eq 'Y' -or $choice -eq 'y') {
    Write-Host "Starting dashboard..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
}

Write-Host ""
Write-Host "Press any key to exit..."
pause