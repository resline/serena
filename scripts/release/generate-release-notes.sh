#!/bin/bash
# Generate release notes from template and git history
# This script helps create comprehensive release notes using the template

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FILE=""
FROM_TAG=""
TO_TAG="HEAD"
TEMPLATE_FILE="$(dirname "$0")/release-notes-template.md"

# Logging functions
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; }
log_info() { echo -e "${BLUE}→ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }

usage() {
    cat << EOF
Usage: $0 -v VERSION [OPTIONS]

Generate release notes from template and git history.

Required:
    -v, --version VERSION    Release version (e.g., 1.0.0)

Options:
    -f, --from TAG          Start tag for git log (default: previous version tag)
    -t, --to TAG            End tag for git log (default: HEAD)  
    -o, --output FILE       Output file (default: release-notes-VERSION.md)
    --template FILE         Template file (default: release-notes-template.md)
    -h, --help              Show this help message

Examples:
    $0 -v 1.0.0                           # Generate notes for version 1.0.0
    $0 -v 1.0.0 -f v0.9.0                 # Compare from v0.9.0 to HEAD
    $0 -v 1.0.0 -o custom-notes.md        # Custom output file
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
            -f|--from)
                FROM_TAG="$2"
                shift 2
                ;;
            -t|--to)
                TO_TAG="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --template)
                TEMPLATE_FILE="$2"
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

    # Set default output file if not specified
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="release-notes-${VERSION}.md"
    fi
}

# Get the previous version tag
get_previous_version() {
    if [[ -n "$FROM_TAG" ]]; then
        echo "$FROM_TAG"
        return
    fi

    # Try to find the most recent version tag
    local prev_tag
    prev_tag=$(git describe --tags --abbrev=0 --match="v*.*.*" 2>/dev/null || true)
    
    if [[ -n "$prev_tag" ]]; then
        echo "$prev_tag"
    else
        log_warning "No previous version tag found, using initial commit"
        git rev-list --max-parents=0 HEAD
    fi
}

# Analyze git commits between versions
analyze_commits() {
    local from_ref="$1"
    local to_ref="$2"
    
    log_info "Analyzing commits from $from_ref to $to_ref..."
    
    # Get commit range
    local commit_range
    if [[ "$from_ref" == *"$(git rev-parse --short HEAD)"* ]] || [[ "$from_ref" == "HEAD" ]]; then
        # If from_ref is a commit hash or HEAD, just use it
        commit_range="$from_ref"
    else
        commit_range="${from_ref}..${to_ref}"
    fi
    
    # Categorize commits by conventional commit types
    declare -A commit_categories
    
    # Get all commits with their messages
    while IFS= read -r commit; do
        local hash msg
        hash=$(echo "$commit" | cut -d'|' -f1)
        msg=$(echo "$commit" | cut -d'|' -f2-)
        
        # Categorize based on conventional commit format
        local category="misc"
        case "$msg" in
            feat*|feature*) category="features" ;;
            fix*|bugfix*) category="fixes" ;;
            docs*|doc*) category="docs" ;;
            test*|tests*) category="tests" ;;
            chore*) category="chore" ;;
            refactor*) category="refactor" ;;
            perf*|performance*) category="performance" ;;
            ci*|workflow*) category="ci" ;;
            breaking*|BREAKING*) category="breaking" ;;
            *language*|*lsp*|*server*) category="language" ;;
            *tool*|*symbol*|*file*) category="tools" ;;
            *config*|*setup*) category="config" ;;
            *mcp*|*agent*) category="agent" ;;
        esac
        
        if [[ -z "${commit_categories[$category]:-}" ]]; then
            commit_categories[$category]=""
        fi
        commit_categories[$category]+="- ${msg} (${hash:0:8})\n"
        
    done < <(git log --pretty=format:'%h|%s' "$commit_range" --no-merges 2>/dev/null || echo "")
    
    # Output categorized commits to temporary files
    local temp_dir
    temp_dir=$(mktemp -d)
    
    for category in "${!commit_categories[@]}"; do
        echo -e "${commit_categories[$category]}" > "${temp_dir}/${category}.txt"
    done
    
    echo "$temp_dir"
}

