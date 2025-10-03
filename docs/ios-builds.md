# macOS iOS Build Integration

This guide explains how to integrate GitHub-hosted macOS runners for iOS builds (QiFlowGo) with your self-hosted Windows runner infrastructure.

## Why macOS is Required

### Xcode and iOS SDK Requirements
- **iOS app building** requires Xcode, which only runs on macOS
- **Code signing** for iOS apps requires macOS-specific tools
- **App Store submission** requires macOS tooling
- **Simulator testing** requires macOS environment

### Platform-Specific Tools
- Xcode Command Line Tools
- CocoaPods for iOS dependency management
- Fastlane for automated iOS builds and deployment
- Apple Developer certificates and provisioning profiles

## Cost Analysis: GitHub-Hosted vs Self-Hosted Mac

### GitHub-Hosted macOS Runners

**Pricing (as of 2024):**
- **macOS (Intel)**: $0.08/minute = $4.80/hour
- **macOS (M1)**: $0.16/minute = $9.60/hour
- Free tier: 0 minutes for private repos

**Monthly Cost Estimates:**
| Build Frequency | Minutes/Month | Cost/Month |
|----------------|---------------|------------|
| 10 builds/day (5 min each) | 1,500 | $120 |
| 20 builds/day (5 min each) | 3,000 | $240 |
| 50 builds/day (10 min each) | 15,000 | $1,200 |
| CI on every commit (100/day, 3 min) | 9,000 | $720 |

**Advantages:**
- ✅ No hardware investment
- ✅ No maintenance required
- ✅ Always up-to-date
- ✅ Scalable on demand
- ✅ Multiple Xcode versions available

**Disadvantages:**
- ❌ Expensive for frequent builds
- ❌ Slower startup time
- ❌ Limited customization
- ❌ No persistent cache between builds

### Self-Hosted Mac Mini

**Initial Investment:**
- **Mac Mini M2**: $599-799
- **Mac Mini M2 Pro**: $1,299-1,499
- **Mac Studio M2**: $1,999+

**Operating Costs:**
- **Power**: ~$5-10/month
- **Internet**: (existing)
- **Apple Developer Account**: $99/year (already needed)
- **Total monthly**: ~$10-15 + hardware depreciation

**Break-Even Analysis:**
| GitHub Usage/Month | Mac Mini Cost | Break-Even Period |
|-------------------|---------------|-------------------|
| $120/month | $799 | 7 months |
| $240/month | $799 | 3.5 months |
| $720/month | $799 | 1 month |

**Advantages:**
- ✅ Cost-effective for frequent builds
- ✅ Faster build times (persistent cache)
- ✅ Full customization
- ✅ Can run 24/7
- ✅ Better for development testing

**Disadvantages:**
- ❌ Upfront hardware cost
- ❌ Requires maintenance
- ❌ Requires physical space
- ❌ Single Xcode version per machine
- ❌ Setup complexity

## Recommendation

**For QiFlowGo Project:**

### Current Stage (Development/MVP)
**Use GitHub-hosted macOS runners**
- Lower initial investment
- Easier setup
- Good for occasional builds
- Estimated cost: $50-150/month

### Future Stage (Active Development)
**Migrate to self-hosted Mac Mini** when:
- Building 10+ times per day
- Monthly GitHub Actions cost exceeds $200
- Need faster build times
- Require custom build environment

## Workflow Configuration for React Native iOS Builds

### Hybrid Strategy: Windows + macOS

The recommended approach uses **self-hosted Windows runner for Android** and **GitHub-hosted macOS for iOS**.

### Example: QiFlowGo Workflow

Create `.github/workflows/mobile-ci.yml`:

