# ============================================================
# The MOAM Powerhouse - Windows Installer
# One command installs everything you need.
# ============================================================

$ErrorActionPreference = "Stop"
$Repo   = "manonamission-coaching/moam-powerhouse"
$Folder = "moam-powerhouse"
$Workspace = "$HOME\Documents\$Folder"

function Step($n, $msg) { Write-Host "`n[$n of 6] $msg" -ForegroundColor White }
function Pass($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Doing($msg) { Write-Host "  -> $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  [X] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "==============================================" -ForegroundColor White
Write-Host "  The MOAM Powerhouse - Windows Installer" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White
Write-Host ""
Write-Host "This sets up your AI agent in about 5-15 minutes."
Write-Host "Your browser will open so you can sign in to GitHub."
Write-Host ""

# --- Step 1: winget / GitHub CLI ---
Step 1 "Checking GitHub CLI (connects to the skill library)"
if (Get-Command gh -ErrorAction SilentlyContinue) {
  Pass "GitHub CLI already installed"
} else {
  Doing "Installing GitHub CLI..."
  winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
  if (Get-Command gh -ErrorAction SilentlyContinue) { Pass "GitHub CLI installed" } else { Fail "GitHub CLI failed. Close this window, reopen PowerShell, and run the installer again."; exit 1 }
}

# --- Step 2: GitHub Auth ---
Step 2 "Connecting to GitHub"
& gh auth status *> $null
if ($LASTEXITCODE -eq 0) {
  Pass "Already connected to GitHub"
} else {
  Doing "Opening your browser to connect to GitHub..."
  Write-Host "  You'll see an 8-character code. Copy it, press Enter, paste it, Authorize, come back." -ForegroundColor Yellow
  gh auth login --hostname github.com --git-protocol https --web
  & gh auth status *> $null
  if ($LASTEXITCODE -eq 0) { Pass "Connected" } else { Fail "GitHub connection failed. Try again."; exit 1 }
}

# --- Step 3: Download the workspace ---
Step 3 "Downloading your MOAM Powerhouse"
if ((Test-Path $Workspace) -and (Test-Path "$Workspace\CLAUDE.md")) {
  Pass "Workspace already exists at Documents\$Folder"
  Doing "Checking for updates..."
  & git -C $Workspace pull --ff-only -q *> $null
  if ($LASTEXITCODE -eq 0) { Pass "Up to date with the MOAM library" } else { Doing "Kept your copy as it is. Inside Claude, say: get skills" }
} else {
  Doing "Downloading from the MOAM skill library..."
  & gh api "repos/$Repo" --jq '.name' *> $null
  if ($LASTEXITCODE -ne 0) {
    Fail "Can't access the MOAM Powerhouse library."
    Write-Host "  You probably haven't accepted Matt's invitation yet." -ForegroundColor Yellow
    Write-Host "  Go to github.com/notifications, accept it, then run this again." -ForegroundColor Yellow
    exit 1
  }
  New-Item -ItemType Directory -Force -Path "$HOME\Documents" | Out-Null
  Set-Location "$HOME\Documents"
  gh repo clone $Repo $Folder
  if (Test-Path "$Workspace\CLAUDE.md") { Pass "Workspace downloaded to Documents\$Folder" } else { Fail "Download failed."; exit 1 }
}

# --- Step 3b: Wire skills (Windows uses directory junctions) ---
Doing "Wiring your skills..."
Set-Location $Workspace
New-Item -ItemType Directory -Force -Path ".claude\skills" | Out-Null
Get-ChildItem "my-skills" -Directory | ForEach-Object {
  $link = ".claude\skills\$($_.Name)"
  # git checks the repo's links out as small text files on Windows; replace them
  if ((Test-Path $link) -and -not ((Get-Item $link -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { Remove-Item $link -Force }
  if (-not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $_.FullName | Out-Null }
}
Pass "Skills wired"

# --- Step 3c: Shortcuts that work from any folder ---
# Claude only sees my-skills when it opens inside the Powerhouse folder.
# These small shortcuts point back to it, so "/lets-wrap" works anywhere.
if (Test-Path "$Workspace\global-skills") {
  Get-ChildItem "$Workspace\global-skills" -Directory | ForEach-Object {
    $dest = "$HOME\.claude\skills\$($_.Name)"
    # never overwrite a skill the member made themselves
    $ours = (Test-Path "$dest\SKILL.md") -and (Select-String -Path "$dest\SKILL.md" -Pattern "MOAM-POWERHOUSE-SHORTCUT" -Quiet)
    if ((-not (Test-Path $dest)) -or $ours) {
      New-Item -ItemType Directory -Force -Path $dest | Out-Null
      Copy-Item "$($_.FullName)\SKILL.md" "$dest\SKILL.md" -Force
    }
  }
  Pass "Shortcuts added (lets wrap works from any folder)"
}

# --- Step 4: Claude Code ---
Step 4 "Installing Claude Code (your AI agent)"
if (Get-Command claude -ErrorAction SilentlyContinue) {
  Pass "Claude Code already installed"
} else {
  Doing "Installing Claude Code..."
  irm https://claude.ai/install.ps1 | iex
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path
  if (Get-Command claude -ErrorAction SilentlyContinue) { Pass "Claude Code installed" } else { Fail "Installed, but PowerShell can't find it yet. Close and reopen PowerShell." }
}

# --- Step 5: Desktop launcher ---
Step 5 "Creating Desktop launcher"
$launcher = "$HOME\Desktop\MOAM Powerhouse.bat"
"@echo off`r`ncd /d %USERPROFILE%\Documents\$Folder`r`nclaude" | Out-File -FilePath $launcher -Encoding ascii
Pass "Desktop launcher created - 'MOAM Powerhouse' on your Desktop"

# --- Step 6: Done ---
Step 6 "Activating Claude Code"
Write-Host "  Claude needs to connect to your Claude account on first launch." -ForegroundColor Yellow
Write-Host "  Double-click the Desktop launcher and sign in when the browser opens." -ForegroundColor Yellow
Write-Host ""
Write-Host "==============================================" -ForegroundColor White
Write-Host "          Setup Complete!" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White
Write-Host ""
Write-Host "HOW TO START:" -ForegroundColor White
Write-Host "  1. Double-click 'MOAM Powerhouse' on your Desktop"
Write-Host "  2. Type: build my mission context"
Write-Host "  3. Follow the guided interview (~50 minutes)"
Write-Host ""
Write-Host "  If Claude asks to trust project settings: type y"
Write-Host "  If Claude asks to register skills: say yes, register them all"
Write-Host ""
Write-Host "  You're all set. Build the consistent leader. Then scale the business." -ForegroundColor Green
Write-Host ""
