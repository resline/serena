"""E2E tests for MCP server communication.

This module tests the Model Context Protocol (MCP) server communication layer,
including connection, tool listing, and basic tool invocation.
"""

import asyncio
import json
from pathlib import Path

import pytest

from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv


@pytest.mark.e2e
@pytest.mark.mcp
@pytest.mark.asyncio
class TestMCPServerCommunication:
    """Tests for MCP server communication protocol."""

    async def test_mcp_server_startup_stdio(self, standalone_env: StandaloneTestEnv) -> None:
        """Test MCP server starts successfully with stdio transport."""
        server_exe = standalone_env.get_executable_path("serena-mcp-server")

        client = MCPTestClient(server_command=[str(server_exe)], transport="stdio")

        await client.connect()
        assert client.is_connected()
        await client.disconnect()
        assert not client.is_connected()

    async def test_mcp_server_context_manager(self, standalone_env: StandaloneTestEnv) -> None:
        """Test MCP server works with async context manager."""
        server_exe = standalone_env.get_executable_path("serena-mcp-server")

        async with MCPTestClient(server_command=[str(server_exe)]) as client:
            assert client.is_connected()
            tools = await client.list_tools()
            assert len(tools) > 0

        # Should be disconnected after context exit
        assert not client.is_connected()

    async def test_list_tools(self, mcp_client: MCPTestClient) -> None:
        """Test listing all available tools from MCP server."""
        tools = await mcp_client.list_tools()

        # Should have at least some tools
        assert len(tools) > 0, "No tools returned from server"

        # Verify essential tools are present
        tool_names = {tool.name for tool in tools}

        # Core file operations
        assert "read_file" in tool_names, "read_file tool not found"
        assert "write_file" in tool_names, "write_file tool not found"
        assert "list_directory" in tool_names, "list_directory tool not found"

        # Core symbol operations (may vary by active project)
        # These might not be available without an active project
        # assert "find_symbol" in tool_names, "find_symbol tool not found"

    async def test_tool_schemas_have_required_fields(self, mcp_client: MCPTestClient) -> None:
        """Verify tool schemas have required fields."""
        tools = await mcp_client.list_tools()

        for tool in tools:
            # All tools must have name
            assert hasattr(tool, "name"), f"Tool missing name: {tool}"
            assert tool.name, "Tool has empty name"

            # All tools should have description
            assert hasattr(tool, "description"), f"Tool {tool.name} missing description"

            # All tools should have input schema
            assert hasattr(tool, "inputSchema"), f"Tool {tool.name} missing inputSchema"

    async def test_tool_invocation_success(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test successful tool invocation."""
        # Create a test file
        test_file = tmp_path / "test.txt"
        test_file.write_text("Hello, World!")

        # Read file using MCP tool
        result = await mcp_client.call_tool("read_file", {"file_path": str(test_file)})

        # Verify result structure
        assert hasattr(result, "content"), "Result missing content"
        assert len(result.content) > 0, "Result content is empty"

        # Verify content
        content_text = result.content[0].text
        assert "Hello, World!" in content_text, f"Expected content not found in: {content_text}"

    async def test_tool_invocation_error(self, mcp_client: MCPTestClient) -> None:
        """Test tool invocation with invalid parameters."""
        # Try to read non-existent file
        with pytest.raises(Exception) as exc_info:
            await mcp_client.call_tool("read_file", {"file_path": "/nonexistent/file.txt"})

        # Should raise some error
        assert exc_info.value is not None

    async def test_concurrent_tool_calls(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test multiple concurrent tool invocations."""
        # Create multiple test files
        files = []
        for i in range(5):
            test_file = tmp_path / f"file{i}.txt"
            test_file.write_text(f"Content {i}")
            files.append(test_file)

        # Call read_file concurrently for all files
        tasks = [mcp_client.call_tool("read_file", {"file_path": str(f)}) for f in files]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # All calls should succeed
        assert len(results) == 5
        for i, result in enumerate(results):
            assert not isinstance(result, Exception), f"Call {i} failed: {result}"
            assert hasattr(result, "content"), f"Result {i} missing content"

    async def test_list_directory_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test list_directory tool."""
        # Create test directory structure
        (tmp_path / "file1.txt").write_text("test1")
        (tmp_path / "file2.txt").write_text("test2")
        (tmp_path / "subdir").mkdir()

        result = await mcp_client.call_tool("list_directory", {"path": str(tmp_path)})

        assert hasattr(result, "content")
        content_text = result.content[0].text

        # Should contain our files
        assert "file1.txt" in content_text
        assert "file2.txt" in content_text
        assert "subdir" in content_text

    async def test_write_file_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test write_file tool."""
        test_file = tmp_path / "output.txt"
        test_content = "This is test content"

        # Write file
        result = await mcp_client.call_tool(
            "write_file", {"file_path": str(test_file), "content": test_content}
        )

        assert hasattr(result, "content")

        # Verify file was written
        assert test_file.exists()
        assert test_file.read_text() == test_content

    @pytest.mark.slow
    async def test_long_running_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test tool that takes significant time."""
        # Create a larger directory to list
        for i in range(100):
            (tmp_path / f"file{i}.txt").write_text(f"content{i}")

        # This should complete but may take a moment
        result = await mcp_client.call_tool_with_timeout(
            "list_directory", {"path": str(tmp_path)}, timeout=30.0
        )

        assert hasattr(result, "content")

    async def test_tool_timeout_handling(self, mcp_client: MCPTestClient) -> None:
        """Test timeout handling for tool calls."""
        # Note: This test is tricky because we need a tool that takes a long time
        # For now, we just verify the timeout mechanism works by using a very short timeout

        with pytest.raises(asyncio.TimeoutError):
            # Try to list a potentially large directory with tiny timeout
            await mcp_client.call_tool_with_timeout("list_directory", {"path": "/"}, timeout=0.001)

    async def test_server_handles_multiple_connections(self, standalone_env: StandaloneTestEnv) -> None:
        """Test server can handle sequential connections."""
        server_exe = standalone_env.get_executable_path("serena-mcp-server")

        # First connection
        async with MCPTestClient(server_command=[str(server_exe)]) as client1:
            tools1 = await client1.list_tools()
            assert len(tools1) > 0

        # Second connection (after first disconnects)
        async with MCPTestClient(server_command=[str(server_exe)]) as client2:
            tools2 = await client2.list_tools()
            assert len(tools2) > 0

        # Tool counts should be similar (not necessarily identical)
        assert abs(len(tools1) - len(tools2)) < 5

    async def test_graceful_shutdown(self, standalone_env: StandaloneTestEnv) -> None:
        """Test MCP server shuts down cleanly."""
        server_exe = standalone_env.get_executable_path("serena-mcp-server")

        client = MCPTestClient(server_command=[str(server_exe)])

        await client.connect()
        assert client.is_connected()

        # Do some work
        tools = await client.list_tools()
        assert len(tools) > 0

        # Disconnect
        await client.disconnect()
        assert not client.is_connected()

        # Give it a moment to clean up
        await asyncio.sleep(0.5)

        # Server process should have terminated
        # (We can't easily check this without keeping a reference to the process)
