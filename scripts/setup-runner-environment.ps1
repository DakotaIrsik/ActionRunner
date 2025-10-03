<#
.SYNOPSIS
    Sets up the complete environment for GitHub Actions self-hosted runner with Node.js, Python, and Docker support.

.DESCRIPTION
    This script automates the setup of a self-hosted GitHub Actions runner environment for the Jesus project.
    It installs and configures:
    - Node.js 20.x with pnpm 9.x
    - Python 3.11 with pip and essential security tools
    - Docker with BuildKit support
    - Security tools (OSV Scanner, etc.)

.PARAMETER SkipNodeJS
    Skip Node.js and pnpm installation

.PARAMETER SkipPython
    Skip Python installation

.PARAMETER SkipDocker
    Skip Docker installation check

.PARAMETER SkipSecurityTools
    Skip security tools installation

.EXAMPLE
    .\setup-runner-environment.ps1
    Sets up complete environment with all components

.EXAMPLE
    .\setup-runner-environment.ps1 -SkipDocker
    Sets up environment without Docker

.NOTES
    Requires: PowerShell 5.0+, Administrator privileges for some installations
    Platform: Windows with WSL2 support recommended, or native Linux support via WSL
#>

[CmdletBinding()]
param(
    [switch]$SkipNodeJS,
    [switch]$SkipPython,
    [switch]$SkipDocker,
    [switch]$SkipSecurityTools,
    [switch]$Validate
)

$ErrorActionPreference = 'Stop'

# Color output helpers
function Write-Status {
    param([string]$Message, [string]$Type = 'Info')

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Error' { 'Red' }
        'Warning' { 'Yellow' }
        default { 'Cyan' }
    }

    $prefix = switch ($Type) {
        'Success' { '✅' }
        'Error' { '❌' }
        'Warning' { '⚠️' }
        default { 'ℹ️' }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-CommandExists {
    param([string]$Command)

    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    try {
        if (Get-Command $Command) {
            return $true
        }
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }

    return $false
}

function Install-NodeJS {
    Write-Status "Setting up Node.js environment..." -Type Info

    # Check if Node.js 20 is already installed
    if (Test-CommandExists 'node') {
        $nodeVersion = node --version
        if ($nodeVersion -match 'v20\.') {
            Write-Status "Node.js 20 already installed: $nodeVersion" -Type Success
        }
        else {
            Write-Status "Found Node.js $nodeVersion, but need v20.x" -Type Warning
            Write-Status "Please install Node.js 20.x from https://nodejs.org/" -Type Warning
            return $false
        }
    }
    else {
        Write-Status "Node.js not found. Install from: https://nodejs.org/dist/latest-v20.x/" -Type Warning
        Write-Status "Download: https://nodejs.org/dist/latest-v20.x/node-v20-x64.msi" -Type Info
        return $false
    }

    # Check/Install pnpm
    if (Test-CommandExists 'pnpm') {
        $pnpmVersion = pnpm --version
        Write-Status "pnpm already installed: v$pnpmVersion" -Type Success
    }
    else {
        Write-Status "Installing pnpm 9.x..." -Type Info
        try {
            npm install -g pnpm@9
            $pnpmVersion = pnpm --version
            Write-Status "pnpm installed: v$pnpmVersion" -Type Success
        }
        catch {
            Write-Status "Failed to install pnpm: $_" -Type Error
            return $false
        }
    }

    return $true
}

function Install-Python {
    Write-Status "Setting up Python environment..." -Type Info

    # Check if Python 3.11 is installed
    $pythonCmd = $null
    foreach ($cmd in @('python', 'python3', 'python3.11')) {
        if (Test-CommandExists $cmd) {
            $version = & $cmd --version 2>&1
            if ($version -match '3\.11\.') {
                $pythonCmd = $cmd
                Write-Status "Python 3.11 found: $version" -Type Success
                break
            }
        }
    }

    if (-not $pythonCmd) {
        Write-Status "Python 3.11 not found" -Type Warning
        Write-Status "Install from: https://www.python.org/downloads/" -Type Info
        Write-Status "Download: https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" -Type Info
        return $false
    }

    # Check pip
    if (Test-CommandExists 'pip' -or Test-CommandExists 'pip3') {
        Write-Status "pip is available" -Type Success
    }
    else {
        Write-Status "pip not found, attempting to install..." -Type Warning
        try {
            & $pythonCmd -m ensurepip --upgrade
            Write-Status "pip installed successfully" -Type Success
        }
        catch {
            Write-Status "Failed to install pip: $_" -Type Error
            return $false
        }
    }

    # Install security tools
    if (-not $SkipSecurityTools) {
        Write-Status "Installing Python security tools..." -Type Info

        $tools = @('pip-audit', 'detect-secrets')
        foreach ($tool in $tools) {
            try {
                & $pythonCmd -m pip install $tool --quiet
                Write-Status "$tool installed" -Type Success
            }
            catch {
                Write-Status "Warning: Failed to install $tool : $_" -Type Warning
            }
        }
    }

    return $true
}

function Test-Docker {
    Write-Status "Checking Docker setup..." -Type Info

    if (-not (Test-CommandExists 'docker')) {
        Write-Status "Docker not found" -Type Warning
        Write-Status "Install Docker Desktop from: https://www.docker.com/products/docker-desktop" -Type Info
        return $false
    }

    try {
        $dockerVersion = docker --version
        Write-Status "Docker installed: $dockerVersion" -Type Success

        # Check Docker is running
        docker ps > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Docker daemon is running" -Type Success
        }
        else {
            Write-Status "Docker daemon is not running. Please start Docker Desktop" -Type Warning
            return $false
        }

        # Check BuildKit
        if (Test-CommandExists 'docker buildx') {
            $buildxVersion = docker buildx version
            Write-Status "Docker Buildx available: $buildxVersion" -Type Success
        }
        else {
            Write-Status "Docker Buildx not found (required for BuildKit)" -Type Warning
        }
    }
    catch {
        Write-Status "Docker check failed: $_" -Type Error
        return $false
    }

    return $true
}

