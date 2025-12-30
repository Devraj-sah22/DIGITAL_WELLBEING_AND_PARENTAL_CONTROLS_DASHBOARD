# Digital Wellbeing & Parental Controls Dashboard - ULTIMATE DIGITAL EDITION
# COMPLETE WITH ALL FEATURES AND DIGITAL UI
# Save as: DigitalWellbeing.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ========== REAL SCREEN TIME TRACKING ==========
$global:lastActiveTime = [DateTime]::Now
$global:totalActiveTime = 0
$global:currentApp = ""
$global:appUsage = @{}
$global:isTrackingEnabled = $true
$global:notifications = @()
$global:activityLog = @()

# Windows API for idle detection
Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public class UserActivity {
        [DllImport("user32.dll")]
        public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();
        
        [DllImport("user32.dll", SetLastError = true)]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
        
        [StructLayout(LayoutKind.Sequential)]
        public struct LASTINPUTINFO {
            public uint cbSize;
            public uint dwTime;
        }
        
        public static uint GetLastInputTime() {
            LASTINPUTINFO lastInput = new LASTINPUTINFO();
            lastInput.cbSize = (uint)Marshal.SizeOf(lastInput);
            GetLastInputInfo(ref lastInput);
            return lastInput.dwTime;
        }
        
        public static int GetIdleTime() {
            uint lastInputTime = GetLastInputTime();
            uint currentTime = (uint)Environment.TickCount;
            return (int)(currentTime - lastInputTime) / 1000;
        }
        
        public static string GetForegroundProcessName() {
            try {
                IntPtr hwnd = GetForegroundWindow();
                uint pid;
                GetWindowThreadProcessId(hwnd, out pid);
                System.Diagnostics.Process p = System.Diagnostics.Process.GetProcessById((int)pid);
                return p.ProcessName;
            } catch {
                return "Unknown";
            }
        }
    }
"@

function Get-CurrentApplication {
    if ($global:isTrackingEnabled -and $global:appData.Settings.RealTimeTracking) {
        try {
            return [UserActivity]::GetForegroundProcessName()
        }
        catch {
            return "Unknown"
        }
    }
    return "Tracking Disabled"
}

function Get-UserActivityLevel {
    if (-not $global:isTrackingEnabled -or -not $global:appData.Settings.RealTimeTracking) {
        return "Tracking Off"
    }
    
    $idleSeconds = [UserActivity]::GetIdleTime()
    if ($idleSeconds -lt 60) {
        return "Active"
    } elseif ($idleSeconds -lt 300) {
        return "Away"
    } else {
        return "Idle"
    }
}

function Update-ScreenTimeTracking {
    if (-not $global:isTrackingEnabled -or -not $global:appData.Settings.RealTimeTracking) {
        return
    }
    
    $currentTime = [DateTime]::Now
    $timeDiff = ($currentTime - $global:lastActiveTime).TotalSeconds
    
    # Check if user is active
    $activityLevel = Get-UserActivityLevel
    
    if ($activityLevel -eq "Active") {
        $global:totalActiveTime += $timeDiff
        
        # Get current application
        $currentApp = Get-CurrentApplication
        
        if ($currentApp -ne $global:currentApp) {
            $global:currentApp = $currentApp
            
            # Record app switch in activity log
            $activityEntry = @{
                Timestamp = (Get-Date).ToString("HH:mm:ss")
                Application = $currentApp
                Type = "AppSwitch"
                Duration = 0
            }
            
            if ($global:activityLog.Count -gt 100) {
                $global:activityLog = $global:activityLog | Select-Object -Last 50
            }
            
            $global:activityLog += $activityEntry
            
            # Add to global app data
            $global:appData.ActivityLog += $activityEntry
        }
        
        # Update app usage if tracking is enabled
        if ($global:appData.Settings.TrackApplications -and 
            $currentApp -ne "Idle" -and 
            $currentApp -ne "Unknown" -and 
            $currentApp -ne "Tracking Disabled") {
            
            if (-not $global:appUsage.ContainsKey($currentApp)) {
                $global:appUsage[$currentApp] = 0
            }
            $global:appUsage[$currentApp] += $timeDiff
        }
    }
    
    $global:lastActiveTime = $currentTime
}

# ========== DATA MANAGEMENT ==========
$global:appDataPath = "$env:APPDATA\DigitalWellbeing"
$global:dataFile = "$appDataPath\activity_data.json"

# Create data directory
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
}

# Load or initialize data
function Initialize-Data {
    if (Test-Path $dataFile) {
        try {
            $data = Get-Content $dataFile | ConvertFrom-Json
            
            # Initialize arrays if they don't exist
            if (-not $data.ActivityLog) { $data.ActivityLog = @() }
            if (-not $data.Notifications) { $data.Notifications = @() }
            if (-not $data.Alerts) { $data.Alerts = @() }
            if (-not $data.TimeBlocks) { $data.TimeBlocks = @() }
            if (-not $data.Applications) { $data.Applications = @{} }
            if (-not $data.DailyStats) { $data.DailyStats = @{} }
            if (-not $data.DailyDetailed) { $data.DailyDetailed = @{} }
            if (-not $data.ScreenTime) { $data.ScreenTime = @{} }
            if (-not $data.AppUsage) { $data.AppUsage = @{} }
            
            # Initialize settings with defaults
            if (-not $data.Settings) { 
                $data | Add-Member -NotePropertyName "Settings" -NotePropertyValue @{}
            }
            
            $defaultSettings = @{
                RealTimeTracking = $true
                TrackApplications = $true
                TrackProductivity = $true
                AutoSaveData = $true
                GenerateReports = $true
                ShowNotifications = $true
                AlertSounds = $true
                DarkMode = $false
                AutoStart = $false
                DataRetention = 30
            }
            
            foreach ($setting in $defaultSettings.Keys) {
                if (-not $data.Settings.$setting) {
                    $data.Settings.$setting = $defaultSettings.$setting
                }
            }
            
            # Initialize other objects
            if (-not $data.Goals) {
                $data.Goals = @{
                    DailyLimit = 6
                    ProductiveHours = 3
                    BreakReminders = $true
                    FocusSessions = 4
                }
            }
            
            if (-not $data.ParentalControls) {
                $data.ParentalControls = @{
                    TimeLimit = 6
                    Bedtime = "22:00"
                    BlockedApps = @("Steam", "TikTok", "Instagram", "Discord", "YouTube")
                    WebsiteFilter = $true
                    FocusMode = $false
                    IsActive = $true
                    DailyReport = $true
                }
            }
            
            if (-not $data.UserProfile) {
                $data.UserProfile = @{
                    Name = "User"
                    Theme = "Light"
                    Notifications = 5
                }
            }
            
            if (-not $data.Premium) { $data.Premium = $false }
            
            return $data
        }
        catch {
            Write-Host "Data file corrupted, creating new..." -ForegroundColor Yellow
        }
    }
    
    $defaultData = @{
        Applications = @{}
        DailyStats = @{}
        DailyDetailed = @{}
        Notifications = @()
        ScreenTime = @{}
        TimeBlocks = @()
        Alerts = @()
        ActivityLog = @()
        AppUsage = @{}
        Goals = @{
            DailyLimit = 6
            ProductiveHours = 3
            BreakReminders = $true
            FocusSessions = 4
        }
        ParentalControls = @{
            TimeLimit = 6
            Bedtime = "22:00"
            BlockedApps = @("Steam", "TikTok", "Instagram", "Discord", "YouTube")
            WebsiteFilter = $true
            FocusMode = $false
            IsActive = $true
            DailyReport = $true
        }
        Premium = $false
        Settings = @{
            RealTimeTracking = $true
            TrackApplications = $true
            TrackProductivity = $true
            AutoSaveData = $true
            GenerateReports = $true
            ShowNotifications = $true
            AlertSounds = $true
            DarkMode = $false
            AutoStart = $false
            DataRetention = 30
        }
        UserProfile = @{
            Name = "User"
            Theme = "Light"
            Notifications = 5
        }
    }
    $defaultData | ConvertTo-Json | Set-Content $dataFile
    return $defaultData
}

$global:appData = Initialize-Data
$global:isTrackingEnabled = $global:appData.Settings.RealTimeTracking

# Initialize arrays from loaded data
$global:activityLog = $global:appData.ActivityLog
$global:notifications = $global:appData.Notifications

# ========== UTILITY FUNCTIONS ==========
function Update-Status {
    param(
        [string]$status,
        [System.Drawing.Color]$color = [System.Drawing.Color]::LightGreen
    )
    
    $statusLabel.Text = $status
    $statusLabel.ForeColor = $color
}

