# Windows Portable Build Testing Checklist

Comprehensive testing checklist for validating Serena Windows portable package builds.

## Pre-Build Testing

### Development Environment

- [ ] **Python Version**
  ```powershell
  python --version
  # Should output: Python 3.11.x
  ```

- [ ] **uv Installation**
  ```powershell
  uv --version
  # Should output uv version
  ```

- [ ] **PowerShell Version**
  ```powershell
  $PSVersionTable.PSVersion
  # Should be 5.1 or higher
  ```

- [ ] **Git Repository Status**
  ```powershell
  git status
  # Should be clean or have only expected changes
  ```

- [ ] **Disk Space**
  ```powershell
  Get-PSDrive C | Select-Object Free
  # Should have at least 5-15 GB free (tier-dependent)
  ```

### Code Quality

- [ ] **Type Checking**
  ```powershell
  cd [repo-root]
  uv run poe type-check
  # Should pass with no errors
  ```

- [ ] **Linting**
  ```powershell
  uv run poe lint
  # Should pass with no errors
  ```

- [ ] **Unit Tests**
  ```powershell
  uv run poe test -m "python or go or typescript"
  # Should pass all tests
  ```

## Build Execution Testing

### Build Initialization

- [ ] **Script Execution**
  ```powershell
  cd scripts/build-windows
  .\build-windows-portable.ps1 -Tier essential -Clean
  # Should start without syntax errors
  ```

- [ ] **Parameter Validation**
  ```powershell
  # Test invalid tier
  .\build-windows-portable.ps1 -Tier invalid
  # Should reject with error message
  ```

### Stage Monitoring

Monitor each stage during build:

- [ ] **Stage 1: Environment Validation**
  - Python 3.11 detected
  - uv found and version displayed
  - Optional tools checked
  - Disk space validated
  - **Expected duration:** 2-5 seconds

- [ ] **Stage 2: Dependency Resolution**
  - pyproject.toml found
  - Version extracted correctly
  - Windows dependencies installed
  - uv sync completes
  - PyInstaller installed
  - **Expected duration:** 30-60 seconds (first run)

- [ ] **Stage 3: Tests Execution**
  - Type checking passes
  - Linting passes
  - Core tests pass
  - **Expected duration:** 60-180 seconds
  - **Skip test:** Use `-SkipTests` flag

- [ ] **Stage 4: Language Server Bundling**
  - Download script executes
  - Language servers downloaded (tier-dependent)
  - Files extracted successfully
  - Total size matches expectations
  - **Expected duration:** 60-300 seconds (tier-dependent)

- [ ] **Stage 5: PyInstaller Build**
  - Environment variables set
  - spec file found
  - PyInstaller executes
  - 3 executables created:
    - serena-mcp-server.exe
    - serena.exe
    - index-project.exe
  - **Expected duration:** 120-240 seconds

- [ ] **Stage 6: Directory Structure**
  - Package directory created
  - Subdirectories created:
    - bin/
    - config/
    - docs/
    - scripts/
    - language_servers/
  - **Expected duration:** 1-2 seconds

- [ ] **Stage 7: File Copying**
  - Executables copied to bin/
  - Language servers copied
  - Config files copied
  - Documentation copied
  - Launcher script copied
  - VERSION.txt created
  - **Expected duration:** 10-60 seconds

- [ ] **Stage 8: Archive Creation**
  - ZIP archive created
  - Archive size reasonable
  - Compression ratio 40-60%
  - **Expected duration:** 30-120 seconds

- [ ] **Stage 9: Checksum Generation**
  - SHA256 checksum computed
  - .sha256 file created
  - Executable checksums stored
  - **Expected duration:** 5-15 seconds

- [ ] **Stage 10: Manifest Generation**
  - JSON manifest created
  - All stage data captured
  - "latest" manifest created
  - **Expected duration:** 1-2 seconds

### Build Completion

- [ ] **Success Summary Displayed**
  - Build ID shown
  - Version correct
  - Tier correct
  - Total duration displayed
  - Stage timings shown

