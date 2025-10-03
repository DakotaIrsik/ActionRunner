<#
.SYNOPSIS
    Migrates GitHub Actions workflows from GitHub-hosted to self-hosted runners.

.DESCRIPTION
    This script helps migrate GitHub Actions workflows to use self-hosted runners by:
    - Scanning workflow files for GitHub-hosted runner configurations
    - Backing up original workflows
    - Updating runs-on to use self-hosted runners
    - Providing a migration report

.PARAMETER WorkflowPath
    Path to the .github/workflows directory (default: .github/workflows)

.PARAMETER RunnerLabels
    Comma-separated list of runner labels (default: self-hosted)

.PARAMETER BackupDir
    Directory to store workflow backups (default: .github/workflows.backup)

.PARAMETER DryRun
    Preview changes without modifying files

.EXAMPLE
    .\migrate-to-self-hosted.ps1
    Migrates all workflows with default settings

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -RunnerLabels "self-hosted,linux,x64" -DryRun
    Preview migration with specific runner labels
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$WorkflowPath = ".github/workflows",

    [Parameter()]
    [string]$RunnerLabels = "self-hosted",

    [Parameter()]
    [string]$BackupDir = ".github/workflows.backup",

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# GitHub-hosted runner identifiers to detect
$GitHubHostedRunners = @(
    'ubuntu-latest', 'ubuntu-22.04', 'ubuntu-20.04',
    'windows-latest', 'windows-2022', 'windows-2019',
    'macos-latest', 'macos-13', 'macos-12', 'macos-11'
)

function Write-Header {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Get-WorkflowFiles {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Workflow path not found: $Path"
    }

    return Get-ChildItem -Path $Path -Filter "*.yml" -File
}

function Test-GitHubHostedRunner {
    param([string]$Content)

    foreach ($runner in $GitHubHostedRunners) {
        if ($Content -match "runs-on:\s+$runner") {
            return $true
        }
        if ($Content -match "runs-on:\s+\[$runner\]") {
            return $true
        }
    }
    return $false
}

function Convert-RunnerConfig {
    param(
        [string]$Content,
        [string]$Labels
    )

    $labelsArray = $Labels -split ',' | ForEach-Object { $_.Trim() }
    $runnerConfig = if ($labelsArray.Count -eq 1) {
        $labelsArray[0]
    } else {
        "[" + ($labelsArray -join ", ") + "]"
    }

    $modified = $Content
    foreach ($runner in $GitHubHostedRunners) {
        # Match both simple and array format
        $modified = $modified -replace "runs-on:\s+$runner", "runs-on: $runnerConfig"
        $modified = $modified -replace "runs-on:\s+\[$runner\]", "runs-on: $runnerConfig"
    }

    return $modified
}

function Backup-Workflow {
    param(
        [string]$FilePath,
        [string]$BackupDirectory
    )

    if (-not (Test-Path $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }

    $fileName = Split-Path $FilePath -Leaf
    $backupPath = Join-Path $BackupDirectory $fileName
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # Add timestamp if backup already exists
    if (Test-Path $backupPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $backupPath = Join-Path $BackupDirectory "$baseName.$timestamp$extension"
    }

    Copy-Item -Path $FilePath -Destination $backupPath -Force
    return $backupPath
}

function Show-Diff {
    param(
        [string]$Original,
        [string]$Modified,
        [string]$FileName
    )

    Write-Host "`nChanges for: $FileName" -ForegroundColor Magenta
    Write-Host "─" * 60

    $originalLines = $Original -split "`n"
    $modifiedLines = $Modified -split "`n"

    for ($i = 0; $i -lt [Math]::Max($originalLines.Count, $modifiedLines.Count); $i++) {
        $origLine = if ($i -lt $originalLines.Count) { $originalLines[$i] } else { "" }
        $modLine = if ($i -lt $modifiedLines.Count) { $modifiedLines[$i] } else { "" }

        if ($origLine -ne $modLine) {
            if ($origLine) {
                Write-Host "- $origLine" -ForegroundColor Red
            }
            if ($modLine) {
                Write-Host "+ $modLine" -ForegroundColor Green
            }
        }
    }
    Write-Host "─" * 60
}

# Main execution
try {
    Write-Header "GitHub Actions Self-Hosted Runner Migration"

    if ($DryRun) {
        Write-Info "Running in DRY-RUN mode - no files will be modified"
    }

    Write-Host "Workflow Path: $WorkflowPath"
    Write-Host "Runner Labels: $RunnerLabels"
    Write-Host "Backup Directory: $BackupDir"

    # Get all workflow files
    Write-Header "Scanning Workflow Files"
    $workflowFiles = Get-WorkflowFiles -Path $WorkflowPath
    Write-Host "Found $($workflowFiles.Count) workflow file(s)"

    # Track migration statistics
    $stats = @{
        Total = $workflowFiles.Count
        Migrated = 0
        AlreadyMigrated = 0
        Skipped = 0
    }

    $migratedFiles = @()

    # Process each workflow
    foreach ($file in $workflowFiles) {
        Write-Host "`nProcessing: $($file.Name)" -ForegroundColor White

        $content = Get-Content -Path $file.FullName -Raw

        # Check if migration is needed
        if (-not (Test-GitHubHostedRunner -Content $content)) {
            Write-Info "Already using self-hosted runners or no runs-on found"
            $stats.AlreadyMigrated++
            continue
        }

        # Convert runner configuration
        $modifiedContent = Convert-RunnerConfig -Content $content -Labels $RunnerLabels

        if ($DryRun) {
            Show-Diff -Original $content -Modified $modifiedContent -FileName $file.Name
            $stats.Migrated++
            $migratedFiles += $file.Name
        } else {
            # Backup original workflow
            $backupPath = Backup-Workflow -FilePath $file.FullName -BackupDirectory $BackupDir
            Write-Info "Backed up to: $backupPath"

            # Write modified content
            Set-Content -Path $file.FullName -Value $modifiedContent -NoNewline
            Write-Success "Migrated: $($file.Name)"

            $stats.Migrated++
            $migratedFiles += $file.Name
        }
    }

    # Migration summary
    Write-Header "Migration Summary"
    Write-Host "Total workflows: $($stats.Total)"
    Write-Host "Migrated: $($stats.Migrated)" -ForegroundColor Green
    Write-Host "Already migrated: $($stats.AlreadyMigrated)" -ForegroundColor Yellow
    Write-Host "Skipped: $($stats.Skipped)" -ForegroundColor Gray

    if ($migratedFiles.Count -gt 0) {
        Write-Host "`nMigrated workflows:" -ForegroundColor Cyan
        $migratedFiles | ForEach-Object { Write-Host "  - $_" }
    }

    if (-not $DryRun -and $stats.Migrated -gt 0) {
        Write-Host "`nNext steps:" -ForegroundColor Magenta
        Write-Host "1. Review the changes in your workflows"
        Write-Host "2. Ensure your self-hosted runner is configured with labels: $RunnerLabels"
        Write-Host "3. Test workflows in a feature branch first"
        Write-Host "4. Commit and push changes: git add .github/workflows && git commit -m 'chore: migrate to self-hosted runners'"
        Write-Host "5. Backups are available in: $BackupDir"
    }

    if ($DryRun) {
        Write-Host "`nRe-run without -DryRun to apply changes" -ForegroundColor Yellow
    }

    Write-Success "Migration completed successfully"

} catch {
    Write-Host "`n[ERROR] Migration failed: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}
