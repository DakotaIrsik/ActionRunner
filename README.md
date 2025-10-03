# ActionRunner

A secure, self-hosted GitHub Actions runner setup for Windows environments with comprehensive security controls and best practices.

## ⚠️ Security Notice

**CRITICAL**: Self-hosted runners should NEVER be used with public repositories or untrusted pull requests. Malicious code can execute arbitrary commands, steal secrets, and compromise your infrastructure.

For detailed security information, see [Security Documentation](docs/security.md).

## Quick Start

### 1. Download and Install GitHub Actions Runner

```powershell
# Create runner directory
mkdir C:\actions-runner
cd C:\actions-runner

# Download the latest runner (check GitHub for current version)
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-win-x64-2.328.0.zip -OutFile actions-runner-win-x64.zip

# Extract
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner-win-x64.zip", "$PWD")
```

### 2. Security Setup (REQUIRED)

**Before configuring the runner, implement security controls:**

Clone this repository and run the security scripts:

```powershell
# Run as Administrator
cd C:\

# Clone the ActionRunner repository
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# Step 1: Create secure service account with limited permissions
.\config\runner-user-setup.ps1

# Step 2: Apply firewall rules for network isolation
.\config\apply-firewall-rules.ps1

# Step 3: Review security settings
notepad .\docs\security.md
notepad .\config\firewall-rules.yaml
```

### 3. Configure Runner

```powershell
# Configure the runner (use the service account created above)
# Replace YOUR-REPO with your target repository name (e.g., qiflow, gifdistributor)
# Get YOUR-TOKEN from GitHub: Settings → Actions → Runners → New self-hosted runner
.\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice

# When prompted, use the GitHubRunner account created by runner-user-setup.ps1
```

### 4. Verify Security Configuration

```powershell
# Check service is running as limited user
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Verify firewall rules are active
Get-NetFirewallRule -DisplayName "GitHub Actions Runner*"

# Test runner
cd C:\actions-runner
.\run.cmd
```

## Using the Self-Hosted Runners

### Available Runners

The following self-hosted runners are configured and available:

| Repository | Runner Labels | Docker Support |
|------------|---------------|----------------|
| **ActionRunner** | `self-hosted`, `windows`, `docker` | ✅ |
| **qiflow** | `self-hosted`, `windows`, `docker` | ✅ |
| **qiflowgo** | `self-hosted`, `windows`, `docker` | ✅ |
| **gifdistributor** | `self-hosted`, `windows`, `docker` | ✅ |

**Note**: The `docker` label is optional. Use `runs-on: [self-hosted, windows]` for standard workflows, or add `docker` when you need container isolation.

### Workflow Configuration