- [ ] **Build Log Created**
  ```powershell
  Test-Path dist/windows/build.log
  # Should return True
  ```

- [ ] **Build Manifest Created**
  ```powershell
  Test-Path dist/windows/build-manifest-latest.json
  # Should return True
  ```

## Package Structure Testing

### Directory Structure

- [ ] **Package Directory Exists**
  ```powershell
  $packageDir = "dist/windows/serena-portable-v{VERSION}-windows-{ARCH}-{TIER}"
  Test-Path $packageDir
  # Should return True
  ```

- [ ] **Subdirectories Present**
  ```powershell
  Test-Path "$packageDir/bin"
  Test-Path "$packageDir/config"
  Test-Path "$packageDir/docs"
  Test-Path "$packageDir/scripts"
  Test-Path "$packageDir/language_servers"  # If not minimal tier
  ```

- [ ] **Launcher Script Present**
  ```powershell
  Test-Path "$packageDir/serena-portable.bat"
  ```

- [ ] **VERSION.txt Present**
  ```powershell
  Test-Path "$packageDir/VERSION.txt"
  Get-Content "$packageDir/VERSION.txt"
  # Verify version, tier, architecture are correct
  ```

### Executable Files

- [ ] **serena-mcp-server.exe**
  ```powershell
  Test-Path "$packageDir/bin/serena-mcp-server.exe"
  (Get-Item "$packageDir/bin/serena-mcp-server.exe").Length / 1MB
  # Should be ~40-50 MB
  ```

- [ ] **serena.exe**
  ```powershell
  Test-Path "$packageDir/bin/serena.exe"
  (Get-Item "$packageDir/bin/serena.exe").Length / 1MB
  # Should be ~40-50 MB
  ```

- [ ] **index-project.exe**
  ```powershell
  Test-Path "$packageDir/bin/index-project.exe"
  (Get-Item "$packageDir/bin/index-project.exe").Length / 1MB
  # Should be ~40-50 MB
  ```

### Configuration Files

- [ ] **launcher-config.json**
  ```powershell
  Test-Path "$packageDir/config/launcher-config.json"
  Get-Content "$packageDir/config/launcher-config.json" | ConvertFrom-Json
  # Should parse without errors
  ```

### Documentation Files

- [ ] **README-PORTABLE.md**
  ```powershell
  Test-Path "$packageDir/docs/README-PORTABLE.md"
  ```

- [ ] **README.md**
  ```powershell
  Test-Path "$packageDir/docs/README.md"
  ```

- [ ] **LICENSE**
  ```powershell
  Test-Path "$packageDir/docs/LICENSE"
  ```

### Language Servers (Tier-Dependent)

#### Essential Tier

- [ ] **Python (Pyright)**
  ```powershell
  Test-Path "$packageDir/language_servers/python"
  ```

- [ ] **TypeScript**
  ```powershell
  Test-Path "$packageDir/language_servers/typescript"
  ```

- [ ] **Go (gopls)**
  ```powershell
  Test-Path "$packageDir/language_servers/go"
  ```

- [ ] **C# Language Server**
  ```powershell
  Test-Path "$packageDir/language_servers/csharp"
  ```

#### Complete Tier (Additional)

- [ ] **Java (Eclipse JDT-LS)**
  ```powershell
  Test-Path "$packageDir/language_servers/java"
  ```

- [ ] **Rust Analyzer**
  ```powershell
  Test-Path "$packageDir/language_servers/rust"
  ```

- [ ] **Kotlin**
  ```powershell
  Test-Path "$packageDir/language_servers/kotlin"
  ```

- [ ] **Clojure LSP**
  ```powershell
  Test-Path "$packageDir/language_servers/clojure"
  ```

#### Full Tier (All Languages)

- [ ] **All 28+ language servers present**
  ```powershell
  (Get-ChildItem "$packageDir/language_servers" -Directory).Count
  # Should be 20-28+ depending on configuration
  ```

## Archive Testing

### Archive Creation

