# Digital Wellbeing & Parental Controls Dashboard
# Clean version - No emojis, no encoding issues
# Save as: DigitalWellbeing.ps1

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ========== DATA MANAGEMENT ==========
$global:appDataPath = "$env:APPDATA\DigitalWellbeing"
$global:dataFile = "$appDataPath\activity_data.json"
$global:configFile = "$appDataPath\config.json"

# Create data directory
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
}

# Load or initialize data
function Initialize-Data {
    if (Test-Path $dataFile) {
        return Get-Content $dataFile | ConvertFrom-Json
    } else {
        $defaultData = @{
            Applications = @{}
            DailyStats = @{}
            Notifications = @()
            ScreenTime = @{}
            TimeBlocks = @()
            Alerts = @()
            ParentalControls = @{
                TimeLimit = 6
                Bedtime = "22:00"
                BlockedApps = @("Steam", "TikTok", "Instagram")
                WebsiteFilter = $true
                FocusMode = $false
            }
            Premium = $false
            Settings = @{
                AutoStart = $true
                Notifications = $true
                DarkMode = $false
                DataRetention = 30
            }
        }
        $defaultData | ConvertTo-Json | Set-Content $dataFile
        return $defaultData
    }
}

$global:appData = Initialize-Data

# ========== MAIN FORM ==========
$form = New-Object System.Windows.Forms.Form
$form.Text = "Digital Wellbeing & Parental Controls"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\shell32.dll")

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
    $button.Location = New-Object System.Drawing.Point(10, 120 + ($i * 55))
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
$statusLabel.Text = "Tracking Active"
$statusLabel.ForeColor = [System.Drawing.Color]::LightGreen
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
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

$timeLabel = New-Object System.Windows.Forms.Label
$timeLabel.Text = (Get-Date).ToString("hh:mm tt")
$timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$timeLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
$timeLabel.Size = New-Object System.Drawing.Size(100, 30)
$timeLabel.Location = New-Object System.Drawing.Point(800, 30)
$timeLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$headerPanel.Controls.Add($timeLabel)

$contentPanel.Controls.Add($headerPanel)

# ========== PANEL MANAGEMENT ==========
$panels = @{}

