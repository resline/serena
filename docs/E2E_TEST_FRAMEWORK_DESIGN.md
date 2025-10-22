# E2E Test Framework Design for Serena Standalone

## Executive Summary

This document describes the design and implementation of a comprehensive End-to-End (E2E) test framework for Serena MCP standalone builds. The framework fills critical gaps in test coverage identified during verification of standalone builds.

**Status**: Design Complete, Ready for Implementation
**Version**: 1.0
**Last Updated**: 2025-10-22

---

## 1. Current State Analysis

### Existing Test Coverage (7/10)

**Strengths:**
- ✅ 60+ smoke tests for standalone packages
- ✅ 200+ integration tests for Language Servers (27 languages)
- ✅ 93 unit tests for Serena Agent
- ✅ 11 MCP tool conversion tests
- ✅ Snapshot tests for symbolic editing

**Gaps:**
- ❌ **No E2E tests for MCP server communication**
- ❌ **No real Language Server integration E2E tests**
- ❌ **No standalone executable E2E tests**
- ❌ **No project workflow E2E tests**
- ❌ **No performance/load tests**

### Test Files Found

```
test/
├── serena/
│   ├── test_serena_agent.py (286 lines, integration-level)
│   ├── test_mcp.py (300 lines, tool conversion only)
│   └── test_symbol_editing.py (521 lines, snapshot tests)
├── solidlsp/ (27 language dirs)
│   ├── python/test_python_basic.py
│   ├── elixir/test_elixir_integration.py
│   └── [200+ more integration tests]
└── conftest.py (shared fixtures)
```

---

## 2. E2E Test Framework Architecture

### 2.1 Test Layers

```
┌─────────────────────────────────────────────────────────────┐
│                   E2E Test Framework                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Layer 1: Standalone Executable Tests                 │  │
│  │  - serena.exe --help, --version                      │  │
│  │  - serena-mcp-server.exe startup/shutdown            │  │
│  │  - index-project.exe on sample projects              │  │
│  └──────────────────────────────────────────────────────┘  │
│                         ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Layer 2: MCP Server Communication Tests              │  │
│  │  - stdio transport (mcp.Client ↔ mcp.Server)        │  │
│  │  - SSE transport                                      │  │
│  │  - Tool listing and invocation                        │  │
│  │  - Error handling and timeouts                        │  │
│  └──────────────────────────────────────────────────────┘  │
│                         ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Layer 3: Tool Execution E2E Tests                    │  │
│  │  - find_symbol via MCP                                │  │
│  │  - edit_symbol via MCP                                │  │
│  │  - Multi-tool workflows                               │  │
│  │  - Cross-language scenarios                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                         ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Layer 4: Language Server Integration E2E              │  │
│  │  - Real LS startup via MCP tools                      │  │
│  │  - Symbol operations on real codebases                │  │
│  │  - LS crash recovery                                  │  │
│  │  - Concurrent requests                                │  │
│  └──────────────────────────────────────────────────────┘  │
│                         ↓                                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Layer 5: Project Workflow E2E Tests                  │  │
│  │  - Project initialization and indexing                │  │
│  │  - Memory persistence and retrieval                   │  │
│  │  - Configuration loading and switching                │  │
│  │  - Multi-project scenarios                            │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Test Infrastructure Components

#### A. MCP Client Test Harness (`test/e2e/mcp_test_client.py`)

```python
class MCPTestClient:
    """Test client for MCP server communication."""

    def __init__(self, server_command: list[str], transport: str = "stdio"):
        """Initialize with server command and transport type."""

    async def connect(self) -> None:
        """Start server process and establish connection."""

    async def disconnect(self) -> None:
        """Clean shutdown of server."""

    async def list_tools(self) -> list[ToolSchema]:
        """Get available tools from server."""

    async def call_tool(self, name: str, arguments: dict) -> ToolResult:
        """Execute a tool and return result."""

    async def call_tool_with_timeout(self, name: str, arguments: dict, timeout: float) -> ToolResult:
        """Execute with timeout handling."""
