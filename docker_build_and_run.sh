#!/usr/bin/bash

# Serena MCP Docker Build and Run Script
# Version: 0.1.4
# Description: Builds and runs Serena MCP in a Docker container

set -e  # Exit on error

echo "Building Serena Docker image (v0.1.4)..."
docker build -t serena:latest -t serena:0.1.4 .

if [ $? -eq 0 ]; then
    echo "✓ Docker image built successfully"
    echo ""
    echo "Starting Serena container..."
    echo "Mounting current directory as /workspace"
    docker run -it --rm \
        -v "$(pwd)":/workspace \
        -e HTTP_PROXY="${HTTP_PROXY}" \
        -e HTTPS_PROXY="${HTTPS_PROXY}" \
        -e NO_PROXY="${NO_PROXY}" \
        --name serena-mcp \
        serena:latest
else
    echo "✗ Failed to build Docker image"
    exit 1
fi
