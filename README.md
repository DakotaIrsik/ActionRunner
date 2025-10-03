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

```powershell
# Run as Administrator

# Step 1: Create secure service account with limited permissions
.\config\runner-user-setup.ps1

# Step 2: Apply firewall rules for network isolation
.\config\apply-firewall-rules.ps1

# Step 3: Review and customize security settings
notepad .\docs\security.md
notepad .\config\firewall-rules.yaml
```

### 3. Configure Runner

```powershell
# Configure the runner (use the service account created above)
# Replace YOUR-ORG and YOUR-REPO with your GitHub organization/repository
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN --runasservice

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

## Security Features

This repository includes comprehensive security controls:

- ✅ **Network Isolation**: Firewall rules restricting inbound/outbound traffic
- ✅ **Least Privilege**: Dedicated service account with minimal permissions
- ✅ **Secrets Management**: Best practices for GitHub secrets and tokens
- ✅ **Container Isolation**: Docker-based workflow execution
- ✅ **Audit Logging**: Comprehensive logging and monitoring
- ✅ **Documentation**: Security risks, best practices, and compliance guidance

## Documentation

- **[Migration Guide](docs/migration-guide.md)**: Step-by-step guide for migrating to self-hosted runner
  - Environment setup automation
  - Security configuration
  - Jesus project specific requirements
  - Troubleshooting and rollback procedures

- **[Security Guide](docs/security.md)**: Comprehensive security documentation
  - Security risks and mitigation strategies
  - Network isolation and firewall configuration
  - Token management and rotation
  - Container isolation with Docker
  - Monitoring and incident response
  - Compliance considerations

- **[macOS/iOS Build Integration](docs/ios-builds.md)**: Guide for hybrid runner setup
  - Cost analysis: GitHub-hosted vs self-hosted Mac
  - React Native iOS build workflows
  - Code signing setup and requirements

## Configuration Files

- **[scripts/setup-runner-environment.ps1](scripts/setup-runner-environment.ps1)**: Automated environment setup for Node.js, Python, Docker
- **[config/firewall-rules.yaml](config/firewall-rules.yaml)**: Windows Firewall rules configuration
- **[config/runner-user-setup.ps1](config/runner-user-setup.ps1)**: Service account creation script
- **[config/apply-firewall-rules.ps1](config/apply-firewall-rules.ps1)**: Firewall rules application script

## Development

This repository includes automated testing via GitHub Actions CI:

- **PowerShell Script Tests**: Validates all scripts with Pester
- **Configuration Validation**: Checks YAML syntax and workflow files
- **Security Scanning**: Detects potential secrets and hardcoded paths

See [.github/workflows/ci.yml](.github/workflows/ci.yml) for details.

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
# Then re-run config

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