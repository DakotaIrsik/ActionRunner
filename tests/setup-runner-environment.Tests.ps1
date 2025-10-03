BeforeAll {
    $script:scriptPath = Join-Path (Join-Path $PSScriptRoot '..') 'scripts\setup-runner-environment.ps1'
}

Describe 'setup-runner-environment.ps1' {
    Context 'Script Structure' {
        It 'Should exist' {
            $script:scriptPath | Should -Exist
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should have help documentation' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.EXAMPLE'
        }
    }

    Context 'Parameters' {
        It 'Should have SkipNodeJS parameter' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\[switch\]\$SkipNodeJS'
        }

        It 'Should have SkipPython parameter' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\[switch\]\$SkipPython'
        }

        It 'Should have SkipDocker parameter' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\[switch\]\$SkipDocker'
        }

        It 'Should have SkipSecurityTools parameter' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\[switch\]\$SkipSecurityTools'
        }
    }

    Context 'Helper Functions' {
        It 'Should define Write-Status function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Write-Status'
        }

        It 'Should define Test-CommandExists function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Test-CommandExists'
        }

        It 'Should define Install-NodeJS function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Install-NodeJS'
        }

        It 'Should define Install-Python function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Install-Python'
        }

        It 'Should define Test-Docker function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Test-Docker'
        }

        It 'Should define Install-SecurityTools function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Install-SecurityTools'
        }

        It 'Should define Test-DiskSpace function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Test-DiskSpace'
        }

        It 'Should define Show-Summary function' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'function Show-Summary'
        }
    }

    Context 'Node.js Setup' {
        It 'Should check for Node.js 20' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match "v20\."
        }

        It 'Should install pnpm 9' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'npm install -g pnpm@9'
        }
    }

    Context 'Python Setup' {
        It 'Should check for Python 3.11' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '3\.11\.'
        }

        It 'Should install pip-audit' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'pip-audit'
        }

        It 'Should install detect-secrets' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'detect-secrets'
        }
    }

    Context 'Docker Setup' {
        It 'Should check for Docker' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'docker --version'
        }

        It 'Should check for Docker Buildx' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'docker buildx'
        }

        It 'Should verify Docker daemon is running' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'docker ps'
        }
    }

    Context 'Security Tools' {
        It 'Should check for curl' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'curl'
        }

        It 'Should check for OSV Scanner' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'osv-scanner'
        }

        It 'Should provide OSV Scanner installation instructions' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'google.github.io/osv-scanner'
        }
    }

    Context 'Disk Space Check' {
        It 'Should check for minimum 100GB free space' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '100'
        }

        It 'Should recommend 500GB for MCP development' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '500'
        }
    }

    Context 'Error Handling' {
        It 'Should set ErrorActionPreference to Stop' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference\s*=\s*''Stop'''
        }

        It 'Should have try-catch for main execution' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'try\s*\{[\s\S]*\}\s*catch'
        }
    }

    Context 'Output and Summary' {
        It 'Should display summary of installed components' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'Show-Summary'
        }

        It 'Should provide next steps guidance' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'Next Steps:'
        }

        It 'Should mention runner configuration' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'config\.cmd'
        }

        It 'Should mention security setup' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'runner-user-setup\.ps1'
        }

        It 'Should mention firewall rules' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'apply-firewall-rules\.ps1'
        }
    }

    Context 'Jesus Project Requirements' {
        It 'Should support Node.js 20 requirement' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'Node\.js 20'
        }

        It 'Should support Python 3.11 requirement' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'Python 3\.11'
        }

        It 'Should support Docker BuildKit requirement' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'BuildKit'
        }

        It 'Should support pnpm workspace (monorepo) requirement' {
            $content = Get-Content $script:scriptPath -Raw
            $content | Should -Match 'pnpm'
        }
    }
}
