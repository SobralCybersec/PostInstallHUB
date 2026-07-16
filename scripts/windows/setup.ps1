#Requires -Version 5.1
<#
.SYNOPSIS
    PostInstallHUB — Windows 11 post-install setup script
.DESCRIPTION
    Wraps winrift for system tweaks; adds structured app installation on top.
    Control behaviour via environment variables before running:
        WINDOWS_TWEAKS=1    Run winrift (system audit, tweaks, privacy hardening)
        WINDOWS_DEBLOAT=1   Remove Microsoft bloatware
        WINDOWS_DEV=1       Install WSL2, PowerShell 7, Node, Rust, dev tooling
        WINDOWS_GAMING=1    Install Steam, Epic, GOG, GPU tools
        POSTINSTALL_YES=1   Skip interactive prompts (use defaults)
.EXAMPLE
    $env:WINDOWS_DEV="1"; $env:WINDOWS_DEBLOAT="1"; .\setup.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Tracking ─────────────────────────────────────────────────────────────────
$script:Installed = [System.Collections.Generic.List[string]]::new()
$script:Skipped   = [System.Collections.Generic.List[string]]::new()
$script:Failed    = [System.Collections.Generic.List[string]]::new()

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Step([string]$msg) {
    Write-Host "`n══  $msg" -ForegroundColor Cyan
}

function Write-Info([string]$msg) {
    Write-Host "    $msg" -ForegroundColor Gray
}

function Write-Ok([string]$msg) {
    Write-Host "  v $msg" -ForegroundColor Green
}

function Write-Warn([string]$msg) {
    Write-Host "  ! $msg" -ForegroundColor Yellow
}

function Write-Err([string]$msg) {
    Write-Host "  x $msg" -ForegroundColor Red
}

function Test-Admin {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = [System.Security.Principal.WindowsPrincipal]$id
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WingetPkg([string]$id) {
    $result = winget list --id $id --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0) -and ($result -match [regex]::Escape($id))
}

function Install-WingetPkg([string]$id, [string]$name) {
    if (Test-WingetPkg $id) {
        Write-Info "Already installed: $name ($id)"
        $script:Skipped.Add($name)
        return
    }
    Write-Info "Installing $name ..."
    winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$name installed"
        $script:Installed.Add($name)
    } else {
        Write-Err "$name failed (exit $LASTEXITCODE)"
        $script:Failed.Add($name)
    }
}

# ── Step 1 — Prerequisites ────────────────────────────────────────────────────

function Invoke-Step1Prerequisites {
    Write-Step "Step 1 - Prerequisites"

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Err "winget not found."
        Write-Info "Install App Installer from the Microsoft Store:"
        Write-Info "  https://aka.ms/getwinget"
        Write-Info "Or: ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
        exit 1
    }
    Write-Ok "winget available: $(winget --version)"

    Write-Info "Refreshing winget sources ..."
    winget source update --accept-source-agreements 2>&1 | Out-Null

    if (Test-Admin) {
        Write-Info "Creating system restore point ..."
        try {
            Enable-ComputerRestore -Drive "$env:SystemDrive\"
            Checkpoint-Computer -Description "PostInstallHUB pre-setup" -RestorePointType MODIFY_SETTINGS
            Write-Ok "Restore point created"
        } catch {
            Write-Warn "Restore point failed (non-critical): $_"
        }
    } else {
        Write-Warn "Not running as admin - skipping restore point"
    }
}

# ── Step 2 — Winrift ──────────────────────────────────────────────────────────

function Invoke-Step2Winrift {
    Write-Step "Step 2 - Winrift (system audit + tweaks)"
    Write-Info "winrift covers:"
    Write-Info "  - 33-point system audit"
    Write-Info "  - 13 categories of Windows tweaks"
    Write-Info "  - Privacy hardening (telemetry, tracking, ads)"
    Write-Info "  - Driver detection + benchmark report"
    Write-Warn "Interactive - follow the prompts in the new window."
    Write-Info "Launching winrift ..."

    $cmd   = 'irm https://raw.githubusercontent.com/emylfy/winrift/main/scripts/launch.ps1 | iex'
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
    Start-Process $shell -ArgumentList '-NoProfile', '-Command', $cmd -Wait
    Write-Ok "winrift session finished"
}

# ── Step 3 — Debloat ──────────────────────────────────────────────────────────