# Generate placeholders from git analysis
generate_placeholders() {
    local version="$1"
    local from_ref="$2" 
    local to_ref="$3"
    local analysis_dir="$4"
    
    declare -A placeholders
    
    # Basic version info
    placeholders["VERSION"]="$version"
    placeholders["RELEASE_DATE"]="$(date '+%Y-%m-%d')"
    placeholders["PREVIOUS_VERSION"]="$(echo "$from_ref" | sed 's/^v//')"
    
    # Git info
    placeholders["GIT_COMMIT"]="$(git rev-parse HEAD)"
    placeholders["GIT_BRANCH"]="$(git branch --show-current)"
    
    # Commit counts
    local total_commits
    total_commits=$(git rev-list --count "${from_ref}..${to_ref}" 2>/dev/null || echo "0")
    placeholders["TOTAL_COMMITS"]="$total_commits"
    
    # File counts
    local files_changed
    files_changed=$(git diff --name-only "${from_ref}..${to_ref}" 2>/dev/null | wc -l || echo "0")
    placeholders["FILES_CHANGED"]="$files_changed"
    
    # Contributor info
    local contributors
    contributors=$(git shortlog -sn "${from_ref}..${to_ref}" 2>/dev/null | wc -l || echo "0")
    placeholders["CONTRIBUTOR_COUNT"]="$contributors"
    
    # Category-specific content
    if [[ -f "${analysis_dir}/features.txt" ]]; then
        placeholders["NEW_FEATURES"]="$(head -10 "${analysis_dir}/features.txt" || echo "No new features")"
    else
        placeholders["NEW_FEATURES"]="No new features"
    fi
    
    if [[ -f "${analysis_dir}/fixes.txt" ]]; then
        placeholders["BUG_FIXES"]="$(head -10 "${analysis_dir}/fixes.txt" || echo "No bug fixes")"
    else
        placeholders["BUG_FIXES"]="No bug fixes"
    fi
    
    if [[ -f "${analysis_dir}/breaking.txt" ]]; then
        placeholders["BREAKING_CHANGES"]="$(cat "${analysis_dir}/breaking.txt" || echo "No breaking changes")"
    else
        placeholders["BREAKING_CHANGES"]="No breaking changes"
    fi
    
    # Simple descriptions (these should be manually updated)
    placeholders["BRIEF_DESCRIPTION"]="[EDIT: Brief description of this release]"
    placeholders["MAJOR_HIGHLIGHTS"]="[EDIT: Major highlights and improvements]"
    
    # Technical details (should be manually updated)
    placeholders["PERFORMANCE_IMPROVEMENTS"]="[EDIT: Performance improvements if any]"
    placeholders["DX_IMPROVEMENTS"]="[EDIT: Developer experience improvements]"
    placeholders["STABILITY_IMPROVEMENTS"]="[EDIT: Stability improvements]"
    
    # Print placeholders for reference
    echo "$temp_dir"
    for key in "${!placeholders[@]}"; do
        echo "${key}=${placeholders[$key]}"
    done > "${temp_dir}/placeholders.env"
    
    # Return the temp directory
    echo "$temp_dir"
}

# Apply placeholders to template
apply_template() {
    local template_file="$1"
    local output_file="$2"
    local placeholders_file="$3"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        exit 1
    fi
    
    log_info "Applying template: $template_file -> $output_file"
    
    # Start with the template
    cp "$template_file" "$output_file"
    
    # Apply placeholders
    while IFS='=' read -r key value; do
        if [[ -n "$key" ]] && [[ -n "$value" ]]; then
            # Replace {KEY} with value
            sed -i "s/{$key}/$value/g" "$output_file" 2>/dev/null || {
                # Fallback for systems where sed -i needs backup
                sed "s/{$key}/$value/g" "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
            }
        fi
    done < "$placeholders_file"
    
    log_success "Generated release notes: $output_file"
}

# Add manual editing reminders
add_editing_reminders() {
    local output_file="$1"
    
    cat << 'EOF' >> "$output_file"

---
## 📝 Editing Checklist

**Before publishing these release notes, please:**

- [ ] Review and update the brief description
- [ ] Add specific feature descriptions
- [ ] Document any breaking changes with migration guides  
- [ ] Update performance improvement details
- [ ] Add known issues if any
- [ ] Verify installation instructions
- [ ] Check asset links and checksums
- [ ] Remove placeholder text and this checklist

**Sections that typically need manual editing:**
- Version highlights and brief description
- Breaking changes with migration instructions
- Feature descriptions with usage examples
- Performance improvements with metrics
- Known issues and workarounds
- Asset checksums and download sizes

EOF
}

# Main execution
main() {
    echo -e "\n${CYAN}=== Serena Release Notes Generator ===${NC}"
    echo -e "${CYAN}Version: $VERSION${NC}"
    echo -e "${CYAN}Output: $OUTPUT_FILE${NC}"
    echo ""
    
    # Check if we're in a git repository
    if [[ ! -d .git ]]; then
        log_error "Not in a git repository"
        exit 1
    fi
    
    # Get version range
    local from_ref
    from_ref=$(get_previous_version)
    
    log_info "Analyzing changes from $from_ref to $TO_TAG"
    
    # Analyze commits
    local analysis_dir
    analysis_dir=$(analyze_commits "$from_ref" "$TO_TAG")
    
    # Generate placeholders
    local placeholders_dir
    placeholders_dir=$(generate_placeholders "$VERSION" "$from_ref" "$TO_TAG" "$analysis_dir")
    
    # Apply template
    apply_template "$TEMPLATE_FILE" "$OUTPUT_FILE" "${placeholders_dir}/placeholders.env"
    
    # Add editing reminders
    add_editing_reminders "$OUTPUT_FILE"
    
    # Cleanup
    rm -rf "$analysis_dir" "$placeholders_dir" || true
    
    log_success "Release notes generated successfully!"
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo "1. Review and edit: $OUTPUT_FILE"
    echo "2. Update placeholder content marked with [EDIT: ...]"
    echo "3. Add specific feature descriptions and breaking changes"
    echo "4. Verify asset information and checksums"
    echo "5. Remove the editing checklist before publishing"
    
    echo -e "\n${YELLOW}Quick preview:${NC}"
    head -20 "$OUTPUT_FILE" | sed 's/^/  /'
    echo "  ..."
    echo -e "\n${BLUE}Full content saved to: $OUTPUT_FILE${NC}"
}

# Parse arguments and run
parse_args "$@"
main