function Create-DashboardPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    
    # Stats Cards
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(940, 150)
    $statsPanel.Location = New-Object System.Drawing.Point(0, 0)
    
    $cards = @(
        @{Title="SCREEN TIME"; Value="3h 42m"; Color="#4F46E5"},
        @{Title="APPS USED"; Value="12"; Color="#10B981"},
        @{Title="NOTIFICATIONS"; Value="47"; Color="#F59E0B"},
        @{Title="FOCUS TIME"; Value="2h 15m"; Color="#EF4444"}
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
    $panel.Controls.Add($statsPanel)
    
    # Charts Area
    $chartsPanel = New-Object System.Windows.Forms.Panel
    $chartsPanel.Size = New-Object System.Drawing.Size(940, 300)
    $chartsPanel.Location = New-Object System.Drawing.Point(0, 170)
    
    # Weekly Chart
    $chartPanel = New-Object System.Windows.Forms.Panel
    $chartPanel.Size = New-Object System.Drawing.Size(460, 280)
    $chartPanel.Location = New-Object System.Drawing.Point(0, 0)
    $chartPanel.BackColor = [System.Drawing.Color]::White
    
    $chartTitle = New-Object System.Windows.Forms.Label
    $chartTitle.Text = "Weekly Screen Time"
    $chartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $chartTitle.Size = New-Object System.Drawing.Size(300, 30)
    $chartTitle.Location = New-Object System.Drawing.Point(20, 20)
    $chartPanel.Controls.Add($chartTitle)
    
    $chartBox = New-Object System.Windows.Forms.PictureBox
    $chartBox.Size = New-Object System.Drawing.Size(420, 200)
    $chartBox.Location = New-Object System.Drawing.Point(20, 60)
    $chartBox.BackColor = [System.Drawing.Color]::White
    
    $bitmap = New-Object System.Drawing.Bitmap(420, 200)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    
    $days = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    $hours = @(3.5, 4.2, 3.8, 5.1, 4.5, 6.2, 4.8)
    $maxHours = ($hours | Measure-Object -Maximum).Maximum
    
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(79, 70, 229, 100))
    
    for ($i = 0; $i -lt $days.Length; $i++) {
        $x = 30 + ($i * 55)
        $barHeight = ($hours[$i] / $maxHours) * 120
        $y = 150 - $barHeight
        
        $graphics.FillRectangle($brush, $x, $y, 30, $barHeight)
        
        $graphics.DrawString($days[$i], (New-Object System.Drawing.Font("Segoe UI", 9)), [System.Drawing.Brushes]::Black, $x, 160)
        $graphics.DrawString("$($hours[$i])h", (New-Object System.Drawing.Font("Segoe UI", 8)), [System.Drawing.Brushes]::Gray, $x, $y - 15)
    }
    
    $chartBox.Image = $bitmap
    $chartPanel.Controls.Add($chartBox)
    $chartsPanel.Controls.Add($chartPanel)
    
    # Top Apps
    $appsPanel = New-Object System.Windows.Forms.Panel
    $appsPanel.Size = New-Object System.Drawing.Size(460, 280)
    $appsPanel.Location = New-Object System.Drawing.Point(480, 0)
    $appsPanel.BackColor = [System.Drawing.Color]::White
    
    $appsTitle = New-Object System.Windows.Forms.Label
    $appsTitle.Text = "Top Applications"
    $appsTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $appsTitle.Size = New-Object System.Drawing.Size(300, 30)
    $appsTitle.Location = New-Object System.Drawing.Point(20, 20)
    $appsPanel.Controls.Add($appsTitle)
    
    $apps = @(
        @{Name="Chrome"; Time="2h 15m"; Percent=35},
        @{Name="Discord"; Time="1h 30m"; Percent=23},
        @{Name="Word"; Time="1h 15m"; Percent=19},
        @{Name="Spotify"; Time="45m"; Percent=12}
    )
    
    for ($i = 0; $i -lt $apps.Length; $i++) {
        $yPos = 60 + ($i * 55)
        
        $appLabel = New-Object System.Windows.Forms.Label
        $appLabel.Text = $apps[$i].Name
        $appLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $appLabel.Size = New-Object System.Drawing.Size(120, 30)
        $appLabel.Location = New-Object System.Drawing.Point(20, $yPos)
        $appsPanel.Controls.Add($appLabel)
        
        $timeLabel = New-Object System.Windows.Forms.Label
        $timeLabel.Text = $apps[$i].Time
        $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $timeLabel.Size = New-Object System.Drawing.Size(80, 30)
        $timeLabel.Location = New-Object System.Drawing.Point(150, $yPos)
        $appsPanel.Controls.Add($timeLabel)
        
        $percentLabel = New-Object System.Windows.Forms.Label
        $percentLabel.Text = "$($apps[$i].Percent)%"
        $percentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $percentLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
        $percentLabel.Size = New-Object System.Drawing.Size(50, 30)
        $percentLabel.Location = New-Object System.Drawing.Point(240, $yPos)
        $appsPanel.Controls.Add($percentLabel)
        
        $progressPanel = New-Object System.Windows.Forms.Panel
        $progressPanel.Size = New-Object System.Drawing.Size(150, 8)
        $progressPanel.Location = New-Object System.Drawing.Point(300, $yPos + 10)
        $progressPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
        
        $progressBar = New-Object System.Windows.Forms.Panel
        $progressBar.Size = New-Object System.Drawing.Size(($apps[$i].Percent * 1.5), 8)
        $progressBar.Location = New-Object System.Drawing.Point(0, 0)
        $progressBar.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
        $progressPanel.Controls.Add($progressBar)
        $appsPanel.Controls.Add($progressPanel)
    }
    
    $chartsPanel.Controls.Add($appsPanel)
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
    
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(940, 80)
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Activity Details"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $titlePanel.Controls.Add($titleLabel)
    
    $panel.Controls.Add($titlePanel)
    
    # Activity Grid
    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Size = New-Object System.Drawing.Size(940, 560)
    $dataGrid.Location = New-Object System.Drawing.Point(0, 100)
    $dataGrid.BackgroundColor = [System.Drawing.Color]::White
    $dataGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.ReadOnly = $true
    $dataGrid.RowHeadersVisible = $false
    
    $dataGrid.Columns.Add("Time", "Time") | Out-Null
    $dataGrid.Columns.Add("Application", "Application") | Out-Null
    $dataGrid.Columns.Add("Duration", "Duration") | Out-Null
    $dataGrid.Columns.Add("Category", "Category") | Out-Null
    $dataGrid.Columns.Add("Status", "Status") | Out-Null
    
    $sampleData = @(
        @{Time="09:00 AM"; Application="Google Chrome"; Duration="45m"; Category="Browser"; Status="Active"},
        @{Time="10:00 AM"; Application="Microsoft Teams"; Duration="30m"; Category="Communication"; Status="Meeting"},
        @{Time="11:30 AM"; Application="Microsoft Word"; Duration="90m"; Category="Productivity"; Status="Active"},
        @{Time="01:00 PM"; Application="Windows Explorer"; Duration="15m"; Category="System"; Status="Active"},
        @{Time="02:00 PM"; Application="Spotify"; Duration="60m"; Category="Music"; Status="Background"},
        @{Time="03:30 PM"; Application="Visual Studio Code"; Duration="45m"; Category="Development"; Status="Active"},
        @{Time="04:30 PM"; Application="Discord"; Duration="30m"; Category="Communication"; Status="Active"}
    )
    
    foreach ($item in $sampleData) {
        $dataGrid.Rows.Add($item.Time, $item.Application, $item.Duration, $item.Category, $item.Status) | Out-Null
    }
    
    $panel.Controls.Add($dataGrid)
    
    return $panel
}

