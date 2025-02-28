#!/bin/bash

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# Define VMs to clean up
VM_NAMES=("controlplane" "node01" "node02" "node03")

echo "Checking for multipass..."
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} multipass is not installed. Cannot clean up VMs."
    echo "  Please install Multipass from: https://canonical.com/multipass/install"
    exit 1
fi

echo "The following VMs will be deleted:"
multipass list | grep -E "controlplane|node01|node02|node03" || echo "  No Kubernetes VMs found"

echo -e "${YELLOW}⚠${NC} This will delete all Kubernetes-related VMs (controlplane, node01, node02, node03)."
echo -e "${YELLOW}⚠${NC} All deployments, configurations, and data on these VMs will be lost."
echo "Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Deleting Kubernetes VMs..."
multipass delete "${VM_NAMES[@]}" 2>/dev/null || true
echo -e "${GREEN}✓${NC} VMs deleted"

echo "Purging deleted VMs..."
multipass purge
echo -e "${GREEN}✓${NC} Deleted VMs purged"

echo -e "${GREEN}✓${NC} Cleanup complete."
