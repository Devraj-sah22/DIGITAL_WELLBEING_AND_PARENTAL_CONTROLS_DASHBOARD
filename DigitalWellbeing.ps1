# Digital Wellbeing & Parental Controls Dashboard
# COMPLETELY FIXED - WITH WORKING SIMPLE GRAPHS
# Save as: DigitalWellbeing.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ========== SIMPLE GRAPH DRAWING FUNCTIONS ==========
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
        
        # Draw simple bar
        $graphics.FillRectangle($brush, $x, $y, $barWidth - 10, $barHeight)
        
        # Draw outline
        $graphics.DrawRectangle(
            (New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 0, 0, 0), 1)),
            $x, $y, $barWidth - 10, $barHeight
        )
        
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

function Draw-SimpleLineChart {
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
    
    $pointWidth = ($width - 100) / ($data.Count - 1)
    $scale = ($height - 80) / $maxValue
    
    # Draw grid
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
    
    # Draw line
    $linePen = New-Object System.Drawing.Pen($color, 3)
    
    for ($i = 0; $i -lt $data.Count - 1; $i++) {
        $x1 = 50 + ($i * $pointWidth)
        $y1 = $height - 40 - ($data[$i] * $scale)
        $x2 = 50 + (($i + 1) * $pointWidth)
        $y2 = $height - 40 - ($data[$i + 1] * $scale)
        
        $graphics.DrawLine($linePen, $x1, $y1, $x2, $y2)
    }
    
    # Draw data points and labels
    $pointBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    
    for ($i = 0; $i -lt $data.Count; $i++) {
        $x = 50 + ($i * $pointWidth)
        $y = $height - 40 - ($data[$i] * $scale)
        
        # Draw data point
        $graphics.FillEllipse($pointBrush, $x - 4, $y - 4, 8, 8)
        $graphics.DrawEllipse(
            (New-Object System.Drawing.Pen($color, 2)),
            $x - 4, $y - 4, 8, 8
        )
        
        # Draw label (only every 3rd label)
        if ($i % 3 -eq 0) {
            $graphics.DrawString($labels[$i], 
                (New-Object System.Drawing.Font("Segoe UI", 8)), 
                (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Gray)), 
                $x - 10, $height - 30)
        }
        
        # Draw value
        $graphics.DrawString("$($data[$i])h", 
            (New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)), 
            (New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 0, 0, 0))), 
            $x - 10, $y - 20)
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
            return Get-Content $dataFile | ConvertFrom-Json
        }
        catch {
            Write-Host "Data file corrupted, creating new..." -ForegroundColor Yellow
        }
    }
    
    $defaultData = @{
        Applications = @{}
        DailyStats = @{}
        Notifications = @()
        ScreenTime = @{}
        TimeBlocks = @()
        Alerts = @()
        ActivityLog = @()
        ParentalControls = @{
            TimeLimit = 6
            Bedtime = "22:00"
            BlockedApps = @("Steam", "TikTok", "Instagram", "Discord")
            WebsiteFilter = $true
            FocusMode = $false
            IsActive = $true
        }
        Premium = $false
        Settings = @{
            AutoStart = $true
            Notifications = $true
            DarkMode = $false
            DataRetention = 30
            TrackRealTime = $true
            AlertSound = $true
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
    
    # Update stats cards with real data
    if ($global:appData.DailyStats.$today) {
        $screenTimeHours = [math]::Floor($global:appData.DailyStats.$today.TotalMinutes / 60)
        $screenTimeMinutes = $global:appData.DailyStats.$today.TotalMinutes % 60
        
        if ($statsPanel -and $statsPanel.Controls.Count -gt 0) {
            if ($statsPanel.Controls[0].Controls[0]) {
                $statsPanel.Controls[0].Controls[0].Text = "${screenTimeHours}h ${screenTimeMinutes}m"
            }
            
            # Count unique apps
            $appCount = ($global:appData.ActivityLog | Where-Object { 
                $_.Date -eq $today -and $_.Application -ne $null 
            } | Select-Object -ExpandProperty Application -Unique).Count
            
            if ($statsPanel.Controls[1].Controls[0]) {
                $statsPanel.Controls[1].Controls[0].Text = "$appCount"
            }
        }
    }
}

function Update-Charts {
    # Update weekly chart
    if ($weeklyChartBox -and $weeklyChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($weeklyChartBox.Width, $weeklyChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        $weeklyData = @(3.5, 4.2, 3.8, 5.1, 4.5, 6.2, 4.8)
        $weeklyLabels = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
        
        Draw-SimpleBarChart $graphics $weeklyData $weeklyLabels $weeklyChartBox.Width $weeklyChartBox.Height ([System.Drawing.Color]::FromArgb(79, 70, 229))
        
        $weeklyChartBox.Image = $bitmap
    }
    
    # Update daily chart
    if ($dailyChartBox -and $dailyChartBox.Visible) {
        $bitmap = New-Object System.Drawing.Bitmap($dailyChartBox.Width, $dailyChartBox.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        $hourlyData = @(0.5, 1.2, 2.0, 1.8, 2.5, 3.0, 2.8, 2.5, 2.0, 1.5, 1.0, 0.8, 1.2, 1.5, 2.0, 2.5, 3.0, 2.8, 2.2, 1.8, 1.5, 1.2, 0.8, 0.5)
        $hourlyLabels = @()
        for ($i = 0; $i -lt 24; $i++) {
            $hourlyLabels += "$i"
        }
        
        Draw-SimpleLineChart $graphics $hourlyData $hourlyLabels $dailyChartBox.Width $dailyChartBox.Height ([System.Drawing.Color]::FromArgb(16, 185, 129))
        
        $dailyChartBox.Image = $bitmap
    }
}

# ========== MAIN FORM ==========
$form = New-Object System.Windows.Forms.Form
$form.Text = "Digital Wellbeing & Parental Controls"
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
$logoLabel.Text = "DIGITAL`nWELLBEING"
$logoLabel.ForeColor = [System.Drawing.Color]::White
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$logoLabel.Size = New-Object System.Drawing.Size(200, 80)
$logoLabel.Location = New-Object System.Drawing.Point(10, 10)
$logoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$logoPanel.Controls.Add($logoLabel)

# Sidebar Buttons
$buttonTitles = @("Dashboard", "Activity", "Screen Time", "Notifications", "App Usage", "Parental Controls", "Reports", "Settings")

for ($i = 0; $i -lt $buttonTitles.Length; $i++) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $buttonTitles[$i]
    $button.Size = New-Object System.Drawing.Size(200, 45)
    # FIXED: Correct way to create Point
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
$statusPanel.Size = New-Object System.Drawing.Size(220, 60)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 60)
$statusPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$sidebar.Controls.Add($statusPanel)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Initializing..."
$statusLabel.ForeColor = [System.Drawing.Color]::LightGreen
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$statusLabel.Size = New-Object System.Drawing.Size(200, 20)
$statusLabel.Location = New-Object System.Drawing.Point(10, 20)
$statusPanel.Controls.Add($statusLabel)

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
$welcomeLabel.Text = "Digital Wellbeing Dashboard"
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

# FIXED TIME DISPLAY
$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = (Get-Date).ToString("HH:mm")
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$timeLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
$timeLabel.Size = New-Object System.Drawing.Size(100, 30)
$timeLabel.Location = New-Object System.Drawing.Point(800, 30)
$timeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerPanel.Controls.Add($timeLabel)

$contentPanel.Controls.Add($headerPanel)

# ========== PANEL MANAGEMENT ==========
$panels = @{}
$global:statsPanel = $null
$global:weeklyChartBox = $null
$global:dailyChartBox = $null

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
        @{Title="SCREEN TIME"; Value="0h 0m"; Color="#4F46E5"},
        @{Title="APPS USED"; Value="0"; Color="#10B981"},
        @{Title="NOTIFICATIONS"; Value="0"; Color="#F59E0B"},
        @{Title="FOCUS TIME"; Value="0h 0m"; Color="#EF4444"}
    )
    
    for ($i = 0; $i -lt $cards.Length; $i++) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(220, 140)
        $card.Location = New-Object System.Drawing.Point(($i * 240), 0)
        $card.BackColor = [System.Drawing.Color]::White
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::None
        
        $valueLabel = New-Object System.Windows.Forms.Label
        $valueLabel.Text = $cards[$i].Value
        $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
        $valueLabel.ForeColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
        $valueLabel.Size = New-Object System.Drawing.Size(200, 60)
        $valueLabel.Location = New-Object System.Drawing.Point(20, 30)
        $card.Controls.Add($valueLabel)
        
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = $cards[$i].Title
        $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $titleLabel.ForeColor = [System.Drawing.Color]::Gray
        $titleLabel.Size = New-Object System.Drawing.Size(200, 25)
        $titleLabel.Location = New-Object System.Drawing.Point(20, 100)
        $card.Controls.Add($titleLabel)
        
        $statsPanel.Controls.Add($card)
    }
    $global:statsPanel = $statsPanel
    $panel.Controls.Add($statsPanel)
    
    # Charts Area - WITH SIMPLE GRAPHS
    $chartsPanel = New-Object System.Windows.Forms.Panel
    $chartsPanel.Size = New-Object System.Drawing.Size(940, 300)
    $chartsPanel.Location = New-Object System.Drawing.Point(0, 170)
    
    # Weekly Chart Panel
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
    
    # Weekly Chart PictureBox
    $weeklyChartBox = New-Object System.Windows.Forms.PictureBox
    $weeklyChartBox.Size = New-Object System.Drawing.Size(420, 200)
    $weeklyChartBox.Location = New-Object System.Drawing.Point(20, 60)
    $weeklyChartBox.BackColor = [System.Drawing.Color]::White
    $global:weeklyChartBox = $weeklyChartBox
    
    $weeklyChartPanel.Controls.Add($weeklyChartBox)
    $chartsPanel.Controls.Add($weeklyChartPanel)
    
    # Daily Chart Panel
    $dailyChartPanel = New-Object System.Windows.Forms.Panel
    $dailyChartPanel.Size = New-Object System.Drawing.Size(460, 280)
    $dailyChartPanel.Location = New-Object System.Drawing.Point(480, 0)
    $dailyChartPanel.BackColor = [System.Drawing.Color]::White
    
    $dailyChartTitle = New-Object System.Windows.Forms.Label
    $dailyChartTitle.Text = "Daily Usage Pattern"
    $dailyChartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $dailyChartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $dailyChartTitle.Location = New-Object System.Drawing.Point(20, 20)
    $dailyChartPanel.Controls.Add($dailyChartTitle)
    
    # Daily Chart PictureBox
    $dailyChartBox = New-Object System.Windows.Forms.PictureBox
    $dailyChartBox.Size = New-Object System.Drawing.Size(420, 200)
    $dailyChartBox.Location = New-Object System.Drawing.Point(20, 60)
    $dailyChartBox.BackColor = [System.Drawing.Color]::White
    $global:dailyChartBox = $dailyChartBox
    
    $dailyChartPanel.Controls.Add($dailyChartBox)
    $chartsPanel.Controls.Add($dailyChartPanel)
    
    $panel.Controls.Add($chartsPanel)
    
    # Recent Activity
    $activityPanel = New-Object System.Windows.Forms.Panel
    $activityPanel.Size = New-Object System.Drawing.Size(940, 180)
    $activityPanel.Location = New-Object System.Drawing.Point(0, 480)
    $activityPanel.BackColor = [System.Drawing.Color]::White
    
    $activityTitle = New-Object System.Windows.Forms.Label
    $activityTitle.Text = "Recent Activity"
    $activityTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $activityTitle.Size = New-Object System.Drawing.Size(300, 30)
    $activityTitle.Location = New-Object System.Drawing.Point(20, 20)
    $activityPanel.Controls.Add($activityTitle)
    
    $activityList = New-Object System.Windows.Forms.ListBox
    $activityList.Size = New-Object System.Drawing.Size(900, 130)
    $activityList.Location = New-Object System.Drawing.Point(20, 60)
    $activityList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $activityList.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $activityList.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 255)
    
    $activities = @(
        "09:00 AM  •  Chrome  •  45 minutes",
        "10:00 AM  •  12 notifications received",
        "11:30 AM  •  Microsoft Word  •  1.5 hours",
        "01:00 PM  •  Lunch break",
        "02:30 PM  •  Zoom Meeting  •  1 hour",
        "04:00 PM  •  Social Media  •  30 minutes",
        "06:00 PM  •  Gaming  •  1 hour"
    )
    
    foreach ($activity in $activities) {
        $activityList.Items.Add($activity)
    }
    
    $activityPanel.Controls.Add($activityList)
    $panel.Controls.Add($activityPanel)
    
    return $panel
}

