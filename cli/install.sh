#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Determine OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture to Go architecture naming
case $ARCH in
  x86_64)
    GOARCH="amd64"
    ;;
  aarch64|arm64)
    GOARCH="arm64"
    ;;
  *)
    echo -e "${RED}✗ Error:${NC} Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Binary paths
BINARY_NAME="provision"
BINARY_PATH="bin/${OS}_${GOARCH}/${BINARY_NAME}"
INSTALL_DIR="$HOME/.local/bin"

echo "Installing infrastructure CLI tool..."

# Check if the binary exists for this platform
if [ ! -f "$BINARY_PATH" ]; then
  echo -e "${RED}✗ Error:${NC} Binary not found for your platform: ${OS}_${GOARCH}"
  echo "Please compile the binary for your platform or contact the repository maintainer."
  exit 1
fi

# Create installation directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# Copy binary to installation directory
cp "$BINARY_PATH" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo -e "${GREEN}✓${NC} Installation successful!"

# Check if installation directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo -e "${YELLOW}⚠${NC} The installation directory is not in your PATH."
  echo "Please add the following line to your shell profile:"
  echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
  echo ""
  echo "Then restart your shell or run:"
  echo "  source ~/.bashrc  # or your appropriate shell config file"
else
  echo -e "${GREEN}✓${NC} The CLI tool is now available in your PATH."
fi

echo ""
echo "Run '${BINARY_NAME}' to start using the tool."