```yaml
name: Mobile CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  # Android build on self-hosted Windows runner
  android:
    name: Build Android
    runs-on: [self-hosted, windows, X64]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        run: node --version  # Already installed on self-hosted runner

      - name: Install dependencies
        run: |
          npm install -g yarn
          yarn install

      - name: Setup Java for Android
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Android SDK
        uses: android-actions/setup-android@v3

      - name: Build Android APK
        run: |
          cd android
          ./gradlew assembleRelease

      - name: Upload Android artifact
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: android/app/build/outputs/apk/release/app-release.apk
          retention-days: 30

  # iOS build on GitHub-hosted macOS runner
  ios:
    name: Build iOS
    runs-on: macos-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          npm install -g yarn
          yarn install

      - name: Install CocoaPods dependencies
        run: |
          cd ios
          pod install

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: 'latest-stable'

      - name: Build iOS app
        run: |
          cd ios
          xcodebuild \
            -workspace QiFlowGo.xcworkspace \
            -scheme QiFlowGo \
            -configuration Release \
            -sdk iphoneos \
            -archivePath ./build/QiFlowGo.xcarchive \
            archive

      - name: Export IPA
        run: |
          cd ios
          xcodebuild \
            -exportArchive \
            -archivePath ./build/QiFlowGo.xcarchive \
            -exportPath ./build \
            -exportOptionsPlist ./ExportOptions.plist

      - name: Upload iOS artifact
        uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: ios/build/*.ipa
          retention-days: 30

  # Publish artifacts (optional)
  publish:
    name: Publish Builds
    needs: [android, ios]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Download Android APK
        uses: actions/download-artifact@v4
        with:
          name: android-apk

      - name: Download iOS IPA
        uses: actions/download-artifact@v4
        with:
          name: ios-ipa

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: |
            app-release.apk
            *.ipa
          tag_name: v${{ github.run_number }}
```

## Runner Selection Strategy

### Using Labels to Route Jobs

**Self-hosted Windows runner:**
```yaml
runs-on: [self-hosted, windows, X64]
```

**GitHub-hosted macOS runner (Intel):**
```yaml
runs-on: macos-latest  # or macos-13
```

**GitHub-hosted macOS runner (M1):**
```yaml
runs-on: macos-14  # M1 chip, faster but more expensive
```

**Multiple platform matrix:**
```yaml
strategy:
  matrix:
    platform:
      - { os: [self-hosted, windows], name: Android }
      - { os: macos-latest, name: iOS }
```

## Cost Optimization Tips

### 1. Build Caching

Cache dependencies to reduce build time:

```yaml
- name: Cache Node modules
  uses: actions/cache@v4
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/yarn.lock') }}

- name: Cache Pods
  uses: actions/cache@v4
  with:
    path: ios/Pods
    key: ${{ runner.os }}-pods-${{ hashFiles('ios/Podfile.lock') }}
```

### 2. Conditional iOS Builds

Only build iOS when iOS files change:

```yaml
ios:
  runs-on: macos-latest
  if: contains(github.event.head_commit.modified, 'ios/')
```

### 3. Scheduled Builds Instead of Per-Commit

For development branches:

```yaml
on:
  push:
    branches: [main]  # Only main branch
  schedule:
    - cron: '0 2 * * *'  # Nightly builds for develop
```

### 4. Use Smaller macOS Runners

For simple tasks, use `macos-13` (Intel) instead of `macos-14` (M1) to save 50% cost.

## iOS Build Requirements Checklist

### Code Signing Setup

- [ ] Apple Developer Account ($99/year)
- [ ] iOS Distribution Certificate
- [ ] Provisioning Profiles
- [ ] App Store Connect API key

### GitHub Secrets Required

Store these in **Settings → Secrets → Actions**:

```yaml
APPLE_DEVELOPER_CERTIFICATE  # Base64-encoded .p12 file
CERTIFICATE_PASSWORD         # Password for .p12
PROVISIONING_PROFILE        # Base64-encoded .mobileprovision
KEYCHAIN_PASSWORD           # For temporary keychain
APP_STORE_CONNECT_API_KEY   # For app submission
```

### Example: Signing Configuration

