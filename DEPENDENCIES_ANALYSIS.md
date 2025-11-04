# Analiza Zależności Python w Projekcie Serena

## Podsumowanie Wykonawcze

- **Całkowita liczba zależności runtime**: 59 pakietów (21 bezpośrednich + 38 przechodnich)
- **Szacowany rozmiar dla jednej platformy**: ~122 MB
- **Szacowany rozmiar dla wszystkich platform**: ~350-450 MB
- **Zależności natywne/binarne**: 11 pakietów (wymagających kompilacji lub platform-specific wheels)
- **Główne problemy dla offline deployment**: Zależności Rust, pywin32, multi-platform wheels

---

## 1. Zależności Bezpośrednie (Runtime)

### Lista 21 bezpośrednich zależności:

| Pakiet | Wersja | Typ | Rozmiar | Uwagi |
|--------|--------|-----|---------|-------|
| anthropic | 0.59.0 | Pure Python | 0.28 MB | SDK dla Claude API |
| docstring-parser | 0.17.0 | Pure Python | 0.04 MB | Parser docstringów |
| dotenv | 0.9.9 | Pure Python | <0.01 MB | Ładowanie .env (stary) |
| flask | 3.1.1 | Pure Python | 0.10 MB | Web framework dla dashboardu |
| fortls | 3.2.2 | Pure Python | 0.27 MB | Fortran language server |
| jinja2 | 3.1.6 | Pure Python | 0.13 MB | Silnik szablonów |
| joblib | 1.5.1 | Pure Python | 0.29 MB | Utilities (caching, parallel) |
| mcp | 1.12.3 | Pure Python | 0.15 MB | Model Context Protocol |
| overrides | 7.7.0 | Pure Python | 0.02 MB | Dekorator @override |
| pathspec | 0.12.1 | Pure Python | 0.03 MB | Gitignore-style pattern matching |
| psutil | 7.0.0 | **NATIVE** | 1.71 MB | Process/system monitoring (C) |
| pydantic | 2.11.7 | Pure Python | 0.42 MB | Data validation (wrapper) |
| pyright | 1.1.403 | Pure Python | 5.42 MB | Python type checker |
| python-dotenv | 1.1.1 | Pure Python | 0.02 MB | Ładowanie .env (nowy) |
| pyyaml | 6.0.2 | **NATIVE** | 4.21 MB | YAML parser (C) |
| requests | 2.32.4 | Pure Python | 0.06 MB | HTTP client |
| ruamel-yaml | 0.18.14 | Pure Python | 0.11 MB | YAML parser (wrapper) |
| sensai-utils | 1.5.0 | Pure Python | 0.07 MB | Utilities |
| tiktoken | 0.9.0 | **NATIVE** | 6.26 MB | OpenAI tokenizer (Rust) |
| tqdm | 4.67.1 | Pure Python | 0.07 MB | Progress bars |
| types-pyyaml | 6.0.12 | Pure Python | 0.02 MB | Type stubs |

---

## 2. Zależności Natywne/Binarne (11 pakietów)

Pakiety wymagające platform-specific wheels lub kompilacji:

| Pakiet | Rozmiar (Linux) | Język | Multi-platform | Uwagi |
|--------|-----------------|-------|----------------|-------|
| **pydantic-core** | 45.43 MB | **Rust** | ~135 MB | Największa zależność! Core validation engine |
| **pywin32** | 25.66 MB | C/Win32 | ~26 MB | **TYLKO WINDOWS** - można wyłączyć dla Linux/macOS |
| **rpds-py** | 10.05 MB | **Rust** | ~30 MB | Persistent data structures |
| **regex** | 9.20 MB | C | ~25 MB | Advanced regex engine |
| **tiktoken** | 6.26 MB | **Rust** | ~18 MB | OpenAI tokenizer |
| **ruamel-yaml-clib** | 4.38 MB | C | ~12 MB | YAML C extension |
| **jiter** | 4.23 MB | **Rust** | ~12 MB | JSON iterator |
| **pyyaml** | 4.21 MB | C | ~12 MB | YAML C extension |
| **charset-normalizer** | 1.81 MB | C | ~5 MB | Character encoding detection |
| **psutil** | 1.71 MB | C | ~5 MB | System monitoring |
| **markupsafe** | 0.19 MB | C | ~0.5 MB | Jinja2 escaping |

