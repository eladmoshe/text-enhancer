# CI/CD Pipeline Documentation

This document describes the comprehensive CI/CD pipeline configured for the TextEnhancer project.

## 🏗️ Overview

The CI/CD pipeline is built using GitHub Actions and provides automated building, testing, code quality checks, security scanning, and deployment for the TextEnhancer macOS application.

## 📋 Pipeline Components

### 1. Main CI/CD Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Release events

**Jobs:**

#### Build and Test
- **Matrix builds** on Swift 5.9 and 5.10
- **Platforms**: macOS 14 (latest GitHub runners)
- **Actions**:
  - Build debug and release configurations
  - Run comprehensive test suite
  - Test build scripts
  - Upload build artifacts

#### Code Quality
- **SwiftLint** with custom configuration
- **SwiftFormat** formatting checks
- **TODO/FIXME** comment scanning
- **Custom rules** for production code quality

#### Security Scanning
- **Trivy** vulnerability scanner
- **Hardcoded secrets** detection
- **SARIF results** uploaded to GitHub Security tab

#### App Bundle Build
- **Release builds** for `main` branch and releases
- **Signed bundles** using project Makefile
- **Artifact archiving** for distribution
- **Dependencies**: Requires build and quality checks to pass

#### Release Automation
- **Automatic releases** on GitHub release events
- **Asset uploading** to release
- **Versioned artifacts** with proper naming

### 2. Documentation Workflow (`.github/workflows/docs.yml`)

**Triggers:**
- Changes to `Sources/` or `docs/` directories
- Documentation workflow changes

**Features:**
- **Auto-generated** API documentation
- **GitHub Pages** deployment
- **Documentation validation** in PRs
- **Link checking** for markdown files

### 3. Dependency Management

#### Dependabot (`.github/dependabot.yml`)
- **Swift Package Manager** dependency updates
- **GitHub Actions** version updates
- **Weekly schedule** with automatic PR creation
- **Automated labeling** and assignment

## 🔧 Code Quality Configuration

### SwiftLint (`.swiftlint.yml`)

**Key Rules:**
- Line length: 120 chars (warning), 150 (error)
- Function length: 60 lines (warning), 100 (error)
- File length: 500 lines (warning), 1200 (error)
- No force unwrapping in production code
- Prefer guard statements for early returns

**Custom Rules:**
- No print statements in production
- Encourage proper error handling
- Documentation requirements for public APIs

### SwiftFormat (`.swiftformat`)

**Configuration:**
- 4-space indentation
- Trailing commas required
- Import organization (testable at bottom)
- Self keyword removal where appropriate
- Consistent bracing and spacing

## 🛡️ Security Features

### Vulnerability Scanning
- **Trivy scanner** for filesystem vulnerabilities
- **SARIF integration** with GitHub Security
- **Secret detection** for hardcoded credentials
- **Dependency scanning** via Dependabot

### Safe Practices
- **API key exclusion** in .gitignore
- **Signed bundle builds** for releases
- **Permissions validation** in workflows
- **No sensitive data** in repositories

## 📊 Quality Gates

### Required Checks (for PRs)
- ✅ All tests pass
- ✅ Code builds successfully
- ✅ SwiftLint passes without errors
- ✅ SwiftFormat validation passes
- ✅ Security scan passes
- ✅ Documentation builds

### Optional Checks
- ⚠️ SwiftLint warnings (won't block PRs)
- ⚠️ TODO/FIXME comments (informational)
- ⚠️ Performance implications noted

## 🚀 Release Process

### Automated Release Flow
1. **Create release** in GitHub UI
2. **Trigger CI pipeline** automatically
3. **Build signed bundle** if all checks pass
4. **Upload release assets** automatically
5. **Deploy documentation** to GitHub Pages

### Manual Release Steps
1. Update version in relevant files
2. Create and push git tag
3. Create GitHub release
4. CI automatically handles the rest

## 📝 Issue and PR Templates

### Bug Reports (`.github/ISSUE_TEMPLATE/bug_report.yml`)
- **Structured form** with required fields
- **macOS version** and app configuration
- **Reproduction steps** and troubleshooting
- **Logs and error messages** collection

### Feature Requests (`.github/ISSUE_TEMPLATE/feature_request.yml`)
- **Problem statement** and proposed solution
- **Use cases** and implementation considerations
- **Priority assessment** and contribution interest
- **Design mockups** and alternatives

### Pull Requests (`.github/pull_request_template.md`)
- **Comprehensive checklist** for contributors
- **Testing requirements** and security considerations
- **App-specific validation** for macOS features
- **Documentation** and review guidelines

## 📚 Development Workflow

### Local Development
```bash
# Install tools
brew install swiftlint swiftformat

# Build and test
./build.sh --run
swift test

# Code quality
swiftlint lint
swiftformat --lint Sources/ Tests/

# Create PR
git checkout -b feature/my-feature
# ... make changes ...
git commit -m "feat(scope): description"
git push origin feature/my-feature
```

### CI Integration
1. **Push code** to feature branch
2. **CI runs** all quality checks
3. **Review results** in GitHub UI
4. **Address issues** if any
5. **Merge** when all checks pass

## 🔄 Monitoring and Maintenance

### GitHub Actions
- **Workflow runs** visible in Actions tab
- **Failure notifications** via GitHub
- **Artifact downloads** for debugging
- **Log inspection** for troubleshooting

### Dependabot
- **Weekly PRs** for dependency updates
- **Automatic merging** for patch updates
- **Manual review** for major updates
- **Security updates** prioritized

### Documentation
- **Auto-generated** API docs on GitHub Pages
- **Manual documentation** in `/docs` folder
- **Contributing guide** for new developers
- **Setup instructions** for local development

## 🎯 Best Practices

### For Contributors
1. **Run local checks** before pushing
2. **Write comprehensive tests** for new features
3. **Update documentation** when needed
4. **Follow coding standards** (enforced by tools)
5. **Use conventional commits** for clarity

### For Maintainers
1. **Monitor CI health** regularly
2. **Update dependencies** promptly
3. **Review security reports** in GitHub
4. **Maintain documentation** accuracy
5. **Respond to community** issues and PRs

## 🚨 Troubleshooting

### Common CI Issues
- **Build failures**: Check Swift version compatibility
- **Test failures**: Review test logs and fix issues
- **Lint errors**: Run SwiftLint locally and fix
- **Format issues**: Run SwiftFormat to auto-fix
- **Security alerts**: Review and address vulnerabilities

### Local Development Issues
- **Permission errors**: Ensure proper macOS permissions
- **Build script errors**: Check Xcode and Swift versions
- **API key issues**: Verify configuration setup
- **Signing issues**: Follow code signing documentation

---

This CI/CD pipeline ensures code quality, security, and reliable releases for the TextEnhancer project. For questions or improvements, please open an issue or submit a pull request. 