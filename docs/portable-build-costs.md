# Portable Build Cost Estimation

This document provides detailed cost estimates for GitHub Actions minutes when building Serena portable packages.

## GitHub Actions Pricing

### Runner Cost Multipliers

| Runner | OS | Multiplier | Free Tier Minutes |
|--------|----|-----------:|------------------:|
| ubuntu-latest | Linux | 1x | 2,000/month |
| windows-latest | Windows | 2x | 1,000/month (2,000 raw) |
| macos-13 | macOS Intel | 10x | 200/month (2,000 raw) |
| macos-14 | macOS ARM | 10x | 200/month (2,000 raw) |

**Note:** Free tier applies to public repositories. Private repositories have different limits.

## Build Time Estimates

Based on empirical testing with warm caches:

### With Warm Cache

| Platform | Minimal | Standard | Full |
|----------|---------|----------|------|
| **Linux** | | | |
| - Setup | 2 min | 2 min | 2 min |
| - Build | 8 min | 12 min | 20 min |
| - Test | 3 min | 5 min | 8 min |
| - Archive | 1 min | 2 min | 3 min |
| **Total** | **14 min** | **21 min** | **33 min** |
| | | | |
| **Windows** | | | |
| - Setup | 3 min | 3 min | 3 min |
| - Build | 10 min | 15 min | 25 min |
| - Test | 4 min | 6 min | 10 min |
| - Archive | 2 min | 3 min | 4 min |
| **Total** | **19 min** | **27 min** | **42 min** |
| | | | |
| **macOS Intel** | | | |
| - Setup | 3 min | 3 min | 3 min |
| - Build | 12 min | 18 min | 30 min |
| - Test | 4 min | 7 min | 12 min |
| - Archive | 2 min | 3 min | 4 min |
| **Total** | **21 min** | **31 min** | **49 min** |
| | | | |
| **macOS ARM** | | | |
| - Setup | 3 min | 3 min | 3 min |
| - Build | 10 min | 15 min | 25 min |
| - Test | 4 min | 7 min | 12 min |
| - Archive | 2 min | 3 min | 4 min |
| **Total** | **19 min** | **28 min** | **44 min** |

### Without Cache (Cold Build)

| Platform | Minimal | Standard | Full |
|----------|---------|----------|------|
| Linux | 25 min | 38 min | 60 min |
| Windows | 32 min | 48 min | 75 min |
| macOS Intel | 38 min | 55 min | 85 min |
| macOS ARM | 35 min | 52 min | 80 min |

**Cache Impact:** 40-50% reduction in build time

### With Test Skip

Reduces build time by ~25-30%:

| Platform | Minimal | Standard | Full |
|----------|---------|----------|------|
| Linux | 11 min | 16 min | 25 min |
| Windows | 15 min | 21 min | 32 min |
| macOS Intel | 17 min | 24 min | 37 min |
| macOS ARM | 15 min | 21 min | 32 min |

## Billable Minute Calculations

### Scenario Matrix

| Scenario | Platform | Language Set | Tests | Cache | Time | Billable |
|----------|----------|--------------|-------|-------|------|----------|
| **Development** | | | | | | |
| 1 | Linux | Minimal | Skip | Warm | 11 min | 11 |
| 2 | Linux | Standard | Skip | Warm | 16 min | 16 |
| 3 | Linux | Standard | Full | Warm | 21 min | 21 |
| 4 | Windows | Minimal | Skip | Warm | 15 min | 30 |
| 5 | Windows | Standard | Skip | Warm | 21 min | 42 |
| **Pre-Release** | | | | | | |
| 6 | All 4 | Standard | Full | Warm | 107 min | 664 |
| 7 | All 4 | Standard | Skip | Warm | 78 min | 482 |
| 8 | All 4 | Minimal | Skip | Warm | 60 min | 372 |
| **Release** | | | | | | |
| 9 | All 4 | Standard | Full | Warm | 107 min | 664 |
| 10 | All 4 | Full | Full | Warm | 168 min | 1,044 |
| **Cold Start** | | | | | | |
| 11 | Linux | Standard | Full | Cold | 38 min | 38 |
| 12 | All 4 | Standard | Full | Cold | 196 min | 1,216 |

### Detailed Breakdown: Full Release (Scenario 9)

| Platform | Raw Minutes | Multiplier | Billable Minutes |
|----------|------------|-----------|-----------------|
| Linux | 21 | 1x | 21 |
| Windows | 27 | 2x | 54 |
| macOS Intel | 31 | 10x | 310 |
| macOS ARM | 28 | 10x | 280 |
| **Total** | **107** | - | **664** |

