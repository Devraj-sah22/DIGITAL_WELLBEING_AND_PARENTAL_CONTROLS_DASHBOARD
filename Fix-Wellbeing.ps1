# Fix-Wellbeing.ps1 - Simple fix tool
Write-Host "Digital Wellbeing Fix Tool" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

# Check if main script exists
$mainScript = "DigitalWellbeing.ps1"
if (-not (Test-Path $mainScript)) {
    Write-Host "ERROR: $mainScript not found!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Closing any running dashboard..." -ForegroundColor Yellow
Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.MainWindowTitle -match "Digital Wellbeing" } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Clearing old data..." -ForegroundColor Yellow
$dataPath = "$env:APPDATA\DigitalWellbeing"
if (Test-Path "$dataPath\activity_data.json") {
    Remove-Item "$dataPath\activity_data.json" -Force -ErrorAction SilentlyContinue
}

Write-Host "Fix complete!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now start the dashboard: .\DigitalWellbeing.ps1" -ForegroundColor White
Write-Host ""
pause