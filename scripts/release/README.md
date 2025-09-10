# Serena Release Automation System

This directory contains scripts and configuration files for automating the Serena release process.

## Files Overview

- **`prepare-release.ps1`** - PowerShell script for Windows release preparation
- **`prepare-release.sh`** - Bash script for Unix/Linux/macOS release preparation  
- **`release-notes-template.md`** - Template for generating comprehensive release notes
- **`README.md`** - This documentation file

## Additional Configuration

- **`.github/release.yml`** - GitHub automatic release note generation configuration

## Quick Start

### Using PowerShell (Windows)

```powershell
# Basic release preparation
.\scripts\release\prepare-release.ps1 -Version "1.0.0"

# Dry run to see what would happen
.\scripts\release\prepare-release.ps1 -Version "1.0.0" -DryRun

# Skip tests during preparation
.\scripts\release\prepare-release.ps1 -Version "1.0.0" -SkipTests

# Use different branch
.\scripts\release\prepare-release.ps1 -Version "1.0.0" -Branch "develop"
```

### Using Bash (Linux/macOS)

```bash
# Basic release preparation
./scripts/release/prepare-release.sh -v "1.0.0"

# Dry run to see what would happen
./scripts/release/prepare-release.sh -v "1.0.0" --dry-run

# Skip tests during preparation
./scripts/release/prepare-release.sh -v "1.0.0" --skip-tests

# Use different branch
./scripts/release/prepare-release.sh -v "1.0.0" -b "develop"
```

## What the Scripts Do

### Automated Steps

1. **Prerequisites Check** - Verifies required tools (git, uv/python, etc.)
2. **Git Repository Validation** - Ensures clean working directory and correct branch
3. **Version Bumping** - Updates version in `pyproject.toml`
4. **Changelog Generation** - Automatically generates changelog entries from git commits
5. **Quality Checks** - Runs formatting, type checking, and tests
6. **Distribution Building** - Creates wheel and source distribution packages
7. **Checksum Generation** - Generates SHA256 checksums for all release assets
8. **Asset Preparation** - Copies important files and creates version info
9. **Release Validation** - Verifies all steps completed successfully
10. **Git Tag Creation** - Creates annotated git tag for the release

### Generated Assets

After running the script, you'll find:

- **`dist/`** - Distribution packages (`.whl` and `.tar.gz`)
- **`dist/checksums.txt`** - SHA256 checksums for verification
- **`assets/`** - Additional release assets (README, LICENSE, etc.)
- **`assets/version-info.json`** - Build metadata and version information

## Release Notes Template

The `release-notes-template.md` provides a comprehensive template for creating professional release notes. It includes sections for:

- **Version Highlights** - Key features and improvements
- **Breaking Changes** - Important changes that require user action
- **New Features** - Detailed feature descriptions
- **Bug Fixes** - Critical and general fixes
- **Known Issues** - Current limitations and workarounds  
- **Installation Instructions** - Complete installation and upgrade guide
- **Download Information** - Asset descriptions and verification steps

### Using the Template

1. Copy the template content
2. Replace placeholders like `{VERSION}`, `{FEATURE_NAME}`, etc.
3. Fill in sections based on the actual changes in your release
4. Remove unused sections if not applicable

## GitHub Integration

The `.github/release.yml` file configures automatic release note generation on GitHub with:

- **Categorized Changes** - Automatically organizes PRs by type
- **Smart Labeling** - Uses PR labels to categorize changes
- **Contributor Credits** - Automatically includes contributor information
- **Exclusion Rules** - Filters out internal/CI changes

### Supported Categories

- 🚨 Breaking Changes
- 🗣️ New Language Support
- 🚀 New Features
- 🛠️ Tool System
- 🔧 Language Server Protocol
- 🤖 Agent & MCP Integration
- ⚙️ Configuration & Setup
- ⚡ Performance
- 🐛 Bug Fixes
- 📚 Documentation
- 🧪 Testing & Quality
- 🖥️ Platform Support
- 👨‍💻 Developer Experience
- 🔒 Security
- ⚠️ Deprecations
- 📦 Dependencies
- 🔧 Infrastructure