- [ ] **ZIP File Exists**
  ```powershell
  $archivePath = "$packageDir.zip"
  Test-Path $archivePath
  # Should return True
  ```

- [ ] **Checksum File Exists**
  ```powershell
  Test-Path "$archivePath.sha256"
  ```

- [ ] **Archive Size Reasonable**
  ```powershell
  $archiveSize = (Get-Item $archivePath).Length / 1MB
  $dirSize = (Get-ChildItem $packageDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
  $compressionRatio = ($dirSize - $archiveSize) / $dirSize * 100

  Write-Host "Directory: $dirSize MB"
  Write-Host "Archive: $archiveSize MB"
  Write-Host "Compression: $compressionRatio%"
  # Compression should be 40-60% for binaries
  ```

### Archive Extraction

- [ ] **Extract Test**
  ```powershell
  $testExtractDir = "dist/windows/test-extract"
  Expand-Archive -Path $archivePath -DestinationPath $testExtractDir -Force

  # Verify extraction succeeded
  Test-Path $testExtractDir
  ```

- [ ] **Extracted Structure Matches Original**
  ```powershell
  $originalCount = (Get-ChildItem $packageDir -Recurse -File).Count
  $extractedCount = (Get-ChildItem "$testExtractDir/*" -Recurse -File).Count

  Write-Host "Original: $originalCount files"
  Write-Host "Extracted: $extractedCount files"
  # Should match
  ```

### Checksum Verification

- [ ] **Verify Archive Checksum**
  ```powershell
  $checksumContent = Get-Content "$archivePath.sha256"
  $expectedHash = $checksumContent.Split()[0]
  $actualHash = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash

  if ($expectedHash -eq $actualHash) {
      Write-Host "✓ Checksum verified" -ForegroundColor Green
  } else {
      Write-Host "✗ Checksum mismatch!" -ForegroundColor Red
      Write-Host "Expected: $expectedHash"
      Write-Host "Actual: $actualHash"
  }
  ```

## Functional Testing

### Executable Version Tests

- [ ] **serena-mcp-server.exe --version**
  ```powershell
  cd $packageDir
  .\bin\serena-mcp-server.exe --version
  # Should display version matching build
  ```

- [ ] **serena.exe --version**
  ```powershell
  .\bin\serena.exe --version
  # Should display version matching build
  ```

- [ ] **index-project.exe --version**
  ```powershell
  .\bin\index-project.exe --version
  # Should display version matching build
  ```

### Executable Help Tests

- [ ] **serena-mcp-server.exe --help**
  ```powershell
  .\bin\serena-mcp-server.exe --help
  # Should display help text with available options
  ```

- [ ] **serena.exe --help**
  ```powershell
  .\bin\serena.exe --help
  # Should display CLI help
  ```

- [ ] **index-project.exe --help**
  ```powershell
  .\bin\index-project.exe --help
  # Should display indexing help
  ```

### Launcher Script Test

- [ ] **Launcher Execution**
  ```powershell
  cd $packageDir
  .\serena-portable.bat --help
  # Should start launcher and display help
  ```

- [ ] **Environment Variables Set**
  ```batch
  # Run launcher and check environment
  # Should set:
  # - SERENA_PORTABLE=1
  # - SERENA_HOME=[package-dir]
  # - PATH includes bin/ and language_servers/
  ```

### Portable Mode Test

- [ ] **First Run Initialization**
  ```powershell
  cd $packageDir

  # Run launcher (this should create .serena-portable/)
  # Note: May need to run actual command or server start

  # Verify .serena-portable/ created
  Test-Path ".\.serena-portable"
  Test-Path ".\.serena-portable\cache"
  Test-Path ".\.serena-portable\logs"
  Test-Path ".\.serena-portable\config"
  ```

- [ ] **No User Home Directory Writes**
  ```powershell
  # Monitor user home directory for unexpected changes
  $userHome = $env:USERPROFILE
  # Serena should NOT write to $userHome/.serena in portable mode
  # Only .serena-portable/ in package directory should be used
  ```

### MCP Server Test

