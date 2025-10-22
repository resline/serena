"""E2E tests for tool execution workflows.

This module tests real tool execution scenarios through MCP, including:
- Symbol finding and editing
- Multi-tool workflows
- Cross-language operations
- Error handling
"""

import json
from pathlib import Path

import pytest

from solidlsp.ls_config import Language
from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv


@pytest.mark.e2e
@pytest.mark.tools
@pytest.mark.asyncio
class TestToolExecutionE2E:
    """Tests for end-to-end tool execution workflows."""

    async def test_read_file_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test read_file tool end-to-end."""
        # Create test file
        test_file = tmp_path / "sample.py"
        test_content = """def hello():
    return "Hello, World!"
"""
        test_file.write_text(test_content)

        # Read file via MCP
        result = await mcp_client.call_tool("read_file", {"file_path": str(test_file)})

        assert hasattr(result, "content")
        content_text = result.content[0].text

        assert "def hello():" in content_text
        assert "Hello, World!" in content_text

    async def test_write_file_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test write_file tool end-to-end."""
        test_file = tmp_path / "output.py"
        test_content = """def add(a, b):
    return a + b
"""

        # Write file via MCP
        result = await mcp_client.call_tool(
            "write_file", {"file_path": str(test_file), "content": test_content}
        )

        assert hasattr(result, "content")

        # Verify file was written
        assert test_file.exists()
        written_content = test_file.read_text()
        assert "def add(a, b):" in written_content

    async def test_list_directory_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test list_directory tool with various file types."""
        # Create directory structure
        (tmp_path / "file1.py").write_text("# Python file")
        (tmp_path / "file2.txt").write_text("Text file")
        (tmp_path / "subdir").mkdir()
        (tmp_path / "subdir" / "nested.py").write_text("# Nested file")

        # List directory via MCP
        result = await mcp_client.call_tool("list_directory", {"path": str(tmp_path)})

        assert hasattr(result, "content")
        content_text = result.content[0].text

        # Should list top-level items
        assert "file1.py" in content_text
        assert "file2.txt" in content_text
        assert "subdir" in content_text

    async def test_search_files_tool(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test search_files tool for pattern matching."""
        # Create test files with searchable content
        (tmp_path / "file1.py").write_text("""
def calculate_total(items):
    return sum(items)
""")
        (tmp_path / "file2.py").write_text("""
def process_data(data):
    return data
""")

        # Search for pattern
        result = await mcp_client.call_tool(
            "search_files", {"path": str(tmp_path), "pattern": "def calculate", "file_pattern": "*.py"}
        )

        assert hasattr(result, "content")
        content_text = result.content[0].text

        # Should find the function
        assert "calculate_total" in content_text or "file1.py" in content_text

    async def test_read_write_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: read file, modify, write back."""
        original_file = tmp_path / "code.py"
        original_content = """def old_function():
    return "old"
