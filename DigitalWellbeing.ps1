# Digital Wellbeing & Parental Controls Dashboard
# Clean version without encoding issues

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Initialize data storage
$global:appDataPath = "$env:APPDATA\DigitalWellbeing"
$global:dataFile = "$appDataPath\activity_data.json"
$global:configFile = "$appDataPath\config.json"

# Create data directory if it doesn't exist
if (-not (Test-Path $appDataPath)) {
    New-Item -ItemType Directory -Path $appDataPath -Force | Out-Null
}

# Load or initialize data
function Initialize-Data {
    if (Test-Path $dataFile) {
        $json = Get-Content $dataFile | ConvertFrom-Json
        return $json
    }
    else {
        $defaultData = @{
            Applications = @{}
            DailyStats = @{}
            Notifications = @()
            ScreenTime = @{}
            TimeBlocks = @()
            Alerts = @()
            Premium = $false
        }
        $defaultData | ConvertTo-Json | Set-Content $dataFile
        return $defaultData
    }
}

$global:appData = Initialize-Data

# Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Digital Wellbeing & Parental Controls"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 242, 245)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Sidebar Panel
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(200, 800)
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
$sidebar.Dock = [System.Windows.Forms.DockStyle]::Left
$form.Controls.Add($sidebar)

# Logo/Title in Sidebar
$logoLabel = New-Object System.Windows.Forms.Label
$logoLabel.Text = "WELLBEING"
$logoLabel.ForeColor = [System.Drawing.Color]::White
$logoLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$logoLabel.Size = New-Object System.Drawing.Size(180, 40)
$logoLabel.Location = New-Object System.Drawing.Point(10, 20)
$logoLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$sidebar.Controls.Add($logoLabel)

# Sidebar Buttons
$sidebarButtons = @()
$buttonTitles = @("Dashboard", "Activity Details", "Screen Time", "Notifications", "App Usage", "Settings", "Premium")

for ($i = 0; $i -lt $buttonTitles.Length; $i++) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $buttonTitles[$i]
    $button.Size = New-Object System.Drawing.Size(180, 40)
    $button.Location = New-Object System.Drawing.Point(10, 80 + ($i * 50))
    $button.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 70)
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderSize = 0
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $button.Add_Click({
        param($sender)
        Show-Panel $sender.Text
    })
    $sidebarButtons += $button
    $sidebar.Controls.Add($button)
}

# Main Content Panel
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Size = New-Object System.Drawing.Size(1000, 800)
$contentPanel.BackColor = [System.Drawing.Color]::White
$contentPanel.Dock = [System.Windows.Forms.DockStyle]::Right
$contentPanel.Padding = New-Object System.Windows.Forms.Padding(20)
$form.Controls.Add($contentPanel)

# Header Panel
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(960, 80)
$headerPanel.BackColor = [System.Drawing.Color]::White
$headerPanel.Dock = [System.Windows.Forms.DockStyle]::Top
$contentPanel.Controls.Add($headerPanel)

# Welcome Label
$welcomeLabel = New-Object System.Windows.Forms.Label
$welcomeLabel.Text = "Welcome to Digital Wellbeing"
$welcomeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$welcomeLabel.Size = New-Object System.Drawing.Size(400, 40)
$welcomeLabel.Location = New-Object System.Drawing.Point(20, 20)
$headerPanel.Controls.Add($welcomeLabel)

# Date Label
$dateLabel = New-Object System.Windows.Forms.Label
$dateLabel.Text = (Get-Date).ToString("dddd, MMMM dd, yyyy")
$dateLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$dateLabel.ForeColor = [System.Drawing.Color]::Gray
$dateLabel.Size = New-Object System.Drawing.Size(300, 30)
$dateLabel.Location = New-Object System.Drawing.Point(20, 50)
$headerPanel.Controls.Add($dateLabel)

# Content Panels
$panels = @{}

