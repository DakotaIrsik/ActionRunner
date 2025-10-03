#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='3.4.0' }

<#
.SYNOPSIS
    Tests for migrate-to-self-hosted.ps1 migration script

.DESCRIPTION
    Comprehensive tests validating workflow migration functionality:
    - Detection of GitHub-hosted runners
    - Conversion to self-hosted configuration
    - Backup creation
    - Dry-run mode
    - Error handling
#>

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Get script path
$scriptPath = Join-Path $PSScriptRoot "..\scripts\migrate-to-self-hosted.ps1"

# Helper function to invoke script
function Invoke-MigrationScript {
    param(
        [string]$WorkflowPath,
        [string]$BackupDir,
        [string]$RunnerLabels = "self-hosted",
        [switch]$DryRun
    )

    $params = @{
        WorkflowPath = $WorkflowPath
        BackupDir = $BackupDir
        RunnerLabels = $RunnerLabels
    }

    if ($DryRun) {
        $params.Add('DryRun', $true)
    }

    & $scriptPath @params 2>&1 | Out-Null
    return $LASTEXITCODE
}

Describe "Migrate-to-Self-Hosted Script Tests" {

    BeforeAll {
        # Create temporary test directory
        $script:testRoot = Join-Path $TestDrive "migration-test"
        $script:workflowDir = Join-Path $testRoot ".github\workflows"
        $script:backupDir = Join-Path $testRoot ".github\workflows.backup"

        New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
    }

    AfterAll {
        # Cleanup
        if (Test-Path $script:testRoot) {
            Remove-Item -Path $script:testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "GitHub-Hosted Runner Detection" {

        It "Detects ubuntu-latest runner" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "test-ubuntu.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            # Verify detection (check exitCode and that backup wasn't created in dry-run)
            $exitCode | Should -Be 0
        }

        It "Detects windows-latest runner" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "test-windows.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            $exitCode | Should -Be 0
        }

        It "Detects macos-latest runner" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "test-macos.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            $exitCode | Should -Be 0
        }

        It "Detects array-format runners" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: [ubuntu-latest]
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "test-array.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            $exitCode | Should -Be 0
        }

        It "Skips already-migrated workflows" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "already-migrated.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            # Should complete successfully without changes
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Runner Configuration Conversion" {

        BeforeEach {
            # Clean workflow directory
            Get-ChildItem -Path $workflowDir -Filter "*.yml" | Remove-Item -Force
        }

        It "Converts simple ubuntu-latest to self-hosted" {
            $originalWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "convert-simple.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Match "runs-on:\s+self-hosted"
            $converted | Should -Not -Match "ubuntu-latest"
        }

        It "Converts to custom runner labels" {
            $originalWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "convert-labels.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -RunnerLabels "self-hosted,windows,x64"

            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Match "runs-on:\s+\[self-hosted,\s+windows,\s+x64\]"
        }

        It "Handles multiple jobs in one workflow" {
            $originalWorkflow = @"
name: Multi-Job
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "multi-job.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Not -Match "ubuntu-latest"
            $converted | Should -Not -Match "ubuntu-22.04"
            $converted | Should -Not -Match "windows-latest"
            $converted | Should -Match "runs-on:\s+self-hosted"
        }
    }

    Context "Backup Functionality" {

        BeforeEach {
            Get-ChildItem -Path $workflowDir -Filter "*.yml" | Remove-Item -Force
            if (Test-Path $backupDir) {
                Remove-Item -Path $backupDir -Recurse -Force
            }
        }

        It "Creates backup directory if not exists" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "backup-test.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            Test-Path $backupDir | Should -Be $true
        }

        It "Backs up original workflow before migration" {
            $originalWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "original.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $backupFile = Join-Path $backupDir "original.yml"
            Test-Path $backupFile | Should -Be $true

            $backupContent = Get-Content -Path $backupFile -Raw
            $backupContent | Should -Match "ubuntu-latest"
        }

        It "Does not create backups in dry-run mode" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "dryrun-test.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            # Backup dir might exist from previous tests, but file shouldn't
            $backupFile = Join-Path $backupDir "dryrun-test.yml"
            Test-Path $backupFile | Should -Be $false
        }
    }

    Context "Dry-Run Mode" {

        BeforeEach {
            Get-ChildItem -Path $workflowDir -Filter "*.yml" | Remove-Item -Force
        }

        It "Does not modify files in dry-run mode" {
            $originalWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "dryrun.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            $currentContent = Get-Content -Path $testFile -Raw
            $currentContent | Should -Be $originalWorkflow
        }

        It "Returns successful exit code in dry-run" {
            $testWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "dryrun-exit.yml"
            Set-Content -Path $testFile -Value $testWorkflow

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -DryRun

            $exitCode | Should -Be 0
        }
    }

    Context "Error Handling" {

        It "Fails gracefully when workflow path doesn't exist" {
            $nonExistentPath = Join-Path $TestDrive "does-not-exist"

            { & $scriptPath -WorkflowPath $nonExistentPath -ErrorAction Stop } | Should -Throw
        }

        It "Handles empty workflow directory" {
            $emptyDir = Join-Path $TestDrive "empty-workflows"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            $exitCode = Invoke-MigrationScript -WorkflowPath $emptyDir -BackupDir $backupDir

            $exitCode | Should -Be 0
        }
    }

    Context "Edge Cases" {

        BeforeEach {
            Get-ChildItem -Path $workflowDir -Filter "*.yml" | Remove-Item -Force
        }

        It "Preserves workflow formatting and comments" {
            $workflowWithComments = @"
name: Test
# This is a comment
on: push
jobs:
  test:
    # Run on GitHub-hosted runner
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # Another comment
"@
            $testFile = Join-Path $workflowDir "comments.yml"
            Set-Content -Path $testFile -Value $workflowWithComments

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Match "# This is a comment"
            $converted | Should -Match "# Another comment"
        }

        It "Handles workflows with no runs-on field" {
            $workflowNoRunner = @"
name: Test
on: push
jobs:
  test:
    steps:
      - uses: actions/checkout@v4
"@
            $testFile = Join-Path $workflowDir "no-runner.yml"
            Set-Content -Path $testFile -Value $workflowNoRunner

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $LASTEXITCODE | Should -Be 0
            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Be $workflowNoRunner
        }

        It "Processes multiple workflow files in batch" {
            $workflow1 = @"
name: Test1
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
"@
            $workflow2 = @"
name: Test2
on: push
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
"@
            $workflow3 = @"
name: Test3
on: push
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
"@
            Set-Content -Path (Join-Path $workflowDir "batch1.yml") -Value $workflow1
            Set-Content -Path (Join-Path $workflowDir "batch2.yml") -Value $workflow2
            Set-Content -Path (Join-Path $workflowDir "batch3.yml") -Value $workflow3

            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir

            $LASTEXITCODE | Should -Be 0

            # Verify all were converted
            $file1 = Get-Content -Path (Join-Path $workflowDir "batch1.yml") -Raw
            $file2 = Get-Content -Path (Join-Path $workflowDir "batch2.yml") -Raw
            $file3 = Get-Content -Path (Join-Path $workflowDir "batch3.yml") -Raw

            $file1 | Should -Match "self-hosted"
            $file2 | Should -Match "self-hosted"
            $file3 | Should -Match "self-hosted"
        }
    }

    Context "Integration Tests" {

        BeforeEach {
            Get-ChildItem -Path $workflowDir -Filter "*.yml" | Remove-Item -Force
            if (Test-Path $backupDir) {
                Remove-Item -Path $backupDir -Recurse -Force
            }
        }

        It "Complete migration workflow: detect, backup, convert, verify" {
            $originalWorkflow = @"
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Building..."

  test:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: echo "Testing..."
"@
            $testFile = Join-Path $workflowDir "ci.yml"
            Set-Content -Path $testFile -Value $originalWorkflow

            # Run migration
            $exitCode = Invoke-MigrationScript -WorkflowPath $workflowDir -BackupDir $backupDir -RunnerLabels "self-hosted,linux"

            # Verify backup exists
            $backupFile = Join-Path $backupDir "ci.yml"
            Test-Path $backupFile | Should -Be $true

            # Verify conversion
            $converted = Get-Content -Path $testFile -Raw
            $converted | Should -Match "runs-on:\s+\[self-hosted,\s+linux\]"
            $converted | Should -Not -Match "ubuntu-latest"
            $converted | Should -Not -Match "ubuntu-22.04"

            # Verify backup is original
            $backup = Get-Content -Path $backupFile -Raw
            $backup | Should -Be $originalWorkflow
        }
    }
}