To use the self-hosted runners in your GitHub Actions workflows, specify the runner labels in the `runs-on` field:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, feature/* ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    name: Build and Test
    runs-on: [self-hosted, windows, docker]  # Use self-hosted runner

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        shell: powershell  # Use 'powershell' not 'pwsh'
        run: |
          Write-Host "Running tests..."
          # Your test commands here
```

### Shell Compatibility

**IMPORTANT:** Use `shell: powershell` (Windows PowerShell) instead of `shell: pwsh` (PowerShell Core):

```yaml
# ✅ CORRECT - Use Windows PowerShell
- name: My Step
  shell: powershell
  run: |
    Write-Host "This works!"

# ❌ INCORRECT - PowerShell Core not installed
- name: My Step
  shell: pwsh
  run: |
    Write-Host "This fails!"
```

### Docker Isolation

All runners support Docker for containerized builds:

```yaml
jobs:
  docker-build:
    runs-on: [self-hosted, windows, docker]

    steps:
      - name: Build in Docker
        shell: powershell
        run: |
          docker build -t myapp .
          docker run --rm myapp npm test
```

### Example Workflows

See the workflow in this repository for a complete example:
- **[.github/workflows/ci.yml](.github/workflows/ci.yml)** - CI/CD pipeline with tests and validation

### Best Practices

1. **Always specify runner labels explicitly**: `runs-on: [self-hosted, windows, docker]`
2. **Use `powershell` shell**: Avoid `pwsh` as PowerShell Core is not installed
3. **Avoid UTF-8 special characters**: Use `[OK]` instead of `✓` in PowerShell output
4. **Clean up after jobs**: Use `if: always()` for cleanup steps
5. **Use Docker for untrusted code**: Isolate builds in containers when possible

## Jesus Project Runner Setup

For the **Jesus MCP Agentic AI Platform** project, which requires Node.js, Python, and Docker support, use the development stack installation script:

### Quick Setup (Windows)

```powershell
# 1. Clone this repository
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# 2. Run the environment setup script
.\scripts\setup-runner-environment.ps1

# 3. Verify installation
node --version     # Should show v20.x
pnpm --version     # Should show 9.x
python --version   # Should show 3.11.x
docker --version
```

### Stack Components

The setup script (`setup-runner-environment.ps1`) installs:

- **Node.js 20.x** with **pnpm 9.x** for JavaScript/TypeScript builds
- **Python 3.11** with **pip**, **pip-audit**, and **detect-secrets** for security scanning
- **Docker** verification and configuration
- **OSV Scanner** for vulnerability scanning

### Usage in Jesus Workflows

Update your Jesus project workflows to use the self-hosted runner:

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: [self-hosted, windows, docker]

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        shell: powershell
        run: pnpm install

      - name: Run build
        shell: powershell
        run: pnpm build

      - name: Run tests
        shell: powershell
        run: pnpm test
```

## Security Features

This repository includes comprehensive security controls:

- ✅ **Network Isolation**: Firewall rules restricting inbound/outbound traffic
- ✅ **Least Privilege**: Dedicated service account with minimal permissions
- ✅ **Secrets Management**: Best practices for GitHub secrets and tokens
- ✅ **Container Isolation**: Docker-based workflow execution
- ✅ **Audit Logging**: Comprehensive logging and monitoring
- ✅ **Documentation**: Security risks, best practices, and compliance guidance

## Documentation

- **[Security Guide](docs/security.md)**: Comprehensive security documentation covering risks, network isolation, token management, container isolation, monitoring, and compliance
- **[Migration Guide](docs/migration-guide.md)**: Step-by-step guide for migrating to self-hosted runners
- **[iOS Builds Guide](docs/ios-builds.md)**: macOS runner setup and iOS build integration

## Configuration Files

### Configuration Scripts
- **[config/firewall-rules.yaml](config/firewall-rules.yaml)**: Windows Firewall rules configuration
- **[config/runner-user-setup.ps1](config/runner-user-setup.ps1)**: Service account creation script
- **[config/apply-firewall-rules.ps1](config/apply-firewall-rules.ps1)**: Firewall rules application script

### Migration and Setup Scripts
- **[scripts/migrate-to-self-hosted.ps1](scripts/migrate-to-self-hosted.ps1)**: Automated workflow migration from GitHub-hosted to self-hosted runners
- **[scripts/setup-runner-environment.ps1](scripts/setup-runner-environment.ps1)**: Environment setup for Node.js, Python, Docker and security tools

## Prerequisites

- Windows 10/11 or Windows Server 2019/2022
- PowerShell 5.0 or higher
- Administrator access for initial setup
- Private GitHub repository (NEVER use with public repos)
- Docker Desktop (optional, for container isolation)

## Maintenance

### Regular Tasks

**Weekly:**
- Review runner logs in `C:\actions-runner\_diag\`
- Check firewall logs for blocked connection attempts
- Verify runner service status

**Monthly:**
- Rotate access tokens
- Update GitHub IP ranges in firewall rules
- Apply Windows security updates
- Review security logs

**Quarterly:**
- Full security audit
- Review and update security policies
- Test incident response procedures

### Updating the Runner

```powershell
# Stop the service
Stop-Service actions.runner.*

# Download and extract new version (check GitHub for latest)
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-win-x64-2.328.0.zip -OutFile actions-runner-win-x64.zip

# Extract to runner directory
cd C:\actions-runner
Expand-Archive -Path actions-runner-win-x64.zip -DestinationPath . -Force

# Start the service
Start-Service actions.runner.*
```

## Troubleshooting

### Runner Won't Start
1. Check service account permissions
2. Verify firewall rules allow GitHub connectivity
3. Review logs in `_diag` directory

### Network Connectivity Issues
1. Test HTTPS connectivity: `Test-NetConnection github.com -Port 443`
2. Review firewall logs
3. Verify DNS resolution

### Permission Denied Errors
1. Ensure service account has access to runner directory
2. Check file system permissions
3. Review Windows Event Logs

## Support

For issues or questions:
- Review [Security Documentation](docs/security.md)
- Check GitHub Actions [troubleshooting guide](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/monitoring-and-troubleshooting-self-hosted-runners)
- Contact your organization's security team

## License

This configuration repository is provided as-is for security hardening of GitHub Actions self-hosted runners.

## Contributing

Security improvements and feedback welcome! Please submit issues or pull requests.

---

**Last Updated**: 2025-10-03