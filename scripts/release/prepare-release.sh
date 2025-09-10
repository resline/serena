#!/bin/bash
# Serena Release Preparation Script (Bash version)
# This script automates the release preparation process including version bumping,
# changelog generation, asset preparation, checksum generation, and release validation.

set -euo pipefail

# Default values
BRANCH="main"
DRY_RUN=false
SKIP_TESTS=false
BUILD_DIR="./dist"
ASSETS_DIR="./assets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; }
log_info() { echo -e "${BLUE}→ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Usage information
usage() {
    cat << EOF
Usage: $0 -v VERSION [OPTIONS]

Required:
    -v, --version VERSION    Release version (e.g., 1.0.0)

Options:
    -b, --branch BRANCH      Git branch to use (default: main)
    -d, --dry-run           Run without making changes
    -s, --skip-tests        Skip running tests
    --build-dir DIR         Build output directory (default: ./dist)
    --assets-dir DIR        Assets directory (default: ./assets)
    -h, --help              Show this help message

Examples:
    $0 -v 1.0.0                    # Prepare release 1.0.0
    $0 -v 1.0.0 --dry-run          # Dry run for version 1.0.0
    $0 -v 1.0.0 -b develop         # Use develop branch
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -b|--branch)
                BRANCH="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --build-dir)
                BUILD_DIR="$2"
                shift 2
                ;;
            --assets-dir)
                ASSETS_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z "${VERSION:-}" ]]; then
        log_error "Version is required"
        usage
        exit 1
    fi
}

# Validate version format (semantic versioning)
validate_version() {
    local version="$1"
    if [[ ! $version =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$ ]]; then
        log_error "Invalid version format. Expected format: x.y.z or x.y.z-suffix"
        exit 1
    fi
    
    # Remove 'v' prefix if present
    VERSION="${version#v}"
}

# Check if required tools are available
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local tools=("git" "python3")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "$tool is available"
        else
            log_error "$tool is not available. Please install it first."
            exit 1
        fi
    done
    
    # Check for uv (optional but preferred)
    if command -v uv >/dev/null 2>&1; then
        PYTHON_RUNNER="uv run"
        log_success "uv is available (preferred)"
    else
        PYTHON_RUNNER="python3 -m"
        log_warning "uv not found, falling back to python3 -m"
    fi
}

# Validate git repository state
validate_git_repo() {
    log_info "Validating git repository state..."
    
    # Check if we're in a git repository
    if [[ ! -d .git ]]; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Check if working directory is clean
    if [[ -n $(git status --porcelain) ]] && [[ $DRY_RUN == false ]]; then
        log_error "Working directory is not clean. Please commit or stash changes."
        echo "Uncommitted changes:"
        git status --short
        exit 1
    fi
    
    # Check if we're on the correct branch
    local current_branch
    current_branch=$(git branch --show-current)
    if [[ $current_branch != "$BRANCH" ]]; then
        log_warning "Currently on branch '$current_branch', expected '$BRANCH'"
        if [[ $DRY_RUN == false ]]; then
            read -p "Switch to branch '$BRANCH'? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git checkout "$BRANCH"
                log_success "Switched to branch '$BRANCH'"
            else
                log_error "Aborting release preparation"
                exit 1
            fi
        fi
    fi
    
    # Ensure we're up to date with remote
    if [[ $DRY_RUN == false ]]; then
        log_info "Pulling latest changes from remote..."
        git pull origin "$BRANCH"
    fi
    
    log_success "Git repository state is valid"
}

# Update version in pyproject.toml
update_version() {
    local new_version="$1"
    
    log_info "Updating version to $new_version..."
    
    local pyproject_path="./pyproject.toml"
    if [[ ! -f $pyproject_path ]]; then
        log_error "pyproject.toml not found"
        exit 1
    fi
    
    # Extract current version
    local current_version
    current_version=$(grep -oP 'version\s*=\s*"\K[^"]+' "$pyproject_path" || true)
    
    if [[ -z $current_version ]]; then
        log_error "Could not find current version in pyproject.toml"
        exit 1
    fi
    
    log_info "Current version: $current_version"
    log_info "New version: $new_version"
    
    if [[ $DRY_RUN == false ]]; then
        # Update version using sed
        sed -i.bak "s/version\s*=\s*\"[^\"]*\"/version = \"$new_version\"/" "$pyproject_path"
        rm -f "${pyproject_path}.bak"
        log_success "Updated version in pyproject.toml"
    else
        log_info "[DRY RUN] Would update version in pyproject.toml"
    fi
    
    echo "$current_version"
}

