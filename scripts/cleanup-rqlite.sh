#!/bin/bash

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# Define VMs to clean up
VM_NAMES=("rqlite1" "rqlite2" "rqlite3")
INVENTORY_FILE="$SCRIPT_DIR/../ansible/inventories/rqlite.yml"

echo "Checking for multipass..."
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} multipass is not installed. Cannot clean up VMs."
    echo "  Please install Multipass from: https://canonical.com/multipass/install"
    exit 1
fi

echo "The following VMs will be deleted:"
multipass list | grep -E "rqlite1|rqlite2|rqlite3" || echo "  No rqlite VMs found"

echo -e "${YELLOW}⚠${NC} This will delete all rqlite-related VMs (rqlite1, rqlite2, rqlite3)."
echo -e "${YELLOW}⚠${NC} All configurations and data on these VMs will be lost."
echo "Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Deleting rqlite VMs..."
multipass delete "${VM_NAMES[@]}" 2>/dev/null || true
echo -e "${GREEN}✓${NC} VMs deleted"

echo "Purging deleted VMs..."
multipass purge
echo -e "${GREEN}✓${NC} Deleted VMs purged"

# Remove inventory file if it exists
if [ -f "$INVENTORY_FILE" ]; then
    rm "$INVENTORY_FILE"
    echo -e "${GREEN}✓${NC} Removed inventory file"
fi

echo -e "${GREEN}✓${NC} Cleanup complete."#!/bin/bash

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# Define VMs to clean up
VM_NAMES=("rqlite01" "rqlite02" "rqlite03")

# SSH Key path (needed for Ansible)
SSH_KEY_NAME="id_rsa_provisioning"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"

echo "Checking for multipass..."
if ! command -v multipass &> /dev/null; then
    echo -e "${RED}✗ Error:${NC} multipass is not installed. Cannot clean up VMs."
    echo "  Please install Multipass from: https://canonical.com/multipass/install"
    exit 1
fi

echo "The following VMs will be deleted:"
multipass list | grep -E "rqlite01|rqlite02|rqlite03" || echo "  No rqlite VMs found"

echo -e "${YELLOW}⚠${NC} This will delete all rqlite-related VMs (rqlite01, rqlite02, rqlite03)."
echo -e "${YELLOW}⚠${NC} All configurations and data on these VMs will be lost."
echo "Continue? (y/n)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Check if VMs exist and are running
declare -a RUNNING_VMS=()
for VM in "${VM_NAMES[@]}"; do
    if multipass info "$VM" &>/dev/null; then
        VM_IP=$(multipass info "$VM" | grep "IPv4" | head -n 1 | awk '{print $2}')
        if [ -n "$VM_IP" ]; then
            RUNNING_VMS+=("$VM")
        fi
    fi
done

# Run teardown Ansible playbook if VMs are running
if [ ${#RUNNING_VMS[@]} -gt 0 ]; then
    echo "Running Ansible teardown playbook to clean up rqlite services..."
    
    # Extract IPs
    NODE1_IP=$(multipass info "rqlite01" 2>/dev/null | grep "IPv4" | head -n 1 | awk '{print $2}' || echo "")
    NODE2_IP=$(multipass info "rqlite02" 2>/dev/null | grep "IPv4" | head -n 1 | awk '{print $2}' || echo "")
    NODE3_IP=$(multipass info "rqlite03" 2>/dev/null | grep "IPv4" | head -n 1 | awk '{print $2}' || echo "")
    
    # Only include IPs of running VMs
    NODE_IPS=""
    for IP in "$NODE1_IP" "$NODE2_IP" "$NODE3_IP"; do
        if [ -n "$IP" ]; then
            if [ -z "$NODE_IPS" ]; then
                NODE_IPS="$IP"
            else
                NODE_IPS="$NODE_IPS,$IP"
            fi
        fi
    done
    
    if [ -n "$NODE_IPS" ]; then
        LEADER_IP="$NODE1_IP"
        if [ -z "$LEADER_IP" ] && [ -n "$NODE2_IP" ]; then
            LEADER_IP="$NODE2_IP"
        elif [ -z "$LEADER_IP" ] && [ -n "$NODE3_IP" ]; then
            LEADER_IP="$NODE3_IP"
        fi
        
        if [ -n "$LEADER_IP" ]; then
            ANSIBLE_DIR="$SCRIPT_DIR/../ansible/rqlite/ansible"
            cd "$ANSIBLE_DIR"
            ansible-playbook -i inventory.yml teardown-rqlite.yml -e "node_ips=$NODE_IPS leader_ip=$LEADER_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY_PATH" || true
        fi
    fi
fi

echo "Deleting rqlite VMs..."
multipass delete "${VM_NAMES[@]}" 2>/dev/null || true
echo -e "${GREEN}✓${NC} VMs deleted"

echo "Purging deleted VMs..."
multipass purge
echo -e "${GREEN}✓${NC} Deleted VMs purged"

echo -e "${GREEN}✓${NC} Cleanup complete."
