#Requires -Version 5.1
<#
.SYNOPSIS
    CloudNative Pipeline - Windows Release Packaging Script

.DESCRIPTION
    Creates a distributable Windows release package with SHA256 checksums.
    Run this script before creating a new GitHub release.

.EXAMPLE
    .\create-release.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Version = "",

    [Parameter()]
    [string]$OutputDir = "release"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-Fatal {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    exit 1
}

function Test-ToolAvailable {
    param([string]$Name, [string]$Command)
    Write-Step "Checking $Name..."
    try {
        $null = Get-Command $Command -ErrorAction Stop
        Write-Success "$Name found"
        return $true
    } catch {
        Write-Warning "$Name not found — some features may be unavailable"
        return $false
    }
}

function Get-SafeVersion {
    # Derive version from git tag or fallback to timestamp
    try {
        $tag = git describe --tags --abbrev=0 2>$null
        if ($tag) {
            $tag = $tag.TrimStart("v")
            return $tag
        }
    } catch { }
    return (Get-Date -Format "yyyyMMdd-HHmmss")
}

function Compress-ToZip {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    if (Test-Path $DestinationPath) {
        Remove-Item $DestinationPath -Force
    }
    Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath -CompressionLevel Optimal
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

$ProjectRoot = $PSScriptRoot | Split-Path -Parent

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   CloudNative Pipeline - Windows Release Packager    ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# 1. Resolve version
# ─────────────────────────────────────────────────────────────────────────────
Write-Step "Resolving release version..."

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-SafeVersion
}

Write-Success "Release version: $Version"

# 2. Check for required tools
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Checking required tools..."

$gitOk   = Test-ToolAvailable "git"          "git"
$shaOk   = Test-ToolAvailable "SHA256"       "Get-FileHash"
# docker and docker-compose are optional at pack time
$dockerOk  = Test-ToolAvailable "Docker"      "docker"      $false
$composeOk = Test-ToolAvailable "Docker Compose" "docker-compose" $false

# 3. Verify source files exist
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Verifying source files..."

$RequiredFiles = @(
    "START-WINDOWS.bat",
    "docker-compose.yml",
    ".env.example",
    "README.md",
    "QUICKSTART.md",
    "TROUBLESHOOTING.md"
)

$MissingFiles = @()
foreach ($file in $RequiredFiles) {
    $path = Join-Path $ProjectRoot $file
    if (-not (Test-Path $path)) {
        $MissingFiles += $file
        Write-Warning "Missing: $file"
    } else {
        Write-Success "Found: $file"
    }
}

# Scripts
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ScriptFiles = Get-ChildItem -Path $ScriptsDir -Filter "*.ps1" -File -ErrorAction SilentlyContinue
if ($ScriptFiles) {
    Write-Success "Found $($ScriptFiles.Count) PowerShell script(s) in scripts/"
} else {
    Write-Warning "No .ps1 scripts found in scripts/"
}

if ($MissingFiles.Count -gt 0) {
    Write-Fatal "Required file(s) missing: $($MissingFiles -join ', ')"
}

# 4. Clean & create output directory
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Preparing output directory..."

$ReleaseRoot = Join-Path $ProjectRoot $OutputDir
$VersionDir  = Join-Path $ReleaseRoot "cloudnative-pipeline-$Version"