function Save-Settings {
    # Update arrays before saving
    $global:appData.ActivityLog = $global:activityLog
    $global:appData.Notifications = $global:notifications
    $global:appData.AppUsage = $global:appUsage
    
    $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
}

function Update-DashboardStats {
    $today = (Get-Date).ToString("yyyy-MM-dd")
    
    # Calculate real screen time
    $screenTimeHours = [math]::Floor($global:totalActiveTime / 3600)
    $screenTimeMinutes = [math]::Floor(($global:totalActiveTime % 3600) / 60)
    
    # Update daily stats
    if (-not $global:appData.DailyStats.$today) {
        $global:appData.DailyStats.$today = @{
            TotalSeconds = 0
            TotalMinutes = 0
            StartTime = (Get-Date).ToString("HH:mm:ss")
        }
    }
    
    $global:appData.DailyStats.$today.TotalSeconds = $global:totalActiveTime
    $global:appData.DailyStats.$today.TotalMinutes = [math]::Floor($global:totalActiveTime / 60)
    
    # Update stats cards if they exist
    if ($statsPanel -and $statsPanel.Controls.Count -gt 0) {
        if ($statsPanel.Controls[0].Controls[0]) {
            $statsPanel.Controls[0].Controls[0].Text = "${screenTimeHours}h ${screenTimeMinutes}m"
        }
        
        # Count unique apps used today
        $appCount = ($global:appUsage.Keys | Where-Object { 
            $_ -ne "Idle" -and $_ -ne "Unknown" -and $_ -ne "Tracking Disabled" 
        }).Count
        
        if ($statsPanel.Controls[1].Controls[0]) {
            $statsPanel.Controls[1].Controls[0].Text = "$appCount"
        }
        
        # Notification count
        $notificationCount = $global:notifications.Count
        if ($statsPanel.Controls[2].Controls[0]) {
            $statsPanel.Controls[2].Controls[0].Text = "$notificationCount"
        }
        
        # Calculate productivity score
        $productiveApps = @("OUTLOOK", "EXCEL", "WORD", "POWERPNT", "CODE", "DEVENV", "VSCODE", "CHROME", "EDGE", "FIREFOX", "TEAMS", "ZOOM")
        $productiveTime = 0
        $totalTime = $global:totalActiveTime
        
        foreach ($app in $global:appUsage.Keys) {
            if ($productiveApps -contains $app.ToUpper()) {
                $productiveTime += $global:appUsage[$app]
            }
        }
        
        $productivityScore = if ($totalTime -gt 0 -and $global:appData.Settings.TrackProductivity) { 
            [math]::Round(($productiveTime / $totalTime) * 100) 
        } else { 
            0 
        }
        
        if ($statsPanel.Controls[3].Controls[0]) {
            $statsPanel.Controls[3].Controls[0].Text = "$productivityScore%"
        }
    }
}

function Generate-Report {
    if (-not $global:appData.Settings.GenerateReports) {
        [System.Windows.Forms.MessageBox]::Show("Report generation is disabled in settings.", "Reports Disabled", "OK", "Information")
        return
    }
    
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $screenTimeHours = [math]::Floor($global:totalActiveTime / 3600)
    $screenTimeMinutes = [math]::Floor(($global:totalActiveTime % 3600) / 60)
    
    $report = @"
╔══════════════════════════════════════════════════════════════╗
║                 DIGITAL WELLBEING REPORT                     ║
╠══════════════════════════════════════════════════════════════╣
║ Generated: $(Get-Date)                                       ║
║ Tracking Status: $(if ($global:isTrackingEnabled) {'✅ ENABLED'} else {'❌ DISABLED'}) ║
╠══════════════════════════════════════════════════════════════╣
║ 📊 DAILY SUMMARY                                             ║
║ • Date: $today                                               ║
║ • Total Screen Time: ${screenTimeHours}h ${screenTimeMinutes}m            ║
║ • Applications Used: $(($global:appUsage.Keys | Where-Object { $_ -ne "Idle" -and $_ -ne "Unknown" }).Count) ║
║ • Current Activity: $global:currentApp                       ║
║ • Notifications: $($global:notifications.Count)              ║
╠══════════════════════════════════════════════════════════════╣
║ 📱 APPLICATION USAGE                                         ║
"@
    
    $topApps = $global:appUsage.GetEnumerator() | 
               Where-Object { $_.Key -ne "Idle" -and $_.Key -ne "Unknown" } |
               Sort-Object Value -Descending |
               Select-Object -First 10
    
    $rank = 1
    foreach ($app in $topApps) {
        $hours = [math]::Floor($app.Value / 3600)
        $minutes = [math]::Floor(($app.Value % 3600) / 60)
        $percentage = if ($global:totalActiveTime -gt 0) { [math]::Round(($app.Value / $global:totalActiveTime) * 100) } else { 0 }
        $report += "`n║ $rank. $($app.Key.PadRight(20)) ${hours}h ${minutes}m ($percentage%)" + " ".PadRight(20 - $app.Key.Length) + "║"
        $rank++
    }
    
    $report += @"
╠══════════════════════════════════════════════════════════════╣
║ ⚙️ SETTINGS STATUS                                          ║
║ • Real-time Tracking: $(if ($global:appData.Settings.RealTimeTracking) {'✅'} else {'❌'}) ║
║ • Track Applications: $(if ($global:appData.Settings.TrackApplications) {'✅'} else {'❌'}) ║
║ • Track Productivity: $(if ($global:appData.Settings.TrackProductivity) {'✅'} else {'❌'}) ║
║ • Parental Controls: $(if ($global:appData.ParentalControls.IsActive) {'✅ ACTIVE'} else {'❌ INACTIVE'}) ║
╠══════════════════════════════════════════════════════════════╣
║ 💡 RECOMMENDATIONS                                          ║
"@
    
    if ($global:totalActiveTime -gt 8 * 3600) {
        $report += "`n║ • ⚠️  High screen time detected (>8h). Consider breaks.      ║"
    }
    
    $idleTime = ($global:appUsage.GetEnumerator() | Where-Object { $_.Key -eq "Idle" }).Value
    if ($idleTime -gt 0) {
        $idlePercentage = [math]::Round(($idleTime / $global:totalActiveTime) * 100)
        if ($idlePercentage -gt 30) {
            $report += "`n║ • ⏰ You were idle for ${idlePercentage}% of the time.            ║"
        }
    }
    
    if ($global:notifications.Count -gt 50) {
        $report += "`n║ • 🔔 High notification count ($($global:notifications.Count)). Consider muting.║"
    }
    
    $report += @"
╚══════════════════════════════════════════════════════════════╝
"@
    
    $reportPath = "$env:USERPROFILE\Desktop\Digital_Wellbeing_Report_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Update-Status "📄 Report saved to Desktop" ([System.Drawing.Color]::LightBlue)
    [System.Windows.Forms.MessageBox]::Show("Digital report saved to:`n$reportPath", "📊 REPORT GENERATED", "OK", "Information")
}

function Start-FocusSession {
    if (-not $global:appData.Settings.ShowNotifications) {
        [System.Windows.Forms.MessageBox]::Show("Notifications are disabled in settings.", "Notifications Off", "OK", "Information")
        return
    }
    
    Update-Status "🎯 Focus Mode Activated (25:00)" ([System.Drawing.Color]::Orange)
    $timerLabel.Text = "25:00"
    $focusTimer = New-Object System.Windows.Forms.Timer
    $focusTimer.Interval = 1000
    $focusCountdown = 25 * 60
    $focusTimer.Add_Tick({
        $focusCountdown--
        $minutes = [math]::Floor($focusCountdown / 60)
        $seconds = $focusCountdown % 60
        $timerLabel.Text = ("{0}:{1:00}" -f $minutes, $seconds)
        
        if ($focusCountdown -le 0) {
            $focusTimer.Stop()
            $timerLabel.Text = "Focus Complete!"
            Update-Status "🎯 Focus session completed!" ([System.Drawing.Color]::LightGreen)
            
            if ($global:appData.Settings.ShowNotifications) {
                [System.Windows.Forms.MessageBox]::Show("🎯 Focus session completed! Time for a break.", "Wellbeing Alert", "OK", "Information")
            }
        }
    })
    $focusTimer.Start()
    $global:focusTimer = $focusTimer
    
    # Add notification
    $notification = @{
        Timestamp = (Get-Date).ToString("HH:mm:ss")
        Message = "🎯 Focus session started (25 minutes)"
        Type = "Focus"
    }
    $global:notifications += $notification
}