function Install-SecurityTools {
    Write-Status "Setting up security tools..." -Type Info

    # Check curl
    if (Test-CommandExists 'curl') {
        Write-Status "curl is available" -Type Success
    }
    else {
        Write-Status "curl not found (required for OSV Scanner installation)" -Type Warning
    }

    # Check OSV Scanner
    if (Test-CommandExists 'osv-scanner') {
        $osvVersion = osv-scanner --version 2>&1
        Write-Status "OSV Scanner installed: $osvVersion" -Type Success
    }
    else {
        Write-Status "OSV Scanner not found" -Type Warning
        Write-Status "Install from: https://google.github.io/osv-scanner/installation/" -Type Info

        # Attempt automatic installation (Windows)
        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            Write-Status "Attempting to install OSV Scanner..." -Type Info
            try {
                $osvUrl = "https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_windows_amd64.exe"
                $osvPath = "$env:USERPROFILE\osv-scanner.exe"

                Invoke-WebRequest -Uri $osvUrl -OutFile $osvPath

                # Add to PATH (session only)
                $env:PATH = "$env:USERPROFILE;$env:PATH"

                Write-Status "OSV Scanner installed to: $osvPath" -Type Success
                Write-Status "Add $env:USERPROFILE to your PATH permanently for future sessions" -Type Info
            }
            catch {
                Write-Status "Failed to install OSV Scanner: $_" -Type Warning
            }
        }
    }

    return $true
}

function Test-DiskSpace {
    Write-Status "Checking disk space..." -Type Info

    $drive = (Get-Location).Drive
    $freeSpace = [math]::Round($drive.Free / 1GB, 2)

    Write-Status "Free space on $($drive.Name): ${freeSpace}GB" -Type Info

    if ($freeSpace -lt 100) {
        Write-Status "Warning: Less than 100GB free. Minimum 100GB recommended, 500GB+ preferred" -Type Warning
        return $false
    }
    elseif ($freeSpace -lt 500) {
        Write-Status "Disk space acceptable (100GB+), but 500GB+ recommended for MCP development" -Type Warning
    }
    else {
        Write-Status "Disk space sufficient (500GB+)" -Type Success
    }

    return $true
}

function Show-Summary {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Runner Environment Setup Summary" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan

    $results = @()

    # Node.js check
    if (Test-CommandExists 'node') {
        $nodeVer = node --version
        $results += "✅ Node.js: $nodeVer"
    }
    else {
        $results += "❌ Node.js: Not installed"
    }

    # pnpm check
    if (Test-CommandExists 'pnpm') {
        $pnpmVer = pnpm --version
        $results += "✅ pnpm: v$pnpmVer"
    }
    else {
        $results += "❌ pnpm: Not installed"
    }

    # Python check
    $pythonFound = $false
    foreach ($cmd in @('python', 'python3', 'python3.11')) {
        if (Test-CommandExists $cmd) {
            $pyVer = & $cmd --version 2>&1
            if ($pyVer -match '3\.11') {
                $results += "✅ Python: $pyVer"
                $pythonFound = $true
                break
            }
        }
    }
    if (-not $pythonFound) {
        $results += "❌ Python 3.11: Not installed"
    }

    # Docker check
    if (Test-CommandExists 'docker') {
        $dockerVer = docker --version
        $results += "✅ Docker: $dockerVer"
    }
    else {
        $results += "❌ Docker: Not installed"
    }

    # Security tools
    if (Test-CommandExists 'osv-scanner') {
        $results += "✅ OSV Scanner: Installed"
    }
    else {
        $results += "⚠️ OSV Scanner: Not installed"
    }

    foreach ($result in $results) {
        Write-Host "  $result"
    }

    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Configure GitHub Actions runner: .\config.cmd --url <repo-url> --token <token>" -ForegroundColor White
    Write-Host "  2. Set up security controls: .\config\runner-user-setup.ps1" -ForegroundColor White
    Write-Host "  3. Apply firewall rules: .\config\apply-firewall-rules.ps1" -ForegroundColor White
    Write-Host "  4. Run CI workflows to validate setup" -ForegroundColor White
    Write-Host "="*60 -ForegroundColor Cyan
}

# Main execution
try {
    Write-Host "`nGitHub Actions Self-Hosted Runner Environment Setup" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host ""

    $allSuccess = $true

    if (-not $SkipNodeJS) {
        $allSuccess = (Install-NodeJS) -and $allSuccess
    }

    if (-not $SkipPython) {
        $allSuccess = (Install-Python) -and $allSuccess
    }

    if (-not $SkipDocker) {
        $allSuccess = (Test-Docker) -and $allSuccess
    }

    if (-not $SkipSecurityTools) {
        $allSuccess = (Install-SecurityTools) -and $allSuccess
    }

    Test-DiskSpace | Out-Null

    Write-Host ""
    Show-Summary

    if ($allSuccess) {
        Write-Status "`nEnvironment setup completed successfully!" -Type Success
        exit 0
    }
    else {
        Write-Status "`nEnvironment setup completed with warnings. Please address issues above." -Type Warning
        exit 0
    }
}
catch {
    Write-Status "Setup failed: $_" -Type Error
    exit 1
}