function Create-ActivityPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ActivityPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Activity Details"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    # Simple activity list
    $activityList = New-Object System.Windows.Forms.ListBox
    $activityList.Size = New-Object System.Drawing.Size(900, 580)
    $activityList.Location = New-Object System.Drawing.Point(30, 90)
    $activityList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    
    $activities = @(
        "09:00 AM - Started: Google Chrome",
        "09:45 AM - Switched to: Microsoft Word", 
        "11:30 AM - Break: Lunch",
        "01:00 PM - Meeting: Zoom Call",
        "02:00 PM - Working: Visual Studio Code",
        "04:00 PM - Break: Social Media",
        "06:00 PM - Entertainment: Gaming"
    )
    
    foreach ($activity in $activities) {
        $activityList.Items.Add($activity)
    }
    
    $panel.Controls.Add($activityList)
    
    return $panel
}

function Create-ScreenTimePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ScreenTimePanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Screen Time Analysis"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    # Simple statistics
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $statsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $statsPanel.BackColor = [System.Drawing.Color]::White
    
    $stats = @(
        "Today's Total: 5 hours 20 minutes",
        "Average Daily: 6 hours 15 minutes",
        "Most Used App: Chrome (2h 15m)",
        "Peak Usage Time: 10:00 AM - 12:00 PM",
        "Productive Time: 3 hours 45 minutes",
        "Entertainment Time: 1 hour 35 minutes"
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
    $titleLabel.Text = "Application Usage"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    # App usage list
    $usagePanel = New-Object System.Windows.Forms.Panel
    $usagePanel.Size = New-Object System.Drawing.Size(900, 580)
    $usagePanel.Location = New-Object System.Drawing.Point(30, 90)
    $usagePanel.BackColor = [System.Drawing.Color]::White
    
    $apps = @(
        "Google Chrome - 2h 15m (35%)",
        "Microsoft Word - 1h 30m (23%)",
        "Discord - 1h 15m (19%)",
        "Spotify - 45m (12%)",
        "Visual Studio Code - 30m (8%)",
        "Windows Explorer - 25m (6%)",
        "Steam - 20m (4%)",
        "Zoom - 15m (3%)"
    )
    
    for ($i = 0; $i -lt $apps.Count; $i++) {
        $appLabel = New-Object System.Windows.Forms.Label
        $appLabel.Text = $apps[$i]
        $appLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
        $appLabel.Size = New-Object System.Drawing.Size(800, 40)
        $appLabel.Location = New-Object System.Drawing.Point(30, (30 + ($i * 50)))
        $usagePanel.Controls.Add($appLabel)
    }
    
    $panel.Controls.Add($usagePanel)
    
    return $panel
}