function Add-Notification {
    param([string]$message, [string]$type = "Info")
    
    $notification = @{
        Timestamp = (Get-Date).ToString("HH:mm:ss")
        Message = $message
        Type = $type
    }
    $global:notifications += $notification
    
    if ($global:appData.Settings.ShowNotifications) {
        Update-Status "🔔 $message" ([System.Drawing.Color]::Yellow)
    }
}

# ========== DIGITAL GRAPH FUNCTIONS ==========
function Draw-DigitalBarChart {
    param(
        [System.Drawing.Graphics]$graphics,
        [array]$data,
        [array]$labels,
        [int]$width,
        [int]$height,
        [System.Drawing.Color]$color,
        [string]$title = "CHART"
    )
    
    $graphics.Clear([System.Drawing.Color]::FromArgb(15, 23, 42))
    
    if ($data.Count -eq 0) { 
        # Draw placeholder
        $graphics.DrawString("NO DATA", 
            (New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 40, $height/2 - 20)
        
        $graphics.DrawString("Enable tracking in settings", 
            (New-Object System.Drawing.Font("Segoe UI", 10)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 70, $height/2 + 10)
        return 
    }
    
    $maxValue = ($data | Measure-Object -Maximum).Maximum
    if ($maxValue -eq 0) { $maxValue = 1 }
    
    $barWidth = ($width - 120) / $data.Count
    $scale = ($height - 140) / $maxValue
    
    # Draw title
    $graphics.DrawString($title, 
        (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)), 
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
        20, 15)
    
    # Draw grid lines (digital style)
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 41, 59), 1)
    for ($i = 0; $i -le 5; $i++) {
        $y = $height - 80 - ($i * (($height - 140) / 5))
        $graphics.DrawLine($gridPen, 60, $y, $width - 60, $y)
        
        $value = [math]::Round(($i * $maxValue / 5), 1)
        $graphics.DrawString("${value}", 
            (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))), 
            35, $y - 10)
    }
    
    # Draw bars with digital glow effect
    for ($i = 0; $i -lt $data.Count; $i++) {
        $x = 60 + ($i * $barWidth) + 10
        $barHeight = $data[$i] * $scale
        
        if ($barHeight -lt 1) { $barHeight = 1 }
        
        $y = $height - 80 - $barHeight
        
        # Draw bar with gradient
        $gradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point($x, $y)),
            (New-Object System.Drawing.Point($x, $y + $barHeight)),
            [System.Drawing.Color]::FromArgb(255, $color.R, $color.G, $color.B),
            [System.Drawing.Color]::FromArgb(100, $color.R, $color.G, $color.B)
        )
        $graphics.FillRectangle($gradientBrush, $x, $y, $barWidth - 20, $barHeight)
        
        # Draw bar border
        $graphics.DrawRectangle(
            (New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 200, 200), 1)),
            $x, $y, $barWidth - 20, $barHeight
        )
        
        # Draw digital value on top
        $graphics.DrawString("$($data[$i])", 
            (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
            $x + 2, $y - 20)
        
        # Draw digital label
        $graphics.DrawString($labels[$i], 
            (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))), 
            $x - 5, $height - 65)
    }
    
    # Draw digital border
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51, 65, 85), 2)
    $graphics.DrawRectangle($borderPen, 10, 10, $width - 20, $height - 20)
}

function Draw-DigitalDonutChart {
    param(
        [System.Drawing.Graphics]$graphics,
        [array]$data,
        [array]$labels,
        [array]$colors,
        [int]$width,
        [int]$height,
        [string]$title = "DISTRIBUTION"
    )
    
    $graphics.Clear([System.Drawing.Color]::FromArgb(15, 23, 42))
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    if ($data.Count -eq 0) { 
        # Draw placeholder
        $graphics.DrawString("NO DATA", 
            (New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 40, $height/2 - 20)
        
        $graphics.DrawString("Enable tracking in settings", 
            (New-Object System.Drawing.Font("Segoe UI", 10)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 70, $height/2 + 10)
        return 
    }
    
    $total = ($data | Measure-Object -Sum).Sum
    if ($total -eq 0) { return }
    
    $centerX = $width / 2
    $centerY = $height / 2
    $outerRadius = [math]::Min($centerX, $centerY) - 60
    $innerRadius = $outerRadius * 0.5
    
    $startAngle = 0
    
    # Draw title
    $graphics.DrawString($title, 
        (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)), 
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
        20, 15)
    
    # Draw donut slices
    for ($i = 0; $i -lt $data.Count; $i++) {
        $sweepAngle = ($data[$i] / $total) * 360
        
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $path.AddArc($centerX - $outerRadius, $centerY - $outerRadius, $outerRadius * 2, $outerRadius * 2, $startAngle, $sweepAngle)
        $path.AddArc($centerX - $innerRadius, $centerY - $innerRadius, $innerRadius * 2, $innerRadius * 2, $startAngle + $sweepAngle, -$sweepAngle)
        $path.CloseFigure()
        
        $brush = New-Object System.Drawing.SolidBrush($colors[$i])
        $graphics.FillPath($brush, $path)
        
        # Draw outline
        $graphics.DrawPath(
            (New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 41, 59), 1)),
            $path
        )
        
        $startAngle += $sweepAngle
    }
    
    # Draw center text
    $graphics.FillEllipse(
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 41, 59))),
        $centerX - $innerRadius, $centerY - $innerRadius, $innerRadius * 2, $innerRadius * 2
    )
    
    $totalValue = [math]::Round($total, 1)
    $graphics.DrawString("${totalValue}", 
        (New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)), 
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
        $centerX - 25, $centerY - 15)
    
    $graphics.DrawString("TOTAL", 
        (New-Object System.Drawing.Font("Segoe UI", 10)), 
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))), 
        $centerX - 20, $centerY + 5)
    
    # Draw legend
    $legendX = 20
    $legendY = $height - 100
    
    for ($i = 0; $i -lt [math]::Min($data.Count, 5); $i++) {
        $percentage = [math]::Round(($data[$i] / $total) * 100, 1)
        $graphics.FillRectangle(
            (New-Object System.Drawing.SolidBrush($colors[$i])),
            $legendX, $legendY + ($i * 22), 12, 12
        )
        
        $label = if ($labels[$i].Length -gt 15) { $labels[$i].Substring(0, 12) + "..." } else { $labels[$i] }
        $graphics.DrawString("$label (${percentage}%)", 
            (New-Object System.Drawing.Font("Segoe UI", 9)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
            $legendX + 18, $legendY + ($i * 22) - 2)
    }
    
    # Draw digital border
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51, 65, 85), 2)
    $graphics.DrawRectangle($borderPen, 10, 10, $width - 20, $height - 20)
}

function Draw-DigitalLineGraph {
    param(
        [System.Drawing.Graphics]$graphics,
        [array]$data,
        [array]$labels,
        [int]$width,
        [int]$height,
        [System.Drawing.Color]$color,
        [string]$title = "TREND"
    )
    
    $graphics.Clear([System.Drawing.Color]::FromArgb(15, 23, 42))
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    
    if ($data.Count -eq 0) { 
        # Draw placeholder
        $graphics.DrawString("NO DATA", 
            (New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 40, $height/2 - 20)
        
        $graphics.DrawString("Enable tracking in settings", 
            (New-Object System.Drawing.Font("Segoe UI", 10)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))), 
            $width/2 - 70, $height/2 + 10)
        return 
    }
    
    $maxValue = ($data | Measure-Object -Maximum).Maximum
    if ($maxValue -eq 0) { $maxValue = 1 }
    
    $pointWidth = ($width - 120) / ($data.Count - 1)
    $scale = ($height - 140) / $maxValue
    
    # Draw title
    $graphics.DrawString($title, 
        (New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)), 
        (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
        20, 15)
    
    # Draw grid lines
    $gridPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(30, 41, 59), 1)
    for ($i = 0; $i -le 5; $i++) {
        $y = $height - 80 - ($i * (($height - 140) / 5))
        $graphics.DrawLine($gridPen, 60, $y, $width - 60, $y)
        
        $value = [math]::Round(($i * $maxValue / 5), 1)
        $graphics.DrawString("${value}", 
            (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))), 
            35, $y - 10)
    }
    
    # Create line path
    $linePath = New-Object System.Drawing.Drawing2D.GraphicsPath
    
    for ($i = 0; $i -lt $data.Count; $i++) {
        $x = 60 + ($i * $pointWidth)
        $y = $height - 80 - ($data[$i] * $scale)
        
        if ($i -eq 0) {
            $linePath.StartFigure()
            $linePath.AddLine($x, $y, $x, $y)
        } else {
            $prevX = 60 + (($i - 1) * $pointWidth)
            $prevY = $height - 80 - ($data[$i - 1] * $scale)
            $linePath.AddLine($prevX, $prevY, $x, $y)
        }
        
        # Draw data point
        $graphics.FillEllipse(
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)),
            $x - 4, $y - 4, 8, 8
        )
        
        $graphics.DrawEllipse(
            (New-Object System.Drawing.Pen($color, 2)),
            $x - 4, $y - 4, 8, 8
        )
        
        # Draw value (every other point)
        if ($i % 2 -eq 0) {
            $graphics.DrawString("$($data[$i])", 
                (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
                (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), 
                $x - 8, $y - 25)
        }
        
        # Draw label (every 3rd label)
        if ($i % 3 -eq 0) {
            $graphics.DrawString($labels[$i], 
                (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
                (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(148, 163, 184))), 
                $x - 8, $height - 65)
        }
    }
    
    # Draw the line
    $linePen = New-Object System.Drawing.Pen($color, 3)
    $graphics.DrawPath($linePen, $linePath)
    
    # Draw digital border
    $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(51, 65, 85), 2)
    $graphics.DrawRectangle($borderPen, 10, 10, $width - 20, $height - 20)
}

