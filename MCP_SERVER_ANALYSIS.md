# Serena MCP Server Implementation Analysis

## Overview

The Serena project implements a **Model Context Protocol (MCP) Server** using **FastMCP 1.12.3** that exposes Serena's symbolic code analysis tools to AI agents and clients. The MCP server acts as a bridge between Serena's language-aware tool system and external AI applications.

---

## 1. Entry Point and CLI Integration

### File: `/root/repo/src/serena/cli.py`

#### Primary Entry Point: `start_mcp_server` Command (Lines 106-203)

```python
@click.command("start-mcp-server", help="Starts the Serena MCP server.")
@click.option("--project", "project", type=PROJECT_TYPE, default=None, ...)
@click.option("--context", type=str, default=DEFAULT_CONTEXT, ...)
@click.option("--mode", "modes", type=str, multiple=True, ...)
@click.option("--transport", type=click.Choice(["stdio", "sse", "streamable-http"]), default="stdio", ...)
@click.option("--host", type=str, default="0.0.0.0", ...)
@click.option("--port", type=int, default=8000, ...)
def start_mcp_server(project, project_file_arg, context, modes, transport, host, port, ...):
```

**Key Features:**
- Configurable project activation at startup
- Context and mode selection (can be combined)
- Multiple transport protocols supported (stdio, SSE, streamable-http)
- Host/port configuration for HTTP transports
- Logging setup with multiple handlers:
  - Memory log handler (for GUI/Dashboard)
  - Stderr handler (for console output)
  - File handler (for persistent logging)
- Error handling with ExceptionGroup support (Python 3.11+)

**Flow:**
1. Initialize logging (Memory + File + Stderr handlers)
2. Create `SerenaMCPFactorySingleProcess` instance
3. Call `factory.create_mcp_server()` to build FastMCP server
4. Call `server.run(transport=transport)` to start server

#### Entry Point Scripts (from pyproject.toml):
```
serena-mcp-server = "serena.cli:start_mcp_server"
```

#### Direct Entry Point: `/root/repo/scripts/mcp_server.py`
```python
from serena.cli import start_mcp_server

if __name__ == "__main__":
    start_mcp_server()
```

---

## 2. MCP Server Implementation

### File: `/root/repo/src/serena/mcp.py`

#### Core Class: `SerenaMCPFactory` (Lines 49-310)

**Purpose:** Abstract base factory for creating and configuring MCP servers.

**Key Methods:**

##### `create_mcp_server()` (Lines 246-300)
- Creates a FastMCP server instance
- Accepts configuration parameters:
  - `host`, `port` - network binding
  - `modes` - mode configurations to apply
  - `enable_web_dashboard` - override config
  - `enable_gui_log_window` - override config
  - `log_level` - override config
  - `trace_lsp_communication` - debug flag
  - `tool_timeout` - tool execution timeout

**Configuration Loading:**
```python
config = SerenaConfig.from_config_file()
# Update with CLI parameters if provided
modes_instances = [SerenaAgentMode.load(mode) for mode in modes]
self._instantiate_agent(config, modes_instances)
```

**FastMCP Creation:**
```python
Settings.model_config = SettingsConfigDict(env_prefix="FASTMCP_")
instructions = self._get_initial_instructions()
mcp = FastMCP(lifespan=self.server_lifespan, host=host, port=port, instructions=instructions)
```

##### `_set_mcp_tools()` (Lines 233-240)
- Registers tools with the MCP server
- Clears existing tools and rebuilds tool manager
- Supports OpenAI tool compatibility mode for certain contexts

```python
def _set_mcp_tools(self, mcp: FastMCP, openai_tool_compatible: bool = False) -> None:
    if mcp is not None:
        mcp._tool_manager._tools = {}  # Clear existing
        for tool in self._iter_tools():
            mcp_tool = self.make_mcp_tool(tool, openai_tool_compatible=openai_tool_compatible)
            mcp._tool_manager._tools[tool.get_name()] = mcp_tool
        log.info(f"Starting MCP server with {len(mcp._tool_manager._tools)} tools")
```

##### `make_mcp_tool()` (Lines 168-226)
- **Static method** that converts a Serena Tool to an MCP Tool
- Extracts docstring and parameter metadata
- Creates executable wrapper function
- Sanitizes schema for OpenAI compatibility if needed

**Tool Conversion Process:**
1. Get tool name and docstring from Serena Tool
2. Extract parameter metadata via `func_metadata(apply_fn)`
3. Generate JSON Schema for parameters
4. Optional: Sanitize schema (`_sanitize_for_openai_tools()`)
5. Parse docstring for parameter descriptions
6. Create execution wrapper that calls `tool.apply_ex(log_call=True, catch_exceptions=True, **kwargs)`
7. Return MCPTool with all metadata

