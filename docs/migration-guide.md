# Migration Guide: GitHub-Hosted to Self-Hosted Runner

## Overview

This guide helps you migrate from GitHub-hosted runners to self-hosted runners to avoid GitHub Actions minutes limits and enable faster CI/CD iterations.

**Target Issue**: [#16 - URGENT: Migrate to self-hosted runner](https://github.com/yourusername/ActionRunner/issues/16)

## Why Migrate?

- ✅ **Unlimited CI/CD minutes**: No more quota restrictions
- ✅ **Faster builds**: Local caching and dedicated resources
- ✅ **Custom environment**: Pre-installed tools and dependencies
- ✅ **Cost savings**: Avoid per-minute charges for private repositories
- ✅ **Better control**: Custom hardware and software configurations

## Prerequisites

Before migration, ensure you have:

- [ ] Windows 10/11 or Windows Server 2019/2022
- [ ] Administrator access for initial setup
- [ ] Private GitHub repository (NEVER use with public repos)
- [ ] Minimum 100GB free disk space (500GB+ recommended)
- [ ] Stable internet connection
- [ ] GitHub PAT with `repo` and `admin:org` scopes (for runner registration)

## Migration Steps

### Step 1: Prepare the Runner Environment

Run the automated setup script to install required dependencies:

```powershell
# Clone the ActionRunner repository
git clone https://github.com/yourusername/ActionRunner.git
cd ActionRunner

# Run environment setup (installs Node.js, Python, Docker support)
.\scripts\setup-runner-environment.ps1
```

This script will:
- ✅ Verify Node.js 20.x installation
- ✅ Install pnpm 9.x globally
- ✅ Verify Python 3.11 installation
- ✅ Check Docker and BuildKit availability
- ✅ Install security tools (pip-audit, detect-secrets, OSV Scanner)
- ✅ Check disk space requirements

### Step 2: Download and Install GitHub Actions Runner

```powershell
# Create runner directory
mkdir C:\actions-runner
cd C:\actions-runner

# Download the latest runner
$runnerVersion = "2.328.0"
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile actions-runner.zip

# Extract
Expand-Archive -Path actions-runner.zip -DestinationPath . -Force
```

### Step 3: Security Configuration (REQUIRED)

**Never skip this step!** Self-hosted runners require proper security controls:

```powershell
# Navigate to ActionRunner repository
cd C:\Code\ActionRunner

# Create secure service account
.\config\runner-user-setup.ps1

# Apply firewall rules for network isolation
.\config\apply-firewall-rules.ps1

# Review security documentation
notepad .\docs\security.md
```

### Step 4: Register the Runner

Get a runner registration token from GitHub:

**For Repository Runners:**
1. Go to your repository → Settings → Actions → Runners
2. Click "New self-hosted runner"
3. Copy the registration token

**For Organization Runners:**
1. Go to your organization → Settings → Actions → Runners
2. Click "New runner"
3. Copy the registration token

Register the runner:

```powershell
cd C:\actions-runner

# Configure runner (replace YOUR-ORG/YOUR-REPO and TOKEN)
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN --runasservice

# When prompted for user account, use: .\GitHubRunner
# (Created by runner-user-setup.ps1)
```

### Step 5: Update Workflow Files

You can update workflows manually or use the automated migration script.

#### Option A: Automated Migration (Recommended)

Use the migration script to automatically update all workflows:

```powershell
# Preview changes (dry-run mode)
.\scripts\migrate-to-self-hosted.ps1 -DryRun

# Apply migration with default labels
.\scripts\migrate-to-self-hosted.ps1

# Apply migration with custom labels
.\scripts\migrate-to-self-hosted.ps1 -RunnerLabels "self-hosted,windows,x64"
```

The script will:
- ✅ Scan all workflow files in `.github/workflows`
- ✅ Detect GitHub-hosted runners (ubuntu-latest, windows-latest, etc.)
- ✅ Backup original workflows to `.github/workflows.backup`
- ✅ Update `runs-on` configurations to use self-hosted runners
- ✅ Provide a detailed migration report

#### Option B: Manual Migration

Update your workflow files to use the self-hosted runner:

**Before (GitHub-hosted):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
```

**After (Self-hosted):**
```yaml
jobs:
  build:
    runs-on: [self-hosted, windows]
    # Or for specific labels:
    # runs-on: [self-hosted, windows, X64]
```

### Step 6: Verify Runner Status

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Check firewall rules
Get-NetFirewallRule -DisplayName "GitHub Actions Runner*"

# View runner logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50
```

### Step 7: Test the Migration

1. **Push a test commit** to trigger the workflow
2. **Monitor the workflow** in GitHub Actions tab
3. **Verify runner pickup**: Should show "self-hosted" label
4. **Check for green checkmarks**: All jobs should pass

## Jesus Project Specific Setup

For the Jesus MCP Agentic AI Platform project, ensure:

### CI Workflow Requirements
- ✅ Node.js 20 with pnpm 9.15.0
- ✅ Python 3.11 with pip
- ✅ Docker with BuildKit support
- ✅ Bash environment (via WSL2 or Git Bash)

### Security Workflow Requirements
- ✅ Python 3.11 for pip-audit and detect-secrets
- ✅ curl and sudo access for OSV Scanner
- ✅ pnpm for npm audit

### Validation Commands

Run these on your runner to verify Jesus project requirements:

```powershell
# Node.js + pnpm
node --version    # Should be v20.x
pnpm --version    # Should be 9.x

# Python
python --version  # Should be 3.11.x
pip --version

# Docker
docker --version
docker buildx version

# Security tools
curl --version
osv-scanner --version  # May need installation
pip-audit --version
detect-secrets --version
```

## Rollback Plan

If you need to revert to GitHub-hosted runners:

1. **Update workflow files** back to `runs-on: ubuntu-latest`
2. **Stop the runner service**:
   ```powershell
   Stop-Service actions.runner.*
   ```
3. **Remove runner from GitHub**:
   - Go to repository/org Settings → Actions → Runners
   - Click the runner and select "Remove"
4. **Unregister locally**:
   ```powershell
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-TOKEN
   ```

## Troubleshooting

### Runner Not Picking Up Jobs

**Symptoms**: Workflows stay in "Queued" state

**Solutions**:
1. Check runner is online: Repository → Settings → Actions → Runners
2. Verify runner labels match workflow: `runs-on: [self-hosted, windows]`
3. Check service status: `Get-Service actions.runner.*`
4. Review logs: `C:\actions-runner\_diag\Runner_*.log`

### Permission Denied Errors

**Symptoms**: Workflows fail with access denied

**Solutions**:
1. Verify service account permissions on runner directory
2. Check file system ACLs: `icacls C:\actions-runner`
3. Ensure GitHubRunner account has necessary permissions
4. Review Windows Event Logs for access denied events

### Network Connectivity Issues

**Symptoms**: Runner can't connect to GitHub

**Solutions**:
1. Test connectivity: `Test-NetConnection github.com -Port 443`
2. Check firewall rules: `Get-NetFirewallRule -DisplayName "GitHub Actions Runner*"`
3. Verify DNS resolution: `Resolve-DnsName github.com`
4. Review firewall logs for blocked connections

### Docker Build Failures

**Symptoms**: Docker-based workflows fail

**Solutions**:
1. Verify Docker is running: `docker ps`
2. Check BuildKit is enabled: `docker buildx version`
3. Ensure runner user is in docker group (WSL2)
4. Check Docker Desktop is running and WSL2 integration is enabled

## Post-Migration Checklist

- [ ] All workflows use `self-hosted` runner
- [ ] Green checkmarks appear in GitHub Actions
- [ ] Security controls are in place (firewall, service account)
- [ ] Disk space monitoring is configured
- [ ] Backup/recovery plan documented
- [ ] Team notified of migration
- [ ] Documentation updated with runner details

## Maintenance

### Daily
- Monitor workflow runs for failures
- Check runner service status

### Weekly
- Review runner logs: `C:\actions-runner\_diag\`
- Check disk space usage
- Verify firewall rules are active

### Monthly
- Rotate access tokens
- Update GitHub IP ranges in firewall rules
- Apply Windows security updates
- Review security logs

### Quarterly
- Update runner software
- Full security audit
- Review and update security policies
- Test incident response procedures

## Related Resources

- [Security Documentation](./security.md)
- [Runner User Setup Script](../config/runner-user-setup.ps1)
- [Firewall Rules Configuration](../config/firewall-rules.yaml)
- [GitHub Actions Self-Hosted Runner Docs](https://docs.github.com/en/actions/hosting-your-own-runners)

## Support

For issues or questions:
1. Review this migration guide
2. Check [troubleshooting section](#troubleshooting)
3. Review runner logs in `_diag` directory
4. Contact your organization's security team
5. Open an issue in the ActionRunner repository

---

**Last Updated**: 2025-10-03
**Status**: Active Migration Guide for Issue #16
