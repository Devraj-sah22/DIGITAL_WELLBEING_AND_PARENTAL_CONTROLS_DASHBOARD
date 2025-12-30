# QuickFix.ps1 - Simple fix tool for Digital Wellbeing Dashboard
# Run this if you have problems

Write-Host "Digital Wellbeing Dashboard Quick Fix Tool" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if main script exists
$mainScript = "DigitalWellbeing.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Host "ERROR: $mainScript not found!" -ForegroundColor Red
    Write-Host "Make sure this script is in the same folder as DigitalWellbeing.ps1" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "1. Closing any running dashboard instances..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.MainWindowTitle -match "Digital Wellbeing" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "   Done" -ForegroundColor Green

Write-Host "2. Fixing common issues..." -ForegroundColor Yellow

# Fix time display issue in main script
$content = Get-Content $mainScript -Raw
$content = $content -replace 'ToString\("hh:mm tt"\)', 'ToString("HH:mm")'
$content | Set-Content $mainScript -Encoding UTF8
Write-Host "   Time display fixed" -ForegroundColor Green

# Clear old data
$dataPath = "$env:APPDATA\DigitalWellbeing"
if (Test-Path "$dataPath\activity_data.json") {
    Remove-Item "$dataPath\activity_data.json" -Force -ErrorAction SilentlyContinue
    Write-Host "   Old data cleared" -ForegroundColor Green
}

# Recreate shortcut
Write-Host "3. Recreating shortcuts..." -ForegroundColor Yellow
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktopPath\Digital Wellbeing.lnk"

if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
}

try {
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
    $shortcut.WorkingDirectory = $PWD
    $shortcut.IconLocation = "shell32.dll,13"
    $shortcut.Description = "Digital Wellbeing Dashboard"
    $shortcut.Save()
    Write-Host "   Shortcut recreated" -ForegroundColor Green
}
catch {
    Write-Host "   Could not create shortcut" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "FIXES APPLIED SUCCESSFULLY!" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Run the setup script again: .\Setup-Wellbeing.ps1" -ForegroundColor Gray
Write-Host "2. Or start directly: .\DigitalWellbeing.ps1" -ForegroundColor Gray
Write-Host ""

$startNow = Read-Host "Start the dashboard now? (Y/N)"
if ($startNow -eq 'Y' -or $startNow -eq 'y') {
    Write-Host "Starting dashboard..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PWD\$mainScript`""
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
pause