function Update-Charts {
    # Weekly Chart
    if ($weeklyChartBox -and $weeklyChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($weeklyChartBox.Width, $weeklyChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Generate weekly data
        $weeklyData = @()
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
            if ($global:appData.DailyStats.$date -and $global:appData.DailyStats.$date.TotalSeconds -gt 0) {
                $hours = [math]::Round($global:appData.DailyStats.$date.TotalSeconds / 3600, 1)
                $weeklyData += $hours
            } else {
                # Generate realistic demo data
                $weeklyData += @(3.5, 4.2, 3.8, 5.1, 4.5, 6.2, 4.8)[$i]
            }
        }
        
        $weeklyLabels = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        
        Draw-DigitalBarChart $graphics $weeklyData $weeklyLabels $weeklyChartBox.Width $weeklyChartBox.Height ([System.Drawing.Color]::FromArgb(59, 130, 246)) "WEEKLY SCREEN TIME"
        
        $weeklyChartBox.Image = $bitmap
    }
    
    # App Usage Chart
    if ($appChartBox -and $appChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($appChartBox.Width, $appChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Get top apps
        $topApps = $global:appUsage.GetEnumerator() | 
                   Where-Object { $_.Key -ne "Idle" -and $_.Key -ne "Unknown" -and $_.Key -ne "Tracking Disabled" } |
                   Sort-Object Value -Descending | 
                   Select-Object -First 5
        
        if ($topApps.Count -gt 0) {
            $appData = @()
            $appLabels = @()
            
            foreach ($app in $topApps) {
                $hours = [math]::Round($app.Value / 3600, 1)
                $appData += $hours
                $appLabels += $app.Key
            }
        } else {
            # Demo data
            $appData = @(2.5, 1.8, 1.2, 0.8, 0.5)
            $appLabels = @("Chrome", "Word", "Discord", "Spotify", "Other")
        }
        
        $appColors = @(
            [System.Drawing.Color]::FromArgb(59, 130, 246),
            [System.Drawing.Color]::FromArgb(16, 185, 129),
            [System.Drawing.Color]::FromArgb(245, 158, 11),
            [System.Drawing.Color]::FromArgb(239, 68, 68),
            [System.Drawing.Color]::FromArgb(139, 92, 246)
        )
        
        Draw-DigitalDonutChart $graphics $appData $appLabels $appColors $appChartBox.Width $appChartBox.Height "APP DISTRIBUTION"
        
        $appChartBox.Image = $bitmap
    }
    
    # Productivity Chart
    if ($productivityChartBox -and $productivityChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($productivityChartBox.Width, $productivityChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Generate productivity trend
        $prodData = @(65, 72, 68, 75, 70, 78, 74)
        $prodLabels = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        
        Draw-DigitalLineGraph $graphics $prodData $prodLabels $productivityChartBox.Width $productivityChartBox.Height ([System.Drawing.Color]::FromArgb(16, 185, 129)) "PRODUCTIVITY TREND"
        
        $productivityChartBox.Image = $bitmap
    }
    
    # Daily Pattern Chart
    if ($dailyChartBox -and $dailyChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($dailyChartBox.Width, $dailyChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Generate hourly data
        $hourlyData = @()
        for ($i = 0; $i -lt 12; $i++) {
            $hourlyData += (Get-Random -Minimum 0.5 -Maximum 3.0)
        }
        
        $hourlyLabels = @("6AM", "8AM", "10AM", "12PM", "2PM", "4PM", "6PM", "8PM", "10PM", "12AM", "2AM", "4AM")
        
        Draw-DigitalBarChart $graphics $hourlyData $hourlyLabels $dailyChartBox.Width $dailyChartBox.Height ([System.Drawing.Color]::FromArgb(139, 92, 246)) "DAILY PATTERN"
        
        $dailyChartBox.Image = $bitmap
    }
}

# ========== SETTINGS PANEL ==========
function Create-SettingsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "SettingsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "⚙️ DIGITAL SETTINGS"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    # Settings Container
    $settingsContainer = New-Object System.Windows.Forms.Panel
    $settingsContainer.Size = New-Object System.Drawing.Size(900, 580)
    $settingsContainer.Location = New-Object System.Drawing.Point(30, 90)
    $settingsContainer.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $settingsContainer.AutoScroll = $true
    
    $global:toggleButtons = @{}
    
    function Create-ToggleSetting {
        param(
            [string]$settingName,
            [string]$settingDescription,
            [string]$settingDetails,
            [bool]$initialValue,
            [int]$yPosition
        )
        
        # Setting container
        $settingPanel = New-Object System.Windows.Forms.Panel
        $settingPanel.Size = New-Object System.Drawing.Size(850, 80)
        $settingPanel.Location = New-Object System.Drawing.Point(20, $yPosition)
        $settingPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
        
        # Setting label
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $settingDescription
        $label.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $label.ForeColor = [System.Drawing.Color]::White
        $label.Size = New-Object System.Drawing.Size(500, 25)
        $label.Location = New-Object System.Drawing.Point(20, 15)
        $settingPanel.Controls.Add($label)
        
        # Setting details
        $detailsLabel = New-Object System.Windows.Forms.Label
        $detailsLabel.Text = $settingDetails
        $detailsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $detailsLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
        $detailsLabel.Size = New-Object System.Drawing.Size(500, 20)
        $detailsLabel.Location = New-Object System.Drawing.Point(20, 40)
        $settingPanel.Controls.Add($detailsLabel)
        
        # Toggle button
        $toggleButton = New-Object System.Windows.Forms.Button
        $toggleButton.Size = New-Object System.Drawing.Size(120, 40)
        $toggleButton.Location = New-Object System.Drawing.Point(700, 20)
        $toggleButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $toggleButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $toggleButton.FlatAppearance.BorderSize = 0
        $toggleButton.Cursor = [System.Windows.Forms.Cursors]::Hand
        $toggleButton.Tag = $settingName
        
        $global:toggleButtons[$settingName] = $toggleButton
        
        # Set initial state
        if ($initialValue) {
            $toggleButton.Text = "✅ ENABLED"
            $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
            $toggleButton.ForeColor = [System.Drawing.Color]::White
            $toggleButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(13, 148, 103)
        } else {
            $toggleButton.Text = "❌ DISABLED"
            $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
            $toggleButton.ForeColor = [System.Drawing.Color]::White
            $toggleButton.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
        }
        
        # Click event
        $toggleButton.Add_Click({
            $currentSetting = $this.Tag
            $currentValue = $global:appData.Settings.$currentSetting
            $newValue = -not $currentValue
            
            # Update setting
            $global:appData.Settings.$currentSetting = $newValue
            
            # Update button
            if ($newValue) {
                $this.Text = "✅ ENABLED"
                $this.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
                $this.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(13, 148, 103)
                $message = "✅ $currentSetting enabled"
                $color = [System.Drawing.Color]::LightGreen
            } else {
                $this.Text = "❌ DISABLED"
                $this.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
                $this.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(220, 60, 60)
                $message = "❌ $currentSetting disabled"
                $color = [System.Drawing.Color]::Orange
            }
            
            # Special handling for tracking
            if ($currentSetting -eq "RealTimeTracking") {
                $global:isTrackingEnabled = $newValue
            }
            
            Update-Status $message $color
            Save-Settings
        })
        
        $settingPanel.Controls.Add($toggleButton)
        return $settingPanel
    }
    
    # Create settings
    $settingsList = @(
        @{Name="RealTimeTracking"; Description="📊 REAL-TIME TRACKING"; Details="Monitor screen time and activity"},
        @{Name="TrackApplications"; Description="📱 APPLICATION TRACKING"; Details="Track which apps you use"},
        @{Name="TrackProductivity"; Description="🎯 PRODUCTIVITY METRICS"; Details="Calculate productive time"},
        @{Name="AutoSaveData"; Description="💾 AUTO-SAVE DATA"; Details="Save data automatically"},
        @{Name="GenerateReports"; Description="📄 GENERATE REPORTS"; Details="Create usage reports"},
        @{Name="ShowNotifications"; Description="🔔 SHOW NOTIFICATIONS"; Details="Display alerts"},
        @{Name="AlertSounds"; Description="🔊 ALERT SOUNDS"; Details="Play notification sounds"},
        @{Name="DarkMode"; Description="🌙 DARK MODE"; Details="Dark theme interface"}
    )
    
    $yPos = 20
    foreach ($setting in $settingsList) {
        $settingPanel = Create-ToggleSetting -settingName $setting.Name `
                                            -settingDescription $setting.Description `
                                            -settingDetails $setting.Details `
                                            -initialValue $global:appData.Settings.($setting.Name) `
                                            -yPosition $yPos
        $settingsContainer.Controls.Add($settingPanel)
        $yPos += 90
    }
    
    # Data Management Section
    $dataPanel = New-Object System.Windows.Forms.Panel
    $dataPanel.Size = New-Object System.Drawing.Size(850, 120)
    $dataPanel.Location = New-Object System.Drawing.Point(20, $yPos)
    $dataPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    
    $dataLabel = New-Object System.Windows.Forms.Label
    $dataLabel.Text = "📁 DATA MANAGEMENT"
    $dataLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $dataLabel.ForeColor = [System.Drawing.Color]::White
    $dataLabel.Size = New-Object System.Drawing.Size(300, 30)
    $dataLabel.Location = New-Object System.Drawing.Point(20, 15)
    $dataPanel.Controls.Add($dataLabel)
    
    # Export Button
    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Text = "📤 EXPORT DATA"
    $exportButton.Size = New-Object System.Drawing.Size(150, 40)
    $exportButton.Location = New-Object System.Drawing.Point(20, 60)
    $exportButton.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
    $exportButton.ForeColor = [System.Drawing.Color]::White
    $exportButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $exportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $exportButton.FlatAppearance.BorderSize = 0
    $exportButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $exportButton.Add_Click({
        $exportPath = "$env:USERPROFILE\Desktop\Digital_Wellbeing_Data_$(Get-Date -Format 'yyyyMMdd_HHmm').json"
        $global:appData | ConvertTo-Json -Depth 10 | Set-Content $exportPath -Encoding UTF8
        Update-Status "📤 Data exported to Desktop" ([System.Drawing.Color]::LightBlue)
        [System.Windows.Forms.MessageBox]::Show("Data exported to:`n$exportPath", "EXPORT COMPLETE", "OK", "Information")
    })
    $dataPanel.Controls.Add($exportButton)
    
    # Reset Button
    $resetButton = New-Object System.Windows.Forms.Button
    $resetButton.Text = "🔄 RESET DATA"
    $resetButton.Size = New-Object System.Drawing.Size(150, 40)
    $resetButton.Location = New-Object System.Drawing.Point(190, 60)
    $resetButton.BackColor = [System.Drawing.Color]::FromArgb(245, 158, 11)
    $resetButton.ForeColor = [System.Drawing.Color]::White
    $resetButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $resetButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $resetButton.FlatAppearance.BorderSize = 0
    $resetButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $resetButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Reset all tracking data?", 
            "RESET DATA", 
            [System.Windows.Forms.MessageBoxButtons]::YesNo, 
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq "Yes") {
            $global:appData.DailyStats = @{}
            $global:appData.ActivityLog = @()
            $global:appData.Notifications = @()
            $global:appData.AppUsage = @{}
            $global:totalActiveTime = 0
            $global:appUsage = @{}
            $global:activityLog = @{}
            $global:notifications = @{}
            
            Save-Settings
            Update-DashboardStats
            Update-Status "🔄 All data reset" ([System.Drawing.Color]::Orange)
            [System.Windows.Forms.MessageBox]::Show("All data has been reset.", "RESET COMPLETE", "OK", "Information")
        }
    })
    $dataPanel.Controls.Add($resetButton)
    
    # Save Button
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "💾 SAVE NOW"
    $saveButton.Size = New-Object System.Drawing.Size(150, 40)
    $saveButton.Location = New-Object System.Drawing.Point(360, 60)
    $saveButton.BackColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
    $saveButton.ForeColor = [System.Drawing.Color]::White
    $saveButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveButton.FlatAppearance.BorderSize = 0
    $saveButton.Cursor = [System.Windows.Forms.Cursors]::Hand
    $saveButton.Add_Click({
        Save-Settings
        Update-Status "💾 Settings saved" ([System.Drawing.Color]::LightGreen)
    })
    $dataPanel.Controls.Add($saveButton)
    
    $settingsContainer.Controls.Add($dataPanel)
    
    $panel.Controls.Add($settingsContainer)
    return $panel
}