```

#### B. Standalone Test Utilities (`test/e2e/standalone_utils.py`)

```python
class StandaloneTestEnv:
    """Manages test environment for standalone executables."""

    def __init__(self, build_dir: Path, tier: str = "essential"):
        """Initialize with build directory and tier."""

    def get_executable_path(self, name: str) -> Path:
        """Get path to serena.exe, serena-mcp-server.exe, etc."""

    def verify_executables_exist(self) -> dict[str, bool]:
        """Check all expected executables are present."""

    def run_command(self, exe: str, args: list[str], timeout: float = 30) -> subprocess.CompletedProcess:
        """Run executable with arguments."""

    def start_mcp_server(self, **kwargs) -> subprocess.Popen:
        """Start MCP server as subprocess."""

    @contextmanager
    def temporary_project(self, language: Language) -> Path:
        """Create temporary test project."""
```

#### C. Language Server Test Projects (`test/e2e/test_projects/`)

Reuse existing test repositories from `test/resources/repos/` but with additional scenarios:

```
test/e2e/test_projects/
├── python_simple/          # Simple Python project (10 files)
├── python_large/           # Large Python project (100+ files)
├── polyglot/               # Mixed Python + TypeScript + Go
├── edge_cases/             # Special characters, long paths
└── performance/            # Large codebases for benchmarking
```

#### D. Test Fixtures (`test/e2e/conftest.py`)

```python
@pytest.fixture(scope="session")
def standalone_build_dir() -> Path:
    """Path to standalone build directory."""

@pytest.fixture(scope="session")
def standalone_env(standalone_build_dir) -> StandaloneTestEnv:
    """Configured standalone test environment."""

@pytest.fixture
async def mcp_client(standalone_env) -> AsyncGenerator[MCPTestClient, None]:
    """Connected MCP client for testing."""

@pytest.fixture
def test_project(request, tmp_path) -> Path:
    """Temporary test project based on parametrize."""
```

---

## 3. Test Scenarios

### 3.1 Layer 1: Standalone Executable Tests

**File**: `test/e2e/test_standalone_executables.py`

```python
@pytest.mark.e2e
@pytest.mark.standalone
class TestStandaloneExecutables:

    def test_serena_exe_help(self, standalone_env):
        """Test serena.exe --help returns usage info."""

    def test_serena_exe_version(self, standalone_env):
        """Test serena.exe --version returns correct version."""

    def test_serena_mcp_server_exe_help(self, standalone_env):
        """Test serena-mcp-server.exe --help."""

    def test_index_project_exe_help(self, standalone_env):
        """Test index-project.exe --help."""

    def test_serena_exe_no_args(self, standalone_env):
        """Test serena.exe with no args shows help."""

    def test_all_executables_exist(self, standalone_env):
        """Verify all expected executables are present."""

    def test_executable_signatures(self, standalone_env):
        """Test executables are properly signed (if applicable)."""

    @pytest.mark.slow
    def test_serena_mcp_server_startup_time(self, standalone_env):
        """Verify MCP server starts within 5 seconds."""
```

### 3.2 Layer 2: MCP Server Communication Tests

**File**: `test/e2e/test_mcp_server_communication.py`

```python
@pytest.mark.e2e
@pytest.mark.mcp
class TestMCPServerCommunication:

    @pytest.mark.asyncio
    async def test_mcp_server_startup_stdio(self, standalone_env):
        """Test MCP server starts successfully with stdio transport."""
        client = MCPTestClient(
            server_command=[str(standalone_env.get_executable_path("serena-mcp-server"))],
            transport="stdio"
        )
        await client.connect()
        assert client.is_connected()
        await client.disconnect()

    @pytest.mark.asyncio
    async def test_list_tools(self, mcp_client):
        """Test listing all available tools."""
        tools = await mcp_client.list_tools()
        assert len(tools) > 0

        # Verify essential tools are present
        tool_names = {tool.name for tool in tools}
        assert "find_symbol" in tool_names
        assert "edit_symbol" in tool_names
        assert "read_file" in tool_names

    @pytest.mark.asyncio
    async def test_tool_invocation_success(self, mcp_client, test_project):
        """Test successful tool invocation."""
        result = await mcp_client.call_tool(
            "read_file",
            {"file_path": str(test_project / "main.py")}
        )
        assert result.is_success
        assert len(result.content) > 0

    @pytest.mark.asyncio
    async def test_tool_invocation_error(self, mcp_client):
        """Test tool invocation with invalid parameters."""
        result = await mcp_client.call_tool(
            "read_file",
            {"file_path": "/nonexistent/file.py"}
        )
        assert result.is_error
        assert "not found" in result.error_message.lower()

    @pytest.mark.asyncio
    async def test_concurrent_tool_calls(self, mcp_client, test_project):
        """Test multiple concurrent tool invocations."""
        tasks = [
            mcp_client.call_tool("read_file", {"file_path": str(test_project / f"file{i}.py")})
            for i in range(5)
        ]
        results = await asyncio.gather(*tasks)
        assert all(r.is_success for r in results)

    @pytest.mark.asyncio
    async def test_long_running_tool(self, mcp_client, test_project):
        """Test tool that takes significant time."""
        result = await mcp_client.call_tool_with_timeout(
            "find_symbol",
            {"symbol_pattern": ".*", "project_path": str(test_project)},
            timeout=30.0
        )
        assert result.is_success

    @pytest.mark.asyncio
    async def test_server_graceful_shutdown(self, standalone_env):
        """Test MCP server shuts down cleanly."""
        client = MCPTestClient(
            server_command=[str(standalone_env.get_executable_path("serena-mcp-server"))]
        )
        await client.connect()
        await client.disconnect()
        # Verify no zombie processes
        assert not client.is_process_running()
