# Serena Release Preparation Script
# This script automates the release preparation process including version bumping,
# changelog generation, asset preparation, checksum generation, and release validation.

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$false)]
    [string]$Branch = "main",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildDir = "./dist",
    
    [Parameter(Mandatory=$false)]
    [string]$AssetsDir = "./assets"
)

# Color output functions
function Write-Success { param([string]$Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error { param([string]$Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Info { param([string]$Message) Write-Host "→ $Message" -ForegroundColor Blue }
function Write-Warning { param([string]$Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Validate version format (semantic versioning)
function Test-VersionFormat {
    param([string]$Version)
    
    if ($Version -notmatch '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$') {
        Write-Error "Invalid version format. Expected format: x.y.z or x.y.z-suffix"
        exit 1
    }
    
    # Remove 'v' prefix if present
    return $Version -replace '^v', ''
}

# Check if required tools are available
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $RequiredTools = @(
        @{Name="git"; Command="git --version"},
        @{Name="uv"; Command="uv --version"},
        @{Name="python"; Command="python --version"}
    )
    
    foreach ($Tool in $RequiredTools) {
        try {
            Invoke-Expression $Tool.Command | Out-Null
            Write-Success "$($Tool.Name) is available"
        } catch {
            Write-Error "$($Tool.Name) is not available. Please install it first."
            exit 1
        }
    }
}

# Validate git repository state
function Test-GitRepository {
    Write-Info "Validating git repository state..."
    
    # Check if we're in a git repository
    if (-not (Test-Path ".git")) {
        Write-Error "Not in a git repository"
        exit 1
    }
    
    # Check if working directory is clean
    $GitStatus = git status --porcelain
    if ($GitStatus -and -not $DryRun) {
        Write-Error "Working directory is not clean. Please commit or stash changes."
        Write-Host "Uncommitted changes:" -ForegroundColor Yellow
        git status --short
        exit 1
    }
    
    # Check if we're on the correct branch
    $CurrentBranch = git branch --show-current
    if ($CurrentBranch -ne $Branch) {
        Write-Warning "Currently on branch '$CurrentBranch', expected '$Branch'"
        if (-not $DryRun) {
            $Response = Read-Host "Switch to branch '$Branch'? (y/N)"
            if ($Response -eq 'y' -or $Response -eq 'Y') {
                git checkout $Branch
                Write-Success "Switched to branch '$Branch'"
            } else {
                Write-Error "Aborting release preparation"
                exit 1
            }
        }
    }
    
    # Ensure we're up to date with remote
    if (-not $DryRun) {
        Write-Info "Pulling latest changes from remote..."
        git pull origin $Branch
    }
    
    Write-Success "Git repository state is valid"
}

# Update version in pyproject.toml
function Update-Version {
    param([string]$NewVersion)
    
    Write-Info "Updating version to $NewVersion..."
    
    $PyProjectPath = "./pyproject.toml"
    if (-not (Test-Path $PyProjectPath)) {
        Write-Error "pyproject.toml not found"
        exit 1
    }
    
    # Read current version
    $Content = Get-Content $PyProjectPath -Raw
    $CurrentVersion = [regex]::Match($Content, 'version\s*=\s*"([^"]+)"').Groups[1].Value
    
    if (-not $CurrentVersion) {
        Write-Error "Could not find current version in pyproject.toml"
        exit 1
    }
    
    Write-Info "Current version: $CurrentVersion"
    Write-Info "New version: $NewVersion"
    
    if (-not $DryRun) {
        # Update version
        $UpdatedContent = $Content -replace 'version\s*=\s*"[^"]+"', "version = `"$NewVersion`""
        Set-Content -Path $PyProjectPath -Value $UpdatedContent -NoNewline
        Write-Success "Updated version in pyproject.toml"
    } else {
        Write-Info "[DRY RUN] Would update version in pyproject.toml"
    }
    
    return $CurrentVersion
}

# Generate changelog entry
function Update-Changelog {
    param([string]$Version, [string]$PreviousVersion)
    
    Write-Info "Updating changelog..."
    
    $ChangelogPath = "./CHANGELOG.md"
    if (-not (Test-Path $ChangelogPath)) {
        Write-Error "CHANGELOG.md not found"
        exit 1
    }
    
    if (-not $DryRun) {
        # Get commits since last version
        $CommitRange = if ($PreviousVersion) { "$PreviousVersion..HEAD" } else { "HEAD" }
        $Commits = git log --oneline --no-merges $CommitRange
        
        if ($Commits) {
            # Read current changelog
            $ChangelogContent = Get-Content $ChangelogPath -Raw
            
            # Generate new changelog entry
            $Date = Get-Date -Format "yyyy-MM-dd"
            $NewEntry = @"
# $Version - $Date

## Changes

$(($Commits | ForEach-Object { "* $_" }) -join "`n")

"@
            
            # Insert new entry after "# latest" section
            $UpdatedChangelog = $ChangelogContent -replace '(# latest\s*\n[^\n]*\n)', "`$1`n$NewEntry`n"
            
            Set-Content -Path $ChangelogPath -Value $UpdatedChangelog -NoNewline
            Write-Success "Updated CHANGELOG.md with $($Commits.Count) commits"
        } else {
            Write-Warning "No new commits found for changelog"
        }
    } else {
        Write-Info "[DRY RUN] Would update CHANGELOG.md"
    }
}

# Run tests and quality checks
function Invoke-QualityChecks {
    Write-Info "Running quality checks..."
    
    if ($SkipTests) {
        Write-Warning "Skipping tests as requested"
        return
    }
    
    if (-not $DryRun) {
        try {
            Write-Info "Running code formatting..."
            & uv run poe format
            
            Write-Info "Running type checks..."
            & uv run poe type-check
            
            Write-Info "Running tests..."
            & uv run poe test
            
            Write-Success "All quality checks passed"
        } catch {
            Write-Error "Quality checks failed: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Info "[DRY RUN] Would run quality checks"
    }
}

# Build distribution packages
function Build-Distribution {
    Write-Info "Building distribution packages..."
    
    if (-not $DryRun) {
        # Clean previous builds
        if (Test-Path $BuildDir) {
            Remove-Item -Recurse -Force $BuildDir
        }
        
        try {
            Write-Info "Building wheel and source distribution..."
            & uv build --out-dir $BuildDir
            
            # List built files
            $BuiltFiles = Get-ChildItem $BuildDir
            Write-Success "Built packages:"
            $BuiltFiles | ForEach-Object { Write-Host "  $($_.Name)" -ForegroundColor Cyan }
            
            return $BuiltFiles
        } catch {
            Write-Error "Build failed: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Info "[DRY RUN] Would build distribution packages"
        return @()
    }
}

# Generate checksums for release assets
function New-Checksums {
    param([array]$Files)
    
    Write-Info "Generating checksums..."
    
    if (-not $DryRun -and $Files.Count -gt 0) {
        $ChecksumPath = Join-Path $BuildDir "checksums.txt"
        $Checksums = @()
        
        foreach ($File in $Files) {
            $Hash = Get-FileHash -Path $File.FullName -Algorithm SHA256
            $RelativePath = Split-Path -Leaf $File.FullName
            $Checksums += "$($Hash.Hash)  $RelativePath"
            Write-Info "SHA256($RelativePath) = $($Hash.Hash)"
        }
        
        $Checksums | Out-File -FilePath $ChecksumPath -Encoding UTF8
        Write-Success "Generated checksums file: checksums.txt"
        
        return $ChecksumPath
    } else {
        Write-Info "[DRY RUN] Would generate checksums"
        return $null
    }
}

# Create release assets
function New-ReleaseAssets {
    param([string]$Version)
    
    Write-Info "Preparing release assets..."
    
    if (-not $DryRun) {
        # Create assets directory
        if (-not (Test-Path $AssetsDir)) {
            New-Item -ItemType Directory -Path $AssetsDir | Out-Null
        }
        
        # Copy important files to assets
        $AssetFiles = @(
            "README.md",
            "LICENSE",
            "CHANGELOG.md",
            "CONTRIBUTING.md"
        )
        
        foreach ($File in $AssetFiles) {
            if (Test-Path $File) {
                Copy-Item $File -Destination $AssetsDir
                Write-Info "Added $File to release assets"
            }
        }
        
        # Create version info file
        $VersionInfo = @{
            version = $Version
            build_date = Get-Date -Format "o"
            git_commit = git rev-parse HEAD
            git_branch = git branch --show-current
            python_version = (python --version)
            uv_version = (uv --version)
        } | ConvertTo-Json -Depth 2
        
        $VersionInfo | Out-File -FilePath (Join-Path $AssetsDir "version-info.json") -Encoding UTF8
        
        Write-Success "Release assets prepared in $AssetsDir"
    } else {
        Write-Info "[DRY RUN] Would prepare release assets"
    }
}

# Validate the release
function Test-Release {
    param([string]$Version)
    
    Write-Info "Validating release..."
    
    if (-not $DryRun) {
        try {
            # Check if version was updated correctly
            $UpdatedContent = Get-Content "./pyproject.toml" -Raw
            if ($UpdatedContent -match "version\s*=\s*`"$([regex]::Escape($Version))`"") {
                Write-Success "Version correctly updated in pyproject.toml"
            } else {
                Write-Error "Version not correctly updated in pyproject.toml"
                exit 1
            }
            
            # Check if distribution files exist
            if (Test-Path $BuildDir) {
                $WheelFile = Get-ChildItem -Path $BuildDir -Filter "*.whl" | Select-Object -First 1
                $TarFile = Get-ChildItem -Path $BuildDir -Filter "*.tar.gz" | Select-Object -First 1
                
                if ($WheelFile -and $TarFile) {
                    Write-Success "Distribution files created successfully"
                } else {
                    Write-Error "Distribution files missing"
                    exit 1
                }
            }
            
            Write-Success "Release validation completed"
        } catch {
            Write-Error "Release validation failed: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Info "[DRY RUN] Would validate release"
    }
}

# Create git tag
function New-GitTag {
    param([string]$Version)
    
    Write-Info "Creating git tag..."
    
    if (-not $DryRun) {
        $TagName = "v$Version"
        $TagMessage = "Release version $Version"
        
        try {
            git tag -a $TagName -m $TagMessage
            Write-Success "Created git tag: $TagName"
            
            Write-Info "To push the tag, run: git push origin $TagName"
        } catch {
            Write-Error "Failed to create git tag: $($_.Exception.Message)"
            exit 1
        }
    } else {
        Write-Info "[DRY RUN] Would create git tag: v$Version"
    }
}

# Main execution
function Main {
    Write-Host "`n=== Serena Release Preparation Script ===" -ForegroundColor Magenta
    Write-Host "Version: $Version" -ForegroundColor Cyan
    Write-Host "Branch: $Branch" -ForegroundColor Cyan
    Write-Host "Dry Run: $DryRun" -ForegroundColor Cyan
    Write-Host ""
    
    # Validate version format
    $CleanVersion = Test-VersionFormat $Version
    
    # Step 1: Check prerequisites
    Test-Prerequisites
    
    # Step 2: Validate git repository
    Test-GitRepository
    
    # Step 3: Update version
    $PreviousVersion = Update-Version $CleanVersion
    
    # Step 4: Update changelog
    Update-Changelog $CleanVersion $PreviousVersion
    
    # Step 5: Run quality checks
    Invoke-QualityChecks
    
    # Step 6: Build distribution
    $DistributionFiles = Build-Distribution
    
    # Step 7: Generate checksums
    $ChecksumFile = New-Checksums $DistributionFiles
    
    # Step 8: Prepare release assets
    New-ReleaseAssets $CleanVersion
    
    # Step 9: Validate release
    Test-Release $CleanVersion
    
    # Step 10: Create git tag
    New-GitTag $CleanVersion
    
    Write-Host "`n=== Release Preparation Complete ===" -ForegroundColor Green
    
    if (-not $DryRun) {
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "1. Review the changes and commit them"
        Write-Host "2. Push the tag: git push origin v$CleanVersion"
        Write-Host "3. Create a GitHub release using the generated assets"
        Write-Host "4. Upload distribution files from $BuildDir"
        Write-Host "5. Publish to PyPI if desired"
    } else {
        Write-Host "`nThis was a dry run. No changes were made." -ForegroundColor Yellow
        Write-Host "Run without -DryRun to execute the release preparation."
    }
}

# Execute main function
try {
    Main
} catch {
    Write-Error "Release preparation failed: $($_.Exception.Message)"
    exit 1
}