function Invoke-Step3Bloat {
    Write-Step "Step 3 - Remove bloatware"

    # ── Primary: Win11Debloat CLI (Raphire/Win11Debloat) ─────────────────────
    Write-Info "Attempting Win11Debloat as primary engine ..."
    $w11dSuccess = $false
    try {
        $w11dScript = irm 'https://debloat.raphi.re/'
        & ([scriptblock]::Create($w11dScript)) `
            -CLI `
            -Silent `
            -NoRestartExplorer `
            -AppRemovalTarget AllUsers `
            -RemoveApps `
            -RemoveGamingApps `
            -DisableTelemetry `
            -DisableSuggestions `
            -DisableLocationServices `
            -DisableFindMyDevice `
            -DisableSearchHistory `
            -DisableEdgeAds `
            -DisableDesktopSpotlight `
            -DisableLockscreenTips `
            -DisableSettings365Ads `
            -DisableSettingsHome `
            -DisableBing `
            -DisableStoreSearchSuggestions `
            -DisableSearchHighlights `
            -DisableCopilot `
            -DisableRecall `
            -DisableClickToDo `
            -DisableAISvcAutoStart `
            -DisableEdgeAI `
            -DisablePaintAI `
            -DisableNotepadAI `
            -ClearStart `
            -DisableStartRecommended `
            -RevertContextMenu `
            -DisableMouseAcceleration `
            -DisableStickyKeys `
            -DisableFastStartup `
            -DisableDeliveryOptimization `
            -PreventUpdateAutoReboot `
            -DisableAnimations `
            -DisableTransparency `
            -DisableWidgets `
            -HideChat `
            -HideSearchTb `
            -ShowHiddenFolders `
            -ShowKnownFileExt
        Write-Ok "Win11Debloat completed successfully"
        $w11dSuccess = $true
    } catch {
        Write-Warn "Win11Debloat unavailable or failed: $_ — falling back to manual removal"
    }

    # ── Offline fallback: manual Remove-AppxPackage list ─────────────────────
    if (-not $w11dSuccess) {
        Write-Info "Running offline AppxPackage fallback ..."
        $appx = @(
            'Microsoft.BingNews'
            'Microsoft.BingWeather'
            'Microsoft.GetHelp'
            'Microsoft.Getstarted'
            'Microsoft.MicrosoftOfficeHub'
            'Microsoft.MicrosoftSolitaireCollection'
            'Microsoft.People'
            'Microsoft.WindowsFeedbackHub'
            'Microsoft.XboxApp'
            'Microsoft.XboxGameOverlay'
            'Microsoft.XboxGamingOverlay'
            'Microsoft.XboxIdentityProvider'
            'Microsoft.ZuneMusic'
            'Microsoft.ZuneVideo'
            'Clipchamp.Clipchamp'
            'MicrosoftCorporationII.MicrosoftFamily'
        )

        foreach ($pkg in $appx) {
            $found = Get-AppxPackage -Name $pkg -AllUsers -ErrorAction SilentlyContinue
            if ($found) {
                try {
                    $found | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    Write-Ok "Removed: $pkg"
                } catch {
                    Write-Warn "Could not remove $pkg (may need admin): $_"
                }
            } else {
                Write-Info "Not present: $pkg"
            }
        }
    }
}

# ── Step 4 — Core apps ────────────────────────────────────────────────────────

function Invoke-Step4Apps {
    Write-Step "Step 4 - Core applications"

    Write-Info "-- Browsers"
    Install-WingetPkg 'Google.Chrome'              'Google Chrome'

    Write-Info "-- Dev tools"
    Install-WingetPkg 'Git.Git'                    'Git'
    Install-WingetPkg 'Microsoft.VisualStudioCode' 'Visual Studio Code'
    Install-WingetPkg 'JanDeDobbeleer.OhMyPosh'   'Oh My Posh'

    Write-Info "-- Terminal"
    Install-WingetPkg 'Microsoft.WindowsTerminal'  'Windows Terminal'

    Write-Info "-- Media"
    Install-WingetPkg 'VideoLAN.VLC'               'VLC'
    Install-WingetPkg 'HandBrake.HandBrake'        'HandBrake'
    Install-WingetPkg 'OBSProject.OBSStudio'       'OBS Studio'

    Write-Info "-- Security"
    Install-WingetPkg 'KeePassXCTeam.KeePassXC'   'KeePassXC'
    Install-WingetPkg 'Malwarebytes.Malwarebytes'  'Malwarebytes'

    Write-Info "-- Productivity"
    Install-WingetPkg 'Obsidian.Obsidian'          'Obsidian'
    Install-WingetPkg '7zip.7zip'                  '7-Zip'
    Install-WingetPkg 'Notepad++.Notepad++'        'Notepad++'

    Write-Info "-- Communication"
    Install-WingetPkg 'Discord.Discord'            'Discord'

    Write-Info "-- Utilities"
    Install-WingetPkg 'Flameshot.Flameshot'        'Flameshot'
    Install-WingetPkg 'qBittorrent.qBittorrent'    'qBittorrent'
}

# ── Step 5 — Dev environment ──────────────────────────────────────────────────

function Invoke-Step5DevEnv {
    Write-Step "Step 5 - Developer environment"

    Write-Info "Installing WSL2 ..."
    wsl --install --no-distribution
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "WSL2 installed (reboot may be required before adding a distro)"
    } else {
        Write-Warn "WSL2 install returned exit $LASTEXITCODE - may already be present"
    }

    Install-WingetPkg 'Microsoft.PowerShell'   'PowerShell 7'
    Install-WingetPkg 'Rustlang.Rustup'        'Rustup'
    Install-WingetPkg 'OpenJS.NodeJS.LTS'      'Node.js LTS'

    # Set Windows Terminal as default console (best-effort, registry)
    Write-Info "Setting Windows Terminal as default console ..."
    try {
        $regPath = 'HKCU:\Console\%%Startup'
        if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name 'DelegationConsole'  -Value '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
        Set-ItemProperty -Path $regPath -Name 'DelegationTerminal' -Value '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
        Write-Ok "Windows Terminal set as default"
    } catch {
        Write-Warn "Could not set default terminal: $_"
    }

    # Git identity
    $autoYes  = ($env:POSTINSTALL_YES -eq '1')
    $gitEmail = $env:GIT_USER_EMAIL
    $gitName  = $env:GIT_USER_NAME

    if (-not $autoYes) {
        if (-not $gitEmail) { $gitEmail = Read-Host "Git user.email (blank to skip)" }
        if (-not $gitName)  { $gitName  = Read-Host "Git user.name  (blank to skip)" }
    }

    if ($gitEmail) { git config --global user.email $gitEmail; Write-Ok "Git email = $gitEmail" }
    if ($gitName)  { git config --global user.name  $gitName;  Write-Ok "Git name  = $gitName"  }
}

# ── Step 6 — Gaming ───────────────────────────────────────────────────────────

function Invoke-Step6Gaming {
    Write-Step "Step 6 - Gaming"

    Install-WingetPkg 'Valve.Steam'                  'Steam'
    Install-WingetPkg 'EpicGames.EpicGamesLauncher'  'Epic Games Launcher'
    Install-WingetPkg 'GOG.Galaxy'                   'GOG Galaxy'
    Install-WingetPkg 'CPUID.CPU-Z'                  'CPU-Z'
    Install-WingetPkg 'TechPowerUp.GPU-Z'            'GPU-Z'
    Install-WingetPkg 'Tobias.NVCleanstall'          'NVCleanstall'

    # Xbox Game Bar
    Write-Info "Enabling Xbox Game Bar ..."
    try {
        Set-ItemProperty `
            -Path  'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR' `
            -Name  'AppCaptureEnabled' `
            -Value 1 -Type DWord -Force
        Write-Ok "Xbox Game Bar enabled"
    } catch {
        Write-Warn "Could not set Game Bar key: $_"
    }

    # GPU-vendor-specific software
    $gpuName = (Get-CimInstance -ClassName Win32_VideoController | Select-Object -First 1).Name
    Write-Info "Detected GPU: $gpuName"

    if ($gpuName -match 'NVIDIA') {
        Install-WingetPkg 'Nvidia.GeForceExperience'       'GeForce Experience'
    } elseif ($gpuName -match 'AMD|Radeon') {
        Install-WingetPkg 'AMD.SoftwareAdrenalinEdition'   'AMD Software: Adrenalin Edition'
    } else {
        Write-Warn "GPU vendor unknown from '$gpuName' - skipping GPU software"
    }
}

