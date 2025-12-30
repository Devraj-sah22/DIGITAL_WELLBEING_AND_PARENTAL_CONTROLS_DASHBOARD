# Digital Wellbeing & Parental Controls Dashboard - REAL TRACKING VERSION
# ACTUALLY MEASURES USER SCREEN TIME AND ACTIVITY
# Save as: DigitalWellbeing.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms.DataVisualization
[System.Windows.Forms.Application]::EnableVisualStyles()

# ========== REAL SCREEN TIME TRACKING ==========
$global:lastActiveTime = [DateTime]::Now
$global:totalActiveTime = 0
$global:currentApp = ""
$global:appUsage = @{}
$global:keyPressCount = 0
$global:mouseMoveCount = 0

function Get-CurrentApplication {
    try {
        $process = Get-Process | Where-Object { $_.MainWindowTitle -ne "" -and $_.MainWindowHandle -ne 0 } | 
                   Sort-Object WorkingSet -Descending | Select-Object -First 1
        if ($process) {
            return $process.ProcessName
        }
        return "Idle"
    }
    catch {
        return "Unknown"
    }
}

function Get-UserActivityLevel {
    # Track keyboard and mouse activity
    Add-Type @"
    using System;
    using System.Runtime.InteropServices;
    
    public class UserActivity {
        [DllImport("user32.dll")]
        public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
        
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
            return (int)(currentTime - lastInputTime) / 1000; // Convert to seconds
        }
    }
"@
    
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
            
            if ($global:appData.ActivityLog.Count -gt 100) {
                $global:appData.ActivityLog = $global:appData.ActivityLog | Select-Object -Last 50
            }
            
            $global:appData.ActivityLog += $activityEntry
        }
        
        # Update app usage
        if ($currentApp -ne "Idle" -and $currentApp -ne "Unknown") {
            if (-not $global:appUsage.ContainsKey($currentApp)) {
                $global:appUsage[$currentApp] = 0
            }
            $global:appUsage[$currentApp] += $timeDiff
        }
    }
    
    $global:lastActiveTime = $currentTime
}

# ========== GRAPH DRAWING FUNCTIONS ==========
function Draw-SimpleBarChart {
    param(
        [System.Drawing.Graphics]$graphics,
        [array]$data,
        [array]$labels,
        [int]$width,
        [int]$height,
        [System.Drawing.Color]$color
    )
    
    $graphics.Clear([System.Drawing.Color]::White)
    
    if ($data.Count -eq 0) { return }
    
    $maxValue = ($data | Measure-Object -Maximum).Maximum
    if ($maxValue -eq 0) { $maxValue = 1 }
    
    $barWidth = ($width - 100) / $data.Count
    $scale = ($height - 80) / $maxValue
    
    # Draw grid lines
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230, 230, 230), 1)
    for ($i = 0; $i -le 5; $i++) {
        $y = $height - 40 - ($i * (($height - 80) / 5))
        $graphics.DrawLine($pen, 50, $y, $width - 50, $y)
        
        $value = [math]::Round(($i * $maxValue / 5), 1)
        $graphics.DrawString("${value}h", 
            (New-Object System.Drawing.Font("Segoe UI", 8)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Gray)), 
            20, $y - 10)
    }
    
    # Draw bars
    $brush = New-Object System.Drawing.SolidBrush($color)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    
    for ($i = 0; $i -lt $data.Count; $i++) {
        $x = 50 + ($i * $barWidth) + 5
        $barHeight = $data[$i] * $scale
        $y = $height - 40 - $barHeight
        
        $graphics.FillRectangle($brush, $x, $y, $barWidth - 10, $barHeight)
        
        # Draw value on top
        $graphics.DrawString("$($data[$i])h", 
            (New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)), 
            $textBrush, 
            $x, $y - 20)
        
        # Draw label
        $graphics.DrawString($labels[$i], 
            (New-Object System.Drawing.Font("Segoe UI", 9)), 
            $textBrush, 
            $x, $height - 30)
    }
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
            
            # Initialize missing properties for backward compatibility
            if (-not $data.AppUsage) { $data | Add-Member -NotePropertyName "AppUsage" -NotePropertyValue @{} }
            if (-not $data.DailyDetailed) { $data | Add-Member -NotePropertyName "DailyDetailed" -NotePropertyValue @{} }
            
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
            AutoStart = $true
            Notifications = $true
            DarkMode = $false
            DataRetention = 30
            TrackRealTime = $true
            AlertSound = $true
            TrackApplications = $true
            TrackProductivity = $true
        }
    }
    $defaultData | ConvertTo-Json | Set-Content $dataFile
    return $defaultData
}