# Update changelog
update_changelog() {
    local version="$1"
    local previous_version="$2"
    
    log_info "Updating changelog..."
    
    local changelog_path="./CHANGELOG.md"
    if [[ ! -f $changelog_path ]]; then
        log_error "CHANGELOG.md not found"
        exit 1
    fi
    
    if [[ $DRY_RUN == false ]]; then
        # Get commits since last version
        local commit_range="HEAD"
        if [[ -n $previous_version ]]; then
            commit_range="${previous_version}..HEAD"
        fi
        
        local commits
        commits=$(git log --oneline --no-merges "$commit_range" 2>/dev/null || true)
        
        if [[ -n $commits ]]; then
            local date
            date=$(date '+%Y-%m-%d')
            
            # Create new changelog entry
            local new_entry="# $version - $date

## Changes

$(echo "$commits" | sed 's/^/* /')

"
            
            # Insert new entry after "# latest" section
            awk -v entry="$new_entry" '
                /^# latest/ {
                    print $0
                    getline
                    print $0
                    print ""
                    print entry
                    next
                }
                {print}
            ' "$changelog_path" > "${changelog_path}.tmp" && mv "${changelog_path}.tmp" "$changelog_path"
            
            local commit_count
            commit_count=$(echo "$commits" | wc -l)
            log_success "Updated CHANGELOG.md with $commit_count commits"
        else
            log_warning "No new commits found for changelog"
        fi
    else
        log_info "[DRY RUN] Would update CHANGELOG.md"
    fi
}

# Run quality checks
run_quality_checks() {
    log_info "Running quality checks..."
    
    if [[ $SKIP_TESTS == true ]]; then
        log_warning "Skipping tests as requested"
        return
    fi
    
    if [[ $DRY_RUN == false ]]; then
        if command -v uv >/dev/null 2>&1; then
            log_info "Running code formatting..."
            uv run poe format || { log_error "Code formatting failed"; exit 1; }
            
            log_info "Running type checks..."
            uv run poe type-check || { log_error "Type checking failed"; exit 1; }
            
            log_info "Running tests..."
            uv run poe test || { log_error "Tests failed"; exit 1; }
        else
            log_warning "uv not available, skipping quality checks"
            log_info "Please run quality checks manually:"
            log_info "  - Code formatting: black src scripts test && ruff check --fix src scripts test"
            log_info "  - Type checking: mypy src/serena"
            log_info "  - Tests: pytest test -vv"
        fi
        
        log_success "All quality checks passed"
    else
        log_info "[DRY RUN] Would run quality checks"
    fi
}

# Build distribution packages
build_distribution() {
    log_info "Building distribution packages..."
    
    if [[ $DRY_RUN == false ]]; then
        # Clean previous builds
        if [[ -d $BUILD_DIR ]]; then
            rm -rf "$BUILD_DIR"
        fi
        
        if command -v uv >/dev/null 2>&1; then
            log_info "Building wheel and source distribution..."
            uv build --out-dir "$BUILD_DIR" || { log_error "Build failed"; exit 1; }
        else
            # Fallback to python setup
            log_info "Building with python build module..."
            python3 -m pip install build 2>/dev/null || true
            python3 -m build --outdir "$BUILD_DIR" || { log_error "Build failed"; exit 1; }
        fi
        
        # List built files
        log_success "Built packages:"
        ls -la "$BUILD_DIR" | grep -E '\.(whl|tar\.gz)$' | while read -r line; do
            echo "  $(echo "$line" | awk '{print $9}')"
        done
    else
        log_info "[DRY RUN] Would build distribution packages"
    fi
}

# Generate checksums
generate_checksums() {
    log_info "Generating checksums..."
    
    if [[ $DRY_RUN == false ]] && [[ -d $BUILD_DIR ]]; then
        local checksum_file="$BUILD_DIR/checksums.txt"
        
        # Generate checksums for all files in build directory
        (cd "$BUILD_DIR" && sha256sum *.whl *.tar.gz 2>/dev/null > checksums.txt || true)
        
        if [[ -f $checksum_file ]]; then
            log_success "Generated checksums file: checksums.txt"
            while IFS= read -r line; do
                log_info "SHA256: $line"
            done < "$checksum_file"
        fi
    else
        log_info "[DRY RUN] Would generate checksums"
    fi
}

