#Requires -Version 5.1
<#
.SYNOPSIS
    PostInstallHUB — smoke tests for setup.ps1 (Windows)
.DESCRIPTION
    Checks winget availability and verifies each Step 4 app is installed.
    Conditionally checks WSL (WINDOWS_DEV=1) and gaming apps (WINDOWS_GAMING=1).
    Exits 0 on full pass, 1 if any check fails.
.EXAMPLE
    .\test_windows.ps1
    $env:WINDOWS_DEV="1"; $env:WINDOWS_GAMING="1"; .\test_windows.ps1
#>

$pass = 0
$fail = 0

function Test-WingetPkg([string]$id) {
    $result = winget list --id $id --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0) -and ($result -match [regex]::Escape($id))
}

function Assert-Pass([string]$label) {
    Write-Host "[PASS] $label" -ForegroundColor Green
    $script:pass++
}

function Assert-Fail([string]$label, [string]$hint = '') {
    $msg = "[FAIL] $label"
    if ($hint) { $msg += " -- $hint" }
    Write-Host $msg -ForegroundColor Red
    $script:fail++
}

function Test-Pkg([string]$id, [string]$name) {
    if (Test-WingetPkg $id) {
        Assert-Pass "$name ($id)"
    } else {
        Assert-Fail "$name ($id)" "run setup.ps1 to install"
    }
}

# ── winget ────────────────────────────────────────────────────────────────────

Write-Host "`n=== winget ===" -ForegroundColor Cyan
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Assert-Pass "winget available ($(winget --version))"
} else {
    Assert-Fail "winget not found" "install from https://aka.ms/getwinget"
}

# ── Step 4 — Core apps ────────────────────────────────────────────────────────

Write-Host "`n=== Step 4: Core apps ===" -ForegroundColor Cyan

Test-Pkg 'Google.Chrome'              'Google Chrome'
Test-Pkg 'Git.Git'                    'Git'
Test-Pkg 'Microsoft.VisualStudioCode' 'Visual Studio Code'
Test-Pkg 'JanDeDobbeleer.OhMyPosh'   'Oh My Posh'
Test-Pkg 'Microsoft.WindowsTerminal'  'Windows Terminal'
Test-Pkg 'VideoLAN.VLC'               'VLC'
Test-Pkg 'HandBrake.HandBrake'        'HandBrake'
Test-Pkg 'OBSProject.OBSStudio'       'OBS Studio'
Test-Pkg 'KeePassXCTeam.KeePassXC'   'KeePassXC'
Test-Pkg 'Malwarebytes.Malwarebytes'  'Malwarebytes'
Test-Pkg 'Obsidian.Obsidian'          'Obsidian'
Test-Pkg '7zip.7zip'                  '7-Zip'
Test-Pkg 'Notepad++.Notepad++'        'Notepad++'
Test-Pkg 'Discord.Discord'            'Discord'
Test-Pkg 'Flameshot.Flameshot'        'Flameshot'
Test-Pkg 'qBittorrent.qBittorrent'    'qBittorrent'

# ── Step 5 — Dev (optional) ───────────────────────────────────────────────────

if ($env:WINDOWS_DEV -eq '1') {
    Write-Host "`n=== Step 5: Dev environment ===" -ForegroundColor Cyan

    # WSL presence: wsl --status exits 0 when WSL is installed
    Write-Host "    Checking WSL2 ..." -ForegroundColor Gray
    wsl --status 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Assert-Pass "WSL2 installed"
    } else {
        Assert-Fail "WSL2 not found" "run: wsl --install"
    }

    Test-Pkg 'Microsoft.PowerShell'  'PowerShell 7'
    Test-Pkg 'Rustlang.Rustup'       'Rustup'
    Test-Pkg 'OpenJS.NodeJS.LTS'     'Node.js LTS'
}

# ── Step 6 — Gaming (optional) ───────────────────────────────────────────────

if ($env:WINDOWS_GAMING -eq '1') {
    Write-Host "`n=== Step 6: Gaming ===" -ForegroundColor Cyan

    Test-Pkg 'Valve.Steam'                  'Steam'
    Test-Pkg 'EpicGames.EpicGamesLauncher'  'Epic Games Launcher'
    Test-Pkg 'GOG.Galaxy'                   'GOG Galaxy'
    Test-Pkg 'CPUID.CPU-Z'                  'CPU-Z'
    Test-Pkg 'TechPowerUp.GPU-Z'            'GPU-Z'
    Test-Pkg 'Tobias.NVCleanstall'          'NVCleanstall'
}

# ── Results ───────────────────────────────────────────────────────────────────

$total = $pass + $fail
Write-Host "`n$('=' * 40)" -ForegroundColor Cyan
Write-Host "Results: $pass/$total passed" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Yellow' })
if ($fail -gt 0) {
    Write-Host "$fail check(s) failed — run setup.ps1 with the appropriate flags" -ForegroundColor Red
}
Write-Host ""

exit $(if ($fail -gt 0) { 1 } else { 0 })