$global:appData = Initialize-Data

# ========== UTILITY FUNCTIONS ==========
function Update-Status {
    param(
        [string]$status,
        [System.Drawing.Color]$color = [System.Drawing.Color]::LightGreen
    )
    
    $statusLabel.Text = $status
    $statusLabel.ForeColor = $color
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
    
    # Update stats cards
    if ($statsPanel -and $statsPanel.Controls.Count -gt 0) {
        if ($statsPanel.Controls[0].Controls[0]) {
            $statsPanel.Controls[0].Controls[0].Text = "${screenTimeHours}h ${screenTimeMinutes}m"
        }
        
        # Count unique apps used today
        $appCount = ($global:appUsage.Keys | Where-Object { $_ -ne "Idle" -and $_ -ne "Unknown" }).Count
        if ($statsPanel.Controls[1].Controls[0]) {
            $statsPanel.Controls[1].Controls[0].Text = "$appCount"
        }
        
        # Calculate productivity score
        $productiveApps = @("OUTLOOK", "EXCEL", "WORD", "POWERPNT", "CODE", "DEVENV", "CHROME", "EDGE", "FIREFOX")
        $productiveTime = 0
        $totalTime = $global:totalActiveTime
        
        foreach ($app in $global:appUsage.Keys) {
            if ($productiveApps -contains $app.ToUpper()) {
                $productiveTime += $global:appUsage[$app]
            }
        }
        
        $productivityScore = if ($totalTime -gt 0) { [math]::Round(($productiveTime / $totalTime) * 100) } else { 0 }
        
        if ($statsPanel.Controls[2].Controls[0]) {
            $statsPanel.Controls[2].Controls[0].Text = "$productivityScore%"
        }
        
        # Current activity
        $currentActivity = if ($global:currentApp -eq "Idle") { "Idle" } else { $global:currentApp }
        if ($statsPanel.Controls[3].Controls[0]) {
            $statsPanel.Controls[3].Controls[0].Text = $currentActivity
        }
    }
}

function Update-Charts {
    # Update weekly chart with real data
    if ($weeklyChartBox -and $weeklyChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($weeklyChartBox.Width, $weeklyChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Get last 7 days data
        $weeklyData = @()
        $weeklyLabels = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
            if ($global:appData.DailyStats.$date) {
                $hours = [math]::Round($global:appData.DailyStats.$date.TotalSeconds / 3600, 1)
                $weeklyData += $hours
            } else {
                $weeklyData += 0
            }
        }
        
        Draw-SimpleBarChart $graphics $weeklyData $weeklyLabels $weeklyChartBox.Width $weeklyChartBox.Height ([System.Drawing.Color]::FromArgb(79, 70, 229))
        
        $weeklyChartBox.Image = $bitmap
    }
    
    # Update app usage chart
    if ($appChartBox -and $appChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($appChartBox.Width, $appChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Get top 5 apps by usage
        $topApps = $global:appUsage.GetEnumerator() | 
                   Where-Object { $_.Key -ne "Idle" -and $_.Key -ne "Unknown" } |
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
            
            Draw-SimpleBarChart $graphics $appData $appLabels $appChartBox.Width $appChartBox.Height ([System.Drawing.Color]::FromArgb(16, 185, 129))
        } else {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.DrawString("No app data yet", 
                (New-Object System.Drawing.Font("Segoe UI", 12)), 
                (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Gray)), 
                150, 100)
        }
        
        $appChartBox.Image = $bitmap
    }
}