function Create-ScreenTimePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(940, 80)
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Screen Time Analysis"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $titlePanel.Controls.Add($titleLabel)
    
    $panel.Controls.Add($titlePanel)
    
    # Content
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Size = New-Object System.Drawing.Size(940, 560)
    $contentPanel.Location = New-Object System.Drawing.Point(0, 100)
    $contentPanel.BackColor = [System.Drawing.Color]::White
    
    $chartTitle = New-Object System.Windows.Forms.Label
    $chartTitle.Text = "Daily Usage Pattern"
    $chartTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $chartTitle.Size = New-Object System.Drawing.Size(300, 40)
    $chartTitle.Location = New-Object System.Drawing.Point(30, 20)
    $contentPanel.Controls.Add($chartTitle)
    
    # Time chart
    $timeChart = New-Object System.Windows.Forms.PictureBox
    $timeChart.Size = New-Object System.Drawing.Size(880, 200)
    $timeChart.Location = New-Object System.Drawing.Point(30, 70)
    $timeChart.BackColor = [System.Drawing.Color]::White
    
    $bitmap = New-Object System.Drawing.Bitmap(880, 200)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    
    $hours = @(0.5, 1.2, 2.0, 1.8, 2.5, 3.0, 2.8, 2.5, 2.0, 1.5, 1.0, 0.8, 1.2, 1.5, 2.0, 2.5, 3.0, 2.8, 2.2, 1.8, 1.5, 1.2, 0.8, 0.5)
    $maxHour = ($hours | Measure-Object -Maximum).Maximum
    
    # Draw line chart
    for ($i = 0; $i -lt $hours.Length - 1; $i++) {
        $x1 = 30 + ($i * 35)
        $y1 = 180 - ($hours[$i] / $maxHour * 150)
        $x2 = 30 + (($i + 1) * 35)
        $y2 = 180 - ($hours[$i + 1] / $maxHour * 150)
        
        $graphics.DrawLine([System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(79, 70, 229), 3), $x1, $y1, $x2, $y2)
    }
    
    $timeChart.Image = $bitmap
    $contentPanel.Controls.Add($timeChart)
    
    $panel.Controls.Add($contentPanel)
    
    return $panel
}

