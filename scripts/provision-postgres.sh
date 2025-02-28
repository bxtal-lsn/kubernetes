#!/bin/bash

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# PostgreSQL VM Names
PRIMARY_NAME="pg-primary"
REPLICA1_NAME="pg-replica1"
REPLICA2_NAME="pg-replica2"
LB_NAME="pg-lb"

# SSH Key paths
SSH_KEY_NAME="id_rsa_provisioning"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"

# Cloud-init and inventory paths
CLOUD_INIT_TEMPLATE="$SCRIPT_DIR/../multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$SCRIPT_DIR/../multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$SCRIPT_DIR/../ansible/inventories/postgres.yml"

# Check dependencies
check_dependencies || exit 1

# Ensure SSH key exists
ensure_ssh_key "$SSH_KEY_PATH" || exit 1

# Process cloud-init template
prepare_cloud_init "$CLOUD_INIT_TEMPLATE" "$CLOUD_INIT_PROCESSED" "$SSH_PUB_KEY_PATH" || exit 1

# Check if VMs already exist
PRIMARY_EXISTS=$(check_vm_exists "$PRIMARY_NAME" && echo "true" || echo "false")
REPLICA1_EXISTS=$(check_vm_exists "$REPLICA1_NAME" && echo "true" || echo "false")
REPLICA2_EXISTS=$(check_vm_exists "$REPLICA2_NAME" && echo "true" || echo "false")
LB_EXISTS=$(check_vm_exists "$LB_NAME" && echo "true" || echo "false")

# Create VMs if they don't exist
if [[ "$PRIMARY_EXISTS" == "false" || "$REPLICA1_EXISTS" == "false" || 
      "$REPLICA2_EXISTS" == "false" || "$LB_EXISTS" == "false" ]]; then
    echo "Creating PostgreSQL VMs with Multipass..."
    
    # Create VMs that don't exist
    if [[ "$PRIMARY_EXISTS" == "false" ]]; then
        echo "Creating VM: $PRIMARY_NAME (1 CPU, 1G memory, 5G disk)"
        multipass launch --name "$PRIMARY_NAME" --cpus 1 --memory 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$REPLICA1_EXISTS" == "false" ]]; then
        echo "Creating VM: $REPLICA1_NAME (1 CPU, 1G memory, 5G disk)"
        multipass launch --name "$REPLICA1_NAME" --cpus 1 --memory 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$REPLICA2_EXISTS" == "false" ]]; then
        echo "Creating VM: $REPLICA2_NAME (1 CPU, 1G memory, 5G disk)"
        multipass launch --name "$REPLICA2_NAME" --cpus 1 --memory 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$LB_EXISTS" == "false" ]]; then
        echo "Creating VM: $LB_NAME (1 CPU, 1G memory, 5G disk)"
        multipass launch --name "$LB_NAME" --cpus 1 --memory 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 10
fi

echo "Extracting IP addresses..."
# Extract IPs
PRIMARY_IP=$(get_vm_ip "$PRIMARY_NAME") || exit 1
REPLICA1_IP=$(get_vm_ip "$REPLICA1_NAME") || exit 1
REPLICA2_IP=$(get_vm_ip "$REPLICA2_NAME") || exit 1
LB_IP=$(get_vm_ip "$LB_NAME") || exit 1

# Print the IPs to verify
echo "Primary IP: $PRIMARY_IP"
echo "Replica1 IP: $REPLICA1_IP"
echo "Replica2 IP: $REPLICA2_IP"
echo "Load Balancer IP: $LB_IP"

echo "Generating Ansible inventory..."
# Create directory for inventory file if it doesn't exist
mkdir -p "$(dirname "$INVENTORY_FILE")"

# Create inventory file
cat > "$INVENTORY_FILE" << EOF
[postgres_primary]
pg-primary ansible_host=$PRIMARY_IP

[postgres_replicas]
pg-replica1 ansible_host=$REPLICA1_IP
pg-replica2 ansible_host=$REPLICA2_IP

[postgres_lb]
pg-lb ansible_host=$LB_IP

[postgres:children]
postgres_primary
postgres_replicas
postgres_lb

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$SSH_KEY_PATH
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo -e "${GREEN}✓${NC} Ansible inventory created at $INVENTORY_FILE"

# Verify inventory
echo "Verifying inventory file contents:"
cat "$INVENTORY_FILE"

# Run Ansible playbook
PLAYBOOK="$SCRIPT_DIR/../ansible/playbooks/postgres.yml"
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}✗ Error:${NC} Ansible playbook not found at $PLAYBOOK"
    exit 1
fi

echo "Running Ansible playbook..."
if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK"; then
    echo -e "${GREEN}✓${NC} Ansible playbook completed successfully"
else
    echo -e "${RED}✗ Error:${NC} Ansible playbook failed"
    exit 1
fi

echo -e "${GREEN}✓${NC} PostgreSQL environment is ready!"
echo "Primary: $PRIMARY_IP"
echo "Replicas: $REPLICA1_IP, $REPLICA2_IP"