# Create release assets
create_release_assets() {
    local version="$1"
    
    log_info "Preparing release assets..."
    
    if [[ $DRY_RUN == false ]]; then
        # Create assets directory
        mkdir -p "$ASSETS_DIR"
        
        # Copy important files to assets
        local asset_files=("README.md" "LICENSE" "CHANGELOG.md" "CONTRIBUTING.md")
        
        for file in "${asset_files[@]}"; do
            if [[ -f $file ]]; then
                cp "$file" "$ASSETS_DIR/"
                log_info "Added $file to release assets"
            fi
        done
        
        # Create version info file
        local version_info
        version_info=$(cat << EOF
{
  "version": "$version",
  "build_date": "$(date -Iseconds)",
  "git_commit": "$(git rev-parse HEAD)",
  "git_branch": "$(git branch --show-current)",
  "python_version": "$(python3 --version)",
  "build_system": "$(command -v uv >/dev/null && echo 'uv' || echo 'pip')"
}
EOF
        )
        
        echo "$version_info" > "$ASSETS_DIR/version-info.json"
        
        log_success "Release assets prepared in $ASSETS_DIR"
    else
        log_info "[DRY RUN] Would prepare release assets"
    fi
}

# Validate the release
validate_release() {
    local version="$1"
    
    log_info "Validating release..."
    
    if [[ $DRY_RUN == false ]]; then
        # Check if version was updated correctly
        if grep -q "version = \"$version\"" "./pyproject.toml"; then
            log_success "Version correctly updated in pyproject.toml"
        else
            log_error "Version not correctly updated in pyproject.toml"
            exit 1
        fi
        
        # Check if distribution files exist
        if [[ -d $BUILD_DIR ]]; then
            local wheel_count tar_count
            wheel_count=$(find "$BUILD_DIR" -name "*.whl" | wc -l)
            tar_count=$(find "$BUILD_DIR" -name "*.tar.gz" | wc -l)
            
            if [[ $wheel_count -gt 0 ]] && [[ $tar_count -gt 0 ]]; then
                log_success "Distribution files created successfully"
            else
                log_error "Distribution files missing (wheel: $wheel_count, tar: $tar_count)"
                exit 1
            fi
        fi
        
        log_success "Release validation completed"
    else
        log_info "[DRY RUN] Would validate release"
    fi
}

# Create git tag
create_git_tag() {
    local version="$1"
    
    log_info "Creating git tag..."
    
    if [[ $DRY_RUN == false ]]; then
        local tag_name="v$version"
        local tag_message="Release version $version"
        
        if git tag -a "$tag_name" -m "$tag_message"; then
            log_success "Created git tag: $tag_name"
            log_info "To push the tag, run: git push origin $tag_name"
        else
            log_error "Failed to create git tag"
            exit 1
        fi
    else
        log_info "[DRY RUN] Would create git tag: v$version"
    fi
}

# Main execution
main() {
    echo -e "\n${MAGENTA}=== Serena Release Preparation Script ===${NC}"
    echo -e "${CYAN}Version: $VERSION${NC}"
    echo -e "${CYAN}Branch: $BRANCH${NC}"
    echo -e "${CYAN}Dry Run: $DRY_RUN${NC}"
    echo ""
    
    # Validate version format
    validate_version "$VERSION"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Validate git repository
    validate_git_repo
    
    # Step 3: Update version
    local previous_version
    previous_version=$(update_version "$VERSION")
    
    # Step 4: Update changelog
    update_changelog "$VERSION" "$previous_version"
    
    # Step 5: Run quality checks
    run_quality_checks
    
    # Step 6: Build distribution
    build_distribution
    
    # Step 7: Generate checksums
    generate_checksums
    
    # Step 8: Prepare release assets
    create_release_assets "$VERSION"
    
    # Step 9: Validate release
    validate_release "$VERSION"
    
    # Step 10: Create git tag
    create_git_tag "$VERSION"
    
    echo -e "\n${GREEN}=== Release Preparation Complete ===${NC}"
    
    if [[ $DRY_RUN == false ]]; then
        echo -e "\n${YELLOW}Next steps:${NC}"
        echo "1. Review the changes and commit them"
        echo "2. Push the tag: git push origin v$VERSION"
        echo "3. Create a GitHub release using the generated assets"
        echo "4. Upload distribution files from $BUILD_DIR"
        echo "5. Publish to PyPI if desired"
    else
        echo -e "\n${YELLOW}This was a dry run. No changes were made.${NC}"
        echo "Run without --dry-run to execute the release preparation."
    fi
}

# Parse arguments and run main
parse_args "$@"
main