```yaml
- name: Import Code Signing Certificates
  run: |
    # Create temporary keychain
    security create-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain
    security default-keychain -s build.keychain
    security unlock-keychain -p "${{ secrets.KEYCHAIN_PASSWORD }}" build.keychain

    # Import certificate
    echo "${{ secrets.APPLE_DEVELOPER_CERTIFICATE }}" | base64 --decode > certificate.p12
    security import certificate.p12 -k build.keychain -P "${{ secrets.CERTIFICATE_PASSWORD }}" -T /usr/bin/codesign

    # Import provisioning profile
    echo "${{ secrets.PROVISIONING_PROFILE }}" | base64 --decode > profile.mobileprovision
    mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
    cp profile.mobileprovision ~/Library/MobileDevice/Provisioning\ Profiles/
```

## Advanced: Self-Hosted Mac Mini Setup

If you decide to invest in a Mac Mini runner:

### Hardware Setup

1. **Purchase Mac Mini M2** (minimum recommended)
2. **Configure macOS**:
   - Create dedicated runner user account
   - Disable sleep and screen saver
   - Enable automatic login
   - Install Xcode from App Store

### Software Setup

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods
sudo gem install cocoapods

# Install Fastlane
brew install fastlane

# Download GitHub Actions Runner
mkdir ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-osx-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-x64-2.311.0.tar.gz
tar xzf ./actions-runner-osx-x64-2.311.0.tar.gz

# Configure runner
./config.sh --url https://github.com/USERNAME/REPO --token YOUR_TOKEN --labels self-hosted,macOS,iOS

# Install as service
sudo ./svc.sh install
sudo ./svc.sh start
```

### Workflow for Self-Hosted Mac

```yaml
ios:
  runs-on: [self-hosted, macOS, iOS]
  # Rest same as above
```

## Monitoring and Maintenance

### Track GitHub Actions Usage

View usage in **Settings → Billing → Usage this month**:

```bash
# Using GitHub CLI
gh api /repos/OWNER/REPO/actions/runs --jq '.workflow_runs[] | select(.name == "Mobile CI") | {id, conclusion, created_at, run_started_at}'
```

### Cost Projection Calculator

Use this formula to estimate monthly costs:

```
Monthly Cost = (Builds per day) × (Average build time in minutes) × (30 days) × ($0.08 for Intel or $0.16 for M1)

Example:
20 builds/day × 5 minutes × 30 days × $0.08 = $240/month (Intel)
20 builds/day × 5 minutes × 30 days × $0.16 = $480/month (M1)
```

**Interactive Calculator:**

| Input | Value |
|-------|-------|
| Builds per day | _____ |
| Average build time (min) | _____ |
| Runner type | macOS-13 (Intel) / macOS-14 (M1) |

**Formula:**
```
Cost/Month = [Builds/day] × [Build time] × 30 × [Rate]
```

Where Rate = $0.08 (Intel) or $0.16 (M1)

## Troubleshooting

### Common iOS Build Issues

**Issue: Code signing failed**
- Ensure certificates are valid and not expired
- Check provisioning profile matches bundle ID
- Verify certificate is in keychain

**Issue: Xcode version mismatch**
- Specify exact Xcode version in workflow
- Use `xcode-select` to set correct version

**Issue: CocoaPods dependency errors**
- Clear cache: `pod cache clean --all`
- Update CocoaPods: `pod install --repo-update`

**Issue: Build timeout**
- Increase timeout: `timeout-minutes: 30`
- Optimize build by caching dependencies

## Related Documentation

- [Self-Hosted Runner Setup](../README.md)
- [Workflow Migration Guide](./MIGRATION_GUIDE.md)
- [Security Best Practices](./security.md)

## References

- [GitHub Actions Pricing](https://docs.github.com/en/billing/managing-billing-for-github-actions/about-billing-for-github-actions)
- [iOS App Distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)
- [React Native iOS Build Guide](https://reactnative.dev/docs/publishing-to-app-store)
- [Fastlane Documentation](https://docs.fastlane.tools/)

---

**Status:** ✅ Production Ready
**Last Updated:** October 2025
**Maintained By:** ActionRunner Team