#### Concrete Implementation: `SerenaMCPFactorySingleProcess` (Lines 313-362)

**Purpose:** MCP server factory where SerenaAgent runs in the same process.

**Key Methods:**

##### `_instantiate_agent()` (Lines 329-332)
```python
def _instantiate_agent(self, serena_config: SerenaConfig, modes: list[SerenaAgentMode]) -> None:
    self.agent = SerenaAgent(
        project=self.project, 
        serena_config=serena_config, 
        context=self.context, 
        modes=modes, 
        memory_log_handler=self.memory_log_handler
    )
```

##### `_iter_tools()` (Lines 334-336)
```python
def _iter_tools(self) -> Iterator[Tool]:
    assert self.agent is not None
    yield from self.agent.get_exposed_tool_instances()
```

##### `server_lifespan()` (Lines 343-362) - Async Context Manager
Manages server startup and shutdown:
```python
@asynccontextmanager
async def server_lifespan(self, mcp_server: FastMCP) -> AsyncIterator[None]:
    try:
        openai_tool_compatible = self.context.name in ["chatgpt", "codex", "oaicompat-agent"]
        self._set_mcp_tools(mcp_server, openai_tool_compatible=openai_tool_compatible)
        log.info("MCP server lifetime setup complete")
        yield
    except Exception as e:
        log.exception("Error during MCP server lifetime: %s", e)
        raise
    finally:
        # Cleanup on shutdown
        log.info("MCP server shutting down")
        if self.agent is not None:
            log.debug("Cleaning up agent resources")
```

---

## 3. Tool Registration and Exposure

### File: `/root/repo/src/serena/agent.py`

#### SerenaAgent Tool Exposure (Lines 271-280)

```python
def get_exposed_tool_instances(self) -> list["Tool"]:
    """
    Returns the tool instances which are exposed (e.g. to the MCP client).
    Note that the set of exposed tools is fixed for the session.
    """
    return list(self._exposed_tools.tools)
```

**Tool Selection Process:**

1. **Load all tools** (Line 123):
   ```python
   self._all_tools: dict[type[Tool], Tool] = {
       tool_class: tool_class(self) 
       for tool_class in ToolRegistry().get_all_tool_classes()
   }
   ```

2. **Determine base tool set** (Lines 160-167):
   - Apply Serena config inclusions/exclusions
   - Apply context inclusions/exclusions
   - Apply IDE assistant mode restrictions (if applicable)
   - Apply JetBrains mode restrictions (if applicable)

3. **Filter exposed tools** (Line 167):
   ```python
   self._exposed_tools = AvailableTools([
       t for t in self._all_tools.values() 
       if self._base_tool_set.includes_name(t.get_name())
   ])
   ```

4. **Update active tools dynamically** (Lines 335-353):
   - Applied when project is activated
   - Applied when modes change
   - Filters based on project config read-only status

---

## 4. Language Server Communication

### File: `/root/repo/src/solidlsp/ls.py`

#### SolidLanguageServer Class (Lines 81+)

**Purpose:** Language-agnostic wrapper around LSP implementations.

**Key Communication Methods:**

1. **Document Symbols** (Lines 832-957)
   ```python
   def request_document_symbols(self, relative_file_path: str, include_body: bool = False)
       -> tuple[list[ls_types.UnifiedSymbolInformation], list[ls_types.UnifiedSymbolInformation]]
   ```
   - Request symbols from LSP via `self.server.send.document_symbol()`
   - Cache results based on file content hash
   - Transform LSP response to unified symbol format

2. **References** (Lines 604-670)
   ```python
   def request_references(self, relative_file_path: str, line: int, column: int) 
       -> list[ls_types.Location]
   ```
   - Request references from LSP
   - Filter ignored paths
   - Convert to unified format

3. **Definitions** (Lines 512-592)
   ```python
   def request_definition(self, relative_file_path: str, line: int, column: int) 
       -> list[ls_types.Location]
   ```

4. **Text Edits** (Lines 657-674)
   ```python
   def apply_text_edits_to_file(self, relative_path: str, edits: list[ls_types.TextEdit])
   ```

**LSP Communication Pattern:**
```
Tool (e.g., FindSymbolTool)
  ↓
  SerenaAgent.language_server (SolidLanguageServer)
  ↓
  self.server.send.* (LSP request)
  ↓
  Language Server Process (stdio/TCP)
  ↓
  JSON-RPC Protocol
```

