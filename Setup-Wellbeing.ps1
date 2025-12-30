# Setup script for Digital Wellbeing Dashboard
Write-Host "Setting up Digital Wellbeing Dashboard..." -ForegroundColor Green

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Host ""
    Write-Host "WARNING: Some features require administrator privileges." -ForegroundColor Yellow
    Write-Host "For full functionality, run this script as Administrator." -ForegroundColor Yellow
    Write-Host "Right-click on PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Continuing with limited setup..." -ForegroundColor Yellow
}

# Create desktop shortcut
$desktopPath = [System.Environment]::GetFolderPath("Desktop")
$shortcutPath = "$desktopPath\Digital Wellbeing.lnk"
$targetPath = "$PSScriptRoot\DigitalWellbeing.ps1"

# Check if main script exists
if (-not (Test-Path $targetPath)) {
    Write-Host "Error: DigitalWellbeing.ps1 not found in current directory!" -ForegroundColor Red
    Write-Host "Make sure both scripts are in the same folder." -ForegroundColor Red
    exit 1
}

# Create shortcut
try {
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.IconLocation = "shell32.dll,13"
    $shortcut.Description = "Digital Wellbeing Dashboard"
    $shortcut.Save()
    Write-Host "Desktop shortcut created." -ForegroundColor Green
}
catch {
    Write-Host "Could not create desktop shortcut." -ForegroundColor Yellow
}

# Create Start Menu shortcut
try {
    $startMenuPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Digital Wellbeing.lnk"
    $startShortcut = $WshShell.CreateShortcut($startMenuPath)
    $startShortcut.TargetPath = "powershell.exe"
    $startShortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetPath`""
    $startShortcut.WorkingDirectory = $PSScriptRoot
    $startShortcut.IconLocation = "shell32.dll,13"
    $startShortcut.Save()
    Write-Host "Start Menu shortcut created." -ForegroundColor Green
}
catch {
    Write-Host "Could not create Start Menu shortcut." -ForegroundColor Yellow
}

# Only try to create scheduled task if running as admin
if (Test-Administrator) {
    try {
        Write-Host "Creating system integration..." -ForegroundColor Yellow
        
        # Create scheduled task for auto-start
        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetPath`""
        $taskTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
        
        Register-ScheduledTask -TaskName "DigitalWellbeing" -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Description "Digital Wellbeing Dashboard - Tracks screen time and application usage" -Force
        
        Write-Host "Scheduled task created for auto-start." -ForegroundColor Green
    }
    catch {
        Write-Host "Could not create scheduled task." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Skipping scheduled task creation (requires admin rights)." -ForegroundColor Yellow
}

# Create data directory
$appDataPath = "$env:APPDATA\DigitalWellbeing"
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
    Write-Host "Data directory created: $appDataPath" -ForegroundColor Green
}

# Set execution policy for current user
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
    Write-Host "Execution policy configured." -ForegroundColor Green
}
catch {
    Write-Host "Note: Could not set execution policy." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Installation Complete! ===" -ForegroundColor Green
Write-Host "Desktop shortcut created" -ForegroundColor Cyan
Write-Host "Start Menu shortcut created" -ForegroundColor Cyan
Write-Host "Data directory created" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dashboard will start automatically when you log in" -ForegroundColor White
Write-Host ""
Write-Host "To start the dashboard manually:" -ForegroundColor White
Write-Host "  - Double-click 'Digital Wellbeing' shortcut on Desktop" -ForegroundColor Gray
Write-Host "  - OR Run: .\DigitalWellbeing.ps1" -ForegroundColor Gray
Write-Host "  - OR Find it in Start Menu > Digital Wellbeing" -ForegroundColor Gray

# Ask to start now
Write-Host ""
$response = Read-Host "Start dashboard now? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "Starting Digital Wellbeing Dashboard..." -ForegroundColor Green
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetPath`""
}
else {
    Write-Host ""
    Write-Host "Setup complete! You can start the dashboard anytime using the shortcuts." -ForegroundColor Green
}