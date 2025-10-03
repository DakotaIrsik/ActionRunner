BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $ScriptPath = Join-Path $ProjectRoot "config\apply-firewall-rules.ps1"
    $ConfigPath = Join-Path $ProjectRoot "config\firewall-rules.yaml"
}

Describe "apply-firewall-rules.ps1" {
    Context "Script Structure and Validation" {
        It "Should exist" {
            Test-Path $ScriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "Should have proper help documentation" {
            $help = Get-Help $ScriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It "Should have example usage in help" {
            $help = Get-Help $ScriptPath
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }

        It "Should require Administrator privileges" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match '#Requires -RunAsAdministrator'
        }

        It "Should set ErrorActionPreference to Stop" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*["\x27]Stop["\x27]'
        }
    }

    Context "Parameter Validation" {
        BeforeAll {
            $params = (Get-Command $ScriptPath).Parameters
        }

        It "Should have optional ConfigFile parameter" {
            $params.ContainsKey('ConfigFile') | Should -Be $true
            $params['ConfigFile'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional RemoveExisting switch parameter" {
            $params.ContainsKey('RemoveExisting') | Should -Be $true
            $params['RemoveExisting'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have optional DryRun switch parameter" {
            $params.ContainsKey('DryRun') | Should -Be $true
            $params['DryRun'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should default ConfigFile to firewall-rules.yaml in script directory" {
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match 'firewall-rules\.yaml'
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should define Write-Success function" {
            $scriptContent | Should -Match 'function Write-Success'
        }

        It "Should define Write-Warning function" {
            $scriptContent | Should -Match 'function Write-Warning'
        }

        It "Should define Write-Info function" {
            $scriptContent | Should -Match 'function Write-Info'
        }

        It "Should define Write-Error function" {
            $scriptContent | Should -Match 'function Write-Error'
        }

        It "Should define Test-Prerequisites function" {
            $scriptContent | Should -Match 'function Test-Prerequisites'
        }

        It "Should define Remove-ExistingRules function" {
            $scriptContent | Should -Match 'function Remove-ExistingRules'
        }

        It "Should define Set-FirewallRules function" {
            $scriptContent | Should -Match 'function Set-FirewallRules'
        }

        It "Should define Enable-FirewallLogging function" {
            $scriptContent | Should -Match 'function Enable-FirewallLogging'
        }

        It "Should define Show-Summary function" {
            $scriptContent | Should -Match 'function Show-Summary'
        }

        It "Should define Main function" {
            $scriptContent | Should -Match 'function Main'
        }
    }

    Context "Firewall Rules Configuration" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should create inbound block rule" {
            $scriptContent | Should -Match 'Block All Inbound'
            $scriptContent | Should -Match 'Direction Inbound'
            $scriptContent | Should -Match 'Action Block'
        }

        It "Should configure DNS outbound rule" {
            $scriptContent | Should -Match 'DNS'
            $scriptContent | Should -Match 'RemotePort 53'
            $scriptContent | Should -Match 'Protocol UDP'
        }

        It "Should configure GitHub HTTPS outbound rule" {
            $scriptContent | Should -Match 'GitHub HTTPS'
            $scriptContent | Should -Match 'RemotePort 443'
            $scriptContent | Should -Match 'Protocol TCP'
        }

        It "Should configure Windows Update rule" {
            $scriptContent | Should -Match 'Windows Update'
            $scriptContent | Should -Match 'Service wuauserv'
        }

        It "Should configure NTP outbound rule" {
            $scriptContent | Should -Match 'NTP'
            $scriptContent | Should -Match 'RemotePort 123'
            $scriptContent | Should -Match 'Protocol UDP'
        }

        It "Should create outbound block rule for other traffic" {
            $scriptContent | Should -Match 'Block All Other Outbound'
            $scriptContent | Should -Match 'Direction Outbound'
            $scriptContent | Should -Match 'Action Block'
        }

        It "Should use consistent rule naming prefix" {
            $scriptContent | Should -Match 'GitHub Actions Runner -'
        }
    }

    Context "Security Features" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should check for Administrator privileges" {
            $scriptContent | Should -Match 'WindowsBuiltInRole.*Administrator'
        }

        It "Should enable firewall logging" {
            $scriptContent | Should -Match 'Set-NetFirewallProfile'
            $scriptContent | Should -Match 'LogAllowed True'
            $scriptContent | Should -Match 'LogBlocked True'
        }

        It "Should configure log file size" {
            $scriptContent | Should -Match 'LogMaxSizeKilobytes'
        }

        It "Should apply rules to all profiles" {
            $scriptContent | Should -Match 'Profile Any|Domain,Public,Private'
        }

        It "Should validate config file exists" {
            $scriptContent | Should -Match 'Test-Path.*ConfigFile'
        }
    }

    Context "DryRun Mode Support" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should check DryRun flag before making changes" {
            $scriptContent | Should -Match 'if.*\$DryRun'
        }

        It "Should log DRY RUN messages when enabled" {
            $scriptContent | Should -Match '\[DRY RUN\]'
        }

        It "Should skip firewall rule creation in DryRun mode" {
            $scriptContent | Should -Match 'Would create.*rule'
        }
    }

    Context "Error Handling" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should use ErrorActionPreference Stop for strict error handling" {
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"`"]Stop[''"`"]'
        }

        It "Should handle missing config file" {
            $scriptContent | Should -Match 'Configuration file not found'
        }

        It "Should exit with error code on critical failures" {
            $scriptContent | Should -Match 'exit 1'
        }

        It "Should use SilentlyContinue for checking existing rules" {
            $scriptContent | Should -Match 'ErrorAction SilentlyContinue'
        }
    }

    Context "Rule Removal Functionality" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should search for existing runner rules" {
            $scriptContent | Should -Match 'Get-NetFirewallRule.*DisplayName.*GitHub Actions Runner'
        }

        It "Should remove existing rules when RemoveExisting is specified" {
            $scriptContent | Should -Match 'Remove-NetFirewallRule'
        }

        It "Should count existing rules before removal" {
            $scriptContent | Should -Match '\$existingRules\.Count'
        }
    }

    Context "Summary and Reporting" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should display summary of applied rules" {
            $scriptContent | Should -Match 'Show-Summary'
            $scriptContent | Should -Match 'Firewall Configuration Summary'
        }

        It "Should list active rules" {
            $scriptContent | Should -Match 'Active Rules'
        }

        It "Should display next steps" {
            $scriptContent | Should -Match 'IMPORTANT NEXT STEPS'
        }

        It "Should remind to update GitHub IP ranges" {
            $scriptContent | Should -Match 'Update GitHub IP ranges|api\.github\.com/meta'
        }

        It "Should provide firewall log location" {
            $scriptContent | Should -Match 'pfirewall\.log'
        }
    }

    Context "Best Practices Compliance" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should use CmdletBinding for advanced function features" {
            $scriptContent | Should -Match '\[CmdletBinding\(\)\]'
        }

        It "Should include customization warnings" {
            $scriptContent | Should -Match 'CUSTOMIZE|Customize'
        }

        It "Should warn about RDP rule customization" {
            $scriptContent | Should -Match 'RDP.*customize'
        }

        It "Should output objects to null where appropriate" {
            $scriptContent | Should -Match 'Out-Null'
        }

        It "Should use proper parameter validation" {
            $scriptContent | Should -Match '\[Parameter\('
        }
    }

    Context "Integration Points" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should reference firewall-rules.yaml configuration" {
            Test-Path $ConfigPath | Should -Be $true
        }

        It "Should call Main function for execution" {
            $scriptContent | Should -Match 'Main\s*\$'
        }

        It "Should provide verbose output with colored messages" {
            $scriptContent | Should -Match 'ForegroundColor'
        }
    }
}