- [ ] **Server Startup**
  ```powershell
  cd $packageDir

  # Start server (in background or separate terminal)
  Start-Process .\bin\serena-mcp-server.exe -ArgumentList "--help"

  # Verify it starts without immediate errors
  # Check logs in .serena-portable/logs/
  ```

- [ ] **Server Response**
  ```powershell
  # If server started, verify it responds to requests
  # This requires a test client or manual verification
  ```

### Language Server Integration Test

For each language server in the tier:

- [ ] **Language Server Binary Exists**
  ```powershell
  # Example for Python/Pyright
  Test-Path "$packageDir/language_servers/python"
  ```

- [ ] **Language Server Executable** (if applicable)
  ```powershell
  # Example for Go/gopls
  Test-Path "$packageDir/language_servers/go/gopls.exe"

  # Try running it
  & "$packageDir/language_servers/go/gopls.exe" version
  # Should display version
  ```

## Performance Testing

### Startup Performance

- [ ] **Cold Start Time**
  ```powershell
  $startTime = Get-Date
  & "$packageDir/bin/serena.exe" --version | Out-Null
  $endTime = Get-Date
  $duration = ($endTime - $startTime).TotalSeconds

  Write-Host "Cold start: $duration seconds"
  # Should be < 5 seconds
  ```

- [ ] **Warm Start Time**
  ```powershell
  # Run multiple times to test warm start
  1..3 | ForEach-Object {
      $startTime = Get-Date
      & "$packageDir/bin/serena.exe" --version | Out-Null
      $endTime = Get-Date
      Write-Host "Run $_: $(($endTime - $startTime).TotalSeconds)s"
  }
  # Should be < 2 seconds
  ```

### Memory Usage

- [ ] **Idle Memory**
  ```powershell
  # Start server
  $process = Start-Process "$packageDir/bin/serena-mcp-server.exe" -PassThru

  # Wait for initialization
  Start-Sleep -Seconds 5

  # Check memory usage
  $mem = (Get-Process -Id $process.Id).WorkingSet64 / 1MB
  Write-Host "Memory usage: $mem MB"

  # Stop process
  Stop-Process -Id $process.Id

  # Memory should be < 500 MB idle
  ```

### Package Size

- [ ] **Total Package Size**
  ```powershell
  $size = (Get-ChildItem $packageDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
  Write-Host "Package size: $size MB"

  # Verify matches tier expectations:
  # Minimal: ~150 MB
  # Essential: ~350-500 MB
  # Complete: ~650-850 MB
  # Full: ~1.2-2.2 GB
  ```

## Compatibility Testing

### Windows Versions

Test on multiple Windows versions:

- [ ] **Windows 10 (version 1903 or later)**
  - Extract and run package
  - Verify all executables work
  - Check language server compatibility

- [ ] **Windows 11**
  - Extract and run package
  - Verify all executables work
  - Check UI compatibility

- [ ] **Windows Server 2019/2022**
  - Extract and run package
  - Verify server functionality
  - Check headless operation

### Architecture Testing

If built for multiple architectures:

- [ ] **x64 on x64 System**
  - Native execution
  - Full performance
  - All features work

- [ ] **ARM64 on ARM64 System** (if available)
  - Native execution
  - Check emulated language servers work
  - Verify performance

### Portable Drive Test

- [ ] **USB Drive Deployment**
  ```powershell
  # Copy package to USB drive
  $usbDrive = "E:"  # Adjust as needed
  Copy-Item $packageDir "$usbDrive\serena-portable" -Recurse

  # Run from USB
  cd "$usbDrive\serena-portable"
  .\serena-portable.bat --version

  # Verify it works
  ```

- [ ] **Network Share Deployment**
  ```powershell
  # Copy to network share
  $networkPath = "\\server\share\serena-portable"
  Copy-Item $packageDir $networkPath -Recurse

  # Run from network
  cd $networkPath
  .\serena-portable.bat --version

  # Verify it works
  ```

## Regression Testing

### Compare with Previous Build

If previous build available:

- [ ] **Size Comparison**
  ```powershell
  $oldSize = (Get-ChildItem [old-package] -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
  $newSize = (Get-ChildItem $packageDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
  $diff = $newSize - $oldSize

  Write-Host "Old: $oldSize MB"
  Write-Host "New: $newSize MB"
  Write-Host "Diff: $diff MB"

  # Large differences should be investigated
  ```

- [ ] **Feature Parity**
  - All previous features still work
  - No regressions in functionality
  - New features work as expected

- [ ] **Performance Comparison**
  - Startup time not significantly worse
  - Memory usage comparable
  - Language server performance maintained

## Build Manifest Testing

### Manifest Structure

- [ ] **Manifest Valid JSON**
  ```powershell
  $manifest = Get-Content "dist/windows/build-manifest-latest.json" | ConvertFrom-Json
  # Should parse without errors
  ```

- [ ] **Required Fields Present**
  ```powershell
  $manifest.build_id
  $manifest.version
  $manifest.tier
  $manifest.architecture
  $manifest.stages
  # All should have values
  ```

- [ ] **Stage Status**
  ```powershell
  foreach ($stage in $manifest.stages.PSObject.Properties) {
      $status = $stage.Value.status
      Write-Host "$($stage.Name): $status"

      # All should be "completed" or "skipped" (not "failed")
  }
  ```

- [ ] **Checksums Present**
  ```powershell
  $manifest.checksums.archive
  $manifest.checksums.'serena-mcp-server.exe'
  $manifest.checksums.'serena.exe'
  $manifest.checksums.'index-project.exe'
  # All should be 64-character SHA256 hashes
  ```

### Manifest Accuracy

- [ ] **Version Matches**
  ```powershell
  $manifestVersion = $manifest.version
  $versionFileContent = Get-Content "$packageDir/VERSION.txt"
  # Versions should match
  ```

- [ ] **Tier Matches**
  ```powershell
  $manifestTier = $manifest.tier
  # Should match build parameter
  ```

- [ ] **Build Duration Reasonable**
  ```powershell
  $duration = $manifest.build_duration_seconds
  Write-Host "Build took: $duration seconds"

  # Should match tier expectations:
  # Minimal: ~180-240s
  # Essential: ~300-480s
  # Complete: ~600-720s
  # Full: ~900-1200s
  ```

## Security Testing

### Binary Integrity

- [ ] **No Malware Detection**
  ```powershell
  # Run Windows Defender scan
  Start-MpScan -ScanPath $packageDir -ScanType QuickScan

  # Should complete with no threats found
  ```

- [ ] **Digital Signatures** (if signed)
  ```powershell
  Get-AuthenticodeSignature "$packageDir/bin/serena.exe"
  # Should show valid signature if code signing is implemented
  ```

### File Permissions

- [ ] **Executable Permissions**
  ```powershell
  Get-Acl "$packageDir/bin/serena.exe"
  # Should have execute permissions
  ```

- [ ] **No Overly Permissive Files**
  ```powershell
  # Check that no files are world-writable inappropriately
  # This is less critical on Windows but still good practice
  ```

## Documentation Testing

### README Accuracy

- [ ] **README-PORTABLE.md**
  - Version information correct
  - System requirements accurate
  - Installation steps clear
  - Examples work as documented

- [ ] **Quick Start Guide**
  - Commands execute as documented
  - Output matches examples
  - No missing prerequisites

### Help Text

- [ ] **Command Help Accurate**
  ```powershell
  # For each executable, verify help text
  .\bin\serena-mcp-server.exe --help
  .\bin\serena.exe --help
  .\bin\index-project.exe --help

  # Help should be:
  # - Complete
  # - Accurate
  # - Well-formatted
  ```

## Cleanup and Finalization

### Build Artifacts

- [ ] **Temporary Files Cleaned** (if -Clean used)
  ```powershell
  # These should NOT exist after build:
  Test-Path "dist/windows/temp"  # Should be False
  Test-Path "[repo-root]/build"  # Should be False
  ```