# ========== DIGITAL DASHBOARD PANEL ==========
function Create-DashboardPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "DashboardPanel"
    
    # Digital Stats Cards
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(940, 150)
    $statsPanel.Location = New-Object System.Drawing.Point(0, 0)
    
    $cards = @(
        @{Title="SCREEN TIME"; Value="0h 0m"; Color="#3B82F6"; Icon="⏱️"},
        @{Title="APPS USED"; Value="0"; Color="#10B981"; Icon="📱"},
        @{Title="NOTIFICATIONS"; Value="0"; Color="#F59E0B"; Icon="🔔"},
        @{Title="PRODUCTIVITY"; Value="0%"; Color="#EF4444"; Icon="📈"}
    )
    
    for ($i = 0; $i -lt $cards.Length; $i++) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(220, 140)
        $card.Location = New-Object System.Drawing.Point(($i * 240), 0)
        $card.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $card.BorderColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
        
        # Icon
        $iconLabel = New-Object System.Windows.Forms.Label
        $iconLabel.Text = $cards[$i].Icon
        $iconLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24)
        $iconLabel.ForeColor = [System.Drawing.Color]::White
        $iconLabel.Size = New-Object System.Drawing.Size(50, 50)
        $iconLabel.Location = New-Object System.Drawing.Point(20, 20)
        $iconLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $card.Controls.Add($iconLabel)
        
        # Value
        $valueLabel = New-Object System.Windows.Forms.Label
        $valueLabel.Text = $cards[$i].Value
        $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
        $valueLabel.ForeColor = [System.Drawing.Color]::White
        $valueLabel.Size = New-Object System.Drawing.Size(200, 60)
        $valueLabel.Location = New-Object System.Drawing.Point(80, 20)
        $valueLabel.Name = "CardValue$i"
        $card.Controls.Add($valueLabel)
        
        # Title
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = $cards[$i].Title
        $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
        $titleLabel.Size = New-Object System.Drawing.Size(200, 25)
        $titleLabel.Location = New-Object System.Drawing.Point(20, 100)
        $card.Controls.Add($titleLabel)
        
        # Accent bar
        $accentBar = New-Object System.Windows.Forms.Panel
        $accentBar.Size = New-Object System.Drawing.Size(5, 140)
        $accentBar.Location = New-Object System.Drawing.Point(0, 0)
        $accentBar.BackColor = [System.Drawing.Color]::FromArgb($cards[$i].Color.Substring(1, 2), 
                                                               $cards[$i].Color.Substring(3, 2), 
                                                               $cards[$i].Color.Substring(5, 2))
        $card.Controls.Add($accentBar)
        
        $statsPanel.Controls.Add($card)
    }
    $global:statsPanel = $statsPanel
    $panel.Controls.Add($statsPanel)
    
    # Charts Area
    $chartsPanel = New-Object System.Windows.Forms.Panel
    $chartsPanel.Size = New-Object System.Drawing.Size(940, 500)
    $chartsPanel.Location = New-Object System.Drawing.Point(0, 170)
    
    # Row 1: Weekly Chart & App Usage
    $weeklyChartPanel = New-Object System.Windows.Forms.Panel
    $weeklyChartPanel.Size = New-Object System.Drawing.Size(460, 240)
    $weeklyChartPanel.Location = New-Object System.Drawing.Point(0, 0)
    $weeklyChartPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $weeklyChartPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $weeklyChartPanel.BorderColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    
    $weeklyChartTitle = New-Object System.Windows.Forms.Label
    $weeklyChartTitle.Text = "📊 WEEKLY SCREEN TIME"
    $weeklyChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $weeklyChartTitle.ForeColor = [System.Drawing.Color]::White
    $weeklyChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $weeklyChartTitle.Location = New-Object System.Drawing.Point(20, 15)
    $weeklyChartPanel.Controls.Add($weeklyChartTitle)
    
    $weeklyChartBox = New-Object System.Windows.Forms.PictureBox
    $weeklyChartBox.Size = New-Object System.Drawing.Size(420, 180)
    $weeklyChartBox.Location = New-Object System.Drawing.Point(20, 50)
    $weeklyChartBox.BackColor = [System.Drawing.Color]::Transparent
    $global:weeklyChartBox = $weeklyChartBox
    $weeklyChartPanel.Controls.Add($weeklyChartBox)
    
    # App Usage Chart
    $appChartPanel = New-Object System.Windows.Forms.Panel
    $appChartPanel.Size = New-Object System.Drawing.Size(460, 240)
    $appChartPanel.Location = New-Object System.Drawing.Point(480, 0)
    $appChartPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $appChartPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $appChartPanel.BorderColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    
    $appChartTitle = New-Object System.Windows.Forms.Label
    $appChartTitle.Text = "📱 APP DISTRIBUTION"
    $appChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $appChartTitle.ForeColor = [System.Drawing.Color]::White
    $appChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $appChartTitle.Location = New-Object System.Drawing.Point(20, 15)
    $appChartPanel.Controls.Add($appChartTitle)
    
    $appChartBox = New-Object System.Windows.Forms.PictureBox
    $appChartBox.Size = New-Object System.Drawing.Size(420, 180)
    $appChartBox.Location = New-Object System.Drawing.Point(20, 50)
    $appChartBox.BackColor = [System.Drawing.Color]::Transparent
    $global:appChartBox = $appChartBox
    $appChartPanel.Controls.Add($appChartBox)
    
    # Row 2: Productivity & Daily Pattern
    $productivityChartPanel = New-Object System.Windows.Forms.Panel
    $productivityChartPanel.Size = New-Object System.Drawing.Size(460, 240)
    $productivityChartPanel.Location = New-Object System.Drawing.Point(0, 250)
    $productivityChartPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $productivityChartPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $productivityChartPanel.BorderColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    
    $productivityChartTitle = New-Object System.Windows.Forms.Label
    $productivityChartTitle.Text = "📈 PRODUCTIVITY TREND"
    $productivityChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $productivityChartTitle.ForeColor = [System.Drawing.Color]::White
    $productivityChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $productivityChartTitle.Location = New-Object System.Drawing.Point(20, 15)
    $productivityChartPanel.Controls.Add($productivityChartTitle)
    
    $productivityChartBox = New-Object System.Windows.Forms.PictureBox
    $productivityChartBox.Size = New-Object System.Drawing.Size(420, 180)
    $productivityChartBox.Location = New-Object System.Drawing.Point(20, 50)
    $productivityChartBox.BackColor = [System.Drawing.Color]::Transparent
    $global:productivityChartBox = $productivityChartBox
    $productivityChartPanel.Controls.Add($productivityChartBox)
    
    # Daily Pattern Chart
    $dailyChartPanel = New-Object System.Windows.Forms.Panel
    $dailyChartPanel.Size = New-Object System.Drawing.Size(460, 240)
    $dailyChartPanel.Location = New-Object System.Drawing.Point(480, 250)
    $dailyChartPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    $dailyChartPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $dailyChartPanel.BorderColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    
    $dailyChartTitle = New-Object System.Windows.Forms.Label
    $dailyChartTitle.Text = "🌞 DAILY PATTERN"
    $dailyChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $dailyChartTitle.ForeColor = [System.Drawing.Color]::White
    $dailyChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $dailyChartTitle.Location = New-Object System.Drawing.Point(20, 15)
    $dailyChartPanel.Controls.Add($dailyChartTitle)
    
    $dailyChartBox = New-Object System.Windows.Forms.PictureBox
    $dailyChartBox.Size = New-Object System.Drawing.Size(420, 180)
    $dailyChartBox.Location = New-Object System.Drawing.Point(20, 50)
    $dailyChartBox.BackColor = [System.Drawing.Color]::Transparent
    $global:dailyChartBox = $dailyChartBox
    $dailyChartPanel.Controls.Add($dailyChartBox)
    
    # Add all chart panels
    $chartsPanel.Controls.Add($weeklyChartPanel)
    $chartsPanel.Controls.Add($appChartPanel)
    $chartsPanel.Controls.Add($productivityChartPanel)
    $chartsPanel.Controls.Add($dailyChartPanel)
    
    $panel.Controls.Add($chartsPanel)
    
    return $panel
}