## Customization

### Script Parameters

Both scripts support various parameters for customization:

**Common Parameters:**
- Version (required)
- Branch selection
- Dry run mode
- Skip tests option
- Custom build/asset directories

**PowerShell Specific:**
```powershell
-Version "1.0.0"      # Required version
-Branch "main"        # Git branch (default: main)
-DryRun               # Preview changes without execution
-SkipTests            # Skip quality checks
-BuildDir "./dist"    # Build output directory
-AssetsDir "./assets" # Assets directory
```

**Bash Specific:**
```bash
-v, --version         # Required version
-b, --branch          # Git branch (default: main)  
-d, --dry-run         # Preview changes without execution
-s, --skip-tests      # Skip quality checks
--build-dir           # Build output directory
--assets-dir          # Assets directory
```

### Environment Variables

The scripts respect these environment variables:

- `PYTEST_MARKERS` - Custom test markers for pytest
- `PYTHON_RUNNER` - Override for python command (uv/python3)

## Best Practices

### Before Running

1. **Ensure Clean State** - Commit or stash all changes
2. **Update Dependencies** - Run `uv lock` to update lock file
3. **Run Tests Locally** - Verify all tests pass before release
4. **Review Changes** - Check what will be included in the release

### Version Naming

Follow semantic versioning (SemVer):
- **Major** (1.0.0) - Breaking changes
- **Minor** (0.1.0) - New features, backwards compatible
- **Patch** (0.0.1) - Bug fixes, backwards compatible
- **Pre-release** (1.0.0-rc1) - Release candidates

### Release Process

1. **Prepare Release**
   ```bash
   ./scripts/release/prepare-release.sh -v "1.0.0"
   ```

2. **Review Changes**
   ```bash
   git diff HEAD~1  # Review all changes
   git log --oneline v0.9.0..HEAD  # Review commits
   ```

3. **Commit and Tag**
   ```bash
   git add .
   git commit -m "chore: prepare release v1.0.0"
   git push origin main
   git push origin v1.0.0
   ```

4. **Create GitHub Release**
   - Go to GitHub Releases page
   - Use the v1.0.0 tag
   - Upload assets from `dist/` and `assets/`
   - Use release notes template

5. **Publish to PyPI** (if desired)
   ```bash
   uv publish --username __token__ --password $PYPI_TOKEN
   ```

## Troubleshooting

### Common Issues

**Script Fails at Quality Checks:**
- Run `uv run poe format` manually
- Check `uv run poe type-check` output
- Review failing tests with `uv run poe test -v`

**Git Tag Already Exists:**
```bash
git tag -d v1.0.0  # Delete local tag
git push origin :refs/tags/v1.0.0  # Delete remote tag
```

**Build Failures:**
- Check Python version (requires 3.11)
- Verify all dependencies are installed
- Clear cache: `rm -rf dist/ build/ *.egg-info/`

**Checksum Verification Issues:**
```bash
# Verify checksums manually
cd dist/
sha256sum -c checksums.txt
```

### Getting Help

- Check script output for specific error messages
- Run with dry-run mode first to identify issues
- Verify prerequisites are installed and up to date
- Check GitHub Actions logs for CI-related issues

## Contributing

When modifying the release scripts:

1. **Test Both Platforms** - Ensure PowerShell and Bash versions work
2. **Update Documentation** - Keep this README current
3. **Follow Conventions** - Match existing code style and patterns
4. **Add Error Handling** - Ensure graceful failure and helpful messages

## Security Considerations

- **Token Management** - Never commit API tokens or credentials
- **Checksum Verification** - Always verify checksums before distribution
- **Clean Builds** - Use fresh build environments for official releases
- **Audit Trail** - Keep records of who performs releases and when