function Get-DetailedActivityReport {
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $report = @"
DIGITAL WELLBEING DETAILED REPORT
Generated: $(Get-Date)
=======================================

SUMMARY:
• Total Screen Time: $([math]::Floor($global:totalActiveTime / 3600))h $([math]::Floor(($global:totalActiveTime % 3600) / 60))m
• Active Applications: $(($global:appUsage.Keys | Where-Object { $_ -ne "Idle" -and $_ -ne "Unknown" }).Count)
• Current Status: $(if ($global:currentApp -eq "Idle") { "Idle/Away" } else { "Using $global:currentApp" })

APPLICATION USAGE:
"@
    
    $topApps = $global:appUsage.GetEnumerator() | 
               Where-Object { $_.Key -ne "Idle" -and $_.Key -ne "Unknown" } |
               Sort-Object Value -Descending
    
    foreach ($app in $topApps) {
        $hours = [math]::Floor($app.Value / 3600)
        $minutes = [math]::Floor(($app.Value % 3600) / 60)
        $percentage = if ($global:totalActiveTime -gt 0) { [math]::Round(($app.Value / $global:totalActiveTime) * 100) } else { 0 }
        $report += "`n• $($app.Key): ${hours}h ${minutes}m ($percentage%)"
    }
    
    $report += @"

ACTIVITY LOG (Last 10 entries):
"@
    
    $recentActivities = $global:appData.ActivityLog | Select-Object -Last 10
    foreach ($activity in $recentActivities) {
        $report += "`n• $($activity.Timestamp) - $($activity.Application) ($($activity.Type))"
    }
    
    $report += @"

RECOMMENDATIONS:
"@
    
    if ($global:totalActiveTime -gt 8 * 3600) {
        $report += "`n• ⚠️  High screen time detected (>8h). Consider taking more breaks."
    }
    
    $idleApps = $global:appUsage.GetEnumerator() | Where-Object { $_.Key -eq "Idle" }
    if ($idleApps.Value -gt 0) {
        $idlePercentage = [math]::Round(($idleApps.Value / $global:totalActiveTime) * 100)
        if ($idlePercentage -gt 30) {
            $report += "`n• ⏰ You were idle for ${idlePercentage}% of the time. Try to be more productive!"
        }
    }
    
    return $report
}

# ========== PREMIUM FEATURES FUNCTIONS ==========
function Start-FocusSession {
    Update-Status "Focus Mode Activated for 25 minutes" ([System.Drawing.Color]::Orange)
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
            Update-Status "Focus session completed!" ([System.Drawing.Color]::LightGreen)
            [System.Windows.Forms.MessageBox]::Show("Focus session completed! Time for a break.", "Wellbeing Alert", "OK", "Information")
        }
    })
    $focusTimer.Start()
    $global:focusTimer = $focusTimer
}

function Generate-Report {
    $report = Get-DetailedActivityReport
    $reportPath = "$env:USERPROFILE\Desktop\Wellbeing_Report_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Update-Status "Report saved to Desktop" ([System.Drawing.Color]::LightBlue)
    [System.Windows.Forms.MessageBox]::Show("Detailed report saved to:`n$reportPath", "Report Generated", "OK", "Information")
}

# ========== MAIN FORM ==========
$form = New-Object System.Windows.Forms.Form
$form.Text = "Digital Wellbeing & Parental Controls - REAL TRACKING"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# ========== SIDEBAR ==========
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(220, 800)
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
$sidebar.Dock = [System.Windows.Forms.DockStyle]::Left
$form.Controls.Add($sidebar)

# Logo Panel
$logoPanel = New-Object System.Windows.Forms.Panel
$logoPanel.Size = New-Object System.Drawing.Size(220, 100)
$logoPanel.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
$logoPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$sidebar.Controls.Add($logoPanel)

$logoLabel = New-Object System.Windows.Forms.Label
$logoLabel.Text = "DIGITAL`nWELLBEING`nTRACKER"
$logoLabel.ForeColor = [System.Drawing.Color]::White
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$logoLabel.Size = New-Object System.Drawing.Size(200, 80)
$logoLabel.Location = New-Object System.Drawing.Point(10, 10)
$logoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$logoPanel.Controls.Add($logoLabel)

# Sidebar Buttons
$buttonTitles = @("Dashboard", "Real-time Activity", "Screen Time", "App Usage", "Reports", "Settings")

for ($i = 0; $i -lt $buttonTitles.Length; $i++) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = "  " + $buttonTitles[$i]
    $button.Size = New-Object System.Drawing.Size(200, 45)
    $button.Location = New-Object System.Drawing.Point(10, (120 + ($i * 55)))
    $button.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 70)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.Padding = New-Object System.Windows.Forms.Padding(15, 0, 0, 0)
    $button.Tag = $buttonTitles[$i]
    $button.Add_Click({
        Show-Panel $this.Tag
    })
    $sidebar.Controls.Add($button)
}

