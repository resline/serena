# Serena MCP Server - Quick Reference Guide

## Key Files at a Glance

```
src/serena/cli.py                       - CLI entry point (start_mcp_server command)
src/serena/mcp.py                       - MCP factory and tool registration
src/serena/agent.py                     - SerenaAgent orchestration
src/serena/tools/tools_base.py          - Tool base class and registry
src/solidlsp/ls.py                      - Language server wrapper
test/serena/test_mcp.py                 - MCP unit tests
test/serena/test_serena_agent.py        - Integration tests
scripts/mcp_server.py                   - Direct entry point script
```

## Core Architecture

### 1. MCP Entry Point Flow
```
CLI Command: serena-mcp-server --project X --context Y --mode Z --transport stdio
       ↓
   cli.start_mcp_server()
       ↓
   SerenaMCPFactorySingleProcess
       ├─ _instantiate_agent()          [Creates SerenaAgent]
       ├─ create_mcp_server()           [Creates FastMCP instance]
       └─ _set_mcp_tools()              [Registers tools]
       ↓
   mcp.run(transport=transport)         [Starts server]
```

### 2. Tool Conversion Pipeline
```
Serena Tool (FindSymbolTool, etc.)
    ↓
    [Tool.apply_ex()] method + docstring + type hints
    ↓
    SerenaMCPFactory.make_mcp_tool()
    ├─ Extract metadata
    ├─ Generate JSON Schema
    ├─ Create execution wrapper
    └─ Return MCPTool
    ↓
FastMCP._tool_manager._tools[name] = mcp_tool
    ↓
MCP Client receives Tool via protocol
```

### 3. Tool Execution Pipeline
```
MCP Client -> Tool Call Request (JSON-RPC)
    ↓
FastMCP routes to registered MCPTool.fn()
    ↓
tool.apply_ex(log_call=True, catch_exceptions=True, **kwargs)
    ├─ Validate tool is active
    ├─ Ensure project is activated (if required)
    ├─ Start language server if needed
    ├─ Execute tool.apply(**kwargs)
    │  └─ Query SolidLanguageServer
    │     └─ Send LSP request to language server process
    ├─ Handle exceptions and restart LS if needed
    └─ Return result as string
    ↓
FastMCP -> Tool Result Response (JSON-RPC)
    ↓
MCP Client receives result
```

## Starting the Server

```bash
# Minimal
serena-mcp-server

# With project and context
serena-mcp-server --project /path/to/project --context agent

# With multiple modes
serena-mcp-server --mode planning --mode editing

# HTTP transport
serena-mcp-server --transport sse --host 127.0.0.1 --port 8000

# Full configuration
serena-mcp-server \
  --project my-project \
  --context agent \
  --mode planning \
  --transport stdio \
  --log-level DEBUG \
  --tool-timeout 60 \
  --trace-lsp-communication
```

## Configuration Hierarchy (by precedence)

1. **CLI Arguments** (--project, --context, --mode, etc.)
2. **Project Config** (.serena/project.yml)
3. **User Config** (~/.serena/serena_config.yml)
4. **Modes** (applied dynamically)
5. **Built-in Defaults** (DEFAULT_CONTEXT, DEFAULT_MODES)

## Class Relationships

```
SerenaMCPFactory (Abstract Base)
    ├─ create_mcp_server()
    ├─ _set_mcp_tools()
    ├─ make_mcp_tool() [static]
    └─ server_lifespan() [abstract async context manager]
        │
        └─ SerenaMCPFactorySingleProcess
            ├─ _instantiate_agent() [Creates SerenaAgent]
            ├─ _iter_tools() [Gets exposed tools]
            └─ server_lifespan() [Manages LS lifecycle]

SerenaAgent
    ├─ _all_tools: dict[type[Tool], Tool]
    ├─ _exposed_tools: AvailableTools
    ├─ get_exposed_tool_instances()
    ├─ get_active_project()
    ├─ language_server: SolidLanguageServer
    └─ Tool execution via ThreadPoolExecutor

Tool (Abstract Base)
    ├─ apply(**kwargs) -> str [must override]
    ├─ apply_ex(...) -> str [calls apply + error handling]
    ├─ get_name()
    └─ get_apply_docstring()

ToolRegistry (Singleton)
    ├─ _tool_dict: dict[str, RegisteredTool]
    ├─ get_all_tool_classes()
    ├─ get_tool_names()
    └─ get_tool_names_default_enabled()

SolidLanguageServer
    ├─ server: SolidLanguageServerHandler
    ├─ request_document_symbols()
    ├─ request_references()
    ├─ request_definition()
    └─ start()/stop() [lifecycle]
```

## Testing