function Create-ParentalControlsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(940, 80)
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Parental Controls"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $titlePanel.Controls.Add($titleLabel)
    
    $panel.Controls.Add($titlePanel)
    
    # Controls Panel
    $controlsPanel = New-Object System.Windows.Forms.Panel
    $controlsPanel.Size = New-Object System.Drawing.Size(940, 560)
    $controlsPanel.Location = New-Object System.Drawing.Point(0, 100)
    $controlsPanel.BackColor = [System.Drawing.Color]::White
    
    $yPos = 30
    
    # Time Limit
    $timeLimitLabel = New-Object System.Windows.Forms.Label
    $timeLimitLabel.Text = "Daily Time Limit:"
    $timeLimitLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $timeLimitLabel.Size = New-Object System.Drawing.Size(200, 30)
    $timeLimitLabel.Location = New-Object System.Drawing.Point(30, $yPos)
    $controlsPanel.Controls.Add($timeLimitLabel)
    
    $timeLimitBox = New-Object System.Windows.Forms.NumericUpDown
    $timeLimitBox.Size = New-Object System.Drawing.Size(100, 30)
    $timeLimitBox.Location = New-Object System.Drawing.Point(250, $yPos)
    $timeLimitBox.Minimum = 1
    $timeLimitBox.Maximum = 24
    $timeLimitBox.Value = $global:appData.ParentalControls.TimeLimit
    $controlsPanel.Controls.Add($timeLimitBox)
    
    $yPos += 50
    
    # Bedtime
    $bedtimeLabel = New-Object System.Windows.Forms.Label
    $bedtimeLabel.Text = "Bedtime (No computer after):"
    $bedtimeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $bedtimeLabel.Size = New-Object System.Drawing.Size(250, 30)
    $bedtimeLabel.Location = New-Object System.Drawing.Point(30, $yPos)
    $controlsPanel.Controls.Add($bedtimeLabel)
    
    $bedtimeBox = New-Object System.Windows.Forms.TextBox
    $bedtimeBox.Size = New-Object System.Drawing.Size(100, 30)
    $bedtimeBox.Location = New-Object System.Drawing.Point(300, $yPos)
    $bedtimeBox.Text = $global:appData.ParentalControls.Bedtime
    $controlsPanel.Controls.Add($bedtimeBox)
    
    $yPos += 50
    
    # Block Apps
    $blockLabel = New-Object System.Windows.Forms.Label
    $blockLabel.Text = "Block Applications:"
    $blockLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $blockLabel.Size = New-Object System.Drawing.Size(200, 30)
    $blockLabel.Location = New-Object System.Drawing.Point(30, $yPos)
    $controlsPanel.Controls.Add($blockLabel)
    
    $blockBox = New-Object System.Windows.Forms.TextBox
    $blockBox.Size = New-Object System.Drawing.Size(300, 30)
    $blockBox.Location = New-Object System.Drawing.Point(250, $yPos)
    $blockBox.Text = $global:appData.ParentalControls.BlockedApps -join ", "
    $controlsPanel.Controls.Add($blockBox)
    
    $yPos += 50
    
    # Website Filter
    $websiteCheck = New-Object System.Windows.Forms.CheckBox
    $websiteCheck.Text = "Enable Website Filtering"
    $websiteCheck.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $websiteCheck.Size = New-Object System.Drawing.Size(300, 30)
    $websiteCheck.Location = New-Object System.Drawing.Point(30, $yPos)
    $websiteCheck.Checked = $global:appData.ParentalControls.WebsiteFilter
    $controlsPanel.Controls.Add($websiteCheck)
    
    $yPos += 50
    
    # Focus Mode
    $focusCheck = New-Object System.Windows.Forms.CheckBox
    $focusCheck.Text = "Enable Focus Mode"
    $focusCheck.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $focusCheck.Size = New-Object System.Drawing.Size(300, 30)
    $focusCheck.Location = New-Object System.Drawing.Point(30, $yPos)
    $focusCheck.Checked = $global:appData.ParentalControls.FocusMode
    $controlsPanel.Controls.Add($focusCheck)
    
    $yPos += 80
    
    # Save Button
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save Settings"
    $saveButton.Size = New-Object System.Drawing.Size(200, 50)
    $saveButton.Location = New-Object System.Drawing.Point(30, $yPos)
    $saveButton.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $saveButton.ForeColor = [System.Drawing.Color]::White
    $saveButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveButton.Add_Click({
        $global:appData.ParentalControls.TimeLimit = $timeLimitBox.Value
        $global:appData.ParentalControls.Bedtime = $bedtimeBox.Text
        $global:appData.ParentalControls.BlockedApps = ($blockBox.Text -split ',').Trim()
        $global:appData.ParentalControls.WebsiteFilter = $websiteCheck.Checked
        $global:appData.ParentalControls.FocusMode = $focusCheck.Checked
        
        $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
        [System.Windows.Forms.MessageBox]::Show("Parental control settings saved successfully!", "Success", "OK", "Information")
    })
    $controlsPanel.Controls.Add($saveButton)
    
    $panel.Controls.Add($controlsPanel)
    
    return $panel
}