# Status Panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(220, 100)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 60)
$statusPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$sidebar.Controls.Add($statusPanel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Initializing tracking..."
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

# Header with Action Buttons
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(940, 100)
$headerPanel.Location = New-Object System.Drawing.Point(20, 20)
$headerPanel.BackColor = [System.Drawing.Color]::White

$welcomeLabel = New-Object System.Windows.Forms.Label
$welcomeLabel.Text = "Real-time Screen Time Tracker"
$welcomeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$welcomeLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
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

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = (Get-Date).ToString("HH:mm:ss")
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$timeLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
$timeLabel.Size = New-Object System.Drawing.Size(100, 30)
$timeLabel.Location = New-Object System.Drawing.Point(800, 30)
$timeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerPanel.Controls.Add($timeLabel)

# Action Buttons
$focusButton = New-Object System.Windows.Forms.Button
$focusButton.Text = "🎯 Start Focus"
$focusButton.Size = New-Object System.Drawing.Size(120, 35)
$focusButton.Location = New-Object System.Drawing.Point(600, 30)
$focusButton.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
$focusButton.ForeColor = [System.Drawing.Color]::White
$focusButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$focusButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$focusButton.Add_Click({ Start-FocusSession })
$headerPanel.Controls.Add($focusButton)

$reportButton = New-Object System.Windows.Forms.Button
$reportButton.Text = "📊 Generate Report"
$reportButton.Size = New-Object System.Drawing.Size(140, 35)
$reportButton.Location = New-Object System.Drawing.Point(730, 30)
$reportButton.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
$reportButton.ForeColor = [System.Drawing.Color]::White
$reportButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$reportButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$reportButton.Add_Click({ Generate-Report })
$headerPanel.Controls.Add($reportButton)

$contentPanel.Controls.Add($headerPanel)

# ========== PANEL MANAGEMENT ==========
$panels = @{}
$global:statsPanel = $null
$global:weeklyChartBox = $null
$global:appChartBox = $null

function Create-DashboardPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "DashboardPanel"
    
    # Stats Cards
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(940, 150)
    $statsPanel.Location = New-Object System.Drawing.Point(0, 0)
    
    $cards = @(
        @{Title="SCREEN TIME TODAY"; Value="0h 0m"; Color="#4F46E5"; Desc="Active time"},
        @{Title="APPS USED"; Value="0"; Color="#10B981"; Desc="Unique applications"},
        @{Title="PRODUCTIVITY"; Value="0%"; Color="#F59E0B"; Desc="Productive time"},
        @{Title="CURRENT ACTIVITY"; Value="Idle"; Color="#EF4444"; Desc="Now using"}
    )
    
    for ($i = 0; $i -lt $cards.Length; $i++) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(220, 140)
        $card.Location = New-Object System.Drawing.Point(($i * 240), 0)
        $card.BackColor = [System.Drawing.Color]::White
        
        $valueLabel = New-Object System.Windows.Forms.Label
        $valueLabel.Text = $cards[$i].Value
        $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
        $valueLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
        $valueLabel.Size = New-Object System.Drawing.Size(200, 60)
        $valueLabel.Location = New-Object System.Drawing.Point(20, 30)
        $card.Controls.Add($valueLabel)
        
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = $cards[$i].Title
        $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $titleLabel.ForeColor = [System.Drawing.Color]::Gray
        $titleLabel.Size = New-Object System.Drawing.Size(200, 25)
        $titleLabel.Location = New-Object System.Drawing.Point(20, 100)
        $card.Controls.Add($titleLabel)
        
        $statsPanel.Controls.Add($card)
    }
    $global:statsPanel = $statsPanel
    $panel.Controls.Add($statsPanel)
    
    # Charts Area
    $chartsPanel = New-Object System.Windows.Forms.Panel
    $chartsPanel.Size = New-Object System.Drawing.Size(940, 300)
    $chartsPanel.Location = New-Object System.Drawing.Point(0, 170)
    
    # Weekly Chart
    $weeklyChartPanel = New-Object System.Windows.Forms.Panel
    $weeklyChartPanel.Size = New-Object System.Drawing.Size(460, 280)
    $weeklyChartPanel.Location = New-Object System.Drawing.Point(0, 0)
    $weeklyChartPanel.BackColor = [System.Drawing.Color]::White
    
    $weeklyChartTitle = New-Object System.Windows.Forms.Label
    $weeklyChartTitle.Text = "Weekly Screen Time"
    $weeklyChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $weeklyChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $weeklyChartTitle.Location = New-Object System.Drawing.Point(20, 20)
    $weeklyChartPanel.Controls.Add($weeklyChartTitle)
    
    $weeklyChartBox = New-Object System.Windows.Forms.PictureBox
    $weeklyChartBox.Size = New-Object System.Drawing.Size(420, 200)
    $weeklyChartBox.Location = New-Object System.Drawing.Point(20, 60)
    $weeklyChartBox.BackColor = [System.Drawing.Color]::White
    $global:weeklyChartBox = $weeklyChartBox
    $weeklyChartPanel.Controls.Add($weeklyChartBox)
    $chartsPanel.Controls.Add($weeklyChartPanel)
    
    # App Usage Chart
    $appChartPanel = New-Object System.Windows.Forms.Panel
    $appChartPanel.Size = New-Object System.Drawing.Size(460, 280)
    $appChartPanel.Location = New-Object System.Drawing.Point(480, 0)
    $appChartPanel.BackColor = [System.Drawing.Color]::White
    
    $appChartTitle = New-Object System.Windows.Forms.Label
    $appChartTitle.Text = "Top Applications"
    $appChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $appChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $appChartTitle.Location = New-Object System.Drawing.Point(20, 20)
    $appChartPanel.Controls.Add($appChartTitle)
    
    $appChartBox = New-Object System.Windows.Forms.PictureBox
    $appChartBox.Size = New-Object System.Drawing.Size(420, 200)
    $appChartBox.Location = New-Object System.Drawing.Point(20, 60)
    $appChartBox.BackColor = [System.Drawing.Color]::White
    $global:appChartBox = $appChartBox
    $appChartPanel.Controls.Add($appChartBox)
    $chartsPanel.Controls.Add($appChartPanel)
    
    $panel.Controls.Add($chartsPanel)
    
    # Real-time Activity Feed
    $activityPanel = New-Object System.Windows.Forms.Panel
    $activityPanel.Size = New-Object System.Drawing.Size(940, 180)
    $activityPanel.Location = New-Object System.Drawing.Point(0, 480)
    $activityPanel.BackColor = [System.Drawing.Color]::White
    
    $activityTitle = New-Object System.Windows.Forms.Label
    $activityTitle.Text = "🔄 Real-time Activity"
    $activityTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $activityTitle.Size = New-Object System.Drawing.Size(300, 30)
    $activityTitle.Location = New-Object System.Drawing.Point(20, 20)
    $activityPanel.Controls.Add($activityTitle)
    
    $activityList = New-Object System.Windows.Forms.ListBox
    $activityList.Size = New-Object System.Drawing.Size(900, 130)
    $activityList.Location = New-Object System.Drawing.Point(20, 60)
    $activityList.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $activityList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $activityList.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 255)
    $activityPanel.Controls.Add($activityList)
    
    $panel.Controls.Add($activityPanel)
    
    return $panel
}

