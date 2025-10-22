# E2E Testing Guide for Serena Standalone

This guide explains how to run and write End-to-End (E2E) tests for Serena standalone builds.

## Overview

E2E tests verify that standalone Serena executables work correctly from a user's perspective. They test:

1. **Standalone executables** - serena.exe, serena-mcp-server.exe, index-project.exe
2. **MCP server communication** - Tool listing and invocation via MCP protocol
3. **Tool execution** - Real tool workflows with Language Servers
4. **Language Server integration** - LS startup, crash recovery, performance
5. **Project workflows** - Initialization, indexing, memory persistence

## Prerequisites

### Build Requirements

Before running E2E tests, you need a standalone build:

```powershell
# Build standalone (Windows)
.\scripts\build-windows\build-portable.ps1 -Tier essential -Architecture x64
```

Or download from GitHub Releases.

### Python Environment

```bash
# Install dependencies including pytest-asyncio
uv pip install -e ".[dev]"
```

## Running E2E Tests

### Basic Usage

```bash
# Run all E2E tests
pytest test/e2e/ -v -m e2e

# Run with specific build directory
SERENA_BUILD_DIR=/path/to/build pytest test/e2e/ -v

# Run specific test layers
pytest test/e2e/ -v -m standalone    # Executable tests only
pytest test/e2e/ -v -m mcp           # MCP communication tests only
pytest test/e2e/ -v -m tools         # Tool execution tests only
```

### Windows

```powershell
# Set build directory
$env:SERENA_BUILD_DIR = "C:\path\to\serena-portable-windows-x64-essential"

# Run tests
uv run pytest test/e2e/ -v -m e2e
```

### Linux/Mac

```bash
# Set build directory
export SERENA_BUILD_DIR="/path/to/serena-portable-linux-x64-essential"

# Run tests
uv run pytest test/e2e/ -v -m e2e
```

## Test Markers

E2E tests use pytest markers for filtering:

| Marker | Description | Example |
|--------|-------------|---------|
| `e2e` | All E2E tests | `pytest -m e2e` |
| `standalone` | Executable tests | `pytest -m standalone` |
| `mcp` | MCP communication tests | `pytest -m mcp` |
| `tools` | Tool execution tests | `pytest -m tools` |
| `language_server` | Language Server tests | `pytest -m language_server` |
| `workflow` | Project workflow tests | `pytest -m workflow` |
| `slow` | Tests >30 seconds | `pytest -m "not slow"` |

### Combining Markers

```bash
# Run MCP and tool tests, but not slow ones
pytest test/e2e/ -v -m "mcp or tools" -m "not slow"

# Run only standalone tests
pytest test/e2e/ -v -m "e2e and standalone"
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERENA_BUILD_DIR` | Path to standalone build | `dist/windows/serena-portable-*` |
| `E2E_TIMEOUT` | Default test timeout (seconds) | 30 |
| `E2E_SKIP_SLOW` | Skip slow tests | false |

## Test Structure

```
test/e2e/
├── __init__.py
├── conftest.py                          # Shared fixtures
├── mcp_test_client.py                   # MCP test harness
├── standalone_utils.py                  # Utility functions
├── test_standalone_executables.py       # Layer 1 tests
├── test_mcp_server_communication.py     # Layer 2 tests
├── test_tool_execution_e2e.py           # Layer 3 tests (TODO)
├── test_language_server_e2e.py          # Layer 4 tests (TODO)
└── test_project_workflow_e2e.py         # Layer 5 tests (TODO)
```

## Writing E2E Tests

### Example: Standalone Executable Test

```python
import pytest
from test.e2e.standalone_utils import StandaloneTestEnv

@pytest.mark.e2e
@pytest.mark.standalone
class TestMyFeature:

    def test_serena_command(self, standalone_env: StandaloneTestEnv):
        """Test serena.exe command."""
        result = standalone_env.run_command("serena", ["--version"])

        assert result.returncode == 0
        assert "0.1." in result.stdout
```

### Example: MCP Communication Test

```python
import pytest
from test.e2e.mcp_test_client import MCPTestClient

@pytest.mark.e2e
@pytest.mark.mcp
@pytest.mark.asyncio
class TestMyMCPFeature:

    async def test_tool_call(self, mcp_client: MCPTestClient):
        """Test MCP tool invocation."""
        result = await mcp_client.call_tool(
            "read_file",
            {"file_path": "/path/to/file.py"}
        )

        assert result.content
```

### Example: Using Temporary Projects

```python
from solidlsp.ls_config import Language

@pytest.mark.e2e
@pytest.mark.tools
@pytest.mark.asyncio
async def test_with_project(mcp_client, standalone_env):
    """Test with temporary Python project."""
    with standalone_env.temporary_project(Language.PYTHON) as project:
        # Project contains sample Python files
        result = await mcp_client.call_tool(
            "find_symbol",
            {"project_path": str(project), "symbol_pattern": "main"}
        )

        assert result.content
```

## CI/CD Integration

### GitHub Actions Workflow

E2E tests run automatically in CI via `.github/workflows/test-e2e-portable.yml`.

**Trigger manually:**

1. Go to Actions tab
2. Select "E2E Tests for Portable Builds"
3. Click "Run workflow"
4. Select tier (essential, complete, full)

**Automatic triggers:**

