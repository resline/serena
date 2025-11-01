# Workflow Runs - November 1, 2025

## Uruchomione Workflow Buildów

### 1. Build Portable Package - Linux
- **Run ID**: 18992827999
- **URL**: https://github.com/resline/serena/actions/runs/18992827999
- **Status**: In Progress
- **Parametry**:
  - Version: v0.1.5
  - Language Set: standard
  - Skip Tests: false
  - Ref: main

### 2. Build Portable Package - Windows
- **Run ID**: 18992828131
- **URL**: https://github.com/resline/serena/actions/runs/18992828131
- **Status**: In Progress
- **Parametry**:
  - Version: v0.1.5
  - Language Set: standard
  - Skip Tests: false
  - Ref: main

### 3. Portable Release Orchestrator
- **Run ID**: 18992828316
- **URL**: https://github.com/resline/serena/actions/runs/18992828316
- **Status**: In Progress
- **Parametry**:
  - Platform Filter: all (Linux + Windows)
  - Language Set: standard
  - Skip Tests: false
  - Release Tag: v0.1.5
  - Ref: main

## Opis Workflow

### Build Portable Package - Linux
Standalone build dla platformy Linux x64:
- Używa Python Build Standalone (indygreg)
- Tworzy archiwum TAR.GZ
- Zawiera embedded Python runtime
- Zawiera pre-downloaded language servers
- Cache: Python runtime, Language Servers, UV dependencies
- Koszt: 1x multiplier (najbardziej efektywne)

**Spodziewany czas**: ~20-30 minut

### Build Portable Package - Windows
Standalone build dla platformy Windows x64:
- Używa Python embedded z python.org
- Tworzy archiwum ZIP (PowerShell Compress-Archive)
- Zawiera embedded Python runtime
- Zawiera pre-downloaded language servers
- Cache: Python runtime, Language Servers, UV dependencies
- Koszt: 2x multiplier (dwa razy droższe niż Linux)

**Spodziewany czas**: ~25-35 minut

### Portable Release Orchestrator
Orkiestruje oba buildy równolegle:
1. **Prepare Release** - określa wersję i konfigurację
2. **Build Linux** - wywołuje portable-build-linux.yml
3. **Build Windows** - wywołuje portable-build-windows.yml (równolegle)
4. **Generate Manifest** - tworzy latest.json z metadanymi
5. **Upload to Release** - uploaduje artefakty do GitHub release

**Spodziewany czas**: ~30-40 minut (buildy równolegle)

## Oczekiwane Artefakty

Po zakończeniu każdy workflow wyprodukuje:

### Linux Build
- `serena-linux-x64-v0.1.5.tar.gz` - Portable package (~500-600 MB)
- `serena-linux-x64-v0.1.5.tar.gz.sha256` - Checksum

### Windows Build
- `serena-windows-x64-v0.1.5.zip` - Portable package (~60-80 MB)
- `serena-windows-x64-v0.1.5.zip.sha256` - Checksum

### Orchestrator
Wszystkie powyższe plus:
- `latest.json` - Manifest z metadanymi release

## Zawartość Portable Package

### Struktura Katalogów
```
serena-portable-{platform}-x64-v0.1.5/
├── bin/
│   ├── serena-mcp-server*       # Main executable
│   └── index-project*           # Project indexing tool
├── python/                      # Embedded Python 3.11
│   ├── python*
│   ├── lib/
│   └── ...
├── language_servers/            # Pre-downloaded LSP servers
│   ├── pyright/
│   ├── typescript-language-server/
│   ├── gopls/
│   ├── rust-analyzer/
│   ├── elixir-ls/
│   ├── clojure-lsp/
│   └── ...                      # (standard set)
├── data/                        # Runtime data directory
├── config/                      # Configuration directory
└── cache/                       # Cache directory
```

### Language Servers (Standard Set)
- **Python**: pyright
- **TypeScript/JavaScript**: typescript-language-server
- **Go**: gopls
- **Rust**: rust-analyzer
- **Java**: jdtls
- **C#**: omnisharp
- **PHP**: intelephense
- **Ruby**: solargraph
- **Elixir**: elixir-ls
- **Clojure**: clojure-lsp
- **Terraform**: terraform-ls
- **Bash**: bash-language-server

## Monitorowanie Postępu

### CLI Commands
```bash
# Obserwuj Linux build
gh run watch 18992827999

# Obserwuj Windows build
gh run watch 18992828131

# Obserwuj Orchestrator
gh run watch 18992828316

# Lista wszystkich runów
gh run list --limit 10

# Szczegóły konkretnego runa
gh run view 18992827999
```

### Kluczowe Etapy

#### Linux Build
1. ✓ Checkout repository
2. ⏳ Setup Python 3.11
3. ⏳ Install build dependencies
4. ⏳ Install UV package manager
5. ⏳ Cache UV dependencies
6. ⏳ Restore language servers from cache
7. ⏳ Install project dependencies
8. ⏳ Run code quality checks (black, ruff, mypy)
9. ⏳ Build portable executable (PyInstaller)
10. ⏳ Create distribution bundle
11. ⏳ Upload artifacts