# ── Step 7 — Summary ──────────────────────────────────────────────────────────

function Invoke-Step8Activate {
    Write-Host "`n== Step 8: Windows activation (MAS) ==" -ForegroundColor Cyan
    Write-Info "Running Microsoft Activation Scripts (get.activated.win) ..."
    try {
        irm https://get.activated.win | iex
        Write-Ok "Activation script finished."
    } catch {
        Write-Err "Activation script failed: $($_.Exception.Message)"
        $script:Failed += 'Windows activation (MAS)'
    }
}

function Invoke-Step7Summary {
    $line = '=' * 60
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "  PostInstallHUB - done" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan

    if ($script:Installed.Count -gt 0) {
        Write-Host "`n  Installed ($($script:Installed.Count)):" -ForegroundColor Green
        $script:Installed | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green }
    }

    if ($script:Skipped.Count -gt 0) {
        Write-Host "`n  Already present ($($script:Skipped.Count)):" -ForegroundColor Gray
        $script:Skipped | ForEach-Object { Write-Host "    . $_" -ForegroundColor Gray }
    }

    if ($script:Failed.Count -gt 0) {
        Write-Host "`n  Failed ($($script:Failed.Count)):" -ForegroundColor Red
        $script:Failed | ForEach-Object { Write-Host "    x $_" -ForegroundColor Red }
    }

    Write-Host "`n  -- Manual steps --" -ForegroundColor Yellow
    Write-Host "  1. Developer Mode: Settings -> System -> For developers" -ForegroundColor Yellow
    Write-Host "  2. WSL distro (after reboot if WSL was freshly installed):" -ForegroundColor Yellow
    Write-Host "       wsl --install -d Ubuntu" -ForegroundColor Gray
    Write-Host "       wsl --install -d kali-linux" -ForegroundColor Gray
    Write-Host "  3. Windows activation (skipped unless WINDOWS_ACTIVATE=1):" -ForegroundColor Yellow
    Write-Host "       irm https://get.activated.win | iex" -ForegroundColor Gray
    Write-Host "  4. BitLocker: Settings -> Privacy & security -> Device encryption" -ForegroundColor Yellow
    Write-Host "  5. Full winrift audit (if WINDOWS_TWEAKS was not set):" -ForegroundColor Yellow
    Write-Host "       irm https://raw.githubusercontent.com/emylfy/winrift/main/scripts/launch.ps1 | iex" -ForegroundColor Gray
    Write-Host "  6. Reboot to finalise all changes.`n" -ForegroundColor Yellow
}