function Create-DashboardPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    # Stats Cards
    $statsPanel = New-Object System.Windows.Forms.Panel
    $statsPanel.Size = New-Object System.Drawing.Size(920, 150)
    $statsPanel.Location = New-Object System.Drawing.Point(20, 20)
    $statsPanel.BackColor = [System.Drawing.Color]::Transparent
    
    $cards = @(
        @{Title="Screen Time Today"; Value="3h 42m"; Color="#4F46E5"},
        @{Title="Apps Used"; Value="12"; Color="#10B981"},
        @{Title="Notifications"; Value="47"; Color="#F59E0B"},
        @{Title="Focus Time"; Value="2h 15m"; Color="#EF4444"}
    )
    
    for ($i = 0; $i -lt $cards.Length; $i++) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(210, 120)
        $card.Location = New-Object System.Drawing.Point(($i * 230), 0)
        $card.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 255)
        $card.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        
        $titleLabel = New-Object System.Windows.Forms.Label
        $titleLabel.Text = $cards[$i].Title
        $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $titleLabel.ForeColor = [System.Drawing.Color]::Gray
        $titleLabel.Size = New-Object System.Drawing.Size(170, 25)
        $titleLabel.Location = New-Object System.Drawing.Point(20, 75)
        $card.Controls.Add($titleLabel)
        
        $valueLabel = New-Object System.Windows.Forms.Label
        $valueLabel.Text = $cards[$i].Value
        $valueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
        $valueLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
        $valueLabel.Size = New-Object System.Drawing.Size(170, 40)
        $valueLabel.Location = New-Object System.Drawing.Point(20, 20)
        $card.Controls.Add($valueLabel)
        
        $statsPanel.Controls.Add($card)
    }
    
    $panel.Controls.Add($statsPanel)
    
    # Charts Area
    $chartsPanel = New-Object System.Windows.Forms.Panel
    $chartsPanel.Size = New-Object System.Drawing.Size(920, 500)
    $chartsPanel.Location = New-Object System.Drawing.Point(20, 190)
    $chartsPanel.BackColor = [System.Drawing.Color]::Transparent
    
    # Screen Time Chart
    $chartLabel = New-Object System.Windows.Forms.Label
    $chartLabel.Text = "Weekly Screen Time"
    $chartLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $chartLabel.Size = New-Object System.Drawing.Size(300, 30)
    $chartLabel.Location = New-Object System.Drawing.Point(0, 0)
    $chartsPanel.Controls.Add($chartLabel)
    
    # Create simple chart using PictureBox
    $chartBox = New-Object System.Windows.Forms.PictureBox
    $chartBox.Size = New-Object System.Drawing.Size(900, 200)
    $chartBox.Location = New-Object System.Drawing.Point(0, 40)
    $chartBox.BackColor = [System.Drawing.Color]::White
    $chartBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    # Draw chart
    $bitmap = New-Object System.Drawing.Bitmap(900, 200)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    
    $days = @("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
    $hours = @(3.5, 4.2, 3.8, 5.1, 4.5, 6.2, 4.8)
    $maxHours = ($hours | Measure-Object -Maximum).Maximum
    
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(79, 70, 229), 3)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(79, 70, 229, 100))
    
    for ($i = 0; $i -lt $days.Length; $i++) {
        $x = 50 + ($i * 120)
        $barHeight = ($hours[$i] / $maxHours) * 150
        $y = 180 - $barHeight
        
        $graphics.FillRectangle($brush, $x, $y, 40, $barHeight)
        $graphics.DrawRectangle($pen, $x, $y, 40, $barHeight)
        
        # Draw day label
        $dayFont = New-Object System.Drawing.Font("Arial", 10)
        $graphics.DrawString($days[$i], $dayFont, [System.Drawing.Brushes]::Black, $x + 10, 185)
        
        # Draw hour value
        $graphics.DrawString("$($hours[$i])h", $dayFont, [System.Drawing.Brushes]::Gray, $x + 5, $y - 20)
    }
    
    $chartBox.Image = $bitmap
    $chartsPanel.Controls.Add($chartBox)
    
    # Recent Activity
    $activityLabel = New-Object System.Windows.Forms.Label
    $activityLabel.Text = "Recent Activity"
    $activityLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $activityLabel.Size = New-Object System.Drawing.Size(300, 30)
    $activityLabel.Location = New-Object System.Drawing.Point(0, 260)
    $chartsPanel.Controls.Add($activityLabel)
    
    # Activity List
    $activityList = New-Object System.Windows.Forms.ListBox
    $activityList.Size = New-Object System.Drawing.Size(900, 200)
    $activityList.Location = New-Object System.Drawing.Point(0, 300)
    $activityList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $activityList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    $activities = @(
        "9:00 AM - Opened Chrome - 45 minutes",
        "10:00 AM - Received 12 notifications",
        "11:30 AM - Microsoft Word - 1.5 hours",
        "1:00 PM - Lunch Break",
        "2:30 PM - Zoom Meeting - 1 hour",
        "4:00 PM - Social Media - 30 minutes",
        "6:00 PM - Gaming - 1 hour"
    )
    
    foreach ($activity in $activities) {
        $activityList.Items.Add($activity)
    }
    
    $chartsPanel.Controls.Add($activityList)
    
    $panel.Controls.Add($chartsPanel)
    
    return $panel
}