```

### 3.3 Layer 3: Tool Execution E2E Tests

**File**: `test/e2e/test_tool_execution_e2e.py`

```python
@pytest.mark.e2e
@pytest.mark.tools
class TestToolExecutionE2E:

    @pytest.mark.asyncio
    @pytest.mark.parametrize("language", [Language.PYTHON, Language.GO, Language.TYPESCRIPT])
    async def test_find_symbol_e2e(self, mcp_client, test_project, language):
        """E2E test for find_symbol tool with real Language Server."""
        # Activate project
        await mcp_client.call_tool(
            "activate_project",
            {"project_path": str(test_project)}
        )

        # Find symbol
        result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": "main", "symbol_type": "function"}
        )

        assert result.is_success
        symbols = json.loads(result.content[0].text)
        assert len(symbols) > 0
        assert any(s["name"] == "main" for s in symbols)

    @pytest.mark.asyncio
    async def test_edit_symbol_e2e(self, mcp_client, test_project):
        """E2E test for edit_symbol tool."""
        # Find symbol first
        find_result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": "add", "symbol_type": "function"}
        )
        symbols = json.loads(find_result.content[0].text)
        symbol_id = symbols[0]["id"]

        # Edit symbol
        edit_result = await mcp_client.call_tool(
            "edit_symbol",
            {
                "symbol_id": symbol_id,
                "new_body": "    return a + b + 1  # Modified"
            }
        )

        assert edit_result.is_success

        # Verify edit by reading file
        file_path = symbols[0]["file_path"]
        read_result = await mcp_client.call_tool(
            "read_file",
            {"file_path": file_path}
        )
        content = read_result.content[0].text
        assert "# Modified" in content

    @pytest.mark.asyncio
    async def test_multi_tool_workflow(self, mcp_client, test_project):
        """Test realistic multi-tool workflow."""
        # 1. Activate project
        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # 2. Search for pattern
        search_result = await mcp_client.call_tool(
            "search_files",
            {"pattern": "def calculate", "project_path": str(test_project)}
        )
        assert search_result.is_success

        # 3. Find symbol references
        ref_result = await mcp_client.call_tool(
            "find_symbol_references",
            {"symbol_name": "calculate"}
        )
        assert ref_result.is_success

        # 4. Get symbol definition
        def_result = await mcp_client.call_tool(
            "get_symbol_definition",
            {"symbol_name": "calculate"}
        )
        assert def_result.is_success

    @pytest.mark.asyncio
    async def test_cross_language_workflow(self, mcp_client):
        """Test workflow across multiple languages."""
        # Create polyglot project
        project_path = test_project("polyglot")

        await mcp_client.call_tool("activate_project", {"project_path": str(project_path)})

        # Find Python symbols
        py_result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": "process", "file_pattern": "*.py"}
        )
        assert py_result.is_success

        # Find TypeScript symbols
        ts_result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": "process", "file_pattern": "*.ts"}
        )
        assert ts_result.is_success
