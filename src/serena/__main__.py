"""
Entry point for running Serena as a module: python -m serena

This allows the package to be executed with:
    python -m serena [args]

Which is equivalent to:
    serena [args]
"""

from serena.cli import top_level

if __name__ == "__main__":
    top_level()