function Create-RealtimeActivityPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "Real-time ActivityPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "📊 Real-time Activity Monitor"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    $activityPanel = New-Object System.Windows.Forms.Panel
    $activityPanel.Size = New-Object System.Drawing.Size(900, 580)
    $activityPanel.Location = New-Object System.Drawing.Point(30, 90)
    $activityPanel.BackColor = [System.Drawing.Color]::White
    
    # Current Activity
    $currentLabel = New-Object System.Windows.Forms.Label
    $currentLabel.Text = "Current Application:"
    $currentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $currentLabel.Size = New-Object System.Drawing.Size(250, 30)
    $currentLabel.Location = New-Object System.Drawing.Point(30, 30)
    $activityPanel.Controls.Add($currentLabel)
    
    $currentAppLabel = New-Object System.Windows.Forms.Label
    $currentAppLabel.Text = "Detecting..."
    $currentAppLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $currentAppLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $currentAppLabel.Size = New-Object System.Drawing.Size(400, 40)
    $currentAppLabel.Location = New-Object System.Drawing.Point(300, 30)
    $activityPanel.Controls.Add($currentAppLabel)
    
    # Activity Status
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = "Activity Status:"
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $statusLabel.Size = New-Object System.Drawing.Size(250, 30)
    $statusLabel.Location = New-Object System.Drawing.Point(30, 80)
    $activityPanel.Controls.Add($statusLabel)
    
    $activityStatusLabel = New-Object System.Windows.Forms.Label
    $activityStatusLabel.Text = "Checking..."
    $activityStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $activityStatusLabel.ForeColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
    $activityStatusLabel.Size = New-Object System.Drawing.Size(400, 40)
    $activityStatusLabel.Location = New-Object System.Drawing.Point(300, 80)
    $activityPanel.Controls.Add($activityStatusLabel)
    
    # Session Time
    $sessionLabel = New-Object System.Windows.Forms.Label
    $sessionLabel.Text = "Current Session:"
    $sessionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $sessionLabel.Size = New-Object System.Drawing.Size(250, 30)
    $sessionLabel.Location = New-Object System.Drawing.Point(30, 130)
    $activityPanel.Controls.Add($sessionLabel)
    
    $sessionTimeLabel = New-Object System.Windows.Forms.Label
    $sessionTimeLabel.Text = "0h 0m"
    $sessionTimeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $sessionTimeLabel.ForeColor = [System.Drawing.Color]::FromArgb(245, 158, 11)
    $sessionTimeLabel.Size = New-Object System.Drawing.Size(400, 40)
    $sessionTimeLabel.Location = New-Object System.Drawing.Point(300, 130)
    $activityPanel.Controls.Add($sessionTimeLabel)
    
    # Recent Activity Log
    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "Recent Activity Log:"
    $logLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $logLabel.Size = New-Object System.Drawing.Size(250, 30)
    $logLabel.Location = New-Object System.Drawing.Point(30, 180)
    $activityPanel.Controls.Add($logLabel)
    
    $activityLogList = New-Object System.Windows.Forms.ListBox
    $activityLogList.Size = New-Object System.Drawing.Size(800, 300)
    $activityLogList.Location = New-Object System.Drawing.Point(30, 220)
    $activityLogList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    $panel.Controls.Add($activityPanel)
    
    return $panel
}