```

### 3.4 Layer 4: Language Server Integration E2E

**File**: `test/e2e/test_language_server_e2e.py`

```python
@pytest.mark.e2e
@pytest.mark.language_server
class TestLanguageServerE2E:

    @pytest.mark.asyncio
    @pytest.mark.parametrize("language", [Language.PYTHON, Language.RUST, Language.GO])
    async def test_language_server_startup(self, mcp_client, test_project, language):
        """Test Language Server starts successfully for different languages."""
        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # Trigger LS startup by requesting symbols
        result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": ".*"}
        )

        assert result.is_success
        # LS should have started and returned symbols
        assert len(json.loads(result.content[0].text)) > 0

    @pytest.mark.asyncio
    async def test_language_server_crash_recovery(self, mcp_client, test_project):
        """Test automatic LS restart after crash."""
        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # First call - LS starts
        result1 = await mcp_client.call_tool("find_symbol", {"symbol_pattern": "main"})
        assert result1.is_success

        # Simulate LS crash (implementation depends on infrastructure)
        # ...

        # Second call - LS should auto-restart
        result2 = await mcp_client.call_tool("find_symbol", {"symbol_pattern": "main"})
        assert result2.is_success

    @pytest.mark.asyncio
    @pytest.mark.slow
    async def test_language_server_large_codebase(self, mcp_client):
        """Test LS performance on large codebase."""
        large_project = test_project("python_large")  # 100+ files

        await mcp_client.call_tool("activate_project", {"project_path": str(large_project)})

        start_time = time.time()
        result = await mcp_client.call_tool(
            "find_symbol",
            {"symbol_pattern": ".*"}
        )
        elapsed = time.time() - start_time

        assert result.is_success
        assert elapsed < 10.0  # Should complete within 10 seconds

    @pytest.mark.asyncio
    async def test_language_server_concurrent_requests(self, mcp_client, test_project):
        """Test LS handles concurrent requests correctly."""
        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # Send 10 concurrent requests
        tasks = [
            mcp_client.call_tool("find_symbol", {"symbol_pattern": f"symbol_{i}"})
            for i in range(10)
        ]

        results = await asyncio.gather(*tasks)
        # All should succeed (even if no matches found)
        assert all(r.is_success or "not found" in r.error_message.lower() for r in results)
```

### 3.5 Layer 5: Project Workflow E2E Tests

**File**: `test/e2e/test_project_workflow_e2e.py`

```python
@pytest.mark.e2e
@pytest.mark.workflow
class TestProjectWorkflowE2E:

    @pytest.mark.asyncio
    async def test_project_initialization_e2e(self, mcp_client, tmp_path):
        """Test full project initialization workflow."""
        project_path = tmp_path / "new_project"
        project_path.mkdir()
        (project_path / "main.py").write_text("def hello(): pass")

        # Initialize project
        result = await mcp_client.call_tool(
            "initialize_project",
            {"project_path": str(project_path), "languages": ["python"]}
        )
        assert result.is_success

        # Verify project config created
        assert (project_path / ".serena" / "project.yml").exists()

    @pytest.mark.asyncio
    async def test_project_indexing_e2e(self, standalone_env, test_project):
        """Test project indexing via index-project executable."""
        result = standalone_env.run_command(
            "index-project",
            [str(test_project)],
            timeout=60
        )

        assert result.returncode == 0
        # Verify index created
        assert (test_project / ".serena" / "index.db").exists()

    @pytest.mark.asyncio
    async def test_memory_persistence_e2e(self, mcp_client, test_project):
        """Test project memory is persisted and retrieved."""
        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # Store memory
        await mcp_client.call_tool(
            "store_memory",
            {
                "key": "test_fact",
                "content": "This is a test fact about the project."
            }
        )

        # Retrieve memory
        result = await mcp_client.call_tool(
            "retrieve_memory",
            {"query": "test fact"}
        )

        assert result.is_success
        assert "test fact" in result.content[0].text.lower()

    @pytest.mark.asyncio
    async def test_multi_project_switching_e2e(self, mcp_client, tmp_path):
        """Test switching between multiple projects."""
        project1 = tmp_path / "project1"
        project2 = tmp_path / "project2"

        for p in [project1, project2]:
            p.mkdir()
            (p / "main.py").write_text(f"def main_{p.name}(): pass")

        # Activate project1
        await mcp_client.call_tool("activate_project", {"project_path": str(project1)})
        result1 = await mcp_client.call_tool("find_symbol", {"symbol_pattern": "main_project1"})
        assert result1.is_success

        # Switch to project2
        await mcp_client.call_tool("activate_project", {"project_path": str(project2)})
        result2 = await mcp_client.call_tool("find_symbol", {"symbol_pattern": "main_project2"})
        assert result2.is_success

    @pytest.mark.asyncio
    async def test_configuration_loading_e2e(self, mcp_client, test_project):
        """Test project configuration is loaded correctly."""
        # Create custom config
        config_path = test_project / ".serena" / "project.yml"
        config_path.parent.mkdir(exist_ok=True)
        config_path.write_text("""
name: test_project
languages:
  - python
contexts:
  - agent
modes:
  - editing
""")

        await mcp_client.call_tool("activate_project", {"project_path": str(test_project)})

        # Verify config loaded (check available tools match context)
        tools = await mcp_client.list_tools()
        tool_names = {t.name for t in tools}

        # Agent context should have symbol tools
        assert "find_symbol" in tool_names
        assert "edit_symbol" in tool_names