# ========== OTHER PANELS ==========
function Create-ActivityPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ActivityPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "📋 ACTIVITY LOG"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    $activityPanel = New-Object System.Windows.Forms.Panel
    $activityPanel.Size = New-Object System.Drawing.Size(900, 580)
    $activityPanel.Location = New-Object System.Drawing.Point(30, 90)
    $activityPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    
    $activityList = New-Object System.Windows.Forms.ListBox
    $activityList.Size = New-Object System.Drawing.Size(860, 520)
    $activityList.Location = New-Object System.Drawing.Point(20, 20)
    $activityList.Font = New-Object System.Drawing.Font("Consolas", 10)
    $activityList.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $activityList.ForeColor = [System.Drawing.Color]::White
    $activityList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    
    # Add recent activities
    $recentActivities = $global:activityLog | Select-Object -Last 20
    if ($recentActivities.Count -eq 0) {
        $activityList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $activityList.Items.Add("║                   NO ACTIVITY RECORDED                       ║")
        $activityList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        $activityList.Items.Add("║ Enable tracking in settings to start recording activity      ║")
        $activityList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    } else {
        $activityList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $activityList.Items.Add("║                   RECENT ACTIVITIES                          ║")
        $activityList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        foreach ($activity in $recentActivities) {
            $activityList.Items.Add("║ $($activity.Timestamp) - $($activity.Application.PadRight(20))")
        }
        $activityList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    }
    
    $activityPanel.Controls.Add($activityList)
    $panel.Controls.Add($activityPanel)
    
    return $panel
}

function Create-ScreenTimePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ScreenTimePanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "⏱️ SCREEN TIME"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $statsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $statsPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    
    $screenTimeHours = [math]::Floor($global:totalActiveTime / 3600)
    $screenTimeMinutes = [math]::Floor(($global:totalActiveTime % 3600) / 60)
    
    $statsText = @"
╔══════════════════════════════════════════════════════════════╗
║                     SCREEN TIME ANALYSIS                      ║
╠══════════════════════════════════════════════════════════════╣
║ 📊 TODAY'S TOTAL: ${screenTimeHours}h ${screenTimeMinutes}m                               ║
║ 🎯 DAILY GOAL: $($global:appData.Goals.DailyLimit) hours                                    ║
║ 📱 CURRENT APP: $($global:currentApp.PadRight(30))           ║
║ ⚡ ACTIVITY STATUS: $(Get-UserActivityLevel)                                 ║
╠══════════════════════════════════════════════════════════════╣
║                     WEEKLY OVERVIEW                           ║
╠══════════════════════════════════════════════════════════════╣
"@
    
    # Add weekly data
    $days = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
    for ($i = 6; $i -ge 0; $i--) {
        $date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
        $hours = if ($global:appData.DailyStats.$date) { 
            [math]::Round($global:appData.DailyStats.$date.TotalSeconds / 3600, 1) 
        } else { 
            0 
        }
        $dayName = $days[(6 - $i)]
        $statsText += "`n║ $($dayName.PadRight(10)): $hours hours".PadRight(58) + "║"
    }
    
    $statsText += @"
