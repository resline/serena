"""E2E tests for project workflow operations.

This module tests complete project workflows including:
- Project initialization and configuration
- Project indexing
- Multi-project scenarios
- Real-world development workflows
"""

from pathlib import Path

import pytest

from solidlsp.ls_config import Language
from test.e2e.mcp_test_client import MCPTestClient
from test.e2e.standalone_utils import StandaloneTestEnv


@pytest.mark.e2e
@pytest.mark.workflow
@pytest.mark.asyncio
class TestProjectWorkflows:
    """Tests for complete project workflow scenarios."""

    async def test_create_simple_python_project_workflow(
        self, mcp_client: MCPTestClient, tmp_path: Path
    ) -> None:
        """Test workflow: create simple Python project from scratch."""
        project_dir = tmp_path / "simple_project"
        project_dir.mkdir()

        # Step 1: Create project structure
        (project_dir / "src").mkdir()
        (project_dir / "tests").mkdir()

        # Step 2: Create main module
        main_content = """\"\"\"Main module for simple project.\"\"\"


def add(a: int, b: int) -> int:
    \"\"\"Add two numbers.\"\"\"
    return a + b


def multiply(a: int, b: int) -> int:
    \"\"\"Multiply two numbers.\"\"\"
    return a * b


def main() -> None:
    \"\"\"Main entry point.\"\"\"
    result = add(5, 3)
    print(f"5 + 3 = {result}")


if __name__ == "__main__":
    main()
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "src" / "main.py"), "content": main_content}
        )

        # Step 3: Create test file
        test_content = """\"\"\"Tests for main module.\"\"\"

from src.main import add, multiply


def test_add():
    \"\"\"Test addition.\"\"\"
    assert add(2, 3) == 5
    assert add(-1, 1) == 0


def test_multiply():
    \"\"\"Test multiplication.\"\"\"
    assert multiply(2, 3) == 6
    assert multiply(-1, 5) == -5
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "tests" / "test_main.py"), "content": test_content}
        )

        # Step 4: Create README
        readme_content = """# Simple Project

A simple Python project demonstrating basic functionality.

## Installation

```bash
pip install -e .
```

## Usage

```bash
python src/main.py
```

## Testing

```bash
pytest tests/
```
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "README.md"), "content": readme_content}
        )

        # Step 5: Verify project structure
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = result.content[0].text
        assert "src" in listing
        assert "tests" in listing
        assert "README.md" in listing

    async def test_create_typescript_project_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: create TypeScript project."""
        project_dir = tmp_path / "ts_project"
        project_dir.mkdir()

        # Create package.json
        package_json = """{
  "name": "ts-project",
  "version": "1.0.0",
  "description": "A TypeScript project",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "jest": "^29.0.0"
  }
}
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "package.json"), "content": package_json}
        )

        # Create tsconfig.json
        tsconfig = """{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "tsconfig.json"), "content": tsconfig}
        )

        # Create source file
        (project_dir / "src").mkdir()
        ts_content = """export function greet(name: string): string {
    return `Hello, ${name}!`;
}

export function add(a: number, b: number): number {
    return a + b;
}

export default function main(): void {
    console.log(greet("World"));
    console.log(`2 + 2 = ${add(2, 2)}`);
}
"""
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "src" / "index.ts"), "content": ts_content}
        )

        # Verify
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = result.content[0].text
        assert "package.json" in listing
        assert "tsconfig.json" in listing
        assert "src" in listing

    async def test_refactoring_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: refactor code across multiple files."""
        project_dir = tmp_path / "refactor_project"
        project_dir.mkdir()

        # Original code with old function name
        old_module = """def old_calculate(x, y):
    return x + y

result = old_calculate(5, 3)
"""

        old_test = """from main import old_calculate

def test_old_calculate():
    assert old_calculate(2, 3) == 5
"""

        # Write original files
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "main.py"), "content": old_module}
        )
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "test_main.py"), "content": old_test}
        )

        # Refactor: rename function
        new_module = old_module.replace("old_calculate", "calculate_sum")
        new_test = old_test.replace("old_calculate", "calculate_sum")

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "main.py"), "content": new_module}
        )
        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "test_main.py"), "content": new_test}
        )

        # Verify refactoring
        main_result = await mcp_client.call_tool("read_file", {"file_path": str(project_dir / "main.py")})

        main_content = main_result.content[0].text
        assert "calculate_sum" in main_content
        assert "old_calculate" not in main_content

        test_result = await mcp_client.call_tool("read_file", {"file_path": str(project_dir / "test_main.py")})

        test_content = test_result.content[0].text
        assert "calculate_sum" in test_content

    async def test_adding_new_feature_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: add new feature to existing project."""
        project_dir = tmp_path / "feature_project"
        project_dir.mkdir()

        # Existing code
        existing_code = """def greet(name):
    return f"Hello, {name}!"
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "utils.py"), "content": existing_code}
        )

        # Add new feature: farewell function
        updated_code = """def greet(name):
    return f"Hello, {name}!"


