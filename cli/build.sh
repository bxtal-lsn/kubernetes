#!/bin/bash

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Building Kubernetes CLI tool for Linux amd64..."

# Check for Go installation
if ! command -v go &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} Go is not installed. This script requires Go to build the binary."
    exit 1
fi

# Build for Linux amd64 only
echo "Building for linux/amd64..."
GOOS=linux GOARCH=amd64 go build -o "../provision-cli" ./cmd/provision

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Binary built successfully!"
    echo "The binary is available at: ../provision-cli"
    chmod +x ../provision-cli
else
    echo -e "${RED}✗ Error:${NC} Build failed."
    exit 1
fi
