# Running Portable Build Workflows

## Current Status (as of 2025-10-31)

Successfully triggered manual workflow runs:

- **Linux Portable Build**: https://github.com/resline/serena/actions/runs/18984387720
- **Windows Portable Build**: https://github.com/resline/serena/actions/runs/18984388296

## Running Existing Workflows (Available Now)

These workflows are currently registered and can be run immediately:

```bash
# Run Linux portable build
gh workflow run "Build Linux Portable (Simplified)" --ref main

# Run Windows portable build
gh workflow run "Build Windows Portable" --ref main

# Check status
gh run list --workflow=linux-portable.yml --limit 5
gh run list --workflow=windows-portable.yml --limit 5

# Watch a specific run
gh run watch <run-id>
```

## Running New Modular Workflows (After PR #83 Merge)

Once PR #83 is merged to main, the new modular workflows will be available:

### Option 1: Run Complete Release (Recommended)

Runs both Linux and Windows builds in parallel, generates manifest, uploads to release:

```bash
# Full release with all platforms
gh workflow run "Portable Release Orchestrator" \
  --ref main \
  -f platform_filter="all" \
  -f language_set="standard" \
  -f skip_tests="false"

# Linux only (faster, cheaper)
gh workflow run "Portable Release Orchestrator" \
  --ref main \
  -f platform_filter="linux" \
  -f language_set="minimal" \
  -f skip_tests="true"

# Windows only
gh workflow run "Portable Release Orchestrator" \
  --ref main \
  -f platform_filter="windows" \
  -f language_set="standard"
```

### Option 2: Run Individual Platform Builds

Run Linux or Windows builds independently for testing:

```bash
# Linux build
gh workflow run "Build Portable Package - Linux" \
  --ref main \
  -f version="test-v1.0.0" \
  -f language_set="minimal" \
  -f skip_tests="true"

# Windows build
gh workflow run "Build Portable Package - Windows" \
  --ref main \
  -f version="test-v1.0.0" \
  -f language_set="standard" \
  -f skip_tests="false"
```

## Workflow Parameters

### Platform Filter
- `all` - Build both Linux and Windows (default)
- `linux` - Build only Linux (1x cost multiplier)
- `windows` - Build only Windows (2x cost multiplier)

### Language Set
- `minimal` - Core languages only (Python, TypeScript, Go)
- `standard` - Common languages (default)
- `full` - All 16+ supported languages

### Skip Tests
- `false` - Run integration tests (default, recommended)
- `true` - Skip tests for faster builds (testing only)

### Version
- Empty - Auto-detect from pyproject.toml
- `v1.2.3` - Explicit version string
- `test-v1.0.0` - Test build version

## Monitoring Workflow Runs

```bash
# List recent runs
gh run list --limit 10

# Watch a specific run
gh run watch 18984387720

# View run details
gh run view 18984387720

# Download artifacts
gh run download 18984387720

# View logs
gh run view 18984387720 --log
```

## Cost Optimization Tips

1. **Use Linux for testing** - 1x multiplier vs 2x for Windows
2. **Use minimal language set** - Faster builds, less cache usage
3. **Skip tests during iteration** - Enable for final builds only
4. **Run platforms separately** - Test Linux first, then Windows
5. **Use orchestrator for releases** - Parallel builds are more efficient

## Troubleshooting

### Workflow Not Found

If you get "workflow not found" error, the workflow file must exist on the default branch (main):

```bash
# Check if workflow is registered
gh workflow list | grep -i portable

# If not found, ensure it's merged to main
gh pr view 83
gh pr merge 83 --squash
```

### Build Failures

Common issues and solutions:

1. **Cache issues** - Increment `cache_version` parameter
2. **Language server download failures** - Check network, retry
3. **PyInstaller errors** - Review build logs, check dependencies
4. **Test failures** - Use `skip_tests=true` to isolate build issues

### Viewing Workflow Files

```bash
# View workflow YAML
gh workflow view "Portable Release Orchestrator" --yaml

# View on GitHub
gh workflow view "Portable Release Orchestrator" --web
```

## Expected Build Times

- **Linux (minimal)**: ~10-15 minutes
- **Linux (standard)**: ~20-30 minutes
- **Linux (full)**: ~40-60 minutes
- **Windows (minimal)**: ~15-20 minutes (2x Linux)
- **Windows (standard)**: ~30-45 minutes
- **Windows (full)**: ~60-90 minutes

## Artifact Outputs

After successful builds, artifacts are uploaded:

- `serena-linux-x64-<version>.tar.gz` - Linux portable package
- `serena-linux-x64-<version>.tar.gz.sha256` - Checksum
- `serena-windows-x64-<version>.zip` - Windows portable package
- `serena-windows-x64-<version>.zip.sha256` - Checksum
- `latest.json` - Release manifest (orchestrator only)

Download with:

```bash
gh run download <run-id>
```

## Release Workflow

For official releases:

1. Create and push version tag:
   ```bash
   git tag v1.2.3
   git push origin v1.2.3
   ```

2. Workflow auto-triggers, builds both platforms

3. Creates GitHub release with artifacts

4. Generates manifest at `latest.json`

## Next Steps

After PR #83 is merged:

1. Verify workflows are registered: `gh workflow list | grep -i portable`
2. Test Linux build first (cheaper, faster)
3. Validate artifacts and checksums
4. Test Windows build
5. Run full orchestrator for release
6. Validate release artifacts and manifest

## Resources

- Workflow documentation: `docs/portable-workflows.md`
- Build scripts: `scripts/build-portable/`
- PR #83: https://github.com/resline/serena/pull/83