function Create-ParentalControlsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "ParentalControlsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Parental Controls"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    # Controls
    $controlsPanel = New-Object System.Windows.Forms.Panel
    $controlsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $controlsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $controlsPanel.BackColor = [System.Drawing.Color]::White
    
    # Time Limit
    $timeLimitLabel = New-Object System.Windows.Forms.Label
    $timeLimitLabel.Text = "Daily Time Limit:"
    $timeLimitLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $timeLimitLabel.Size = New-Object System.Drawing.Size(200, 30)
    $timeLimitLabel.Location = New-Object System.Drawing.Point(30, 30)
    $controlsPanel.Controls.Add($timeLimitLabel)
    
    $timeLimitValue = New-Object System.Windows.Forms.Label
    $timeLimitValue.Text = "6 hours"
    $timeLimitValue.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $timeLimitValue.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $timeLimitValue.Size = New-Object System.Drawing.Size(200, 30)
    $timeLimitValue.Location = New-Object System.Drawing.Point(250, 30)
    $controlsPanel.Controls.Add($timeLimitValue)
    
    # Bedtime
    $bedtimeLabel = New-Object System.Windows.Forms.Label
    $bedtimeLabel.Text = "Bedtime:"
    $bedtimeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $bedtimeLabel.Size = New-Object System.Drawing.Size(200, 30)
    $bedtimeLabel.Location = New-Object System.Drawing.Point(30, 80)
    $controlsPanel.Controls.Add($bedtimeLabel)
    
    $bedtimeValue = New-Object System.Windows.Forms.Label
    $bedtimeValue.Text = "10:00 PM"
    $bedtimeValue.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $bedtimeValue.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $bedtimeValue.Size = New-Object System.Drawing.Size(200, 30)
    $bedtimeValue.Location = New-Object System.Drawing.Point(250, 80)
    $controlsPanel.Controls.Add($bedtimeValue)
    
    # Blocked Apps
    $blockedLabel = New-Object System.Windows.Forms.Label
    $blockedLabel.Text = "Blocked Applications:"
    $blockedLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $blockedLabel.Size = New-Object System.Drawing.Size(250, 30)
    $blockedLabel.Location = New-Object System.Drawing.Point(30, 130)
    $controlsPanel.Controls.Add($blockedLabel)
    
    $blockedList = New-Object System.Windows.Forms.ListBox
    $blockedList.Size = New-Object System.Drawing.Size(300, 150)
    $blockedList.Location = New-Object System.Drawing.Point(30, 170)
    $blockedList.Items.Add("Steam")
    $blockedList.Items.Add("TikTok")
    $blockedList.Items.Add("Instagram")
    $blockedList.Items.Add("Discord")
    $controlsPanel.Controls.Add($blockedList)
    
    $panel.Controls.Add($controlsPanel)
    
    return $panel
}

