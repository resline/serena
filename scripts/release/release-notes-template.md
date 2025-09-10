# Serena v{VERSION} Release Notes

## Overview

Serena v{VERSION} brings {BRIEF_DESCRIPTION} to the Serena Agent toolkit. This release includes {MAJOR_HIGHLIGHTS} and continues our commitment to providing a comprehensive coding agent experience.

## Version Highlights

### 🚀 Major Features
<!-- Highlight 2-3 most significant features in this release -->

- **{FEATURE_NAME}**: {FEATURE_DESCRIPTION}
- **{FEATURE_NAME}**: {FEATURE_DESCRIPTION}
- **{FEATURE_NAME}**: {FEATURE_DESCRIPTION}

### 🎯 Key Improvements

<!-- List significant improvements and enhancements -->

- **Performance**: {PERFORMANCE_IMPROVEMENTS}
- **Developer Experience**: {DX_IMPROVEMENTS}
- **Stability**: {STABILITY_IMPROVEMENTS}

## Breaking Changes

<!-- List any breaking changes that users need to be aware of -->

> ⚠️ **Important**: Please review these breaking changes before upgrading.

### Configuration Changes

- **{CONFIG_CHANGE}**: {DESCRIPTION_AND_MIGRATION_GUIDE}
- **{CONFIG_CHANGE}**: {DESCRIPTION_AND_MIGRATION_GUIDE}

### API Changes

- **{API_CHANGE}**: {DESCRIPTION_AND_MIGRATION_GUIDE}
- **{API_CHANGE}**: {DESCRIPTION_AND_MIGRATION_GUIDE}

### Deprecated Features

- **{DEPRECATED_FEATURE}**: {DEPRECATION_NOTICE_AND_TIMELINE}

## New Features

### Language Support

- **{LANGUAGE}**: {DESCRIPTION_OF_LANGUAGE_SUPPORT}
  - LSP server: {LSP_SERVER_NAME}
  - Features supported: {SUPPORTED_FEATURES}
  - Platform compatibility: {PLATFORMS}
  - Installation requirements: {REQUIREMENTS}

### Tool Enhancements

- **{TOOL_NAME}**: {ENHANCEMENT_DESCRIPTION}
  - New capabilities: {NEW_CAPABILITIES}
  - Improved performance: {PERFORMANCE_DETAILS}
  - Enhanced error handling: {ERROR_HANDLING_IMPROVEMENTS}

### Configuration System

- **{CONFIG_FEATURE}**: {FEATURE_DESCRIPTION}
  - Usage: {USAGE_EXAMPLE}
  - Benefits: {BENEFITS}

### MCP Integration

- **{MCP_FEATURE}**: {FEATURE_DESCRIPTION}
  - Protocol version: {VERSION}
  - New methods: {NEW_METHODS}
  - Compatibility: {COMPATIBILITY_INFO}

## Bug Fixes

### Critical Fixes

- **{CRITICAL_FIX}**: Fixed {ISSUE_DESCRIPTION} that could cause {IMPACT}
- **{CRITICAL_FIX}**: Resolved {ISSUE_DESCRIPTION} affecting {AFFECTED_COMPONENT}

### General Fixes

- **Language Servers**: 
  - Fixed {LSP_ISSUE} in {LANGUAGE} language server
  - Resolved {LSP_ISSUE} causing {PROBLEM}
  - Improved error recovery for {SCENARIO}

- **Tool System**:
  - Fixed {TOOL_ISSUE} in {TOOL_NAME}
  - Corrected {BEHAVIOR} when {CONDITION}
  - Enhanced {FUNCTIONALITY} reliability

- **Configuration**:
  - Fixed {CONFIG_ISSUE} in {CONFIG_AREA}
  - Resolved {LOADING_ISSUE} with {CONFIG_TYPE}
  - Improved validation for {CONFIG_SETTING}

### Platform-Specific Fixes

- **Windows**: {WINDOWS_SPECIFIC_FIXES}
- **macOS**: {MACOS_SPECIFIC_FIXES}
- **Linux**: {LINUX_SPECIFIC_FIXES}

## Enhancements

### Performance Improvements

- **{PERFORMANCE_AREA}**: {IMPROVEMENT_DESCRIPTION}
  - Speed increase: {PERCENTAGE_OR_MEASUREMENT}
  - Memory usage: {IMPROVEMENT_DETAILS}
  - Scalability: {SCALABILITY_IMPROVEMENTS}

### Developer Experience

- **CLI Enhancements**: {CLI_IMPROVEMENTS}
- **Error Messages**: {ERROR_MESSAGE_IMPROVEMENTS}
- **Documentation**: {DOCUMENTATION_UPDATES}
- **Debugging**: {DEBUGGING_ENHANCEMENTS}

### Reliability & Stability

- **Error Handling**: {ERROR_HANDLING_IMPROVEMENTS}
- **Recovery Mechanisms**: {RECOVERY_IMPROVEMENTS}
- **Timeout Management**: {TIMEOUT_IMPROVEMENTS}
- **Resource Management**: {RESOURCE_IMPROVEMENTS}

## Technical Changes

### Architecture

- **{ARCHITECTURAL_CHANGE}**: {DESCRIPTION_AND_RATIONALE}
- **{ARCHITECTURAL_CHANGE}**: {DESCRIPTION_AND_RATIONALE}

### Dependencies

- **Updated Dependencies**:
  - {DEPENDENCY_NAME}: {OLD_VERSION} → {NEW_VERSION}
  - {DEPENDENCY_NAME}: {OLD_VERSION} → {NEW_VERSION}