╠══════════════════════════════════════════════════════════════╣
║                     RECOMMENDATIONS                          ║
╠══════════════════════════════════════════════════════════════╣
║ • Take regular breaks every 45-60 minutes                    ║
║ • Follow the 20-20-20 rule for eye health                    ║
║ • Use focus sessions for productive work                     ║
║ • Review daily reports to identify patterns                  ║
╚══════════════════════════════════════════════════════════════╝
"@
    
    $statsLabel = New-Object System.Windows.Forms.Label
    $statsLabel.Text = $statsText
    $statsLabel.Font = New-Object System.Drawing.Font("Consolas", 11)
    $statsLabel.ForeColor = [System.Drawing.Color]::White
    $statsLabel.Size = New-Object System.Drawing.Size(860, 550)
    $statsLabel.Location = New-Object System.Drawing.Point(20, 20)
    $statsPanel.Controls.Add($statsLabel)
    
    $panel.Controls.Add($statsPanel)
    return $panel
}

function Create-AppUsagePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "AppUsagePanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "📱 APP USAGE"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    $usagePanel = New-Object System.Windows.Forms.Panel
    $usagePanel.Size = New-Object System.Drawing.Size(900, 580)
    $usagePanel.Location = New-Object System.Drawing.Point(30, 90)
    $usagePanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    
    $appList = New-Object System.Windows.Forms.ListBox
    $appList.Size = New-Object System.Drawing.Size(860, 520)
    $appList.Location = New-Object System.Drawing.Point(20, 20)
    $appList.Font = New-Object System.Drawing.Font("Consolas", 10)
    $appList.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $appList.ForeColor = [System.Drawing.Color]::White
    $appList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    
    if ($global:appUsage.Count -eq 0) {
        $appList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $appList.Items.Add("║              NO APPLICATION DATA                              ║")
        $appList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        $appList.Items.Add("║ Enable application tracking in settings                       ║")
        $appList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    } else {
        $appList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $appList.Items.Add("║                TOP APPLICATIONS TODAY                         ║")
        $appList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        
        $sortedApps = $global:appUsage.GetEnumerator() | 
                     Where-Object { $_.Key -ne "Idle" -and $_.Key -ne "Unknown" } |
                     Sort-Object Value -Descending
        
        $rank = 1
        foreach ($app in $sortedApps) {
            $hours = [math]::Floor($app.Value / 3600)
            $minutes = [math]::Floor(($app.Value % 3600) / 60)
            $percentage = if ($global:totalActiveTime -gt 0) { [math]::Round(($app.Value / $global:totalActiveTime) * 100) } else { 0 }
            
            $appName = if ($app.Key.Length -gt 20) { $app.Key.Substring(0, 17) + "..." } else { $app.Key }
            $timeText = "${hours}h ${minutes}m"
            $appList.Items.Add("║ $rank. $($appName.PadRight(20)) $($timeText.PadRight(10)) ($percentage%)".PadRight(58) + "║")
            $rank++
            if ($rank -gt 10) { break }
        }
        $appList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    }
    
    $usagePanel.Controls.Add($appList)
    $panel.Controls.Add($usagePanel)
    return $panel
}

function Create-NotificationsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "NotificationsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "🔔 NOTIFICATIONS"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    $notifPanel = New-Object System.Windows.Forms.Panel
    $notifPanel.Size = New-Object System.Drawing.Size(900, 580)
    $notifPanel.Location = New-Object System.Drawing.Point(30, 90)
    $notifPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    
    $notifList = New-Object System.Windows.Forms.ListBox
    $notifList.Size = New-Object System.Drawing.Size(860, 520)
    $notifList.Location = New-Object System.Drawing.Point(20, 20)
    $notifList.Font = New-Object System.Drawing.Font("Consolas", 10)
    $notifList.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $notifList.ForeColor = [System.Drawing.Color]::White
    $notifList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    
    if ($global:notifications.Count -eq 0) {
        $notifList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $notifList.Items.Add("║               NO NOTIFICATIONS                               ║")
        $notifList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        $notifList.Items.Add("║ Notifications will appear here                               ║")
        $notifList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    } else {
        $notifList.Items.Add("╔══════════════════════════════════════════════════════════════╗")
        $notifList.Items.Add("║                 RECENT NOTIFICATIONS                         ║")
        $notifList.Items.Add("╠══════════════════════════════════════════════════════════════╣")
        
        $recentNotifs = $global:notifications | Select-Object -Last 15
        foreach ($notif in $recentNotifs) {
            $icon = switch ($notif.Type) {
                "Focus" { "🎯" }
                "Alert" { "⚠️" }
                "Info" { "ℹ️" }
                default { "🔔" }
            }
            $message = if ($notif.Message.Length -gt 50) { $notif.Message.Substring(0, 47) + "..." } else { $notif.Message }
            $notifList.Items.Add("║ $icon $($notif.Timestamp) - $message".PadRight(58) + "║")
        }
        $notifList.Items.Add("╚══════════════════════════════════════════════════════════════╝")
    }
    
    $notifPanel.Controls.Add($notifList)
    $panel.Controls.Add($notifPanel)
    return $panel
}

function Create-ParentalControlsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ParentalControlsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "👨‍👩‍👧‍👦 PARENTAL CONTROLS"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $panel.Controls.Add($titleLabel)
    
    $controlsPanel = New-Object System.Windows.Forms.Panel
    $controlsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $controlsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $controlsPanel.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
    
    $controlsText = @"
╔══════════════════════════════════════════════════════════════╗
║                  PARENTAL CONTROLS STATUS                    ║
╠══════════════════════════════════════════════════════════════╣
║ STATUS: $(if ($global:appData.ParentalControls.IsActive) {'✅ ACTIVE'} else {'❌ INACTIVE'}) ║
║ DAILY TIME LIMIT: $($global:appData.ParentalControls.TimeLimit) hours                        ║
║ BEDTIME: $($global:appData.ParentalControls.Bedtime)                                         ║
║ WEBSITE FILTER: $(if ($global:appData.ParentalControls.WebsiteFilter) {'✅ ON'} else {'❌ OFF'}) ║
║ FOCUS MODE: $(if ($global:appData.ParentalControls.FocusMode) {'✅ ON'} else {'❌ OFF'})      ║
║ DAILY REPORT: $(if ($global:appData.ParentalControls.DailyReport) {'✅ ON'} else {'❌ OFF'})  ║
╠══════════════════════════════════════════════════════════════╣
║                    BLOCKED APPLICATIONS                       ║
╠══════════════════════════════════════════════════════════════╣
"@
    
    foreach ($app in $global:appData.ParentalControls.BlockedApps) {
        $controlsText += "`n║ ❌ $app".PadRight(58) + "║"
    }
    
    $controlsText += @"
╠══════════════════════════════════════════════════════════════╣
║                      CONTROLS                                ║
╠══════════════════════════════════════════════════════════════╣
║ • Set daily time limits for computer usage                   ║
║ • Block inappropriate websites                               ║
║ • Restrict access to specific applications                   ║
║ • Enforce bedtime schedules                                  ║
║ • Generate daily activity reports                            ║
╚══════════════════════════════════════════════════════════════╝
"@
    
    $controlsLabel = New-Object System.Windows.Forms.Label
    $controlsLabel.Text = $controlsText
    $controlsLabel.Font = New-Object System.Drawing.Font("Consolas", 11)
    $controlsLabel.ForeColor = [System.Drawing.Color]::White
    $controlsLabel.Size = New-Object System.Drawing.Size(860, 550)
    $controlsLabel.Location = New-Object System.Drawing.Point(20, 20)
    $controlsPanel.Controls.Add($controlsLabel)
    
    $panel.Controls.Add($controlsPanel)
    return $panel
}

# ========== MAIN FORM ==========
$form = New-Object System.Windows.Forms.Form
$form.Text = "Digital Wellbeing & Parental Controls - DIGITAL DASHBOARD"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# ========== SIDEBAR ==========
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(220, 800)
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$sidebar.Dock = [System.Windows.Forms.DockStyle]::Left
$form.Controls.Add($sidebar)

# Logo Panel
$logoPanel = New-Object System.Windows.Forms.Panel
$logoPanel.Size = New-Object System.Drawing.Size(220, 100)
$logoPanel.BackColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
$logoPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$sidebar.Controls.Add($logoPanel)

$logoLabel = New-Object System.Windows.Forms.Label
$logoLabel.Text = "DIGITAL`nWELLBEING"
$logoLabel.ForeColor = [System.Drawing.Color]::White
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$logoLabel.Size = New-Object System.Drawing.Size(200, 80)
$logoLabel.Location = New-Object System.Drawing.Point(10, 10)
$logoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$logoPanel.Controls.Add($logoLabel)

# Sidebar Buttons
$buttonTitles = @("📊 Dashboard", "📋 Activity", "⏱️ Screen Time", "📱 App Usage", "🔔 Notifications", "👨‍👩‍👧‍👦 Parental", "⚙️ Settings")