### Wymagania kompilacji (jeśli brak wheels):
- **Rust toolchain**: pydantic-core, tiktoken, rpds-py, jiter (4 pakiety)
- **C compiler**: pyyaml, psutil, ruamel-yaml-clib, regex, charset-normalizer, markupsafe (6 pakietów)

---

## 3. Zależności Przechodnie (38 pakietów)

### Kluczowe przechodnie zależności:

**HTTP/Networking (7):**
- httpx 0.28.1, httpcore 1.0.9, h11 0.16.0, urllib3 2.5.0, certifi 2025.7.14, httpx-sse 0.4.1

**Web Framework (5):**
- werkzeug 3.1.3, starlette 0.47.2, uvicorn 0.35.0, sse-starlette 3.0.2, blinker 1.9.0

**Data Validation (3):**
- pydantic-core 2.33.2 (NATIVE - Rust), pydantic-settings 2.10.1, annotated-types 0.7.0

**JSON/Schema (4):**
- json5 0.12.1, jsonschema 4.25.0, jsonschema-specifications 2025.4.1, referencing 0.36.2

**Async (2):**
- anyio 4.9.0, sniffio 1.3.1

**Utilities (10):**
- click 8.2.1, colorama 0.4.6, packaging 25.0, distro 1.9.0, attrs 25.3.0
- itsdangerous 2.2.0, python-multipart 0.0.20, nodeenv 1.9.1, idna 3.10

**Type Hints (3):**
- typing-extensions 4.14.1, typing-inspection 0.4.1

**Data Structures (1):**
- rpds-py 0.26.0 (NATIVE - Rust)

---

## 4. Rozmiary i Statystyki

### Rozmiar według typu:

| Typ | Liczba pakietów | Rozmiar |
|-----|-----------------|---------|
| Pure Python | 48 | 9.11 MB |
| Native/Binary | 11 | 113.14 MB |
| **TOTAL (1 platforma)** | **59** | **~122 MB** |

### Największe zależności (Top 10):

1. **pydantic-core** - 45.43 MB (Rust)
2. **pywin32** - 25.66 MB (Windows only)
3. **rpds-py** - 10.05 MB (Rust)
4. **regex** - 9.20 MB (C)
5. **tiktoken** - 6.26 MB (Rust)
6. **pyright** - 5.42 MB (Pure Python, ale TypeScript-based)
7. **ruamel-yaml-clib** - 4.38 MB (C)
8. **jiter** - 4.23 MB (Rust)
9. **pyyaml** - 4.21 MB (C)
10. **charset-normalizer** - 1.81 MB (C)

**Suma top 10: 116.5 MB (95.3% całkowitej wielkości)**

---

## 5. Problemy dla Offline Deployment

### 5.1 Multi-Platform Wheels

Dla pełnego wsparcia platform (Linux x64, macOS Intel/ARM, Windows x64) każda natywna zależność wymaga 3-4 wheelów:

**Przykład pydantic-core (45 MB × 4 platformy = ~180 MB):**
- `manylinux_2_17_x86_64` (Linux)
- `macosx_10_12_x86_64` (macOS Intel)
- `macosx_11_0_arm64` (macOS ARM)
- `win_amd64` (Windows)

**Szacowany rozmiar dla wszystkich platform:**
- Native dependencies: ~113 MB × 3.5 = **~395 MB**
- Pure Python: **~9 MB** (współdzielone)
- **TOTAL: ~400-450 MB**

### 5.2 Runtime Downloads

**Potencjalne pobieranie w runtime:**