function Create-SettingsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(940, 80)
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Settings"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $titlePanel.Controls.Add($titleLabel)
    
    $panel.Controls.Add($titlePanel)
    
    # Settings Panel
    $settingsPanel = New-Object System.Windows.Forms.Panel
    $settingsPanel.Size = New-Object System.Drawing.Size(940, 560)
    $settingsPanel.Location = New-Object System.Drawing.Point(0, 100)
    $settingsPanel.BackColor = [System.Drawing.Color]::White
    
    $yPos = 30
    
    # Auto Start
    $autoStartCheck = New-Object System.Windows.Forms.CheckBox
    $autoStartCheck.Text = "Start with Windows"
    $autoStartCheck.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $autoStartCheck.Size = New-Object System.Drawing.Size(300, 30)
    $autoStartCheck.Location = New-Object System.Drawing.Point(30, $yPos)
    $autoStartCheck.Checked = $global:appData.Settings.AutoStart
    $settingsPanel.Controls.Add($autoStartCheck)
    
    $yPos += 50
    
    # Notifications
    $notifyCheck = New-Object System.Windows.Forms.CheckBox
    $notifyCheck.Text = "Show Notifications"
    $notifyCheck.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $notifyCheck.Size = New-Object System.Drawing.Size(300, 30)
    $notifyCheck.Location = New-Object System.Drawing.Point(30, $yPos)
    $notifyCheck.Checked = $global:appData.Settings.Notifications
    $settingsPanel.Controls.Add($notifyCheck)
    
    $yPos += 50
    
    # Dark Mode
    $darkModeCheck = New-Object System.Windows.Forms.CheckBox
    $darkModeCheck.Text = "Dark Mode"
    $darkModeCheck.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $darkModeCheck.Size = New-Object System.Drawing.Size(300, 30)
    $darkModeCheck.Location = New-Object System.Drawing.Point(30, $yPos)
    $darkModeCheck.Checked = $global:appData.Settings.DarkMode
    $settingsPanel.Controls.Add($darkModeCheck)
    
    $yPos += 50
    
    # Data Retention
    $dataLabel = New-Object System.Windows.Forms.Label
    $dataLabel.Text = "Data Retention (days):"
    $dataLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $dataLabel.Size = New-Object System.Drawing.Size(250, 30)
    $dataLabel.Location = New-Object System.Drawing.Point(30, $yPos)
    $settingsPanel.Controls.Add($dataLabel)
    
    $dataBox = New-Object System.Windows.Forms.NumericUpDown
    $dataBox.Size = New-Object System.Drawing.Size(100, 30)
    $dataBox.Location = New-Object System.Drawing.Point(300, $yPos)
    $dataBox.Minimum = 7
    $dataBox.Maximum = 365
    $dataBox.Value = $global:appData.Settings.DataRetention
    $settingsPanel.Controls.Add($dataBox)
    
    $yPos += 80
    
    # Clear Data Button
    $clearButton = New-Object System.Windows.Forms.Button
    $clearButton.Text = "Clear All Data"
    $clearButton.Size = New-Object System.Drawing.Size(200, 50)
    $clearButton.Location = New-Object System.Drawing.Point(30, $yPos)
    $clearButton.BackColor = [System.Drawing.Color]::FromArgb(239, 68, 68)
    $clearButton.ForeColor = [System.Drawing.Color]::White
    $clearButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $clearButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $clearButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to clear all data? This cannot be undone.", "Confirm", "YesNo", "Warning")
        if ($result -eq "Yes") {
            $global:appData = Initialize-Data
            [System.Windows.Forms.MessageBox]::Show("All data has been cleared.", "Success", "OK", "Information")
        }
    })
    $settingsPanel.Controls.Add($clearButton)
    
    $yPos += 70
    
    # Save Settings Button
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save Settings"
    $saveButton.Size = New-Object System.Drawing.Size(200, 50)
    $saveButton.Location = New-Object System.Drawing.Point(250, $yPos)
    $saveButton.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $saveButton.ForeColor = [System.Drawing.Color]::White
    $saveButton.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveButton.Add_Click({
        $global:appData.Settings.AutoStart = $autoStartCheck.Checked
        $global:appData.Settings.Notifications = $notifyCheck.Checked
        $global:appData.Settings.DarkMode = $darkModeCheck.Checked
        $global:appData.Settings.DataRetention = $dataBox.Value
        
        $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
        [System.Windows.Forms.MessageBox]::Show("Settings saved successfully!", "Success", "OK", "Information")
    })
    $settingsPanel.Controls.Add($saveButton)
    
    $panel.Controls.Add($settingsPanel)
    
    return $panel
}