**Lifecycle:**
- `start_server()` (Line 357-360) - Context manager for LS lifecycle
- `_start_server()` (Line 367) - Abstract, overridden by language-specific implementations
- `_shutdown()` (Line 300-354) - Robust shutdown with stages:
  1. Graceful LSP shutdown request
  2. Process termination
  3. Force kill if needed

---

## 5. MCP Protocols and Transport

### Supported Transports

1. **stdio (default)**
   - Standard input/output for direct process communication
   - Used by Claude Desktop, most MCP clients
   - Command-line usage: `serena-mcp-server --transport stdio`

2. **SSE (Server-Sent Events)**
   - HTTP-based with streaming responses
   - Command-line usage: `serena-mcp-server --transport sse --host 0.0.0.0 --port 8000`

3. **streamable-http**
   - Alternative HTTP transport with streaming
   - Similar configuration to SSE

### Protocol Details

**MCP Version:** 1.12.3
**Library:** `mcp.server.fastmcp` from `mcp==1.12.3` package

**FastMCP Server Creation:**
```python
from mcp.server.fastmcp.server import FastMCP

mcp = FastMCP(
    lifespan=self.server_lifespan,  # Async context manager
    host=host,
    port=port,
    instructions=instructions       # System prompt for agents
)
mcp.run(transport=transport)
```

**Tool Exposure to Clients:**
- Tools registered in `mcp._tool_manager._tools` dictionary
- Each tool is an `mcp.server.fastmcp.tools.base.Tool` instance
- Contains:
  - `name`: Tool identifier (snake_case)
  - `description`: Human-readable description
  - `parameters`: JSON Schema for arguments
  - `fn`: Executable function (calls tool.apply_ex)

---

## 6. Testing MCP Communication

### File: `/root/repo/test/serena/test_mcp.py`

#### Unit Tests for Tool Conversion

**Test Coverage:**
- Tool creation from Serena Tool instances
- Parameter extraction and validation
- Docstring parsing
- Description formatting
- All tools in registry

**Key Test Fixtures:**

1. **MockAgent** (Lines 14-22)
   ```python
   class MockAgent:
       def __init__(self):
           self.project_config = None
           self.serena_config = None
       
       @staticmethod
       def get_context() -> SerenaAgentContext:
           return SerenaAgentContext.load_default()
   ```

2. **BasicTool** (Lines 31-50)
   - Tests tool with multiple parameters
   - Tests docstring parsing

**Test Examples:**

```python
def test_make_tool_basic() -> None:
    mock_tool = BasicTool()
    mcp_tool = SerenaMCPFactory.make_mcp_tool(mock_tool)
    
    assert isinstance(mcp_tool, MCPTool)
    assert mcp_tool.name == "basic"
    assert "This is a test function" in mcp_tool.description
    assert "name" in mcp_tool.parameters["properties"]
```

```python
def test_make_tool_execution() -> None:
    mock_tool = BasicTool()
    mcp_tool = SerenaMCPFactory.make_mcp_tool(mock_tool)
    result = mcp_tool.fn(name="Alice", age=30)
    assert result == "Hello Alice, you are 30 years old!"
```

```python
@pytest.mark.parametrize("tool_class", ToolRegistry().get_all_tool_classes())
def test_make_tool_all_tools(tool_class) -> None:
    """Test that make_tool works for all tools in the codebase."""
    tool_instance = tool_class(MockAgent())
    mcp_tool = SerenaMCPFactory.make_mcp_tool(tool_instance)
    assert isinstance(mcp_tool, MCPTool)
    assert mcp_tool.name == tool_class.get_name_from_cls()
```

### Integration Tests

#### File: `/root/repo/test/serena/test_serena_agent.py`

Tests tool execution through SerenaAgent:

```python
def test_find_symbol(self, serena_agent, symbol_name: str, ...):
    agent = serena_agent
    find_symbol_tool = agent.get_tool(FindSymbolTool)
    result = find_symbol_tool.apply_ex(name_path=symbol_name)
    
    symbols = json.loads(result)
    # Assert symbol found with correct kind and file
```

### E2E Testing Patterns

#### Pattern 1: Tool Execution with Agent
```python
# Create agent with specific project
agent = SerenaAgent(
    project="test_repo_python",
    serena_config=serena_config
)

# Get exposed tools
tools = agent.get_exposed_tool_instances()

# Execute tool
tool = agent.get_tool(FindSymbolTool)
result = tool.apply_ex(name_path="MyClass", relative_path="file.py")
```

