"""Test client for MCP server communication.

This module provides a test harness for communicating with Serena MCP server
during E2E tests. It supports stdio transport and provides convenient methods
for tool listing and invocation.
"""

import asyncio
import logging
from typing import Any

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

logger = logging.getLogger(__name__)


class MCPTestClient:
    """Test harness for MCP server communication.

    This client manages the lifecycle of an MCP server process and provides
    methods for testing tool listing and invocation.

    Example:
        ```python
        client = MCPTestClient(
            server_command=["serena-mcp-server.exe"],
            transport="stdio"
        )

        await client.connect()
        tools = await client.list_tools()
        result = await client.call_tool("read_file", {"file_path": "main.py"})
        await client.disconnect()
        ```

    """

    def __init__(
        self,
        server_command: list[str],
        transport: str = "stdio",
        env: dict[str, str] | None = None,
    ) -> None:
        """Initialize MCP test client.

        Args:
            server_command: Command and arguments to start MCP server
            transport: Transport type ("stdio" or "sse")
            env: Optional environment variables for server process

        """
        self.server_command = server_command
        self.transport = transport
        self.env = env or {}
        self.session: ClientSession | None = None
        self._read = None
        self._write = None
        self._server_params: StdioServerParameters | None = None

    async def connect(self) -> None:
        """Start server process and establish connection.

        Raises:
            RuntimeError: If connection fails
            TimeoutError: If connection takes too long

        """
        logger.info(f"Starting MCP server: {' '.join(self.server_command)}")

        self._server_params = StdioServerParameters(
            command=self.server_command[0],
            args=self.server_command[1:] if len(self.server_command) > 1 else [],
            env=self.env,
        )

        try:
            self._read, self._write = await stdio_client(self._server_params)
            self.session = ClientSession(self._read, self._write)

            await self.session.initialize()
            logger.info("MCP server connected successfully")

        except Exception as e:
            logger.error(f"Failed to connect to MCP server: {e}")
            raise RuntimeError(f"MCP server connection failed: {e}") from e

    async def disconnect(self) -> None:
        """Clean shutdown of server connection."""
        if self.session:
            logger.info("Disconnecting from MCP server")
            try:
                await self.session.__aexit__(None, None, None)
            except Exception as e:
                logger.warning(f"Error during disconnect: {e}")
            finally:
                self.session = None
                self._read = None
                self._write = None

    def is_connected(self) -> bool:
        """Check if client is currently connected.

        Returns:
            True if connected, False otherwise

        """
        return self.session is not None

    async def list_tools(self) -> list[Any]:
        """Get list of available tools from server.

        Returns:
            List of tool schemas

        Raises:
            RuntimeError: If not connected

        """
        if not self.session:
            raise RuntimeError("Not connected to MCP server. Call connect() first.")

        logger.debug("Listing tools")
        response = await self.session.list_tools()
        logger.debug(f"Found {len(response.tools)} tools")

        return response.tools

    async def call_tool(self, name: str, arguments: dict[str, Any]) -> Any:
        """Call a tool on the MCP server.

        Args:
            name: Tool name
            arguments: Tool arguments as dictionary

        Returns:
            Tool result

        Raises:
            RuntimeError: If not connected

        """
        if not self.session:
            raise RuntimeError("Not connected to MCP server. Call connect() first.")

        logger.debug(f"Calling tool: {name} with args: {arguments}")

        try:
            result = await self.session.call_tool(name, arguments)
            logger.debug(f"Tool {name} completed successfully")
            return result

        except Exception as e:
            logger.error(f"Tool {name} failed: {e}")
            raise

    async def call_tool_with_timeout(self, name: str, arguments: dict[str, Any], timeout_seconds: float) -> Any:
        """Call a tool with a timeout.

        Args:
            name: Tool name
            arguments: Tool arguments
            timeout_seconds: Timeout in seconds

        Returns:
            Tool result

        Raises:
            asyncio.TimeoutError: If tool execution exceeds timeout
            RuntimeError: If not connected

        """
        logger.debug(f"Calling tool {name} with {timeout_seconds}s timeout")

        try:
            result = await asyncio.wait_for(self.call_tool(name, arguments), timeout=timeout_seconds)
            return result

        except TimeoutError:
            logger.error(f"Tool {name} timed out after {timeout_seconds}s")
            raise

    async def __aenter__(self) -> "MCPTestClient":
        """Context manager entry."""
        await self.connect()
        return self

    async def __aexit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        """Context manager exit."""
        await self.disconnect()