function Create-ActivityPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Activity Details"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $panel.Controls.Add($titleLabel)
    
    # Activity Grid
    $dataGrid = New-Object System.Windows.Forms.DataGridView
    $dataGrid.Size = New-Object System.Drawing.Size(920, 600)
    $dataGrid.Location = New-Object System.Drawing.Point(20, 80)
    $dataGrid.BackgroundColor = [System.Drawing.Color]::White
    $dataGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
    $dataGrid.AllowUserToAddRows = $false
    $dataGrid.ReadOnly = $true
    
    # Add columns
    $dataGrid.Columns.Add("Time", "Time")
    $dataGrid.Columns.Add("Application", "Application")
    $dataGrid.Columns.Add("Duration", "Duration")
    $dataGrid.Columns.Add("Category", "Category")
    $dataGrid.Columns.Add("Status", "Status")
    
    # Sample data
    $sampleData = @(
        @{Time="9:00 AM"; Application="Chrome"; Duration="45m"; Category="Browser"; Status="Active"},
        @{Time="10:00 AM"; Application="Discord"; Duration="30m"; Category="Communication"; Status="Active"},
        @{Time="11:30 AM"; Application="Word"; Duration="90m"; Category="Productivity"; Status="Active"},
        @{Time="2:00 PM"; Application="Spotify"; Duration="60m"; Category="Music"; Status="Background"},
        @{Time="4:00 PM"; Application="Instagram"; Duration="45m"; Category="Social"; Status="Limited"}
    )
    
    foreach ($item in $sampleData) {
        $dataGrid.Rows.Add($item.Time, $item.Application, $item.Duration, $item.Category, $item.Status)
    }
    
    $panel.Controls.Add($dataGrid)
    
    return $panel
}

function Create-ScreenTimePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Screen Time Analysis"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $panel.Controls.Add($titleLabel)
    
    # Time Filters
    $filterPanel = New-Object System.Windows.Forms.Panel
    $filterPanel.Size = New-Object System.Drawing.Size(920, 50)
    $filterPanel.Location = New-Object System.Drawing.Point(20, 70)
    $filterPanel.BackColor = [System.Drawing.Color]::Transparent
    
    $filters = @("Today", "Yesterday", "This Week", "This Month")
    
    for ($i = 0; $i -lt $filters.Length; $i++) {
        $filterBtn = New-Object System.Windows.Forms.Button
        $filterBtn.Text = $filters[$i]
        $filterBtn.Size = New-Object System.Drawing.Size(100, 30)
        $filterBtn.Location = New-Object System.Drawing.Point(($i * 110), 10)
        $filterBtn.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 245)
        $filterBtn.ForeColor = [System.Drawing.Color]::Black
        $filterBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
        $filterPanel.Controls.Add($filterBtn)
    }
    
    $panel.Controls.Add($filterPanel)
    
    # App Usage Breakdown
    $breakdownLabel = New-Object System.Windows.Forms.Label
    $breakdownLabel.Text = "App Usage Breakdown"
    $breakdownLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $breakdownLabel.Size = New-Object System.Drawing.Size(300, 30)
    $breakdownLabel.Location = New-Object System.Drawing.Point(20, 140)
    $panel.Controls.Add($breakdownLabel)
    
    $apps = @(
        @{Name="Chrome"; Time="2h 15m"; Percent=35},
        @{Name="Discord"; Time="1h 30m"; Percent=23},
        @{Name="Word"; Time="1h 15m"; Percent=19},
        @{Name="Spotify"; Time="45m"; Percent=12},
        @{Name="Others"; Time="30m"; Percent=11}
    )
    
    for ($i = 0; $i -lt $apps.Length; $i++) {
        $appPanel = New-Object System.Windows.Forms.Panel
        $appPanel.Size = New-Object System.Drawing.Size(920, 60)
        $appPanel.Location = New-Object System.Drawing.Point(20, 180 + ($i * 70))
        $appPanel.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 255)
        
        $appLabel = New-Object System.Windows.Forms.Label
        $appLabel.Text = $apps[$i].Name
        $appLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $appLabel.Size = New-Object System.Drawing.Size(150, 30)
        $appLabel.Location = New-Object System.Drawing.Point(20, 15)
        $appPanel.Controls.Add($appLabel)
        
        $timeLabel = New-Object System.Windows.Forms.Label
        $timeLabel.Text = $apps[$i].Time
        $timeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $timeLabel.Size = New-Object System.Drawing.Size(100, 25)
        $timeLabel.Location = New-Object System.Drawing.Point(200, 15)
        $appPanel.Controls.Add($timeLabel)
        
        $percentLabel = New-Object System.Windows.Forms.Label
        $percentLabel.Text = "$($apps[$i].Percent)%"
        $percentLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $percentLabel.ForeColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
        $percentLabel.Size = New-Object System.Drawing.Size(50, 25)
        $percentLabel.Location = New-Object System.Drawing.Point(320, 15)
        $appPanel.Controls.Add($percentLabel)
        
        # Progress bar
        $progressPanel = New-Object System.Windows.Forms.Panel
        $progressPanel.Size = New-Object System.Drawing.Size(500, 10)
        $progressPanel.Location = New-Object System.Drawing.Point(400, 25)
        $progressPanel.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 235)
        
        $progressBar = New-Object System.Windows.Forms.Panel
        $progressBar.Size = New-Object System.Drawing.Size(($apps[$i].Percent * 5), 10)
        $progressBar.Location = New-Object System.Drawing.Point(0, 0)
        $progressBar.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
        $progressPanel.Controls.Add($progressBar)
        
        $appPanel.Controls.Add($progressPanel)
        
        $panel.Controls.Add($appPanel)
    }
    
    return $panel
}