def farewell(name):
    return f"Goodbye, {name}!"
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "utils.py"), "content": updated_code}
        )

        # Add tests for new feature
        test_code = """from utils import greet, farewell


def test_greet():
    assert greet("Alice") == "Hello, Alice!"


def test_farewell():
    assert farewell("Bob") == "Goodbye, Bob!"
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "test_utils.py"), "content": test_code}
        )

        # Verify
        result = await mcp_client.call_tool("read_file", {"file_path": str(project_dir / "utils.py")})

        content = result.content[0].text
        assert "def greet" in content
        assert "def farewell" in content

    async def test_documentation_update_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow: update project documentation."""
        project_dir = tmp_path / "docs_project"
        project_dir.mkdir()

        # Initial README
        initial_readme = """# My Project

Basic project description.
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "README.md"), "content": initial_readme}
        )

        # Update with comprehensive documentation
        updated_readme = """# My Project

A comprehensive Python project for data processing.

## Features

- Data loading
- Data transformation
- Data export

## Installation

```bash
pip install -e .
```

## Usage

```python
from myproject import process_data

result = process_data("input.csv")
```

## License

MIT License
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "README.md"), "content": updated_readme}
        )

        # Verify update
        result = await mcp_client.call_tool("read_file", {"file_path": str(project_dir / "README.md")})

        content = result.content[0].text
        assert "Features" in content
        assert "Installation" in content
        assert "Usage" in content

    @pytest.mark.slow
    async def test_complete_development_workflow(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test complete development workflow from start to finish."""
        project_dir = tmp_path / "complete_project"
        project_dir.mkdir()

        # Phase 1: Project setup
        (project_dir / "src").mkdir()
        (project_dir / "tests").mkdir()
        (project_dir / "docs").mkdir()

        # Phase 2: Initial implementation
        initial_code = """\"\"\"Data processor module.\"\"\"


class DataProcessor:
    \"\"\"Process data.\"\"\"

    def __init__(self):
        self.data = []

    def add_item(self, item):
        \"\"\"Add item to data.\"\"\"
        self.data.append(item)

    def get_count(self):
        \"\"\"Get count of items.\"\"\"
        return len(self.data)
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "src" / "processor.py"), "content": initial_code}
        )

        # Phase 3: Add tests
        test_code = """\"\"\"Tests for processor module.\"\"\"

from src.processor import DataProcessor


def test_add_item():
    processor = DataProcessor()
    processor.add_item("item1")
    assert processor.get_count() == 1


def test_multiple_items():
    processor = DataProcessor()
    processor.add_item("item1")
    processor.add_item("item2")
    assert processor.get_count() == 2
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "tests" / "test_processor.py"), "content": test_code}
        )

        # Phase 4: Add documentation
        docs_content = """# Data Processor Documentation

## Overview

The DataProcessor class provides functionality for managing data items.

## API Reference

### DataProcessor

#### Methods

- `add_item(item)`: Add an item to the collection
- `get_count()`: Get the number of items

## Examples

```python
processor = DataProcessor()
processor.add_item("example")
print(processor.get_count())  # Output: 1
```
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "docs" / "api.md"), "content": docs_content}
        )

        # Phase 5: Add configuration
        config_content = """[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = "test_*.py"

[tool.black]
line-length = 100
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "pyproject.toml"), "content": config_content}
        )

        # Verify complete structure
        result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})

        listing = result.content[0].text
        assert "src" in listing
        assert "tests" in listing
        assert "docs" in listing
        assert "pyproject.toml" in listing


@pytest.mark.e2e
@pytest.mark.workflow
@pytest.mark.slow
@pytest.mark.asyncio
class TestMultiProjectWorkflows:
    """Tests for workflows involving multiple projects."""

    async def test_multiple_projects_independently(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test working with multiple independent projects."""
        # Create two projects
        project1 = tmp_path / "project1"
        project2 = tmp_path / "project2"
        project1.mkdir()
        project2.mkdir()

        # Project 1: Python
        await mcp_client.call_tool(
            "write_file",
            {"file_path": str(project1 / "main.py"), "content": "def project1_func():\n    pass\n"},
        )

        # Project 2: TypeScript
        await mcp_client.call_tool(
            "write_file",
            {"file_path": str(project2 / "main.ts"), "content": "function project2Func() {}\n"},
        )

        # Verify both projects
        result1 = await mcp_client.call_tool("list_directory", {"path": str(project1)})
        assert "main.py" in result1.content[0].text

        result2 = await mcp_client.call_tool("list_directory", {"path": str(project2)})
        assert "main.ts" in result2.content[0].text

    async def test_shared_utilities_across_projects(self, mcp_client: MCPTestClient, tmp_path: Path) -> None:
        """Test workflow with shared utilities across projects."""
        # Create shared utilities directory
        shared_dir = tmp_path / "shared"
        shared_dir.mkdir()

        # Create shared utility
        shared_utils = """\"\"\"Shared utilities.\"\"\"


def format_message(message):
    return f"[INFO] {message}"


def validate_input(value):
    return value is not None and len(str(value)) > 0
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(shared_dir / "utils.py"), "content": shared_utils}
        )

        # Create project using shared utilities
        project_dir = tmp_path / "project"
        project_dir.mkdir()

        project_code = """\"\"\"Project using shared utilities.\"\"\"

import sys
sys.path.append("../shared")

from utils import format_message, validate_input


def process(data):
    if not validate_input(data):
        return None
    return format_message(data)
"""

        await mcp_client.call_tool(
            "write_file", {"file_path": str(project_dir / "main.py"), "content": project_code}
        )

        # Verify structure
        shared_result = await mcp_client.call_tool("list_directory", {"path": str(shared_dir)})
        assert "utils.py" in shared_result.content[0].text

        project_result = await mcp_client.call_tool("list_directory", {"path": str(project_dir)})
        assert "main.py" in project_result.content[0].text
