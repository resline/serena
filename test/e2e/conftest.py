"""E2E test fixtures and configuration.

This module provides pytest fixtures for E2E testing of Serena standalone builds.
"""

import os
from collections.abc import AsyncGenerator
from pathlib import Path

import pytest

from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv


@pytest.fixture(scope="session")
def standalone_build_dir() -> Path:
    """Get standalone build directory from environment or default.

    The build directory can be specified via SERENA_BUILD_DIR environment variable.
    If not set, defaults to dist/windows/serena-portable-windows-x64-essential.

    Returns:
        Path to standalone build directory

    Raises:
        pytest.skip: If build directory doesn't exist

    """
    build_dir_env = os.environ.get("SERENA_BUILD_DIR")

    if build_dir_env:
        build_path = Path(build_dir_env)
    else:
        # Try default location
        repo_root = Path(__file__).parent.parent.parent
        build_path = repo_root / "dist" / "windows" / "serena-portable-windows-x64-essential"

    if not build_path.exists():
        pytest.skip(
            f"Standalone build not found at {build_path}. "
            "Set SERENA_BUILD_DIR environment variable or build standalone first."
        )

    return build_path


@pytest.fixture(scope="session")
def standalone_env(standalone_build_dir: Path) -> StandaloneTestEnv:
    """Configured standalone test environment.

    Args:
        standalone_build_dir: Path to build directory (from fixture)

    Returns:
        Configured StandaloneTestEnv instance

    """
    return StandaloneTestEnv(standalone_build_dir)


@pytest.fixture
async def mcp_client(standalone_env: StandaloneTestEnv) -> AsyncGenerator[MCPTestClient, None]:
    """Connected MCP client for testing.

    This fixture creates an MCP client, connects to the server, and ensures
    clean disconnection after test completion.

    Args:
        standalone_env: Test environment (from fixture)

    Yields:
        Connected MCPTestClient instance

    Example:
        ```python
        async def test_tool(mcp_client):
            tools = await mcp_client.list_tools()
            assert len(tools) > 0
        ```

    """
    server_exe = standalone_env.get_executable_path("serena-mcp-server")

    client = MCPTestClient(server_command=[str(server_exe)])

    try:
        await client.connect()
        yield client
    finally:
        await client.disconnect()


@pytest.fixture
def test_project(request: pytest.FixtureRequest, tmp_path: Path, standalone_env: StandaloneTestEnv) -> Path:
    """Parameterized test project fixture.

    This fixture creates a temporary test project. The language can be
    specified via parametrize.

    Args:
        request: Pytest request object
        tmp_path: Pytest temp directory
        standalone_env: Test environment (from fixture)

    Returns:
        Path to test project directory

    Example:
        ```python
        @pytest.mark.parametrize("test_project", [Language.PYTHON], indirect=True)
        def test_something(test_project):
            assert (test_project / "main.py").exists()
        ```

    """
    language = getattr(request, "param", None)

    if language:
        with standalone_env.temporary_project(language) as project_path:
            return project_path
    else:
        # Default Python project
        project_dir = tmp_path / "project"
        project_dir.mkdir()
        (project_dir / "main.py").write_text("def main():\n    pass\n")
        return project_dir