#### Pattern 2: MCP Server Startup
```python
from serena.mcp import SerenaMCPFactorySingleProcess

factory = SerenaMCPFactorySingleProcess(
    context="agent",
    project="/path/to/project"
)
mcp_server = factory.create_mcp_server(
    host="127.0.0.1",
    port=8000,
    modes=("planning",),
    enable_web_dashboard=False
)

# In production, would call: mcp_server.run(transport="stdio")
```

#### Pattern 3: Tool Parameter Validation
```python
from mcp.server.fastmcp.tools.base import Tool as MCPTool
from serena.mcp import SerenaMCPFactory

mcp_tool = SerenaMCPFactory.make_mcp_tool(serena_tool)

# Verify parameters
params = mcp_tool.parameters
assert "properties" in params
assert all(param in params["properties"] for param in expected_params)

# Execute with arguments
result = mcp_tool.fn(**test_arguments)
```

---

## 7. MCP Server Lifecycle

### Startup Sequence

```
User Command: serena-mcp-server --project /path --context agent --transport stdio
    ↓
cli.start_mcp_server()
    ↓
1. Initialize Logging (Memory + File + Stderr)
    ↓
2. Create SerenaMCPFactorySingleProcess(context, project, memory_log_handler)
    ↓
3. factory.create_mcp_server(host, port, modes, ...)
    ├─ Load SerenaConfig from ~/.serena/serena_config.yml
    ├─ Apply CLI parameter overrides
    ├─ Load modes
    ├─ Call _instantiate_agent() to create SerenaAgent
    │  └─ SerenaAgent.__init__()
    │     ├─ Load all tools (ToolRegistry)
    │     ├─ Determine exposed tools
    │     ├─ Activate project (if provided)
    │     ├─ Start language server in background thread
    │     └─ Start web dashboard (if enabled)
    ├─ Create FastMCP instance with lifespan manager
    └─ Return FastMCP server
    ↓
4. server.run(transport="stdio")
    ├─ Enter server_lifespan() context manager
    │  ├─ Determine OpenAI compatibility based on context
    │  ├─ Call _set_mcp_tools() to register tools
    │  │  └─ For each exposed tool:
    │  │     ├─ Call SerenaMCPFactory.make_mcp_tool()
    │  │     │  ├─ Extract docstring and parameters
    │  │     │  ├─ Create execution wrapper
    │  │     │  └─ Create MCPTool
    │  │     └─ Register in mcp._tool_manager._tools
    │  └─ yield (server running)
    ├─ Listen on stdio/http for MCP messages
    ├─ Route tool calls to registered handlers
    └─ On shutdown, exit lifespan context (cleanup)
```

### Shutdown Sequence

```
Server receives shutdown signal
    ↓
Exit async context manager (server_lifespan)
    ↓
1. Log shutdown message
2. Stop language server (if running)
3. Save language server cache
4. Clean up resources
    ↓
Process terminates
```

### Tool Execution Flow

```
MCP Client sends Tool Call Request
    ↓
FastMCP routes to registered MCPTool.fn()
    ↓
Tool.apply_ex(log_call=True, catch_exceptions=True, **kwargs)
    ├─ Check if tool is active
    ├─ Check if project is active (unless ToolMarkerDoesNotRequireActiveProject)
    ├─ Start language server if needed
    ├─ Execute tool.apply(**kwargs)
    │  └─ Tool queries language server via SolidLanguageServer
    │     └─ LSP request to external language server process
    ├─ Handle SolidLSPException (restart LS if terminated)
    ├─ Record tool usage statistics (if enabled)
    ├─ Save language server cache
    └─ Return result as string
    ↓
MCPTool.fn() returns result
    ↓
FastMCP sends Tool Response to MCP Client
```

---

## 8. Key Design Patterns

### 1. Tool Adaptation Pattern
- **Serena Tool** → **MCPTool** conversion via `make_mcp_tool()`
- Extracts metadata (docstring, parameters, type hints)
- Creates execution wrapper that delegates to `tool.apply_ex()`

### 2. Lazy Initialization Pattern
- Tools instantiated on demand (only when accessed)
- Language servers started in background threads
- Dashboard/GUI launched in separate processes

### 3. Context/Mode Configuration Pattern
- **Context** (fixed per session): Determines available tools and prompts
- **Modes** (updatable): Adjustable operational patterns
- Configuration applied hierarchically:
  1. SerenaConfig
  2. Context
  3. Modes
  4. Project config

### 4. Tool Inclusion/Exclusion System
- Base toolset determined at startup
- Active tools adjusted when project changes
- Tools can be dynamically disabled (e.g., read-only projects)

### 5. Lifespan Management Pattern
- FastMCP uses async context manager for server lifecycle
- Allows cleanup code to run on shutdown
- Tools registered during startup, not at client request time