"""
        original_file.write_text(original_content)

        # Step 1: Read original file
        read_result = await mcp_client.call_tool("read_file", {"file_path": str(original_file)})

        assert hasattr(read_result, "content")
        original_text = read_result.content[0].text
        assert "old_function" in original_text

        # Step 2: Modify content (simulate)
        modified_content = original_content.replace("old_function", "new_function").replace('"old"', '"new"')

        # Step 3: Write modified content
        write_result = await mcp_client.call_tool(
            "write_file", {"file_path": str(original_file), "content": modified_content}
        )

        assert hasattr(write_result, "content")

        # Step 4: Verify modification
        verify_result = await mcp_client.call_tool("read_file", {"file_path": str(original_file)})

        verify_text = verify_result.content[0].text
        assert "new_function" in verify_text
        assert "old_function" not in verify_text

    async def test_multiple_file_operations(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test multiple file operations in sequence."""
        # Create multiple files
        files = []
        for i in range(3):
            file_path = tmp_path / f"file{i}.py"
            file_path.write_text(f"# File {i}")
            files.append(file_path)

        # Read all files
        for file_path in files:
            result = await mcp_client.call_tool("read_file", {"file_path": str(file_path)})
            assert hasattr(result, "content")
            assert f"# File" in result.content[0].text

    async def test_error_handling_nonexistent_file(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test error handling when reading non-existent file."""
        nonexistent = tmp_path / "does_not_exist.py"

        with pytest.raises(Exception) as exc_info:
            await mcp_client.call_tool("read_file", {"file_path": str(nonexistent)})

        # Should raise some error
        assert exc_info.value is not None

    async def test_error_handling_invalid_path(self, mcp_client: MCPTestClient) -> None:
        """Test error handling with invalid file path."""
        with pytest.raises(Exception):
            await mcp_client.call_tool("read_file", {"file_path": "/invalid/path/file.py"})

    @pytest.mark.parametrize("test_project", [Language.PYTHON], indirect=True)
    async def test_project_file_operations(
        self, mcp_client: MCPTestClient, test_project: Path, standalone_env: StandaloneTestEnv
    ) -> None:
        """Test file operations on a real project structure."""
        # List project directory
        list_result = await mcp_client.call_tool("list_directory", {"path": str(test_project)})

        assert hasattr(list_result, "content")
        listing = list_result.content[0].text

        # Should contain Python files
        assert ".py" in listing

    @pytest.mark.slow
    async def test_large_file_read(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test reading a large file."""
        large_file = tmp_path / "large.py"

        # Create large file (1000 lines)
        lines = [f"# Line {i}\ndef function_{i}(): pass\n" for i in range(1000)]
        large_file.write_text("".join(lines))

        # Read large file
        result = await mcp_client.call_tool("read_file", {"file_path": str(large_file)})

        assert hasattr(result, "content")
        content = result.content[0].text

        # Should contain first and last lines
        assert "Line 0" in content
        assert "Line 999" in content or "function_999" in content

    async def test_file_with_special_characters(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test file operations with special characters in content."""
        special_file = tmp_path / "special.py"
        special_content = """def process():
    # Special chars: äöü ñ 中文 emoji 🎉
    return "Unicode: \\u0394"
"""
        special_file.write_text(special_content, encoding="utf-8")

        # Read file with special chars
        result = await mcp_client.call_tool("read_file", {"file_path": str(special_file)})

        assert hasattr(result, "content")
        content = result.content[0].text

        # Should preserve special characters
        assert "process" in content

    async def test_directory_creation_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow involving directory and file creation."""
        new_dir = tmp_path / "new_project"
        new_dir.mkdir()

        new_file = new_dir / "main.py"

        # Write file in new directory
        result = await mcp_client.call_tool(
            "write_file",
            {"file_path": str(new_file), "content": "def main():\n    pass\n"},
        )

        assert hasattr(result, "content")
        assert new_file.exists()

        # List new directory
        list_result = await mcp_client.call_tool("list_directory", {"path": str(new_dir)})

        listing = list_result.content[0].text
        assert "main.py" in listing

    async def test_file_overwrite(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test overwriting existing file."""
        target_file = tmp_path / "overwrite.py"

        # Write initial content
        await mcp_client.call_tool(
            "write_file", {"file_path": str(target_file), "content": "# Original content\n"}
        )

        assert target_file.exists()
        original = target_file.read_text()
        assert "Original" in original

        # Overwrite with new content
        await mcp_client.call_tool(
            "write_file", {"file_path": str(target_file), "content": "# New content\n"}
        )

        # Verify overwrite
        new_content = target_file.read_text()
        assert "New content" in new_content
        assert "Original" not in new_content

    @pytest.mark.parametrize("extension", ["py", "ts", "go", "rs", "java"])
    async def test_multi_language_file_operations(
        self, mcp_client: MCPTestClient, tmp_path: Path, extension: str
    ) -> None:
        """Test file operations with different language file types."""
        test_file = tmp_path / f"sample.{extension}"

        # Language-specific content
        content_map = {
            "py": "def hello():\n    pass\n",
            "ts": "function hello() {}\n",
            "go": "package main\n\nfunc hello() {}\n",
            "rs": "fn hello() {}\n",
            "java": "public class Sample {\n    public void hello() {}\n}\n",
        }

        content = content_map[extension]

        # Write file
        await mcp_client.call_tool("write_file", {"file_path": str(test_file), "content": content})

        assert test_file.exists()

        # Read back
        result = await mcp_client.call_tool("read_file", {"file_path": str(test_file)})

        read_content = result.content[0].text
        assert "hello" in read_content

    async def test_relative_vs_absolute_paths(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test tool works with absolute paths."""
        test_file = tmp_path / "test.py"
        test_file.write_text("# Test content\n")

        # Use absolute path
        absolute_path = test_file.resolve()

        result = await mcp_client.call_tool("read_file", {"file_path": str(absolute_path)})

        assert hasattr(result, "content")
        content = result.content[0].text
        assert "Test content" in content

    @pytest.mark.slow
    async def test_concurrent_file_reads(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test concurrent reading of multiple files."""
        import asyncio

        # Create multiple files
        files = []
        for i in range(10):
            file_path = tmp_path / f"concurrent_{i}.py"
            file_path.write_text(f"# File {i}\ndef func_{i}(): pass\n")
            files.append(file_path)

        # Read all files concurrently
        tasks = [mcp_client.call_tool("read_file", {"file_path": str(f)}) for f in files]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # All reads should succeed
        assert len(results) == 10
        for i, result in enumerate(results):
            assert not isinstance(result, Exception), f"Read {i} failed: {result}"
            assert hasattr(result, "content")


@pytest.mark.e2e
@pytest.mark.tools
@pytest.mark.slow
@pytest.mark.asyncio
class TestAdvancedToolWorkflows:
    """Advanced multi-tool workflow tests."""

    async def test_search_and_read_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: search for files, then read matches."""
        # Create project structure
        (tmp_path / "src").mkdir()
        (tmp_path / "src" / "main.py").write_text("def main():\n    print('Hello')\n")
        (tmp_path / "src" / "utils.py").write_text("def helper():\n    return 42\n")
        (tmp_path / "tests").mkdir()
        (tmp_path / "tests" / "test_main.py").write_text("def test_main():\n    assert True\n")

        # Step 1: Search for main functions
        search_result = await mcp_client.call_tool(
            "search_files", {"path": str(tmp_path), "pattern": "def main", "file_pattern": "*.py"}
        )

        assert hasattr(search_result, "content")
        search_text = search_result.content[0].text

        # Should find main.py
        assert "main.py" in search_text

        # Step 2: Read found files (simulate extraction of file paths)
        main_file = tmp_path / "src" / "main.py"

        read_result = await mcp_client.call_tool("read_file", {"file_path": str(main_file)})

        content = read_result.content[0].text
        assert "def main():" in content
        assert "Hello" in content

    async def test_directory_tree_traversal(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test traversing directory tree via list_directory."""
        # Create nested structure
        (tmp_path / "level1").mkdir()
        (tmp_path / "level1" / "level2").mkdir()
        (tmp_path / "level1" / "level2" / "file.py").write_text("# Deep file")

        # List top level
        result1 = await mcp_client.call_tool("list_directory", {"path": str(tmp_path)})
        assert "level1" in result1.content[0].text

        # List level 1
        result2 = await mcp_client.call_tool("list_directory", {"path": str(tmp_path / "level1")})
        assert "level2" in result2.content[0].text

        # List level 2
        result3 = await mcp_client.call_tool("list_directory", {"path": str(tmp_path / "level1" / "level2")})
        assert "file.py" in result3.content[0].text

    async def test_create_and_verify_project_structure(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test creating a complete project structure."""
        project_dir = tmp_path / "new_project"
        project_dir.mkdir()

        # Create project files
        files_to_create = [
            ("src/main.py", "def main():\n    pass\n"),
            ("src/__init__.py", ""),
            ("tests/test_main.py", "def test_main():\n    assert True\n"),
            ("README.md", "# New Project\n"),
        ]

        for rel_path, content in files_to_create:
            file_path = project_dir / rel_path
            file_path.parent.mkdir(parents=True, exist_ok=True)

            await mcp_client.call_tool("write_file", {"file_path": str(file_path), "content": content})

        # Verify structure
        list_result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = list_result.content[0].text
        assert "src" in listing
        assert "tests" in listing
        assert "README.md" in listing