## Monthly Usage Projections

### Conservative Project (Small Team)

**Activity:**
- 2 releases/month (full builds with standard set)
- 8 dev builds (Linux only, minimal, skip tests)
- 4 cache warmup runs (all platforms)

| Activity | Count | Minutes Each | Total Raw | Total Billable |
|----------|-------|--------------|-----------|---------------|
| Release | 2 | 107 | 214 | 1,328 |
| Dev builds | 8 | 11 | 88 | 88 |
| Cache warmup | 4 | 20 | 80 | 496 |
| **Total** | **14** | - | **382** | **1,912** |

**By Platform:**
- Linux: ~300 minutes (within free tier ✅)
- Windows: ~350 minutes (within free tier ✅)
- macOS: ~1,260 minutes (**exceeds free tier by 1,060** ⚠️)

### Active Development (Medium Team)

**Activity:**
- 4 releases/month (full builds with standard set)
- 20 dev builds (Linux only, minimal, skip tests)
- 4 cache warmup runs (all platforms)
- 4 testing builds (all platforms, minimal, skip tests)

| Activity | Count | Minutes Each | Total Raw | Total Billable |
|----------|-------|--------------|-----------|---------------|
| Release | 4 | 107 | 428 | 2,656 |
| Dev builds | 20 | 11 | 220 | 220 |
| Cache warmup | 4 | 20 | 80 | 496 |
| Testing | 4 | 60 | 240 | 1,488 |
| **Total** | **32** | - | **968** | **4,860** |

**By Platform:**
- Linux: ~700 minutes (within free tier ✅)
- Windows: ~900 minutes (within free tier ✅)
- macOS: ~3,260 minutes (**exceeds free tier by 3,060** ⚠️)

### High-Intensity Development (Large Team)

**Activity:**
- 8 releases/month (full builds with full language set)
- 40 dev builds (Linux only, minimal, skip tests)
- 4 cache warmup runs (all platforms)
- 12 testing builds (all platforms, minimal, skip tests)

| Activity | Count | Minutes Each | Total Raw | Total Billable |
|----------|-------|--------------|-----------|---------------|
| Release | 8 | 168 | 1,344 | 8,352 |
| Dev builds | 40 | 11 | 440 | 440 |
| Cache warmup | 4 | 20 | 80 | 496 |
| Testing | 12 | 60 | 720 | 4,464 |
| **Total** | **64** | - | **2,584** | **13,752** |

**By Platform:**
- Linux: ~1,500 minutes (within free tier ✅)
- Windows: ~1,800 minutes (**exceeds free tier by 800** ⚠️)
- macOS: ~10,452 minutes (**exceeds free tier by 10,252** ⚠️⚠️)

## Cost Optimization Strategies

### Strategy 1: Linux-First Development

**Approach:**
- All dev builds on Linux only
- Test on all platforms only before release
- Use cache warmup weekly

**Savings:**
- Reduces macOS usage by 80%
- Fits most projects in free tier
- Recommended for budget-conscious teams

**Example Monthly Cost:**
```
Releases (4x all platforms): 2,656 minutes
Dev (20x Linux): 220 minutes
Cache warmup (4x): 496 minutes
Total: 3,372 billable minutes

Linux: 500 min (free tier ✅)
Windows: 700 min (free tier ✅)
macOS: 2,172 min (972 min over ⚠️)
```

### Strategy 2: Minimal Language Set for Testing

**Approach:**
- Use minimal set for all testing
- Switch to standard/full only for releases
- Skip tests during development

**Savings:**
- 30-40% faster builds
- Smaller cache footprint
- Less bandwidth usage

**Example Build Time Reduction:**
```
Before: 107 min (standard, full tests)
After: 60 min (minimal, skip tests)
Savings: 44% reduction
```

### Strategy 3: Strategic Cache Warming

**Approach:**
- Warm cache before major work sessions
- Don't warm cache too frequently
- Time cache warmup during off-peak

**Savings:**
- Prevents cold start penalties
- Reduces build failures from timeouts
- Optimizes cache retention

**Optimal Schedule:**
```
Sunday 00:00 UTC - Weekly warmup (scheduled)
Before release branch - Manual warmup
After dependency updates - Manual warmup
```

### Strategy 4: Selective Platform Builds

**Approach:**
- Build only changed platforms
- Use conditional logic based on file changes
- Manual override for full rebuilds

**Implementation:**
```yaml
# Example: Only build if platform-specific files changed
- name: Check changes
  id: changes
  run: |
    if [[ "${{ github.event_name }}" == "release" ]]; then
      echo "build_all=true" >> $GITHUB_OUTPUT
    else
      # Logic to detect platform-specific changes
      echo "build_all=false" >> $GITHUB_OUTPUT
    fi
```