if (Test-Path $VersionDir) {
    Remove-Item $VersionDir -Recurse -Force
}
if (Test-Path $ReleaseRoot) {
    Remove-Item $ReleaseRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $VersionDir -Force | Out-Null
New-Item -ItemType Directory -Path "$ReleaseRoot\temp" -Force | Out-Null

Write-Success "Created: $VersionDir"

# 5. Copy project files
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Copying project files..."

$CopyMap = @(
    @{ Src = "START-WINDOWS.bat";    Dst = "START-WINDOWS.bat" }
    @{ Src = "docker-compose.yml";  Dst = "docker-compose.yml" }
    @{ Src = ".env.example";         Dst = ".env.example" }
    @{ Src = "README.md";            Dst = "README.md" }
    @{ Src = "QUICKSTART.md";        Dst = "QUICKSTART.md" }
    @{ Src = "TROUBLESHOOTING.md";   Dst = "TROUBLESHOOTING.md" }
)

foreach ($item in $CopyMap) {
    $src = Join-Path $ProjectRoot $item.Src
    $dst = Join-Path $VersionDir  $item.Dst
    Copy-Item -Path $src -Destination $dst -Force
    Write-Success "  Copied: $($item.Dst)"
}

# Copy scripts/
$ScriptsDst = Join-Path $VersionDir "scripts"
New-Item -ItemType Directory -Path $ScriptsDst -Force | Out-Null
foreach ($script in $ScriptFiles) {
    Copy-Item -Path $script.FullName -Destination $ScriptsDst -Force
    Write-Success "  Copied: scripts/$($script.Name)"
}

# 6. Generate RELEASE_NOTES.md from template if it exists
# ─────────────────────────────────────────────────────────────────────────────
$TemplatePath = Join-Path $ProjectRoot "RELEASE_NOTES_TEMPLATE.md"
$ReleaseNotesDst = Join-Path $VersionDir "RELEASE_NOTES.md"

if (Test-Path $TemplatePath) {
    $templateContent = Get-Content $TemplatePath -Raw
    # Replace placeholders
    $templateContent = $templateContent -replace '{{VERSION}}', $Version
    $templateContent = $templateContent -replace '{{DATE}}', (Get-Date -Format "yyyy-MM-dd")
    $templateContent = $templateContent -replace '{{RELEASE_DATE}}', (Get-Date -Format "yyyy年MM月dd日")
    Set-Content -Path $ReleaseNotesDst -Value $templateContent -Encoding UTF8
    Write-Success "Generated: RELEASE_NOTES.md"
} else {
    Write-Warning "RELEASE_NOTES_TEMPLATE.md not found — skipping release notes"
}

# 7. Create distribution ZIP
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Creating distribution package..."

$ZipPath = Join-Path $ReleaseRoot "cloudnative-pipeline-$Version-windows.zip"
Compress-ToZip -SourcePath $VersionDir -DestinationPath $ZipPath
$zipSize = (Get-Item $ZipPath).Length / 1MB
Write-Success "Created: cloudnative-pipeline-$Version-windows.zip ($([math]::Round($zipSize, 2)) MB)"

# 8. Generate SHA256 checksums
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Generating SHA256 checksums..."

$ChecksumFile = Join-Path $ReleaseRoot "SHA256SUMS.txt"
$ItemsToHash = @(
    @{ Path = $ZipPath; Name = "cloudnative-pipeline-$Version-windows.zip" }
)

$hashEntries = @()
foreach ($item in $ItemsToHash) {
    $hash = Get-FileHash -Path $item.Path -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    $entry = "$hash  $($item.Name)"
    $hashEntries += $entry
    Write-Success "  SHA256 ($($item.Name)) = $hash"
}

$hashEntries | Set-Content -Path $ChecksumFile -Encoding UTF8
Write-Success "Created: SHA256SUMS.txt"

# 9. Cleanup temp
# ─────────────────────────────────────────────────────────────────────────────
Remove-Item -Path "$ReleaseRoot\temp" -Recurse -Force -ErrorAction SilentlyContinue

# 10. Summary
# ─────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║              Release Package Summary                  ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Version    : $Version"                           -ForegroundColor White
Write-Host "  Output Dir : $ReleaseRoot"                        -ForegroundColor White
Write-Host ""
Write-Host "  Package    : cloudnative-pipeline-$Version-windows.zip" -ForegroundColor Yellow
Write-Host "  Checksum   : SHA256SUMS.txt"                      -ForegroundColor Yellow
Write-Host ""
Write-Host "  Files included:"                                  -ForegroundColor White
foreach ($item in $CopyMap) {
    Write-Host "    - $($item.Dst)"                              -ForegroundColor DarkGray
}
Write-Host "    - scripts/*.ps1 ($($ScriptFiles.Count) files)"  -ForegroundColor DarkGray
Write-Host "    - RELEASE_NOTES.md"                             -ForegroundColor DarkGray
Write-Host ""
Write-Success "Packaging complete. Upload the contents of the '$OutputDir' folder to your GitHub release."
Write-Host ""
