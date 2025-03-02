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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Determine if we're running from the cli directory or from the repo root
if [[ "$(basename "$SCRIPT_DIR")" == "cli" ]]; then
  # Running from cli directory
  BIN_DIR="$SCRIPT_DIR/bin"
else
  # Check if we have a cli subdirectory, which suggests we're in the repo root
  if [[ -d "$SCRIPT_DIR/cli" ]]; then
    BIN_DIR="$SCRIPT_DIR/cli/bin"
  else
    echo -e "${RED}✗ Error:${NC} Cannot determine the correct path to the binary."
    echo "This script should be run either:"
    echo "  1. From the repository root as ./cli/install.sh"
    echo "  2. From the cli directory as ./install.sh"
    exit 1
  fi
fi

BINARY_PATH="$BIN_DIR/${OS}_${GOARCH}/${BINARY_NAME}"
INSTALL_DIR="$HOME/.local/bin"

echo "Installing infrastructure CLI tool..."
echo "Looking for binary at: $BINARY_PATH"

# Ensure .local directory exists
mkdir -p "$HOME/.local"

# Check and fix .local/bin directory ownership if needed
if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -m 755 -p "$INSTALL_DIR"
  echo -e "${GREEN}✓${NC} Created bin directory with secure permissions"
elif [ "$(stat -c '%U' "$INSTALL_DIR" 2>/dev/null)" != "$USER" ]; then
  echo -e "${YELLOW}⚠${NC} Fixing directory ownership..."
  if command -v sudo >/dev/null; then
    sudo chown -R "$USER:$USER" "$INSTALL_DIR"
  else
    echo -e "${RED}✗ Error:${NC} Cannot fix directory ownership. sudo not available."
    exit 1
  fi
fi

# Check if the binary exists for this platform
if [ ! -f "$BINARY_PATH" ]; then
  echo -e "${RED}✗ Error:${NC} Binary not found for your platform: ${OS}_${GOARCH}"
  echo "Path checked: $BINARY_PATH"
  echo ""
  echo "Possible solutions:"
  echo "  1. Make sure you're running this script from the correct directory:"
  echo "     - From the repository root: ./cli/install.sh"
  echo "     - From the cli directory: ./install.sh"
  echo ""
  echo "  2. If the binary doesn't exist, you may need to build it:"
  echo "     cd cli"
  echo "     go build -o bin/${OS}_${GOARCH}/${BINARY_NAME} ./cmd/provision"
  echo ""
  echo "  3. Check if your OS/architecture (${OS}_${GOARCH}) is supported"
  exit 1
fi

# Try copying the binary
if cp "$BINARY_PATH" "$INSTALL_DIR/$BINARY_NAME"; then
  chmod 755 "$INSTALL_DIR/$BINARY_NAME"
  echo -e "${GREEN}✓${NC} Installation successful!"
else
  echo -e "${RED}✗ Error:${NC} Failed to copy binary. Check directory permissions."
  echo "Current .local/bin permissions:"
  ls -ld "$INSTALL_DIR"
  exit 1
fi

# Check if .local/bin is in PATH
if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
  echo -e "${GREEN}✓${NC} .local/bin is already in your PATH."
else
  echo -e "${YELLOW}⚠${NC} The installation directory is not in your PATH."
  echo "Please add the following line to your shell profile:"
  echo "  export PATH=\"\$PATH:$INSTALL_DIR\""
  echo ""
  echo "Then restart your shell or run:"
  echo "  source ~/.bashrc  # or your appropriate shell config file"
fi

echo ""
echo "Run '${BINARY_NAME}' to start using the tool."
