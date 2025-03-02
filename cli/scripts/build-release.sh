#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Set variables
BINARY_NAME="provision"
OUTPUT_DIR="bin"

echo "Building release binaries for the infrastructure CLI tool..."

# Check for Go installation
if ! command -v go &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} Go is not installed. This script requires Go to build the binaries."
    exit 1
fi

# Check Go version
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
GO_VERSION_MAJOR=$(echo $GO_VERSION | cut -d. -f1)
GO_VERSION_MINOR=$(echo $GO_VERSION | cut -d. -f2)

if [ "$GO_VERSION_MAJOR" -lt 1 ] || ([ "$GO_VERSION_MAJOR" -eq 1 ] && [ "$GO_VERSION_MINOR" -lt 18 ]); then
    echo -e "${RED}✗ Error:${NC} Go version 1.18 or higher is required. You have $GO_VERSION."
    exit 1
fi

echo -e "${GREEN}✓${NC} Using Go version $GO_VERSION"

# Create output directory
mkdir -p $OUTPUT_DIR

# Define target platforms
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "darwin/amd64"
    "darwin/arm64"
    "windows/amd64"
)

# Build for each platform
for PLATFORM in "${PLATFORMS[@]}"; do
    OS="${PLATFORM%/*}"
    ARCH="${PLATFORM#*/}"
    
    OUTPUT_NAME="${BINARY_NAME}"
    if [ "$OS" = "windows" ]; then
        OUTPUT_NAME="${OUTPUT_NAME}.exe"
    fi
    
    echo "Building for ${OS}/${ARCH}..."
    
    mkdir -p "${OUTPUT_DIR}/${OS}_${ARCH}"
    
    GOOS=$OS GOARCH=$ARCH go build -o "${OUTPUT_DIR}/${OS}_${ARCH}/${OUTPUT_NAME}" ./cmd/provision
    
    echo -e "${GREEN}✓${NC} Built ${OS}/${ARCH}"
done

echo -e "${GREEN}✓${NC} All binaries built successfully!"
echo ""
echo "Binaries are available in the ${OUTPUT_DIR} directory with the following structure:"
echo "  ${OUTPUT_DIR}/[os]_[arch]/${BINARY_NAME}"
echo ""
echo "Examples:"
echo "  ${OUTPUT_DIR}/linux_amd64/${BINARY_NAME}"
echo "  ${OUTPUT_DIR}/darwin_arm64/${BINARY_NAME}"
echo "  ${OUTPUT_DIR}/windows_amd64/${BINARY_NAME}.exe"
echo ""
echo "To install the tool, users can run ./install.sh or copy the appropriate binary to their PATH."