```

---

## 4. Test Infrastructure Implementation

### 4.1 MCP Client Implementation

**File**: `test/e2e/mcp_test_client.py`

```python
"""Test client for MCP server communication."""

import asyncio
import json
from pathlib import Path
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


class MCPTestClient:
    """Test harness for MCP server."""

    def __init__(
        self,
        server_command: list[str],
        transport: str = "stdio",
        env: dict[str, str] | None = None
    ):
        self.server_command = server_command
        self.transport = transport
        self.env = env or {}
        self.session: ClientSession | None = None
        self._read = None
        self._write = None

    async def connect(self) -> None:
        """Start server and establish connection."""
        server_params = StdioServerParameters(
            command=self.server_command[0],
            args=self.server_command[1:],
            env=self.env
        )

        self._read, self._write = await stdio_client(server_params)
        self.session = ClientSession(self._read, self._write)

        await self.session.initialize()

    async def disconnect(self) -> None:
        """Clean shutdown."""
        if self.session:
            await self.session.__aexit__(None, None, None)

    def is_connected(self) -> bool:
        """Check if connected."""
        return self.session is not None

    async def list_tools(self) -> list[Any]:
        """Get available tools."""
        if not self.session:
            raise RuntimeError("Not connected")

        response = await self.session.list_tools()
        return response.tools

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Any:
        """Call a tool."""
        if not self.session:
            raise RuntimeError("Not connected")

        result = await self.session.call_tool(name, arguments)
        return result

    async def call_tool_with_timeout(
        self,
        name: str,
        arguments: dict[str, Any],
        timeout: float
    ) -> Any:
        """Call tool with timeout."""
        return await asyncio.wait_for(
            self.call_tool(name, arguments),
            timeout=timeout
        )
```

### 4.2 Standalone Test Utilities

**File**: `test/e2e/standalone_utils.py`

```python
"""Utilities for testing standalone builds."""

import os
import shutil
import subprocess
import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

from solidlsp.ls_config import Language


class StandaloneTestEnv:
    """Manages standalone test environment."""

    def __init__(self, build_dir: Path, tier: str = "essential"):
        self.build_dir = build_dir
        self.tier = tier
        self.bin_dir = build_dir / "bin"

        if not self.build_dir.exists():
            raise ValueError(f"Build directory not found: {build_dir}")

    def get_executable_path(self, name: str) -> Path:
        """Get path to executable."""
        if os.name == "nt":
            name = f"{name}.exe"
        exe_path = self.bin_dir / name

        if not exe_path.exists():
            raise FileNotFoundError(f"Executable not found: {exe_path}")

        return exe_path

    def verify_executables_exist(self) -> dict[str, bool]:
        """Verify all executables exist."""
        expected = ["serena", "serena-mcp-server", "index-project"]
        return {
            name: (self.bin_dir / f"{name}.exe" if os.name == "nt" else name).exists()
            for name in expected
        }

    def run_command(
        self,
        exe: str,
        args: list[str],
        timeout: float = 30,
        **kwargs
    ) -> subprocess.CompletedProcess:
        """Run executable command."""
        exe_path = self.get_executable_path(exe)

        return subprocess.run(
            [str(exe_path)] + args,
            timeout=timeout,
            capture_output=True,
            text=True,
            **kwargs
        )

    @contextmanager
    def temporary_project(self, language: Language) -> Iterator[Path]:
        """Create temporary test project."""
        temp_dir = Path(tempfile.mkdtemp())

        try:
            # Copy test project
            src = Path(__file__).parent.parent / "resources" / "repos" / language.value / "test_repo"
            if src.exists():
                shutil.copytree(src, temp_dir / "project")
                yield temp_dir / "project"
            else:
                # Create minimal project
                project_dir = temp_dir / "project"
                project_dir.mkdir()

                if language == Language.PYTHON:
                    (project_dir / "main.py").write_text("def main(): pass")
                elif language == Language.GO:
                    (project_dir / "main.go").write_text("package main\nfunc main() {}")
                elif language == Language.TYPESCRIPT:
                    (project_dir / "main.ts").write_text("function main() {}")

                yield project_dir
        finally:
            shutil.rmtree(temp_dir, ignore_errors=True)