# ── Main ──────────────────────────────────────────────────────────────────────

if (-not $env:WINDOWS_TWEAKS)   { $env:WINDOWS_TWEAKS   = '0' }
if (-not $env:WINDOWS_DEBLOAT)  { $env:WINDOWS_DEBLOAT  = '0' }
if (-not $env:WINDOWS_DEV)      { $env:WINDOWS_DEV      = '0' }
if (-not $env:WINDOWS_GAMING)   { $env:WINDOWS_GAMING   = '0' }
if (-not $env:WINDOWS_ACTIVATE) { $env:WINDOWS_ACTIVATE = '0' }
if (-not $env:POSTINSTALL_YES)  { $env:POSTINSTALL_YES  = '0' }

Write-Host "PostInstallHUB - Windows 11 setup" -ForegroundColor Cyan
Write-Host "Flags: TWEAKS=$($env:WINDOWS_TWEAKS)  DEBLOAT=$($env:WINDOWS_DEBLOAT)  DEV=$($env:WINDOWS_DEV)  GAMING=$($env:WINDOWS_GAMING)  ACTIVATE=$($env:WINDOWS_ACTIVATE)" -ForegroundColor Gray

Invoke-Step1Prerequisites
Invoke-Step4Apps

if ($env:WINDOWS_TWEAKS   -eq '1') { Invoke-Step2Winrift }
if ($env:WINDOWS_DEBLOAT  -eq '1') { Invoke-Step3Bloat   }
if ($env:WINDOWS_DEV      -eq '1') { Invoke-Step5DevEnv  }
if ($env:WINDOWS_GAMING   -eq '1') { Invoke-Step6Gaming  }
if ($env:WINDOWS_ACTIVATE -eq '1') { Invoke-Step8Activate }

Invoke-Step7Summary