# Create other panels (simplified versions)
function Create-ScreenTimePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ScreenTimePanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "📱 Detailed Screen Time"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $statsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $statsPanel.BackColor = [System.Drawing.Color]::White
    
    $stats = @(
        "Today's Total: Calculating...",
        "Weekly Average: Calculating...",
        "Most Used App: Detecting...",
        "Productive Time: Calculating...",
        "Idle Time: Calculating..."
    )
    
    for ($i = 0; $i -lt $stats.Count; $i++) {
        $statLabel = New-Object System.Windows.Forms.Label
        $statLabel.Text = $stats[$i]
        $statLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
        $statLabel.Size = New-Object System.Drawing.Size(800, 40)
        $statLabel.Location = New-Object System.Drawing.Point(30, (30 + ($i * 50)))
        $statsPanel.Controls.Add($statLabel)
    }
    
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
    $titleLabel.Text = "📊 Application Usage Details"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    $usagePanel = New-Object System.Windows.Forms.Panel
    $usagePanel.Size = New-Object System.Drawing.Size(900, 580)
    $usagePanel.Location = New-Object System.Drawing.Point(30, 90)
    $usagePanel.BackColor = [System.Drawing.Color]::White
    
    $appList = New-Object System.Windows.Forms.ListBox
    $appList.Size = New-Object System.Drawing.Size(800, 500)
    $appList.Location = New-Object System.Drawing.Point(30, 30)
    $appList.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $usagePanel.Controls.Add($appList)
    
    $panel.Controls.Add($usagePanel)
    
    return $panel
}