1. **pyright** (5.4 MB):
   - Jest to wrapper wokół TypeScript-based type checkera
   - Komentarz w kodzie: "we can also use `pyright-langserver --stdio` but it requires pyright to be installed with npm"
   - Używa: `python -m pyright.langserver --stdio`
   - **Status**: Pakiet pyright zawiera bundled langserver, ale warto przetestować offline

2. **nodeenv** (1.9.1):
   - Przechodnia zależność
   - Może próbować pobierać Node.js runtime
   - **Status**: Należy zweryfikować czy jest używany w runtime

3. **fortls** (0.27 MB):
   - Fortran language server
   - Może wymagać dodatkowych komponentów dla języka Fortran
   - **Status**: Zależy od użycia

### 5.3 Platform-Specific Issues

**pywin32 (26 MB):**
- Zależność tylko dla Windows
- Niepotrzebna na Linux/macOS
- W `uv.lock` może być marker: `platform = "windows"`
- **Optymalizacja**: Można wykluczyć dla innych platform

**Brak ARM wheels:**
- Niektóre pakiety mogą nie mieć ARM wheels (Raspberry Pi, AWS Graviton)
- Wymaga kompilacji lub emulacji x64

---

## 6. Struktura Zależności (Drzewo)

### Główne grupy funkcjonalne:

```
AI/LLM Stack:
├── anthropic (Claude API)
│   ├── httpx, anyio, pydantic
│   └── jiter (JSON parsing - Rust)
├── tiktoken (tokenizer - Rust)
└── mcp (Model Context Protocol)

Language Server Infrastructure:
├── pyright (Python LSP)
│   └── nodeenv
├── fortls (Fortran LSP)
└── psutil (process monitoring)

Data Validation:
├── pydantic
│   └── pydantic-core (CORE - Rust, 45 MB!)
│       ├── typing-extensions
│       └── annotated-types
└── pydantic-settings

Configuration:
├── pyyaml (C extension)
├── ruamel-yaml
│   └── ruamel-yaml-clib (C extension)
├── python-dotenv
└── dotenv

Web Framework:
├── flask
│   ├── werkzeug
│   ├── jinja2
│   │   └── markupsafe (C extension)
│   └── blinker
└── MCP Server Infrastructure:
    ├── starlette
    ├── uvicorn
    └── sse-starlette

Utilities:
├── joblib (caching)
├── tqdm (progress bars)
├── requests (HTTP)
├── pathspec (gitignore patterns)
└── sensai-utils
```

---

## 7. Rekomendacje dla Offline Packaging

### 7.1 Przygotowanie Offline Package

```bash
# 1. Export wszystkich dependencies do requirements.txt
uv export --no-dev -o requirements.txt

# 2. Pobierz wheels dla docelowych platform
pip download -r requirements.txt -d ./wheels --platform manylinux_2_17_x86_64
pip download -r requirements.txt -d ./wheels --platform macosx_10_12_x86_64
pip download -r requirements.txt -d ./wheels --platform macosx_11_0_arm64
pip download -r requirements.txt -d ./wheels --platform win_amd64

# 3. Wykluczenie pywin32 dla Linux/macOS
pip download -r requirements.txt -d ./wheels-linux \
    --platform manylinux_2_17_x86_64 \
    --exclude pywin32
```

### 7.2 Optymalizacje Rozmiaru

**Możliwe oszczędności:**

1. **Wykluczenie pywin32** (26 MB) dla Linux/macOS
2. **Usunięcie pyright** (5.4 MB) jeśli type checking nie jest potrzebny w runtime
3. **Zastąpienie tiktoken** prostszym tokenizerem (6.3 MB oszczędności)
4. **Uproszczenie web stack** - czy Flask + MCP server są potrzebne?

**Potencjalne oszczędności: ~40-50 MB**

### 7.3 Testing Offline

```bash
# Test instalacji w środowisku bez internetu
docker run --rm -it --network none python:3.11-slim bash
pip install --no-index --find-links ./wheels serena-agent

# Test runtime w środowisku offline
serena-mcp-server  # czy działa bez dostępu do sieci?
```