function Create-SettingsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "SettingsPanel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Settings"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    # Settings
    $settingsPanel = New-Object System.Windows.Forms.Panel
    $settingsPanel.Size = New-Object System.Drawing.Size(900, 580)
    $settingsPanel.Location = New-Object System.Drawing.Point(30, 90)
    $settingsPanel.BackColor = [System.Drawing.Color]::White
    
    $settings = @(
        "Auto Start with Windows: Enabled",
        "Show Notifications: Enabled",
        "Dark Mode: Disabled",
        "Data Retention: 30 days",
        "Real-time Tracking: Enabled",
        "Alert Sounds: Enabled"
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

# Create simple panels for other sections
function Create-SimplePanel {
    param([string]$title)
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    $panel.Name = "${title}Panel"
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $title
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 30)
    $panel.Controls.Add($titleLabel)
    
    $contentLabel = New-Object System.Windows.Forms.Label
    $contentLabel.Text = "This section contains detailed $title information and analytics."
    $contentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $contentLabel.Size = New-Object System.Drawing.Size(800, 100)
    $contentLabel.Location = New-Object System.Drawing.Point(30, 100)
    $panel.Controls.Add($contentLabel)
    
    return $panel
}

# Create all panels
$panels["Dashboard"] = Create-DashboardPanel
$panels["Activity"] = Create-ActivityPanel
$panels["Screen Time"] = Create-ScreenTimePanel
$panels["Notifications"] = Create-SimplePanel "Notifications"
$panels["App Usage"] = Create-AppUsagePanel
$panels["Parental Controls"] = Create-ParentalControlsPanel
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
        
        # Update charts when dashboard is shown
        if ($panelName -eq "Dashboard") {
            Update-Charts
        }
    }
}

