#!/bin/bash
# provision-rqlite.sh - Creates and configures a rqlite environment with 3 nodes

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# rqlite VM Names
NODE1="rqlite1"
NODE2="rqlite2"
NODE3="rqlite3"

# SSH Key paths
SSH_KEY_NAME="id_rsa_provisioning"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"

# Cloud-init and inventory paths
CLOUD_INIT_TEMPLATE="$SCRIPT_DIR/../multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$SCRIPT_DIR/../multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$SCRIPT_DIR/../ansible/inventories/rqlite.yml"
DEFAULTS_FILE="$SCRIPT_DIR/../ansible/defaults/rqlite.yml"

# Default resource values
NODE_CPU=2
NODE_MEM="2G"
NODE_DISK="10G"

# Load resource values from defaults file if it exists
if [ -f "$DEFAULTS_FILE" ] && command -v python3 >/dev/null && python3 -c "import yaml" 2>/dev/null; then
    echo "Loading VM resource settings from defaults file..."
    # Extract the VM resource values using Python
    RESOURCES=$(python3 -c "
import yaml
try:
    with open('$DEFAULTS_FILE', 'r') as f:
        vars = yaml.safe_load(f)
        node_cpu = vars.get('node_cpus', 2)
        node_mem = vars.get('node_memory', '2G')
        node_disk = vars.get('node_disk', '10G')
        print(f'{node_cpu} {node_mem} {node_disk}')
except Exception as e:
    print('2 2G 10G')  # Default values if anything fails
")
    read NODE_CPU NODE_MEM NODE_DISK <<< "$RESOURCES"
    
    echo "Node resources: $NODE_CPU CPUs, $NODE_MEM memory, $NODE_DISK disk"
else
    echo "Using default VM resource settings"
    echo "Node resources: $NODE_CPU CPUs, $NODE_MEM memory, $NODE_DISK disk"
fi

# Check dependencies
check_dependencies || exit 1

# Ensure SSH key exists
ensure_ssh_key "$SSH_KEY_PATH" || exit 1

# Process cloud-init template
prepare_cloud_init "$CLOUD_INIT_TEMPLATE" "$CLOUD_INIT_PROCESSED" "$SSH_PUB_KEY_PATH" || exit 1

# Check if VMs exist
echo "Checking for existing VMs..."
NODE1_EXISTS=false
NODE2_EXISTS=false
NODE3_EXISTS=false

if multipass info "$NODE1" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE1' exists"
    NODE1_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE1' does not exist"
fi

if multipass info "$NODE2" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE2' exists"
    NODE2_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE2' does not exist"
fi

if multipass info "$NODE3" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE3' exists"
    NODE3_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE3' does not exist"
fi

# Create VMs if they don't exist
if [[ "$NODE1_EXISTS" == "false" || "$NODE2_EXISTS" == "false" || "$NODE3_EXISTS" == "false" ]]; then
    echo "Creating rqlite VMs with Multipass..."
    echo "This may take several minutes. Please be patient..."
    
    # Create VMs that don't exist
    if [[ "$NODE1_EXISTS" == "false" ]]; then
        echo "Creating node VM: $NODE1 ($NODE_CPU CPUs, $NODE_MEM memory, $NODE_DISK disk)"
        multipass launch --name "$NODE1" --cpus "$NODE_CPU" --memory "$NODE_MEM" --disk "$NODE_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$NODE2_EXISTS" == "false" ]]; then
        echo "Creating node VM: $NODE2 ($NODE_CPU CPUs, $NODE_MEM memory, $NODE_DISK disk)"
        multipass launch --name "$NODE2" --cpus "$NODE_CPU" --memory "$NODE_MEM" --disk "$NODE_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$NODE3_EXISTS" == "false" ]]; then
        echo "Creating node VM: $NODE3 ($NODE_CPU CPUs, $NODE_MEM memory, $NODE_DISK disk)"
        multipass launch --name "$NODE3" --cpus "$NODE_CPU" --memory "$NODE_MEM" --disk "$NODE_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 15
fi

echo "Extracting IP addresses..."
# Extract IPs
NODE1_IP=$(multipass info "$NODE1" | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE2_IP=$(multipass info "$NODE2" | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE3_IP=$(multipass info "$NODE3" | grep "IPv4" | head -n 1 | awk '{print $2}')

# Verify IPs were extracted successfully
if [ -z "$NODE1_IP" ] || [ -z "$NODE2_IP" ] || [ -z "$NODE3_IP" ]; then
    echo -e "${RED}✗ Error:${NC} Failed to extract IP addresses from multipass."
    echo "Please verify that VMs are running using 'multipass list'"
    exit 1
fi

# Print the IPs to verify
echo "Node1 IP: $NODE1_IP"
echo "Node2 IP: $NODE2_IP"
echo "Node3 IP: $NODE3_IP"

echo "Generating Ansible inventory..."
# Create directory for inventory file if it doesn't exist
mkdir -p "$(dirname "$INVENTORY_FILE")"

# Create inventory file
cat > "$INVENTORY_FILE" << EOF
---
all:
  children:
    rqlite_cluster:
      children:
        rqlite_leader:
          hosts:
            rqlite1:
              ansible_host: $NODE1_IP
        rqlite_followers:
          hosts:
            rqlite2:
              ansible_host: $NODE2_IP
            rqlite3:
              ansible_host: $NODE3_IP
      vars:
        rqlite_nodes:
          - rqlite1
          - rqlite2
          - rqlite3
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    ansible_ssh_private_key_file: $SSH_KEY_PATH
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

echo -e "${GREEN}✓${NC} Ansible inventory created at $INVENTORY_FILE"

# Verify inventory
echo "Verifying inventory file contents:"
cat "$INVENTORY_FILE"

# Run Ansible playbook
PLAYBOOK="$SCRIPT_DIR/../ansible/playbooks/rqlite.yml"
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}✗ Error:${NC} Ansible playbook not found at $PLAYBOOK"
    exit 1
fi

echo "Running Ansible playbook for rqlite deployment..."
echo "This will take some time. Please be patient..."

if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK"; then
    echo -e "${GREEN}✓${NC} Ansible playbook completed successfully"
else
    echo -e "${RED}✗ Error:${NC} Ansible playbook failed"
    exit 1
fi

echo -e "${GREEN}✓${NC} rqlite environment setup complete."
echo "Leader Node: $NODE1_IP:4001 (HTTP) / $NODE1_IP:4002 (Raft)"
echo "Follower Nodes: $NODE2_IP, $NODE3_IP"
echo ""
echo "To access the rqlite cluster, run:"
echo "rqlite -H $NODE1_IP"
echo ""
echo "Or from inside one of the VMs:"
echo "multipass shell $NODE1"
echo "rqlite"
