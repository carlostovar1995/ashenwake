#Requires -Version 5.1
# TovarLite launch UI - Jagex Account vs title-screen email/password.
# Remembers the last MODE on this PC only. Never collects or writes passwords.
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

$choiceDir = Join-Path $env:LOCALAPPDATA "TovarLite"
$choicePath = Join-Path $choiceDir "launcher-choice.txt"

function Save-LauncherChoice {
    param([string]$Mode)
    try {
        if (-not (Test-Path -LiteralPath $choiceDir)) {
            New-Item -ItemType Directory -Path $choiceDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($choicePath, $Mode)
    } catch { }
}

function Get-LauncherChoice {
    if (-not (Test-Path -LiteralPath $choicePath)) { return "simple" }
    $t = (Get-Content -LiteralPath $choicePath -Raw -ErrorAction SilentlyContinue)
    if (-not $t) { return "simple" }
    switch ($t.Trim()) {
        "jagexdev" { return "jagexdev" }
        default { return "simple" }
    }
}

function Invoke-TovarLiteUpdate {
    param([System.Windows.Forms.Label]$Status)
    $ps1 = Join-Path $root "Update-TovarLite.ps1"
    if (-not (Test-Path -LiteralPath $ps1)) { return }
    if ($Status) {
        $Status.Text = "Checking for RuneLite updates..."
        [System.Windows.Forms.Application]::DoEvents()
    }
    try {
        $p = Start-Process -FilePath $env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $ps1, "-AppDir", $root
        ) -Wait -PassThru -WindowStyle Hidden
        if ($Status) {
            if ($p.ExitCode -eq 0) {
                $Status.Text = "Up to date. Starting..."
            } else {
                $Status.Text = "Update check failed. Starting anyway if possible..."
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch {
        if ($Status) {
            $Status.Text = "Update check failed. Starting anyway if possible..."
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
}

function Invoke-PlayBat {
    param([string]$Arg)
    $bat = Join-Path $root "Play.bat"
    if (-not (Test-Path -LiteralPath $bat)) {
        [System.Windows.Forms.MessageBox]::Show("Play.bat not found in:`n$root", "TovarLite", "OK", "Error") | Out-Null
        return
    }
    Start-Process -FilePath $env:ComSpec -ArgumentList @(
        "/c", "cd /d `"$root`" && call Play.bat $Arg"
    ) -WorkingDirectory $root -WindowStyle Hidden | Out-Null
}

[System.Windows.Forms.Application]::EnableVisualStyles()

$bg = [System.Drawing.Color]::FromArgb(22, 24, 28)
$card = [System.Drawing.Color]::FromArgb(34, 38, 44)
$cardHot = [System.Drawing.Color]::FromArgb(44, 50, 58)
$accent = [System.Drawing.Color]::FromArgb(220, 162, 64)
$text = [System.Drawing.Color]::FromArgb(236, 236, 240)
$muted = [System.Drawing.Color]::FromArgb(156, 163, 175)

$form = New-Object System.Windows.Forms.Form
$form.Text = "TovarLite"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.BackColor = $bg
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$form.ClientSize = New-Object System.Drawing.Size(420, 428)
$form.Padding = New-Object System.Windows.Forms.Padding(0)

$icoPath = Join-Path $root "logo.ico"
if (Test-Path -LiteralPath $icoPath) {
    try { $form.Icon = New-Object System.Drawing.Icon($icoPath) } catch { }
}

$title = New-Object System.Windows.Forms.Label
$title.Text = "TovarLite"
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$title.ForeColor = $text
$title.Location = New-Object System.Drawing.Point(24, 18)
$title.Size = New-Object System.Drawing.Size(372, 34)
$title.BackColor = $bg

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "How do you want to sign in on this computer?"
$sub.ForeColor = $muted
$sub.Location = New-Object System.Drawing.Point(24, 54)
$sub.Size = New-Object System.Drawing.Size(372, 22)
$sub.BackColor = $bg

$status = New-Object System.Windows.Forms.Label
$status.Text = "Each launch updates to the latest RuneLite client."
$status.ForeColor = $accent
$status.Location = New-Object System.Drawing.Point(24, 384)
$status.Size = New-Object System.Drawing.Size(372, 28)
$status.BackColor = $bg

function New-ModeCard {
    param(
        [int]$Y,
        [string]$Heading,
        [string]$Body,
        [string]$Mode
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(24, $Y)
    $panel.Size = New-Object System.Drawing.Size(372, 88)
    $panel.BackColor = $card
    $panel.Cursor = [System.Windows.Forms.Cursors]::Hand
    $panel.Tag = $Mode

    $h = New-Object System.Windows.Forms.Label
    $h.Text = $Heading
    $h.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11.5)
    $h.ForeColor = $text
    $h.Location = New-Object System.Drawing.Point(16, 14)
    $h.Size = New-Object System.Drawing.Size(340, 24)
    $h.BackColor = $card
    $h.Cursor = [System.Windows.Forms.Cursors]::Hand
    $h.Tag = $Mode

    $b = New-Object System.Windows.Forms.Label
    $b.Text = $Body
    $b.ForeColor = $muted
    $b.Location = New-Object System.Drawing.Point(16, 40)
    $b.Size = New-Object System.Drawing.Size(340, 36)
    $b.BackColor = $card
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand
    $b.Tag = $Mode

    $click = {
        $mode = $this.Tag
        Invoke-TovarLiteUpdate -Status $status
        Save-LauncherChoice $mode
        Invoke-PlayBat $mode
        $form.Close()
    }

    $enter = {
        $panel.BackColor = $cardHot
        $h.BackColor = $cardHot
        $b.BackColor = $cardHot
    }.GetNewClosure()
    $leave = {
        $panel.BackColor = $card
        $h.BackColor = $card
        $b.BackColor = $card
    }.GetNewClosure()

    foreach ($ctl in @($panel, $h, $b)) {
        $ctl.Add_Click($click)
        $ctl.Add_MouseEnter($enter)
        $ctl.Add_MouseLeave($leave)
    }

    $panel.Controls.AddRange(@($h, $b))
    return $panel
}

$cardJagex = New-ModeCard -Y 90 -Heading "Jagex Account" -Body "Opens this client for Jagex login on this PC. Uses the official Jagex / RuneLite launcher flow. Tokens stay on this computer." -Mode "jagexdev"
$cardSimple = New-ModeCard -Y 190 -Heading "Email and password" -Body "Opens the Old School title screen. Type your email and password in the game - this launcher never sees them." -Mode "simple"

$note = New-Object System.Windows.Forms.Label
$note.Text = "This copy never stores account passwords, Jagex tokens, or RuneLite session files."
$note.ForeColor = $accent
$note.Location = New-Object System.Drawing.Point(24, 292)
$note.Size = New-Object System.Drawing.Size(372, 36)
$note.BackColor = $bg

$lnk = New-Object System.Windows.Forms.LinkLabel
$lnk.Text = "Open official RuneLite Configure"
$lnk.LinkColor = [System.Drawing.Color]::FromArgb(140, 180, 230)
$lnk.ActiveLinkColor = $accent
$lnk.Location = New-Object System.Drawing.Point(24, 336)
$lnk.Size = New-Object System.Drawing.Size(240, 20)
$lnk.BackColor = $bg
$lnk.Add_LinkClicked({
    $exe = Join-Path $env:LOCALAPPDATA "RuneLite\RuneLite.exe"
    if (Test-Path -LiteralPath $exe) {
        Start-Process -FilePath $exe -ArgumentList "--configure"
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "Official RuneLite launcher not found:`n$exe`n`nInstall from https://runelite.net",
            "TovarLite",
            "OK",
            "Information"
        ) | Out-Null
    }
})

$last = New-Object System.Windows.Forms.Label
$lastChoice = Get-LauncherChoice
$last.Text = if ($lastChoice -eq "jagexdev") { "Last used on this PC: Jagex Account" } else { "Last used on this PC: Email and password" }
$last.ForeColor = $muted
$last.Location = New-Object System.Drawing.Point(24, 360)
$last.Size = New-Object System.Drawing.Size(372, 20)
$last.BackColor = $bg

$form.Controls.AddRange(@($title, $sub, $cardJagex, $cardSimple, $note, $lnk, $last, $status))
[void]$form.ShowDialog()