for ($i = 0; $i -lt $buttonTitles.Length; $i++) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "  " + $buttonTitles[$i]
    $button.Size = New-Object System.Drawing.Size(200, 50)
    $button.Location = New-Object System.Drawing.Point(10, (120 + ($i * 60)))
    $button.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
    $button.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    # Extract panel name
    $panelName = switch -Regex ($buttonTitles[$i]) {
        "^📊" { "Dashboard" }
        "^📋" { "Activity" }
        "^⏱️" { "Screen Time" }
        "^📱" { "App Usage" }
        "^🔔" { "Notifications" }
        "^👨‍👩‍👧‍👦" { "ParentalControls" }
        "^⚙️" { "Settings" }
        default { $buttonTitles[$i].Substring(3) }
    }
    
    $button.Tag = $panelName
    $button.Add_Click({
        Show-Panel $this.Tag
    })
    $sidebar.Controls.Add($button)
}

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(220, 100)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$statusPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$sidebar.Controls.Add($statusPanel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Initializing..."
$statusLabel.ForeColor = [System.Drawing.Color]::LightGreen
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$statusLabel.Size = New-Object System.Drawing.Size(200, 20)
$statusLabel.Location = New-Object System.Drawing.Point(10, 20)
$statusPanel.Controls.Add($statusLabel)

$timerLabel = New-Object System.Windows.Forms.Label
$timerLabel.Text = "Ready"
$timerLabel.ForeColor = [System.Drawing.Color]::White
$timerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$timerLabel.Size = New-Object System.Drawing.Size(200, 30)
$timerLabel.Location = New-Object System.Drawing.Point(10, 50)
$timerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$statusPanel.Controls.Add($timerLabel)

# ========== MAIN CONTENT AREA ==========
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(980, 800)
$contentPanel.BackColor = [System.Drawing.Color]::White
$contentPanel.Dock = [System.Windows.Forms.DockStyle]::Right
$form.Controls.Add($contentPanel)

# Header
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(940, 100)
$headerPanel.Location = New-Object System.Drawing.Point(20, 20)
$headerPanel.BackColor = [System.Drawing.Color]::White

$welcomeLabel = New-Object System.Windows.Forms.Label
$welcomeLabel.Text = "DIGITAL WELLBEING DASHBOARD"
$welcomeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$welcomeLabel.ForeColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$welcomeLabel.Size = New-Object System.Drawing.Size(500, 50)
$welcomeLabel.Location = New-Object System.Drawing.Point(30, 20)
$headerPanel.Controls.Add($welcomeLabel)

$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Text = (Get-Date).ToString("dddd, MMMM dd, yyyy")
$dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$dateLabel.ForeColor = [System.Drawing.Color]::Gray
$dateLabel.Size = New-Object System.Drawing.Size(300, 30)
$dateLabel.Location = New-Object System.Drawing.Point(30, 70)
$headerPanel.Controls.Add($dateLabel)

$clockLabel = New-Object System.Windows.Forms.Label
$clockLabel.Text = (Get-Date).ToString("HH:mm:ss")
$clockLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$clockLabel.ForeColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
$clockLabel.Size = New-Object System.Drawing.Size(100, 30)
$clockLabel.Location = New-Object System.Drawing.Point(800, 30)
$clockLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerPanel.Controls.Add($clockLabel)

# Action Buttons
$focusButton = New-Object System.Windows.Forms.Button
$focusButton.Text = "🎯 START FOCUS"
$focusButton.Size = New-Object System.Drawing.Size(140, 40)
$focusButton.Location = New-Object System.Drawing.Point(600, 30)
$focusButton.BackColor = [System.Drawing.Color]::FromArgb(59, 130, 246)
$focusButton.ForeColor = [System.Drawing.Color]::White
$focusButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$focusButton.FlatAppearance.BorderSize = 0
$focusButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$focusButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$focusButton.Add_Click({ Start-FocusSession })
$headerPanel.Controls.Add($focusButton)

$reportButton = New-Object System.Windows.Forms.Button
$reportButton.Text = "📊 GENERATE REPORT"
$reportButton.Size = New-Object System.Drawing.Size(160, 40)
$reportButton.Location = New-Object System.Drawing.Point(750, 30)
$reportButton.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$reportButton.ForeColor = [System.Drawing.Color]::White
$reportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$reportButton.FlatAppearance.BorderSize = 0
$reportButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$reportButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$reportButton.Add_Click({ Generate-Report })
$headerPanel.Controls.Add($reportButton)

$contentPanel.Controls.Add($headerPanel)

# ========== PANEL MANAGEMENT ==========
$panels = @{}

# Create all panels
$panels["Dashboard"] = Create-DashboardPanel
$panels["Activity"] = Create-ActivityPanel
$panels["Screen Time"] = Create-ScreenTimePanel
$panels["App Usage"] = Create-AppUsagePanel
$panels["Notifications"] = Create-NotificationsPanel
$panels["ParentalControls"] = Create-ParentalControlsPanel
$panels["Settings"] = Create-SettingsPanel

# Add panels to content area
foreach ($panelName in $panels.Keys) {
    $panels[$panelName].Visible = $false
    $contentPanel.Controls.Add($panels[$panelName])
}

# Show panel function
function Show-Panel {
    param([string]$panelName)
    
    foreach ($name in $panels.Keys) {
        $panels[$name].Visible = $false
    }
    
    if ($panels.ContainsKey($panelName)) {
        $panels[$panelName].Visible = $true
        $welcomeLabel.Text = $panelName.ToUpper().Replace("PARENTALCONTROLS", "PARENTAL CONTROLS")
        
        if ($panelName -eq "Dashboard") {
            Update-Charts
        }
    }
}

# Show dashboard by default
Show-Panel "Dashboard"

# ========== TIMERS ==========

# Main timer
$mainTimer = New-Object System.Windows.Forms.Timer
$mainTimer.Interval = 1000
$mainTimer.Add_Tick({
    $timerLabel.Text = (Get-Date).ToString("HH:mm:ss")
    $clockLabel.Text = (Get-Date).ToString("HH:mm:ss")
    
    # Update tracking
    Update-ScreenTimeTracking
    
    # Update stats every 3 seconds
    if ((Get-Date).Second % 3 -eq 0) {
        Update-DashboardStats
    }
    
    # Update status
    $screenTimeHours = [math]::Floor($global:totalActiveTime / 3600)
    $screenTimeMinutes = [math]::Floor(($global:totalActiveTime % 3600) / 60)
    $activityLevel = Get-UserActivityLevel
    $statusText = "$activityLevel • ${screenTimeHours}h ${screenTimeMinutes}m • $(if ($global:isTrackingEnabled) {'TRACKING ✅'} else {'TRACKING ❌'})"
    
    $color = switch ($activityLevel) {
        "Active" { [System.Drawing.Color]::LightGreen }
        "Away" { [System.Drawing.Color]::Yellow }
        "Idle" { [System.Drawing.Color]::LightGray }
        default { [System.Drawing.Color]::Gray }
    }
    
    Update-Status $statusText $color
})
$mainTimer.Start()

# Chart update timer
$chartTimer = New-Object System.Windows.Forms.Timer
$chartTimer.Interval = 30000
$chartTimer.Add_Tick({
    Update-Charts
})
$chartTimer.Start()

# Auto-save timer
$saveTimer = New-Object System.Windows.Forms.Timer
$saveTimer.Interval = 300000
$saveTimer.Add_Tick({
    if ($global:appData.Settings.AutoSaveData) {
        Save-Settings
        Update-Status "💾 Data auto-saved" ([System.Drawing.Color]::LightBlue)
    }
})
$saveTimer.Start()

# Form closing
$form.Add_FormClosing({
    $mainTimer.Stop()
    $chartTimer.Stop()
    $saveTimer.Stop()
    
    if ($global:focusTimer) {
        $global:focusTimer.Stop()
    }
    
    # Final save
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if ($global:appData.DailyStats.$today) {
        $global:appData.DailyStats.$today.TotalSeconds = $global:totalActiveTime
        $global:appData.DailyStats.$today.EndTime = (Get-Date).ToString("HH:mm:ss")
    }
    
    Save-Settings
    Update-Status "Saving data... Goodbye!" ([System.Drawing.Color]::Yellow)
})

# Show form
$form.Add_Shown({
    $form.Activate()
    Update-DashboardStats
    Update-Charts
    Update-Status "Digital Dashboard Ready • All Systems Go" ([System.Drawing.Color]::LightGreen)
    
    # Add welcome notification
    Add-Notification "Welcome to Digital Wellbeing Dashboard!" "Info"
})
[void]$form.ShowDialog()