**Savings:**
- 50-75% reduction for minor changes
- Faster iteration cycles
- Preserve runner minutes

## Cost Comparison

### Full Year Projection

Based on Active Development scenario (4,860 min/month):

| Tier | Monthly | Annual | Cost (if paid) |
|------|---------|--------|----------------|
| Free (Public Repo) | 4,860 | 58,320 | $0 (with overages) |
| Free Tier Covered | 3,200 | 38,400 | $0 |
| Overage | 1,660 | 19,920 | ~$160/year @ $0.008/min |

**Note:** GitHub Actions for public repositories are free with soft limits. Private repositories would incur charges for overages.

### Comparison with Alternatives

| Approach | Setup Time | Monthly Cost | Pros | Cons |
|----------|-----------|--------------|------|------|
| GitHub Actions | 1 day | Free (public) | Integrated, automated | macOS limits |
| Self-Hosted Runners | 1 week | $50-200/month | No limits | Maintenance burden |
| Cloud CI (CircleCI) | 2 days | $30-100/month | Flexible | Additional service |
| Manual Builds | 0 days | $0 | No limits | Time-consuming, error-prone |
| Docker Only | 1 day | Free | Fast Linux builds | No native macOS/Windows |

**Recommendation:** GitHub Actions is optimal for public repositories with moderate release cadence.

## Best Practices for Cost Control

1. **Use Linux for development iterations** - 10x cheaper than macOS
2. **Reserve macOS builds for releases** - Only when necessary
3. **Enable cache warmup** - Weekly schedule keeps builds fast
4. **Skip tests during development** - Run full tests before release
5. **Use minimal language set** - Unless full set required
6. **Monitor usage monthly** - Check Settings → Billing → Actions
7. **Set up notifications** - Alert when approaching limits
8. **Document build triggers** - Avoid unnecessary runs
9. **Use workflow concurrency** - Cancel outdated builds
10. **Profile build times** - Identify optimization opportunities

## Monitoring and Alerts

### GitHub Actions Dashboard

Monitor usage at:
```
https://github.com/ORG/REPO/settings/billing/summary
```

Key metrics:
- Total minutes used (current month)
- Minutes by platform
- Minutes by workflow
- Cache size and hits

### Setting Up Alerts

1. Create a GitHub Action to check usage:
```yaml
name: Monitor Actions Usage
on:
  schedule:
    - cron: '0 0 * * 1'  # Weekly

jobs:
  check-usage:
    runs-on: ubuntu-latest
    steps:
      - name: Check usage
        run: |
          # Use GitHub API to check usage
          # Alert if > 80% of limit
```

2. Set up external monitoring (Datadog, Prometheus)
3. Create Slack/email notifications

## Frequently Asked Questions

### Q: Why are macOS builds so expensive?
**A:** GitHub charges 10x for macOS runners due to hardware costs. Apple Silicon and Intel Macs are more expensive to maintain in cloud infrastructure.

### Q: Can I reduce macOS build time?
**A:** Yes:
- Use cache warmup (40% reduction)
- Skip tests (25% reduction)
- Use minimal language set (30% reduction)
- Combined: up to 60% reduction

### Q: What if I exceed free tier?
**A:** For public repos, GitHub may allow soft overages. For private repos, you'll be charged $0.008/minute (Linux rate) with multipliers for Windows/macOS.

### Q: Should I use self-hosted runners?
**A:** Only if:
- Building > 10 hours/month on macOS
- Need specific hardware/software
- Have IT resources for maintenance

### Q: How to optimize for private repos?
**A:** 
- Buy Actions minutes package ($20 for 2,500 min)
- Use Docker for Linux builds (faster)
- Consider CircleCI or Travis CI
- Self-host for macOS

### Q: Can I build only for one platform?
**A:** Yes, use `platform_filter: ubuntu` for Linux-only builds. Great for testing.

### Q: What about cache costs?
**A:** Cache storage is free up to 10GB. Not counted against Actions minutes.

## Summary

- **Cheapest setup:** Linux-only minimal builds (~11 min, 11 billable)
- **Standard release:** All platforms standard builds (~107 min, 664 billable)
- **Full release:** All platforms full builds (~168 min, 1,044 billable)
- **Recommended:** Linux for dev, all platforms for releases
- **Cache warmup:** Essential for cost control (40-50% savings)
- **Monthly budget:** 2,000-4,000 billable minutes for active development

---

Last updated: 2025-10-31
Version: 1.0