### Unit Tests (test_mcp.py)
```python
# Test basic tool conversion
test_make_tool_basic()
test_make_tool_execution()
test_make_tool_no_params()
test_make_tool_all_tools()  # Parametrized over all tools

# Test description handling
test_make_tool_no_return_description()
test_make_tool_descriptions()
```

### Integration Tests (test_serena_agent.py)
```python
# Test tool execution through agent
test_find_symbol(language_marker)
test_find_symbol_references(language_marker)
test_find_symbol_name_path(language_marker)
```

### E2E Testing Pattern
```python
# 1. Create agent
agent = SerenaAgent(project="test_repo", serena_config=config)

# 2. Get tool
tool = agent.get_tool(FindSymbolTool)

# 3. Execute
result = tool.apply_ex(name_path="ClassName", relative_path="file.py")

# 4. Verify
symbols = json.loads(result)
assert any(s["name_path"] == "ClassName" for s in symbols)
```

## Logging Configuration

```python
# Three handlers configured in start_mcp_server():

1. MemoryLogHandler
   - In-memory circular buffer
   - Used by web dashboard and GUI

2. StreamHandler (stderr)
   - Real-time console output
   - Captured by MCP clients

3. FileHandler
   - Persistent logs
   - Location: ~/.serena/logs/mcp_TIMESTAMP.log

# Log format
SERENA_LOG_FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# Enable debug logging
--log-level DEBUG
--trace-lsp-communication (for LSP protocol tracing)
```

## Transport Protocols

### stdio (Default)
- Direct stdin/stdout communication
- Used by Claude Desktop, most MCP clients
- No network exposure
- Simplest deployment

### SSE (Server-Sent Events)
- HTTP-based with Server-Sent Events
- Requires host and port
- Example: `--transport sse --host 127.0.0.1 --port 8000`

### streamable-http
- Alternative HTTP streaming
- Similar configuration to SSE

## OpenAI Compatibility Mode

When context is "chatgpt", "codex", or "oaicompat-agent":
- Tool schemas are sanitized
- Integer types converted to number
- Union types simplified
- Helps compatibility with OpenAI tool calling API

## Key Concepts

### Exposed Tools (Fixed at Startup)
- Determined during agent initialization
- Based on context and mode inclusions/exclusions
- Cannot change during session (MCP clients don't react to changes)
- Access to disabled tools returns error message

### Active Tools (Dynamic)
- Subset of exposed tools that can currently run
- Adjusted when project is activated
- Read-only projects exclude editing tools
- Tools check `is_active()` before execution

### Contexts
- Fixed configuration for entire session
- Examples: "agent", "ide-assistant", "chatgpt", "codex"
- Controls tool availability and system prompt
- Set at startup via --context flag

### Modes
- Updatable operational patterns
- Examples: "planning", "editing", "interactive", "jetbrains"
- Can be combined (--mode planning --mode editing)
- Affect tool availability and prompt

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "Tool not available" | Verify context/mode includes tool, check project config |
| Language server fails to start | Check language installed, verify path, check logs |
| Tool execution timeout | Increase --tool-timeout, check LS responsiveness |
| Tools not being exposed | Check _exposed_tools filtering logic in agent.py |
| No logs appearing | Verify --log-level, check ~/.serena/logs/ directory |
| Wrong tools exposed | Review context/mode YAML configuration |

## Performance Considerations

1. **Tool Registration:** O(n) where n = number of tools, done at startup
2. **Tool Execution:** Serialized via ThreadPoolExecutor (max_workers=1)
3. **Language Server Caching:** Document symbols cached by content hash
4. **Project Indexing:** Can pre-build cache with `serena project index`

## Debugging Commands

```bash
# List available tools
serena tools list --all

# Get tool description
serena tools description find_symbol

# Check project health
serena project health-check /path/to/project

# Print system prompt
serena print-system-prompt /path/to/project

# Run with debug logging
serena-mcp-server --log-level DEBUG --trace-lsp-communication
```

## Architecture Highlights

1. **Single-Process Model:** Agent and LS communication in same process
2. **Lazy Initialization:** Tools created on demand, LS started when needed
3. **Robust Error Handling:** Automatic LS restart on failure
4. **Async Lifecycle:** FastMCP lifespan context manager for cleanup
5. **Multi-Transport:** Stdio, SSE, or HTTP available
6. **OpenAI Compatible:** Schema sanitization for tool calling API
7. **Comprehensive Logging:** Memory + File + Stderr for debugging
8. **Web Dashboard:** Optional UI for monitoring
9. **GUI Log Viewer:** Real-time log visualization (Linux/Windows)
10. **Tool Usage Stats:** Optional analytics with token counting

---

**For detailed information, see MCP_SERVER_ANALYSIS.md**