function Create-NotificationsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Notifications History"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $panel.Controls.Add($titleLabel)
    
    $notificationsList = New-Object System.Windows.Forms.ListBox
    $notificationsList.Size = New-Object System.Drawing.Size(920, 600)
    $notificationsList.Location = New-Object System.Drawing.Point(20, 80)
    $notificationsList.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $notificationsList.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    
    $notifications = @(
        "9:15 AM - Email: New message from John",
        "9:30 AM - Slack: Team meeting reminder",
        "10:00 AM - Windows: Update available",
        "11:45 AM - Discord: New message in #general",
        "2:00 PM - Outlook: Calendar: Meeting in 15 min",
        "3:30 PM - WhatsApp: New message",
        "5:00 PM - Windows: Battery low",
        "6:15 PM - Steam: Friend is online",
        "7:45 PM - Facebook: You have memories to look back on"
    )
    
    foreach ($notification in $notifications) {
        $notificationsList.Items.Add($notification)
    }
    
    $panel.Controls.Add($notificationsList)
    
    return $panel
}

function Create-AppUsagePanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Application Usage"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $panel.Controls.Add($titleLabel)
    
    $statsGrid = New-Object System.Windows.Forms.DataGridView
    $statsGrid.Size = New-Object System.Drawing.Size(920, 600)
    $statsGrid.Location = New-Object System.Drawing.Point(20, 80)
    $statsGrid.BackgroundColor = [System.Drawing.Color]::White
    $statsGrid.ColumnHeadersHeightSizeMode = [System.Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::AutoSize
    $statsGrid.AllowUserToAddRows = $false
    $statsGrid.ReadOnly = $true
    
    $statsGrid.Columns.Add("AppName", "Application")
    $statsGrid.Columns.Add("TimesOpened", "Times Opened")
    $statsGrid.Columns.Add("TotalTime", "Total Time")
    $statsGrid.Columns.Add("AvgSession", "Avg Session")
    $statsGrid.Columns.Add("LastUsed", "Last Used")
    
    $appStats = @(
        @{AppName="Chrome"; TimesOpened="8"; TotalTime="2h 15m"; AvgSession="17m"; LastUsed="Today 4:30 PM"},
        @{AppName="Discord"; TimesOpened="12"; TotalTime="1h 30m"; AvgSession="8m"; LastUsed="Today 5:15 PM"},
        @{AppName="Microsoft Word"; TimesOpened="3"; TotalTime="1h 15m"; AvgSession="25m"; LastUsed="Today 11:45 AM"},
        @{AppName="Spotify"; TimesOpened="2"; TotalTime="45m"; AvgSession="23m"; LastUsed="Today 2:30 PM"},
        @{AppName="Zoom"; TimesOpened="1"; TotalTime="1h"; AvgSession="60m"; LastUsed="Today 2:00 PM"},
        @{AppName="Steam"; TimesOpened="1"; TotalTime="45m"; AvgSession="45m"; LastUsed="Today 6:00 PM"}
    )
    
    foreach ($stat in $appStats) {
        $statsGrid.Rows.Add($stat.AppName, $stat.TimesOpened, $stat.TotalTime, $stat.AvgSession, $stat.LastUsed)
    }
    
    $panel.Controls.Add($statsGrid)
    
    return $panel
}

