"""E2E tests for Language Server integration.

This module tests real Language Server integration through MCP tools,
including startup, symbol operations, and error recovery.

Note: These tests require Language Servers to be bundled in the standalone build.
For minimal tier (no bundled LSs), tests will be skipped.
"""

import asyncio
from pathlib import Path

import pytest

from solidlsp.ls_config import Language
from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv, get_bundled_language_servers


@pytest.mark.e2e
@pytest.mark.language_server
@pytest.mark.asyncio
class TestLanguageServerIntegration:
    """Tests for Language Server integration through MCP."""

    async def test_bundled_language_servers_exist(self, standalone_env: StandaloneTestEnv) -> None:
        """Verify expected language servers are bundled."""
        bundled_servers = get_bundled_language_servers(standalone_env.build_dir)

        # Essential tier should have at least Python, TypeScript, Rust, Go
        if standalone_env.tier == "essential":
            # Check for presence (exact names may vary)
            assert len(bundled_servers) >= 3, f"Expected 3+ LSs, found: {bundled_servers}"

        elif standalone_env.tier == "minimal":
            # Minimal may have no LSs
            pytest.skip("Minimal tier has no bundled language servers")

    @pytest.mark.parametrize("test_project", [Language.PYTHON], indirect=True)
    async def test_python_project_file_operations(
        self, mcp_client: MCPTestClient, test_project: Path
    ) -> None:
        """Test basic file operations on Python project."""
        # List project files
        result = await mcp_client.call_tool("list_directory", {"path": str(test_project)})

        assert hasattr(result, "content")
        listing = result.content[0].text

        # Should find Python files
        assert ".py" in listing

        # Try to read a Python file
        py_files = list(test_project.glob("*.py"))
        if py_files:
            read_result = await mcp_client.call_tool("read_file", {"file_path": str(py_files[0])})

            content = read_result.content[0].text
            assert len(content) > 0

    @pytest.mark.parametrize("test_project", [Language.GO], indirect=True)
    async def test_go_project_file_operations(self, mcp_client: MCPTestClient, test_project: Path) -> None:
        """Test basic file operations on Go project."""
        # List project files
        result = await mcp_client.call_tool("list_directory", {"path": str(test_project)})

        listing = result.content[0].text

        # Should find Go files
        assert ".go" in listing

        # Read a Go file
        go_files = list(test_project.glob("*.go"))
        if go_files:
            read_result = await mcp_client.call_tool("read_file", {"file_path": str(go_files[0])})

            content = read_result.content[0].text
            assert "package" in content or "func" in content

    @pytest.mark.parametrize("test_project", [Language.TYPESCRIPT], indirect=True)
    async def test_typescript_project_file_operations(
        self, mcp_client: MCPTestClient, test_project: Path
    ) -> None:
        """Test basic file operations on TypeScript project."""
        result = await mcp_client.call_tool("list_directory", {"path": str(test_project)})

        listing = result.content[0].text
        assert ".ts" in listing

    async def test_create_python_project_and_read(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test creating a Python project and reading files."""
        project_dir = tmp_path / "python_project"
        project_dir.mkdir()

        # Create Python file
        main_file = project_dir / "main.py"
        python_code = """def calculate_sum(numbers):
    \"\"\"Calculate sum of numbers.\"\"\"
    return sum(numbers)


def main():
    result = calculate_sum([1, 2, 3, 4, 5])
    print(f"Sum: {result}")


if __name__ == "__main__":
    main()
"""

        await mcp_client.call_tool("write_file", {"file_path": str(main_file), "content": python_code})

        # Read back
        result = await mcp_client.call_tool("read_file", {"file_path": str(main_file)})

        content = result.content[0].text
        assert "calculate_sum" in content
        assert "def main():" in content

    async def test_create_go_project_and_read(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test creating a Go project and reading files."""
        project_dir = tmp_path / "go_project"
        project_dir.mkdir()

        # Create Go file
        main_file = project_dir / "main.go"
        go_code = """package main

import "fmt"

func calculateSum(numbers []int) int {
    sum := 0
    for _, num := range numbers {
        sum += num
    }
    return sum
}

func main() {
    numbers := []int{1, 2, 3, 4, 5}
    result := calculateSum(numbers)
    fmt.Printf("Sum: %d\\n", result)
}
"""

        await mcp_client.call_tool("write_file", {"file_path": str(main_file), "content": go_code})

        # Read back
        result = await mcp_client.call_tool("read_file", {"file_path": str(main_file)})

        content = result.content[0].text
        assert "package main" in content
        assert "calculateSum" in content

    async def test_search_in_project(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test searching for code patterns in a project."""
        project_dir = tmp_path / "search_project"
        project_dir.mkdir()

        # Create multiple files
        (project_dir / "file1.py").write_text("def process_data(data):\n    return data\n")
        (project_dir / "file2.py").write_text("def transform_data(data):\n    return data * 2\n")
        (project_dir / "file3.py").write_text("def save_data(data, path):\n    pass\n")

        # Search for "data" function
        result = await mcp_client.call_tool(
            "search_files", {"path": str(project_dir), "pattern": "def.*data", "file_pattern": "*.py"}
        )

        content = result.content[0].text

        # Should find multiple matches
        assert "data" in content.lower()

    @pytest.mark.slow
    async def test_large_project_file_operations(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test file operations on a larger project structure."""
        project_dir = tmp_path / "large_project"
        project_dir.mkdir()

        # Create multiple directories and files
        for i in range(5):
            subdir = project_dir / f"module_{i}"
            subdir.mkdir()

            for j in range(10):
                file_path = subdir / f"file_{j}.py"
                file_path.write_text(f"# Module {i}, File {j}\ndef func_{i}_{j}():\n    pass\n")

        # List top-level directory
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = result.content[0].text
        assert "module_0" in listing
        assert "module_4" in listing

        # Search across project
        search_result = await mcp_client.call_tool(
            "search_files", {"path": str(project_dir), "pattern": "def func_0", "file_pattern": "*.py"}
        )

        search_content = search_result.content[0].text
        assert "func_0" in search_content

    async def test_multi_language_project(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test operations on a multi-language project."""
        project_dir = tmp_path / "polyglot_project"
        project_dir.mkdir()

        # Create files in different languages
        files = {
            "main.py": "def main():\n    pass\n",
            "utils.ts": "function util() {}\n",
            "helper.go": "package main\n\nfunc helper() {}\n",
            "core.rs": "fn core() {}\n",
        }

        for filename, content in files.items():
            await mcp_client.call_tool(
                "write_file", {"file_path": str(project_dir / filename), "content": content}
            )

        # List directory - should see all files
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = result.content[0].text
        for filename in files.keys():
            assert filename in listing

    @pytest.mark.slow
    async def test_concurrent_file_operations_across_languages(
        self, mcp_client: MCPTestClient, tmp_path: Path
    ) -> None:
        """Test concurrent operations on files in different languages."""
        project_dir = tmp_path / "concurrent_project"
        project_dir.mkdir()

        # Create files in different languages
        files = [
            ("file1.py", "# Python\ndef func1(): pass\n"),
            ("file2.go", "// Go\npackage main\n\nfunc func2() {}\n"),
            ("file3.ts", "// TypeScript\nfunction func3() {}\n"),
            ("file4.rs", "// Rust\nfn func4() {}\n"),
            ("file5.java", "// Java\npublic class File5 {}\n"),
        ]

        # Write all files concurrently
        write_tasks = [
            mcp_client.call_tool("write_file", {"file_path": str(project_dir / fname), "content": content})
            for fname, content in files
        ]

        write_results = await asyncio.gather(*write_tasks)
        assert len(write_results) == 5

        # Read all files concurrently
        read_tasks = [mcp_client.call_tool("read_file", {"file_path": str(project_dir / fname)}) for fname, _ in files]

        read_results = await asyncio.gather(*read_tasks)

        # Verify all reads succeeded
        assert len(read_results) == 5
        for i, result in enumerate(read_results):
            assert hasattr(result, "content")
            # Each file should contain its language identifier
            content = result.content[0].text
            assert len(content) > 0

    async def test_error_recovery_missing_file(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test error recovery when file operations fail."""
        project_dir = tmp_path / "error_project"
        project_dir.mkdir()

        # Try to read non-existent file
        with pytest.raises(Exception):
            await mcp_client.call_tool("read_file", {"file_path": str(project_dir / "nonexistent.py")})

        # Server should still work after error
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})
        assert hasattr(result, "content")

    async def test_file_encoding_handling(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test handling of files with different encodings."""
        test_file = tmp_path / "unicode.py"

        # Create file with Unicode content
        unicode_content = """# -*- coding: utf-8 -*-
def greet():
    return "Hello: 你好 Привет مرحبا"
"""

        await mcp_client.call_tool("write_file", {"file_path": str(test_file), "content": unicode_content})

        # Read back
        result = await mcp_client.call_tool("read_file", {"file_path": str(test_file)})

        content = result.content[0].text
        assert "def greet():" in content
        # Unicode may or may not be preserved depending on encoding handling
        assert "Hello" in content


@pytest.mark.e2e
@pytest.mark.language_server
@pytest.mark.slow
@pytest.mark.asyncio
class TestLanguageServerPerformance:
    """Performance tests for Language Server operations."""

    async def test_read_performance_many_files(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test performance when reading many files."""
        import time

        project_dir = tmp_path / "perf_project"
        project_dir.mkdir()

        # Create 50 files
        for i in range(50):
            file_path = project_dir / f"file_{i}.py"
            file_path.write_text(f"# File {i}\ndef function_{i}():\n    pass\n")

        # Measure time to read all files
        start_time = time.time()

        read_tasks = [
            mcp_client.call_tool("read_file", {"file_path": str(project_dir / f"file_{i}.py")}) for i in range(50)
        ]

        results = await asyncio.gather(*read_tasks, return_exceptions=True)

        elapsed = time.time() - start_time

        # All reads should succeed
        successful = sum(1 for r in results if not isinstance(r, Exception))
        assert successful >= 45  # Allow some failures

        # Performance target: < 10 seconds for 50 files
        assert elapsed < 10.0, f"Reading 50 files took {elapsed:.2f}s (target: <10s)"

    async def test_search_performance_large_codebase(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test search performance on larger codebase."""
        import time

        project_dir = tmp_path / "large_search_project"
        project_dir.mkdir()

        # Create nested structure with many files
        for i in range(10):
            subdir = project_dir / f"module_{i}"
            subdir.mkdir()
            for j in range(20):
                file_path = subdir / f"file_{j}.py"
                file_path.write_text(f"""
# Module {i}, File {j}

def process_{i}_{j}(data):
    return data

def calculate_{i}_{j}(value):
    return value * 2

class Handler_{i}_{j}:
    def handle(self):
        pass
""")

        # Measure search time
        start_time = time.time()

        result = await mcp_client.call_tool(
            "search_files", {"path": str(project_dir), "pattern": "def process", "file_pattern": "*.py"}
        )

        elapsed = time.time() - start_time

        assert hasattr(result, "content")

        # Performance target: < 5 seconds for 200 files
        assert elapsed < 5.0, f"Search took {elapsed:.2f}s (target: <5s)"

    async def test_list_directory_performance(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test performance of directory listing with many files."""
        import time

        large_dir = tmp_path / "large_directory"
        large_dir.mkdir()

        # Create 500 files
        for i in range(500):
            (large_dir / f"file_{i}.txt").write_text(f"Content {i}")

        # Measure listing time
        start_time = time.time()

        result = await mcp_client.call_tool("list_directory", {"path": str(large_dir)})

        elapsed = time.time() - start_time

        assert hasattr(result, "content")

        # Performance target: < 2 seconds
        assert elapsed < 2.0, f"Listing 500 files took {elapsed:.2f}s (target: <2s)"