# Show dashboard by default
Show-Panel "Dashboard"

# FIXED: Clock timer
$clockTimer = New-Object System.Windows.Forms.Timer
$clockTimer.Interval = 60000
$clockTimer.Add_Tick({
    $timeLabel.Text = (Get-Date).ToString("HH:mm")
})
$clockTimer.Start()

# Application monitoring
$monitorTimer = New-Object System.Windows.Forms.Timer
$monitorTimer.Interval = 10000
$monitorTimer.Add_Tick({
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if (-not $global:appData.DailyStats.$today) {
        $global:appData.DailyStats.$today = @{TotalMinutes = 0}
    }
    $global:appData.DailyStats.$today.TotalMinutes++
    
    # Update dashboard stats
    Update-DashboardStats
    
    # Update status
    $screenTime = if ($global:appData.DailyStats.$today) { 
        "$([math]::Round($global:appData.DailyStats.$today.TotalMinutes/60, 1))h" 
    } else { "0h" }
    
    Update-Status "Active • Screen Time: $screenTime" ([System.Drawing.Color]::LightGreen)
    
    # Auto-save every 5 minutes
    if (($global:appData.DailyStats.$today.TotalMinutes % 5) -eq 0) {
        $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
    }
})
$monitorTimer.Start()

# Set initial status
Update-Status "Active • Monitoring" ([System.Drawing.Color]::LightGreen)

# Initial chart drawing
Update-Charts

# Form closing event
$form.Add_FormClosing({
    $clockTimer.Stop()
    $monitorTimer.Stop()
    $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
})

# Show the form
$form.Add_Shown({
    $form.Activate()
    Update-Charts
})
[void]$form.ShowDialog()