- After successful portable build
- On PR to main (if build artifacts exist)

### Local CI Simulation

```bash
# Build first
.\scripts\build-windows\build-portable.ps1 -Tier essential

# Set environment
export SERENA_BUILD_DIR="dist/windows/serena-portable-windows-x64-essential"

# Run E2E tests
pytest test/e2e/ -v -m e2e --tb=short --maxfail=3
```

## Fixtures

### `standalone_build_dir`

Returns path to standalone build directory.

```python
def test_something(standalone_build_dir):
    assert standalone_build_dir.exists()
```

### `standalone_env`

Returns configured `StandaloneTestEnv` instance.

```python
def test_something(standalone_env):
    result = standalone_env.run_command("serena", ["--help"])
    assert result.returncode == 0
```

### `mcp_client`

Returns connected MCP client (async fixture).

```python
async def test_something(mcp_client):
    tools = await mcp_client.list_tools()
    assert len(tools) > 0
```

### `test_project`

Returns temporary test project (can be parametrized by language).

```python
@pytest.mark.parametrize("test_project", [Language.PYTHON], indirect=True)
def test_something(test_project):
    assert (test_project / "main.py").exists()
```

## Troubleshooting

### "Build directory not found"

Set `SERENA_BUILD_DIR` environment variable:

```bash
# Windows
$env:SERENA_BUILD_DIR = "C:\path\to\build"

# Linux/Mac
export SERENA_BUILD_DIR="/path/to/build"
```

### "MCP server connection failed"

Check executable exists and has correct permissions:

```bash
# Windows
ls dist/windows/serena-portable-*/bin/serena-mcp-server.exe

# Linux/Mac
ls -l dist/linux/serena-portable-*/bin/serena-mcp-server
chmod +x dist/linux/serena-portable-*/bin/serena-mcp-server
```

### "Language server not found"

Ensure you're testing with correct tier:

```bash
# Check bundled language servers
ls dist/windows/serena-portable-*/language_servers/

# Essential tier includes: Python, TypeScript, Rust, Go, Java
# Minimal tier includes: None
# Complete tier includes: + C#, Lua, Bash, PHP
# Full tier includes: All 28+ language servers
```

### Tests timeout

Increase timeout via environment variable:

```bash
export E2E_TIMEOUT=60  # 60 seconds
pytest test/e2e/ -v
```

### Async tests fail

Ensure `pytest-asyncio` is installed:

```bash
uv pip install pytest-asyncio

# Verify
pytest --co -q test/e2e/test_mcp_server_communication.py
```

## Performance Targets

| Test Layer | Target Time | Notes |
|------------|-------------|-------|
| Standalone Executable | <5s | Basic CLI commands |
| MCP Communication | <10s | Connection + tool listing |
| Tool Execution | <30s | With LS startup |
| Language Server | <60s | Full integration |
| Project Workflow | <120s | Indexing included |

## Best Practices

### 1. Use Fixtures

Leverage existing fixtures instead of creating resources manually:

```python
# Good
async def test_something(mcp_client):
    result = await mcp_client.call_tool(...)

# Bad
async def test_something(standalone_env):
    client = MCPTestClient(...)
    await client.connect()
    # ... test code ...
    await client.disconnect()
```

### 2. Mark Tests Appropriately

Use markers for filtering:

```python
@pytest.mark.e2e
@pytest.mark.mcp
@pytest.mark.slow  # If test takes >30s
async def test_something(...):
    ...
```

### 3. Clean Up Resources

Use context managers or fixtures for automatic cleanup:

```python
with standalone_env.temporary_project(Language.PYTHON) as project:
    # Project is automatically cleaned up
    ...
```

### 4. Test Real Scenarios

E2E tests should simulate real user workflows:

```python
# Good - realistic workflow
async def test_workflow(mcp_client):
    # 1. Activate project
    await mcp_client.call_tool("activate_project", {...})

    # 2. Find symbols
    await mcp_client.call_tool("find_symbol", {...})

    # 3. Edit symbol
    await mcp_client.call_tool("edit_symbol", {...})

# Bad - just unit testing through MCP
async def test_tool(mcp_client):
    result = await mcp_client.call_tool("some_tool", {...})
    assert result  # Too simple
```

### 5. Handle Async Properly

Always mark async tests with `@pytest.mark.asyncio`:

```python
@pytest.mark.asyncio
async def test_something(mcp_client):
    result = await mcp_client.call_tool(...)
```

## Future Enhancements

Planned test additions:

- [ ] Tool execution E2E tests (Layer 3)
- [ ] Language server integration tests (Layer 4)
- [ ] Project workflow tests (Layer 5)
- [ ] Performance benchmarks
- [ ] Stress tests (concurrent operations)
- [ ] Error recovery scenarios
- [ ] Multi-language project tests

## Resources

- Design Document: `docs/E2E_TEST_FRAMEWORK_DESIGN.md`
- Test Infrastructure: `test/e2e/`
- GitHub Workflow: `.github/workflows/test-e2e-portable.yml`
- Build Scripts: `scripts/build-windows/`

## Getting Help

- Check troubleshooting section above
- Review test examples in `test/e2e/`
- Read design document for architecture details
- File issue at https://github.com/oraios/serena/issues

---

**Last Updated:** 2025-10-22
**Version:** 1.0