---

## 9. Configuration Hierarchy

```
MCP Server Configuration (in order of precedence):
    1. Command-line arguments (--project, --context, --mode, etc.)
    2. Project-specific .serena/project.yml
    3. User config ~/.serena/serena_config.yml
    4. Active modes and contexts
    5. Built-in defaults (DEFAULT_CONTEXT, DEFAULT_MODES)
```

---

## 10. Files and Locations Summary

| Component | File | Key Classes/Functions |
|-----------|------|----------------------|
| CLI Entry Point | `/root/repo/src/serena/cli.py` | `start_mcp_server()`, `TopLevelCommands` |
| MCP Server | `/root/repo/src/serena/mcp.py` | `SerenaMCPFactory`, `SerenaMCPFactorySingleProcess`, `make_mcp_tool()` |
| Serena Agent | `/root/repo/src/serena/agent.py` | `SerenaAgent`, `get_exposed_tool_instances()` |
| Tools Base | `/root/repo/src/serena/tools/tools_base.py` | `Tool`, `ToolRegistry`, `apply_ex()` |
| Language Server | `/root/repo/src/solidlsp/ls.py` | `SolidLanguageServer` |
| MCP Tests | `/root/repo/test/serena/test_mcp.py` | `test_make_tool_*` |
| Agent Tests | `/root/repo/test/serena/test_serena_agent.py` | Integration tests |
| MCP Server Script | `/root/repo/scripts/mcp_server.py` | Direct entry point |
| Config | `/root/repo/pyproject.toml` | Scripts: `serena-mcp-server` |

---

## 11. Running the MCP Server

### Basic Usage
```bash
# Default: stdio transport, no project
serena-mcp-server

# With project activation
serena-mcp-server --project /path/to/project

# With custom context and modes
serena-mcp-server --context ide-assistant --mode planning --mode editing

# HTTP transport
serena-mcp-server --transport sse --host 127.0.0.1 --port 3000

# Full configuration
serena-mcp-server \
  --project my-project \
  --context agent \
  --mode planning \
  --mode interactive \
  --transport stdio \
  --log-level DEBUG \
  --tool-timeout 30
```

### Configuration Files
```
~/.serena/serena_config.yml          # User configuration
~/.serena/modes/                     # Custom modes
~/.serena/contexts/                  # Custom contexts
project_root/.serena/project.yml     # Project configuration
project_root/.serena/logs/           # Project logs
```

---

## 12. Testing Strategy

### Unit Tests
- **Location:** `/root/repo/test/serena/test_mcp.py`
- **Focus:** Tool conversion and MCP tool creation
- **Approach:** Mock agents, various tool signatures

### Integration Tests
- **Location:** `/root/repo/test/serena/test_serena_agent.py`
- **Focus:** End-to-end tool execution through SerenaAgent
- **Approach:** Test repositories for multiple languages

### E2E Testing (Manual)
1. Start MCP server with test project
2. Connect MCP client
3. List available tools
4. Execute tools with test inputs
5. Verify results against language server

### Docker/Containerization Testing
```bash
# In CloudShell or Docker:
docker run serena-mcp-server:latest --transport stdio --project /workspace
```

---

## 13. Debugging and Troubleshooting

### Enable Debug Logging
```bash
serena-mcp-server --log-level DEBUG --trace-lsp-communication
```

### Check Generated Logs
```bash
# Find latest log file
ls -lt ~/.serena/logs/mcp_*.log | head -1

# Follow logs in real-time (if available)
tail -f ~/.serena/logs/mcp_*.log
```

### Common Issues
1. **Language Server Fails to Start**
   - Check language is installed and in PATH
   - Check logs for initialization errors
   - Try `serena project health-check`

2. **Tools Not Available**
   - Verify context/mode includes the tool
   - Check project config for exclusions
   - Ensure project is activated if required

3. **Tool Execution Timeouts**
   - Increase `--tool-timeout` parameter
   - Check language server responsiveness
   - Check for stuck processes with `ps aux | grep language-server`

---

## Summary

The Serena MCP Server is a sophisticated implementation that:
1. **Exposes** Serena's symbolic code tools via MCP protocol
2. **Manages** complex configuration through contexts and modes
3. **Integrates** with multiple language servers via LSP
4. **Handles** async operations and cleanup via lifespan management
5. **Supports** multiple transport protocols (stdio, SSE, HTTP)
6. **Provides** comprehensive logging, dashboards, and statistics
7. **Enables** both standalone and IDE integration use cases

Key architectural patterns include tool adaptation, lazy initialization, hierarchical configuration, and robust lifecycle management.