- [ ] **Build Logs Preserved**
  ```powershell
  Test-Path "dist/windows/build.log"  # Should be True
  Test-Path "dist/windows/build-manifest-latest.json"  # Should be True
  ```

### Release Readiness

- [ ] **All Files Ready for Distribution**
  - Package directory complete
  - ZIP archive created
  - Checksum file present
  - Build manifest generated

- [ ] **Documentation Complete**
  - README accurate
  - Version info correct
  - Changelog updated (if applicable)

- [ ] **Testing Complete**
  - All critical tests passed
  - No major issues found
  - Performance acceptable

## Test Result Summary

```
┌─────────────────────────────────────────────────────┐
│          TESTING CHECKLIST SUMMARY                  │
├─────────────────────────────────────────────────────┤
│ Pre-Build Tests:        [ ] Passed  [ ] Failed      │
│ Build Execution:        [ ] Passed  [ ] Failed      │
│ Package Structure:      [ ] Passed  [ ] Failed      │
│ Archive Tests:          [ ] Passed  [ ] Failed      │
│ Functional Tests:       [ ] Passed  [ ] Failed      │
│ Performance Tests:      [ ] Passed  [ ] Failed      │
│ Compatibility Tests:    [ ] Passed  [ ] Failed      │
│ Manifest Tests:         [ ] Passed  [ ] Failed      │
│ Security Tests:         [ ] Passed  [ ] Failed      │
│ Documentation Tests:    [ ] Passed  [ ] Failed      │
├─────────────────────────────────────────────────────┤
│ OVERALL RESULT:         [ ] PASS    [ ] FAIL        │
└─────────────────────────────────────────────────────┘

Build ID: _______________________
Version: ________________________
Tier: ___________________________
Tested By: ______________________
Date: ___________________________

Notes:
_________________________________________________
_________________________________________________
_________________________________________________
```

## End-to-End (E2E) Testing

**NEW**: Automated E2E tests for standalone builds.

See `docs/E2E_TESTING.md` for complete guide.

### Running E2E Tests

- [ ] **Set Build Directory**
  ```powershell
  $env:SERENA_BUILD_DIR = "$packageDir"
  ```

- [ ] **Install Test Dependencies**
  ```powershell
  uv pip install pytest pytest-asyncio
  ```

- [ ] **Run All E2E Tests**
  ```powershell
  uv run pytest test/e2e/ -v -m e2e
  # Should pass all tests (100% pass rate)
  ```

### E2E Test Categories

- [ ] **Standalone Executable Tests**
  ```powershell
  pytest test/e2e/ -v -m standalone
  # Tests: --help, --version, basic commands
  # Expected: All pass (~10 tests, <5s)
  ```

- [ ] **MCP Server Communication Tests**
  ```powershell
  pytest test/e2e/ -v -m mcp
  # Tests: Connection, tool listing, tool invocation
  # Expected: All pass (~15 tests, <30s)
  ```

- [ ] **Tool Execution Tests** (Future)
  ```powershell
  pytest test/e2e/ -v -m tools
  # Tests: find_symbol, edit_symbol, workflows
  # Expected: All pass (~20 tests, <60s)
  ```

- [ ] **Language Server Integration Tests** (Future)
  ```powershell
  pytest test/e2e/ -v -m language_server
  # Tests: LS startup, crash recovery, performance
  # Expected: All pass (~15 tests, <120s)
  ```

### E2E Test Results

- [ ] **All Tests Passed**
  ```powershell
  # Check test summary
  # Total: XX tests
  # Passed: XX
  # Failed: 0
  # Duration: <5 minutes
  ```

- [ ] **No Test Failures**
  - No connection errors
  - No timeout issues
  - No assertion failures

- [ ] **Performance Within Targets**
  - MCP server startup < 5s
  - Tool calls < 2s
  - No memory leaks

---

**Checklist Version:** 1.1.0
**Last Updated:** 2025-10-22
**For Build Script:** build-windows-portable.ps1 v1.0.0
**E2E Tests:** See docs/E2E_TESTING.md