function Create-SettingsPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::White
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Settings"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $titleLabel.Size = New-Object System.Drawing.Size(300, 40)
    $titleLabel.Location = New-Object System.Drawing.Point(20, 20)
    $panel.Controls.Add($titleLabel)
    
    $yPos = 80
    
    # Parental Controls Section
    $parentalLabel = New-Object System.Windows.Forms.Label
    $parentalLabel.Text = "Parental Controls"
    $parentalLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $parentalLabel.Size = New-Object System.Drawing.Size(300, 30)
    $parentalLabel.Location = New-Object System.Drawing.Point(20, $yPos)
    $panel.Controls.Add($parentalLabel)
    
    $yPos += 40
    
    # Daily Time Limit
    $timeLimitLabel = New-Object System.Windows.Forms.Label
    $timeLimitLabel.Text = "Daily Time Limit (hours):"
    $timeLimitLabel.Size = New-Object System.Drawing.Size(200, 25)
    $timeLimitLabel.Location = New-Object System.Drawing.Point(40, $yPos)
    $panel.Controls.Add($timeLimitLabel)
    
    $timeLimitBox = New-Object System.Windows.Forms.NumericUpDown
    $timeLimitBox.Size = New-Object System.Drawing.Size(100, 25)
    $timeLimitBox.Location = New-Object System.Drawing.Point(250, $yPos)
    $timeLimitBox.Minimum = 1
    $timeLimitBox.Maximum = 24
    $timeLimitBox.Value = 6
    $panel.Controls.Add($timeLimitBox)
    
    $yPos += 40
    
    # Bedtime Control
    $bedtimeLabel = New-Object System.Windows.Forms.Label
    $bedtimeLabel.Text = "Bedtime (No computer after):"
    $bedtimeLabel.Size = New-Object System.Drawing.Size(200, 25)
    $bedtimeLabel.Location = New-Object System.Drawing.Point(40, $yPos)
    $panel.Controls.Add($bedtimeLabel)
    
    $bedtimePicker = New-Object System.Windows.Forms.DateTimePicker
    $bedtimePicker.Size = New-Object System.Drawing.Size(100, 25)
    $bedtimePicker.Location = New-Object System.Drawing.Point(250, $yPos)
    $bedtimePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Time
    $bedtimePicker.ShowUpDown = $true
    $bedtimePicker.Value = [DateTime]::Parse("10:00 PM")
    $panel.Controls.Add($bedtimePicker)
    
    $yPos += 40
    
    # Block Specific Apps
    $blockAppsLabel = New-Object System.Windows.Forms.Label
    $blockAppsLabel.Text = "Block Specific Applications:"
    $blockAppsLabel.Size = New-Object System.Drawing.Size(200, 25)
    $blockAppsLabel.Location = New-Object System.Drawing.Point(40, $yPos)
    $panel.Controls.Add($blockAppsLabel)
    
    $blockAppsBox = New-Object System.Windows.Forms.TextBox
    $blockAppsBox.Size = New-Object System.Drawing.Size(200, 25)
    $blockAppsBox.Location = New-Object System.Drawing.Point(250, $yPos)
    $blockAppsBox.Text = "Steam, Instagram, TikTok"
    $panel.Controls.Add($blockAppsBox)
    
    $yPos += 50
    
    # Save Settings Button
    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = "Save Settings"
    $saveButton.Size = New-Object System.Drawing.Size(150, 40)
    $saveButton.Location = New-Object System.Drawing.Point(40, $yPos)
    $saveButton.BackColor = [System.Drawing.Color]::FromArgb(79, 70, 229)
    $saveButton.ForeColor = [System.Drawing.Color]::White
    $saveButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $saveButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("Settings saved successfully!", "Digital Wellbeing", "OK", "Information")
    })
    $panel.Controls.Add($saveButton)
    
    return $panel
}

