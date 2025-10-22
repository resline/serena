# E2E Tests for Serena Standalone

End-to-End tests for Serena standalone builds.

## Quick Start

```bash
# 1. Build standalone (or download from releases)
.\scripts\build-windows\build-portable.ps1 -Tier essential

# 2. Set environment variable
$env:SERENA_BUILD_DIR = "dist\windows\serena-portable-windows-x64-essential"

# 3. Run tests
pytest test/e2e/ -v -m e2e
```

## Test Files

| File | Description | Tests | Status |
|------|-------------|-------|--------|
| `test_standalone_executables.py` | Executable basic functionality | 10+ | ✅ Implemented |
| `test_mcp_server_communication.py` | MCP protocol communication | 18+ | ✅ Implemented |
| `test_tool_execution_e2e.py` | Tool workflows | 25+ | ✅ Implemented |
| `test_language_server_e2e.py` | Language Server integration | 20+ | ✅ Implemented |
| `test_project_workflow_e2e.py` | Project workflows | 15+ | ✅ Implemented |

## Infrastructure

| File | Description |
|------|-------------|
| `conftest.py` | Pytest fixtures |
| `mcp_test_client.py` | MCP client test harness |
| `standalone_utils.py` | Utility functions |

## Documentation

- **User Guide**: [docs/E2E_TESTING.md](../../docs/E2E_TESTING.md)
- **Design Document**: [docs/E2E_TEST_FRAMEWORK_DESIGN.md](../../docs/E2E_TEST_FRAMEWORK_DESIGN.md)
- **Testing Checklist**: [scripts/build-windows/TESTING-CHECKLIST.md](../../scripts/build-windows/TESTING-CHECKLIST.md)

## CI/CD

Tests run automatically via `.github/workflows/test-e2e-portable.yml`.

**Trigger manually:**
1. Go to Actions → "E2E Tests for Portable Builds"
2. Click "Run workflow"
3. Select tier and architecture

## Examples

### Run Specific Test Layers

```bash
# Only standalone executable tests
pytest test/e2e/ -v -m standalone

# Only MCP communication tests
pytest test/e2e/ -v -m mcp

# Exclude slow tests
pytest test/e2e/ -v -m "e2e and not slow"
```

### Using Custom Build

```bash
# Point to different build
export SERENA_BUILD_DIR="/custom/path/to/build"
pytest test/e2e/ -v
```

### Debugging

```bash
# Verbose output with logging
pytest test/e2e/ -v -s --log-cli-level=DEBUG

# Stop on first failure
pytest test/e2e/ -v -x

# Run specific test
pytest test/e2e/test_mcp_server_communication.py::TestMCPServerCommunication::test_list_tools -v
```

## Test Markers

Use `-m` flag to filter tests:

- `e2e` - All E2E tests
- `standalone` - Executable tests
- `mcp` - MCP communication tests
- `tools` - Tool execution tests
- `language_server` - Language Server tests
- `workflow` - Project workflow tests
- `slow` - Tests >30 seconds

## Requirements

- Python 3.11
- pytest >= 8.0.2
- pytest-asyncio >= 0.21.0
- mcp == 1.12.3
- Standalone build (essential tier recommended)

## Contributing

When adding new E2E tests:

1. Follow existing patterns (see `test_standalone_executables.py`)
2. Use appropriate markers
3. Add fixtures to `conftest.py` if reusable
4. Update this README
5. Update [docs/E2E_TESTING.md](../../docs/E2E_TESTING.md)

## Status

**Current Coverage**: ~100% (All 5 layers implemented) 🎉

- ✅ **Layer 1**: Standalone Executables (10 tests)
- ✅ **Layer 2**: MCP Communication (18 tests)
- ✅ **Layer 3**: Tool Execution (25 tests)
- ✅ **Layer 4**: Language Server Integration (20 tests)
- ✅ **Layer 5**: Project Workflows (15 tests)

**Total**: 88 E2E tests across all layers ✨

## License

MIT - See [LICENSE](../../LICENSE)