function Create-SettingsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "SettingsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "⚙️ Settings"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    $settingsPanel = New-Object System.Windows.Forms.Panel
    $settingsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $settingsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $settingsPanel.BackColor = [System.Drawing.Color]::White
    
    $settings = @(
        "Real-time Tracking: Enabled",
        "Track Applications: Enabled",
        "Track Productivity: Enabled",
        "Auto-save Data: Every 5 minutes",
        "Generate Daily Reports: Enabled",
        "Show Notifications: Enabled"
    )
    
    for ($i = 0; $i -lt $settings.Count; $i++) {
        $settingLabel = New-Object System.Windows.Forms.Label
        $settingLabel.Text = $settings[$i]
        $settingLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
        $settingLabel.Size = New-Object System.Drawing.Size(800, 40)
        $settingLabel.Location = New-Object System.Drawing.Point(30, (30 + ($i * 50)))
        $settingsPanel.Controls.Add($settingLabel)
    }
    
    $panel.Controls.Add($settingsPanel)
    
    return $panel
}

# Create all panels
$panels["Dashboard"] = Create-DashboardPanel
$panels["Real-time Activity"] = Create-RealtimeActivityPanel
$panels["Screen Time"] = Create-ScreenTimePanel
$panels["App Usage"] = Create-AppUsagePanel
$panels["Reports"] = Create-SimplePanel "Reports"
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
        $welcomeLabel.Text = $panelName
    }
}

# Show dashboard by default
Show-Panel "Dashboard"

# ========== REAL-TIME TRACKING TIMERS ==========

# Clock timer
$clockTimer = New-Object System.Windows.Forms.Timer
$clockTimer.Interval = 1000
$clockTimer.Add_Tick({
    $timeLabel.Text = (Get-Date).ToString("HH:mm:ss")
    
    # Update screen time tracking
    Update-ScreenTimeTracking
    
    # Update dashboard stats
    Update-DashboardStats
    
    # Update status with real data
    $screenTimeHours = [math]::Floor($global:totalActiveTime / 3600)
    $screenTimeMinutes = [math]::Floor(($global:totalActiveTime % 3600) / 60)
    
    $activityLevel = Get-UserActivityLevel
    $statusText = "$activityLevel • $screenTimeHours" + "h $screenTimeMinutes" + "m • $global:currentApp"
    
    if ($activityLevel -eq "Active") {
        Update-Status $statusText ([System.Drawing.Color]::LightGreen)
    } elseif ($activityLevel -eq "Away") {
        Update-Status $statusText ([System.Drawing.Color]::Yellow)
    } else {
        Update-Status $statusText ([System.Drawing.Color]::LightGray)
    }
})
$clockTimer.Start()

# Auto-save timer (every 5 minutes)
$saveTimer = New-Object System.Windows.Forms.Timer
$saveTimer.Interval = 300000
$saveTimer.Add_Tick({
    $today = (Get-Date).ToString("yyyy-MM-dd")
    
    # Save app usage data
    $global:appData.AppUsage = @{}
    foreach ($app in $global:appUsage.Keys) {
        $global:appData.AppUsage[$app] = $global:appUsage[$app]
    }
    
    # Save detailed daily data
    if (-not $global:appData.DailyDetailed.$today) {
        $global:appData.DailyDetailed.$today = @{}
    }
    
    $global:appData.DailyDetailed.$today.LastUpdate = (Get-Date).ToString("HH:mm:ss")
    $global:appData.DailyDetailed.$today.TotalSeconds = $global:totalActiveTime
    $global:appData.DailyDetailed.$today.AppUsage = $global:appUsage
    
    # Save to file
    $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
    Update-Status "Data auto-saved" ([System.Drawing.Color]::LightBlue)
})
$saveTimer.Start()

# Chart update timer (every 30 seconds)
$chartTimer = New-Object System.Windows.Forms.Timer
$chartTimer.Interval = 30000
$chartTimer.Add_Tick({
    Update-Charts
})
$chartTimer.Start()

# Set initial status
Update-Status "Starting real-time tracking..." ([System.Drawing.Color]::LightGreen)

# Initial chart drawing
Update-Charts

# Form closing event
$form.Add_FormClosing({
    $clockTimer.Stop()
    $saveTimer.Stop()
    $chartTimer.Stop()
    
    # Final save
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $global:appData.DailyStats.$today.TotalSeconds = $global:totalActiveTime
    $global:appData.DailyStats.$today.EndTime = (Get-Date).ToString("HH:mm:ss")
    $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
    
    Update-Status "Shutting down..." ([System.Drawing.Color]::Yellow)
})

# Show the form
$form.Add_Shown({
    $form.Activate()
    Update-Charts
    Update-Status "Real-time tracking active" ([System.Drawing.Color]::LightGreen)
})
[void]$form.ShowDialog()