### 7.4 Dockerfile Optimization

```dockerfile
# Multi-stage build dla minimalizacji rozmiaru
FROM python:3.11-slim AS builder
COPY wheels /wheels
RUN pip wheel --no-deps --wheel-dir /wheels-built /wheels/*.whl

FROM python:3.11-slim
COPY --from=builder /wheels-built /wheels
RUN pip install --no-index --find-links /wheels serena-agent
RUN rm -rf /wheels  # Usunięcie wheels po instalacji
```

---

## 8. Potencjalne Problemy i Rozwiązania

### Problem 1: Zależności Rust (60+ MB)

**Pakiety:**
- pydantic-core (45 MB)
- tiktoken (6 MB)
- rpds-py (10 MB)
- jiter (4 MB)

**Rozwiązania:**
- ✅ Używaj pre-built wheels (zawsze)
- ⚠️ Dla nietypowych platform: zainstaluj Rust toolchain
- 💡 Rozważ alternatywy bez Rust dla edge cases

### Problem 2: pywin32 na Linux/macOS

**Problem:** Niepotrzebna zależność 26 MB

**Rozwiązanie:**
```toml
# W pyproject.toml można dodać marker:
dependencies = [
    "pywin32>=311; sys_platform == 'win32'"
]
```

### Problem 3: Wieloplatformowe Wheels

**Problem:** 400-450 MB dla wszystkich platform

**Rozwiązanie:**
- Używaj platform-specific packages
- Twórz osobne artifacts per-platform
- Używaj Docker multi-platform builds

### Problem 4: Potencjalne Runtime Downloads

**Testy wymagane dla:**
- pyright (czy bundled langserver jest kompletny?)
- nodeenv (czy pobiera Node.js?)
- fortls (czy wymaga zewnętrznych komponentów?)

**Rozwiązanie:**
- Test w środowisku `--network none`
- Monitorowanie network calls podczas pierwszego uruchomienia
- Sprawdzenie katalogów cache (~/.cache, ~/.local)

---

## 9. Podsumowanie Kluczowych Zależności

### Must-Have (Core Runtime):

1. **anthropic** - Claude API SDK
2. **mcp** - Model Context Protocol
3. **pydantic** + pydantic-core - Data validation (DUŻE!)
4. **flask** - Web dashboard
5. **pyyaml** / ruamel-yaml - Config parsing
6. **requests** / httpx - HTTP clients
7. **tiktoken** - Tokenization dla LLM
8. **psutil** - Process monitoring

### Language Server Support:

1. **pyright** - Python language server
2. **fortls** - Fortran language server

### Nice-to-Have (Potencjalnie opcjonalne):

1. **tqdm** - Progress bars (można usunąć)
2. **dotenv** - Duplikat python-dotenv
3. **types-pyyaml** - Type stubs (tylko dev?)

---

## 10. Checklist Offline Deployment

- [ ] Pobierz wszystkie wheels dla docelowej platformy
- [ ] Test instalacji bez internetu
- [ ] Test pierwszego uruchomienia bez internetu
- [ ] Sprawdź logi dla prób network access
- [ ] Zweryfikuj rozm katalogów cache
- [ ] Wykluczenie pywin32 dla Linux/macOS
- [ ] Dokumentacja platform-specific requirements
- [ ] Przygotowanie fallback dla brakujących wheels

---

## 11. Szacunki Końcowe

| Scenariusz | Rozmiar | Notatki |
|------------|---------|---------|
| Linux x64 only | ~122 MB | Bez pywin32 = ~96 MB |
| macOS (Intel + ARM) | ~200 MB | 2 architektury |
| Windows x64 only | ~122 MB | Z pywin32 |
| Wszystkie platformy | ~400-450 MB | Pełne wsparcie |
| Minimalizowane (bez pyright, tiktoken) | ~60-80 MB | Utrata funkcjonalności |

**Rekomendowany rozmiar offline package: 100-150 MB per platform**