function Create-PremiumPanel {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Size = New-Object System.Drawing.Size(960, 680)
    $panel.Location = New-Object System.Drawing.Point(0, 80)
    $panel.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 46)
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = "Premium Features"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::White
    $titleLabel.Size = New-Object System.Drawing.Size(400, 50)
    $titleLabel.Location = New-Object System.Drawing.Point(280, 50)
    $titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $panel.Controls.Add($titleLabel)
    
    $featuresPanel = New-Object System.Windows.Forms.Panel
    $featuresPanel.Size = New-Object System.Drawing.Size(800, 300)
    $featuresPanel.Location = New-Object System.Drawing.Point(80, 150)
    $featuresPanel.BackColor = [System.Drawing.Color]::Transparent
    
    $premiumFeatures = @(
        "Advanced Activity Reports",
        "Real-time Screen Time Alerts",
        "App Blocking Scheduler",
        "Website Filtering",
        "Multi-user Profiles",
        "Cloud Sync & Backup",
        "Focus Mode Automation",
        "24/7 Support"
    )
    
    for ($i = 0; $i -lt $premiumFeatures.Length; $i++) {
        $featureLabel = New-Object System.Windows.Forms.Label
        $featureLabel.Text = ">> $($premiumFeatures[$i])"
        $featureLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14)
        $featureLabel.ForeColor = [System.Drawing.Color]::LightGreen
        $featureLabel.Size = New-Object System.Drawing.Size(350, 30)
        $featureLabel.Location = New-Object System.Drawing.Point(($i % 2 * 400), ([math]::Floor($i / 2) * 40))
        $featuresPanel.Controls.Add($featureLabel)
    }
    
    $panel.Controls.Add($featuresPanel)
    
    $upgradeButton = New-Object System.Windows.Forms.Button
    $upgradeButton.Text = "UPGRADE TO PREMIUM - 4.99/month"
    $upgradeButton.Size = New-Object System.Drawing.Size(300, 60)
    $upgradeButton.Location = New-Object System.Drawing.Point(330, 500)
    $upgradeButton.BackColor = [System.Drawing.Color]::Gold
    $upgradeButton.ForeColor = [System.Drawing.Color]::Black
    $upgradeButton.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $upgradeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $upgradeButton.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("Thank you for choosing Premium! This is a demo version.", "Digital Wellbeing", "OK", "Information")
    })
    $panel.Controls.Add($upgradeButton)
    
    return $panel
}

function Show-Panel {
    param([string]$panelName)
    
    # Hide all panels
    foreach ($panel in $panels.Values) {
        $panel.Visible = $false
    }
    
    # Show selected panel
    if ($panels.ContainsKey($panelName)) {
        $panels[$panelName].Visible = $true
    }
    
    # Update header
    $welcomeLabel.Text = $panelName
}

# Create and add panels
$panels["Dashboard"] = Create-DashboardPanel
$panels["Activity Details"] = Create-ActivityPanel
$panels["Screen Time"] = Create-ScreenTimePanel
$panels["Notifications"] = Create-NotificationsPanel
$panels["App Usage"] = Create-AppUsagePanel
$panels["Settings"] = Create-SettingsPanel
$panels["Premium"] = Create-PremiumPanel

# Add all panels to content area
foreach ($panel in $panels.Values) {
    $contentPanel.Controls.Add($panel)
}

# Show dashboard by default
Show-Panel "Dashboard"

# Simple application monitoring (without complex Win32 API calls)
function Start-SimpleMonitor {
    # Create timer for monitoring
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 5000  # Check every 5 seconds
    $timer.Add_Tick({
        $currentTime = Get-Date
        $today = $currentTime.ToString("yyyy-MM-dd")
        
        # Track some basic data
        if (-not $global:appData.DailyStats.$today) {
            $global:appData.DailyStats.$today = @{
                StartTime = $currentTime.ToString("HH:mm:ss")
                AppCount = 0
                TotalMinutes = 0
            }
        }
        
        # Update daily stats
        $global:appData.DailyStats.$today.TotalMinutes++
        
        # Save data periodically
        if (($global:appData.DailyStats.$today.TotalMinutes % 5) -eq 0) {
            $global:appData | ConvertTo-Json -Depth 10 | Set-Content $dataFile -Force
        }
    })
    $timer.Start()
    return $timer
}

# Start monitoring
$monitorTimer = Start-SimpleMonitor

# Form closing event
$form.Add_FormClosing({
    if ($monitorTimer) {
        $monitorTimer.Stop()
    }
    # Save final data
    $global:appData | ConvertTo-Json -Depth 10 | Set-Content $dataFile -Force
})

# Show form
[void]$form.ShowDialog()