# Simple panels for other sections
function Create-SimplePanel {
    param([string]$title, [string]$content)
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(940, 660)
    $panel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.BackColor = [System.Drawing.Color]::Transparent
    
    $titlePanel = New-Object System.Windows.Forms.Panel
    $titlePanel.Size = New-Object System.Drawing.Size(940, 80)
    $titlePanel.Location = New-Object System.Drawing.Point(0, 0)
    $titlePanel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = $title
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(400, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(30, 20)
    $titlePanel.Controls.Add($titleLabel)
    
    $panel.Controls.Add($titlePanel)
    
    $contentPanel = New-Object System.Windows.Forms.Panel
    $contentPanel.Size = New-Object System.Drawing.Size(940, 560)
    $contentPanel.Location = New-Object System.Drawing.Point(0, 100)
    $contentPanel.BackColor = [System.Drawing.Color]::White
    
    $contentLabel = New-Object System.Windows.Forms.Label
    $contentLabel.Text = $content
    $contentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
    $contentLabel.Size = New-Object System.Drawing.Size(880, 200)
    $contentLabel.Location = New-Object System.Drawing.Point(30, 30)
    $contentPanel.Controls.Add($contentLabel)
    
    $panel.Controls.Add($contentPanel)
    
    return $panel
}

# Create all panels
$panels["Dashboard"] = Create-DashboardPanel
$panels["Activity"] = Create-ActivityPanel
$panels["Screen Time"] = Create-ScreenTimePanel
$panels["Notifications"] = Create-SimplePanel "Notifications" "Track and manage all notifications from applications. View history, set notification limits, and configure alerts."
$panels["App Usage"] = Create-SimplePanel "Application Usage" "Detailed statistics for each application including time spent, frequency of use, and usage patterns over time."
$panels["Parental Controls"] = Create-ParentalControlsPanel
$panels["Reports"] = Create-SimplePanel "Reports" "Generate detailed reports of digital wellbeing. Daily, weekly, and monthly summaries with export options."
$panels["Settings"] = Create-SettingsPanel

# Add panels to content area
foreach ($panel in $panels.Values) {
    $contentPanel.Controls.Add($panel)
}

# Show panel function
function Show-Panel {
    param([string]$panelName)
    
    foreach ($panel in $panels.Values) {
        $panel.Visible = $false
    }
    
    if ($panels.ContainsKey($panelName)) {
        $panels[$panelName].Visible = $true
        $welcomeLabel.Text = $panelName
    }
}

# Show dashboard by default
Show-Panel "Dashboard"

# Clock timer
$clockTimer = New-Object System.Windows.Forms.Timer
$clockTimer.Interval = 60000
$clockTimer.Add_Tick({
    $timeLabel.Text = (Get-Date).ToString("hh:mm tt")
})
$clockTimer.Start()

# Application monitoring (simplified)
$monitorTimer = New-Object System.Windows.Forms.Timer
$monitorTimer.Interval = 10000
$monitorTimer.Add_Tick({
    $today = (Get-Date).ToString("yyyy-MM-dd")
    if (-not $global:appData.DailyStats.$today) {
        $global:appData.DailyStats.$today = @{TotalMinutes = 0}
    }
    $global:appData.DailyStats.$today.TotalMinutes++
    
    # Auto-save every 5 minutes
    if (($global:appData.DailyStats.$today.TotalMinutes % 5) -eq 0) {
        $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
    }
})
$monitorTimer.Start()

# Form closing event
$form.Add_FormClosing({
    $clockTimer.Stop()
    $monitorTimer.Stop()
    $global:appData | ConvertTo-Json | Set-Content $dataFile -Force
})

# Show the form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()