```

### 4.3 Pytest Configuration

**File**: `test/e2e/conftest.py`

```python
"""E2E test fixtures."""

import os
from pathlib import Path
from typing import AsyncGenerator

import pytest

from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv


@pytest.fixture(scope="session")
def standalone_build_dir() -> Path:
    """Get standalone build directory from environment or default."""
    build_dir = os.environ.get("SERENA_BUILD_DIR")

    if not build_dir:
        # Try default location
        repo_root = Path(__file__).parent.parent.parent
        build_dir = repo_root / "dist" / "windows" / "serena-portable-windows-x64-essential"

    build_path = Path(build_dir)

    if not build_path.exists():
        pytest.skip(f"Standalone build not found at {build_path}. Set SERENA_BUILD_DIR environment variable.")

    return build_path


@pytest.fixture(scope="session")
def standalone_env(standalone_build_dir: Path) -> StandaloneTestEnv:
    """Configured standalone test environment."""
    return StandaloneTestEnv(standalone_build_dir)


@pytest.fixture
async def mcp_client(standalone_env: StandaloneTestEnv) -> AsyncGenerator[MCPTestClient, None]:
    """Connected MCP client."""
    client = MCPTestClient(
        server_command=[str(standalone_env.get_executable_path("serena-mcp-server"))]
    )

    await client.connect()

    try:
        yield client
    finally:
        await client.disconnect()


@pytest.fixture
def test_project(request, tmp_path, standalone_env):
    """Parameterized test project fixture."""
    language = getattr(request, "param", None)

    if language:
        with standalone_env.temporary_project(language) as project_path:
            yield project_path
    else:
        # Default Python project
        project_dir = tmp_path / "project"
        project_dir.mkdir()
        (project_dir / "main.py").write_text("def main(): pass")
        yield project_dir
```

---

## 5. GitHub Actions Integration

### 5.1 New Workflow: E2E Tests

**File**: `.github/workflows/test-e2e-portable.yml`

```yaml
name: E2E Tests for Portable Builds

on:
  workflow_dispatch:
    inputs:
      tier:
        description: 'Build tier to test'
        required: true
        default: 'essential'
        type: choice
        options:
          - minimal
          - essential
          - complete
          - full
  workflow_call:
    inputs:
      build_artifact_name:
        description: 'Name of build artifact to test'
        required: true
        type: string