#### Windows Build
1. ✓ Checkout repository
2. ⏳ Setup Python 3.11
3. ⏳ Install Windows dependencies
4. ⏳ Install UV package manager
5. ⏳ Cache UV dependencies
6. ⏳ Restore language servers from cache
7. ⏳ Download portable Python runtime
8. ⏳ Install project dependencies
9. ⏳ Run code quality checks
10. ⏳ Build portable executable (PyInstaller)
11. ⏳ Create ZIP distribution
12. ⏳ Upload artifacts

#### Orchestrator
1. ✓ Prepare release (determine version, config)
2. ⏳ Build Linux (parallel)
3. ⏳ Build Windows (parallel)
4. ⏳ Generate manifest (latest.json)
5. ⏳ Upload to GitHub release

## Szacunkowe Czasy i Koszty

### Build Times (z cache)
- **Linux**: ~20-30 min = 20-30 billable minutes (1x)
- **Windows**: ~25-35 min = 50-70 billable minutes (2x)
- **Orchestrator**: ~30-40 min (parallel) = ~70-100 billable minutes total

### Build Times (cold cache)
- **Linux**: ~40-50 min
- **Windows**: ~45-60 min (90-120 billable min)

### Cache Layers
1. **Python Runtime Cache**: ~5-10 min saved
2. **Language Servers Cache**: ~10-15 min saved
3. **UV Dependencies Cache**: ~2-5 min saved

## Success Criteria

### Linux Build Success
- ✅ Code quality checks pass (black, ruff, mypy)
- ✅ PyInstaller build completes without errors
- ✅ TAR.GZ archive created
- ✅ SHA256 checksum generated
- ✅ Artifact uploaded successfully
- ✅ Tests pass (if skip_tests=false)

### Windows Build Success
- ✅ Code quality checks pass
- ✅ PyInstaller build completes without errors
- ✅ ZIP archive created
- ✅ SHA256 checksum generated
- ✅ Artifact uploaded successfully
- ✅ Tests pass (if skip_tests=false)

### Orchestrator Success
- ✅ Both platform builds complete
- ✅ Manifest generated correctly
- ✅ All artifacts uploaded to release
- ✅ latest.json contains valid metadata

## Znane Problemy i Obejścia

### E2E Test Failures
**Problem**: E2E testy mogą failować na etapie "Extract build"
**Impact**: Medium - buildy są OK, tylko testy mają problem
**Workaround**: Uruchomić z `skip_tests=true` lub zignorować błędy testów

### Cache Misses
**Problem**: Pierwsze buildy mogą być wolniejsze bez cache
**Impact**: Low - tylko dłuższy czas buildu
**Solution**: Kolejne buildy będą szybsze dzięki cache

### Windows Archive Size
**Obserwacja**: Windows ZIP (~60 MB) vs Linux TAR.GZ (~500 MB)
**Wyjaśnienie**: ZIP jest mniej efektywny niż TAR.GZ, ale to normalne
**Action**: Weryfikacja zawartości po zakończeniu buildu

## Po Zakończeniu Buildów

### Download Artifacts
```bash
# Download z konkretnego runa
gh run download 18992827999 -D /tmp/linux-build
gh run download 18992828131 -D /tmp/windows-build
gh run download 18992828316 -D /tmp/release

# Rozpakowanie
cd /tmp/linux-build
tar -xzf serena-linux-x64-v0.1.5.tar.gz

cd /tmp/windows-build
unzip serena-windows-x64-v0.1.5.zip
```

### Verify Checksums
```bash
# Linux
cd /tmp/linux-build
sha256sum -c serena-linux-x64-v0.1.5.tar.gz.sha256

# Windows (PowerShell)
cd C:\tmp\windows-build
Get-FileHash serena-windows-x64-v0.1.5.zip -Algorithm SHA256
```

### Test Basic Functionality
```bash
# Linux
cd serena-portable-linux-x64-v0.1.5
./bin/serena-mcp-server --version

# Windows
cd serena-portable-windows-x64-v0.1.5
bin\serena-mcp-server.exe --version
```

## Następne Kroki

Po pomyślnym zakończeniu buildów:

1. **Weryfikacja artefaktów**
   - Sprawdź checksums
   - Zweryfikuj rozmiary plików
   - Test basic functionality

2. **Testing**
   - Manual testing na target platforms
   - Verify language servers work offline
   - Test MCP integration

3. **Release**
   - Create GitHub release with tag v0.1.5
   - Upload artifacts
   - Write release notes

4. **Documentation**
   - Update installation instructions
   - Document known issues
   - Update changelog

## Links

- **Linux Build**: https://github.com/resline/serena/actions/runs/18992827999
- **Windows Build**: https://github.com/resline/serena/actions/runs/18992828131
- **Orchestrator**: https://github.com/resline/serena/actions/runs/18992828316
- **Workflow Documentation**: docs/portable-workflows.md
- **Running Guide**: docs/running-portable-workflows.md

---

**Started**: 2025-11-01T06:36:28Z
**Version**: v0.1.5
**Language Set**: standard
**Tests**: enabled