- **New Dependencies**:
  - {DEPENDENCY_NAME} {VERSION}: {PURPOSE}
- **Removed Dependencies**:
  - {DEPENDENCY_NAME}: {REASON_FOR_REMOVAL}

### Internal Improvements

- **Code Quality**: {CODE_QUALITY_IMPROVEMENTS}
- **Test Coverage**: {TEST_COVERAGE_IMPROVEMENTS}
- **Documentation**: {INTERNAL_DOC_IMPROVEMENTS}

## Known Issues

### Current Limitations

- **{LIMITATION}**: {DESCRIPTION_AND_WORKAROUND}
- **{LIMITATION}**: {DESCRIPTION_AND_WORKAROUND}

### Platform-Specific Issues

- **Windows**: {WINDOWS_KNOWN_ISSUES}
- **macOS**: {MACOS_KNOWN_ISSUES}
- **Linux**: {LINUX_KNOWN_ISSUES}

### Workarounds

For issues where workarounds are available:

1. **{ISSUE}**: 
   - Problem: {PROBLEM_DESCRIPTION}
   - Workaround: {WORKAROUND_STEPS}
   - Tracking: {ISSUE_LINK}

## Installation & Upgrade

### System Requirements

- Python: 3.11 (Python 3.12 not yet supported)
- Operating Systems: Windows 10+, macOS 10.15+, Linux (Ubuntu 20.04+ recommended)
- Memory: Minimum 4GB RAM (8GB recommended for large projects)
- Disk Space: 500MB for core installation + language server requirements

### Installation Methods

#### Via pip (Recommended)

```bash
# Install from PyPI
pip install serena-agent=={VERSION}

# Or upgrade existing installation
pip install --upgrade serena-agent
```

#### Via uv (Fast)

```bash
# Install with uv
uv pip install serena-agent=={VERSION}
```

#### From Source

```bash
# Clone and install from source
git clone https://github.com/oraios/serena.git
cd serena
git checkout v{VERSION}
uv pip install -e .
```

### Upgrade Instructions

#### From Previous Versions

1. **Backup Configuration**: 
   ```bash
   cp -r ~/.serena ~/.serena.backup
   ```

2. **Upgrade Package**:
   ```bash
   pip install --upgrade serena-agent
   ```

3. **Update Configuration** (if needed):
   ```bash
   # Check for configuration changes
   serena config validate
   
   # Migrate if necessary
   serena config migrate
   ```

4. **Verify Installation**:
   ```bash
   serena --version
   serena config test
   ```

#### Breaking Change Migration

If upgrading from versions with breaking changes:

1. **{MIGRATION_STEP}**: {DETAILED_INSTRUCTIONS}
2. **{MIGRATION_STEP}**: {DETAILED_INSTRUCTIONS}

### Language Server Setup

Some languages require additional setup:

```bash
# Auto-setup for supported languages
serena setup-language python
serena setup-language typescript
serena setup-language go

# Or setup all at once
serena setup-languages --all
```

## Download Information

### Release Assets

| Asset | Description | Size | SHA256 Checksum |
|-------|-------------|------|-----------------|
| `serena_agent-{VERSION}-py3-none-any.whl` | Python wheel package | {SIZE} | `{CHECKSUM}` |
| `serena-agent-{VERSION}.tar.gz` | Source distribution | {SIZE} | `{CHECKSUM}` |
| `checksums.txt` | All file checksums | {SIZE} | `{CHECKSUM}` |

### Verification

Verify your download:

```bash
# Download checksums
curl -LO https://github.com/oraios/serena/releases/download/v{VERSION}/checksums.txt

# Verify checksum (Linux/macOS)
sha256sum -c checksums.txt

# Verify checksum (Windows PowerShell)
$expected = (Get-Content checksums.txt | Select-String "serena_agent.*\.whl").ToString().Split()[0]
$actual = (Get-FileHash serena_agent-{VERSION}-py3-none-any.whl -Algorithm SHA256).Hash.ToLower()
if ($expected -eq $actual) { "✓ Checksum verified" } else { "✗ Checksum mismatch" }
```

## Community & Support

### Getting Help

- **Documentation**: [https://github.com/oraios/serena/wiki](https://github.com/oraios/serena/wiki)
- **Issues**: [https://github.com/oraios/serena/issues](https://github.com/oraios/serena/issues)
- **Discussions**: [https://github.com/oraios/serena/discussions](https://github.com/oraios/serena/discussions)

### Contributing

We welcome contributions! See our [Contributing Guide](CONTRIBUTING.md) for details.

### Acknowledgments

Special thanks to our contributors for this release:

- @{CONTRIBUTOR}: {CONTRIBUTION}
- @{CONTRIBUTOR}: {CONTRIBUTION}
- @{CONTRIBUTOR}: {CONTRIBUTION}

And thank you to everyone who reported issues, provided feedback, and helped test this release!

## What's Next

Looking ahead to the next release, we're planning:

- **{UPCOMING_FEATURE}**: {BRIEF_DESCRIPTION}
- **{UPCOMING_FEATURE}**: {BRIEF_DESCRIPTION}
- **{UPCOMING_IMPROVEMENT}**: {BRIEF_DESCRIPTION}

Stay tuned for updates and follow our [roadmap](roadmap.md) for more details.

---

**Full Changelog**: [v{PREVIOUS_VERSION}...v{VERSION}](https://github.com/oraios/serena/compare/v{PREVIOUS_VERSION}...v{VERSION})

Released on {RELEASE_DATE} by the Serena team.