jobs:
  test-e2e-windows:
    name: E2E Tests (Windows)
    runs-on: windows-2022

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Python 3.11
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install UV
        run: |
          irm https://astral.sh/uv/install.ps1 | iex

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.build_artifact_name }}
          path: dist/

      - name: Extract build
        run: |
          Expand-Archive -Path dist/*.zip -DestinationPath dist/extracted/

      - name: Install test dependencies
        run: |
          uv pip install -e ".[dev]"
          uv pip install pytest pytest-asyncio mcp

      - name: Run E2E tests
        env:
          SERENA_BUILD_DIR: dist/extracted/serena-portable-*
        run: |
          uv run pytest test/e2e/ -v -m e2e --tb=short

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: e2e-test-results
          path: test-results/
```

### 5.2 Integration with Existing Workflows

Modify `.github/workflows/windows-portable.yml` to call E2E tests:

```yaml
jobs:
  build-portable:
    # ... existing build job ...

  test-e2e:
    name: Run E2E Tests
    needs: build-portable
    uses: ./.github/workflows/test-e2e-portable.yml
    with:
      build_artifact_name: ${{ needs.build-portable.outputs.artifact_name }}
```

---

## 6. Execution Plan

### Phase 1: Infrastructure (Week 1)
- [ ] Create `test/e2e/` directory structure
- [ ] Implement `MCPTestClient` class
- [ ] Implement `StandaloneTestEnv` class
- [ ] Create `conftest.py` with fixtures
- [ ] Add pytest markers for e2e tests

### Phase 2: Layer 1 Tests (Week 1)
- [ ] Implement `test_standalone_executables.py`
- [ ] Test all 3 executables (serena, serena-mcp-server, index-project)
- [ ] Verify help, version, basic commands

### Phase 3: Layer 2 Tests (Week 2)
- [ ] Implement `test_mcp_server_communication.py`
- [ ] Test stdio transport
- [ ] Test tool listing
- [ ] Test tool invocation (success/error cases)
- [ ] Test concurrent requests

### Phase 4: Layer 3 Tests (Week 2)
- [ ] Implement `test_tool_execution_e2e.py`
- [ ] Test find_symbol E2E
- [ ] Test edit_symbol E2E
- [ ] Test multi-tool workflows

### Phase 5: Layer 4 Tests (Week 3)
- [ ] Implement `test_language_server_e2e.py`
- [ ] Test LS startup for Python, Go, TypeScript
- [ ] Test LS crash recovery
- [ ] Test concurrent LS requests

### Phase 6: Layer 5 Tests (Week 3)
- [ ] Implement `test_project_workflow_e2e.py`
- [ ] Test project initialization
- [ ] Test project indexing
- [ ] Test memory persistence

### Phase 7: CI/CD Integration (Week 4)
- [ ] Create `.github/workflows/test-e2e-portable.yml`
- [ ] Integrate with `windows-portable.yml`
- [ ] Test on GitHub Actions runners
- [ ] Document CI/CD setup

### Phase 8: Documentation (Week 4)
- [ ] Create `docs/E2E_TESTING.md` user guide
- [ ] Update `TESTING-CHECKLIST.md`
- [ ] Add E2E test examples to README

---

## 7. Success Criteria

### Coverage Targets
- ✅ 100% of standalone executables tested
- ✅ 80% of MCP tools tested E2E
- ✅ Top 5 languages tested (Python, Go, TS, Rust, Java)
- ✅ All critical workflows covered

### Performance Targets
- ✅ MCP server startup < 5 seconds
- ✅ Tool invocation < 2 seconds (simple tools)
- ✅ Language server startup < 10 seconds
- ✅ E2E test suite completes < 10 minutes

### Quality Targets
- ✅ All E2E tests pass on Windows
- ✅ No false positives (flaky tests < 1%)
- ✅ Clear error messages for failures
- ✅ Tests run successfully in CI/CD

---

## 8. Maintenance Plan

### Regular Updates
- Run E2E tests on every PR that touches:
  - MCP server code
  - Language server code
  - Tool implementations
  - Build scripts

### Monitoring
- Track E2E test execution time
- Monitor flaky test rate
- Track coverage metrics

### Documentation
- Keep test scenarios up to date with new features
- Document new test patterns
- Update troubleshooting guides

---

## 9. Appendix

### A. Pytest Markers

```ini
[tool.pytest.ini_options]
markers = [
    "e2e: End-to-end tests (deselect with '-m \"not e2e\"')",
    "standalone: Tests for standalone executables",
    "mcp: MCP server communication tests",
    "tools: Tool execution tests",
    "language_server: Language server integration tests",
    "workflow: Project workflow tests",
    "slow: Slow tests (>30 seconds)",
]
```

### B. Example Commands

```bash
# Run all E2E tests
pytest test/e2e/ -v -m e2e

# Run only standalone tests
pytest test/e2e/ -v -m standalone

# Run only MCP tests
pytest test/e2e/ -v -m mcp

# Run with specific build
SERENA_BUILD_DIR=/path/to/build pytest test/e2e/ -v

# Run with coverage
pytest test/e2e/ -v --cov=serena --cov-report=html

# Run in CI mode
pytest test/e2e/ -v -m e2e --tb=short --maxfail=3
```

### C. Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SERENA_BUILD_DIR` | Path to standalone build | `dist/windows/serena-portable-*` |
| `E2E_TIMEOUT` | Default timeout for E2E tests | 30 seconds |
| `E2E_SKIP_SLOW` | Skip slow tests | false |

---

## 10. References

- MCP Protocol: https://github.com/anthropics/model-context-protocol
- FastMCP Documentation: https://github.com/jlowin/fastmcp
- pytest-asyncio: https://pytest-asyncio.readthedocs.io/
- Existing test patterns: `test/serena/test_serena_agent.py`
- Language server tests: `test/solidlsp/`

---

**End of Design Document**
