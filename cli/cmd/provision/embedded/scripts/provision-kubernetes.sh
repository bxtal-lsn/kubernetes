#!/bin/bash
# provision-kubernetes.sh - Creates and configures a Kubernetes environment

set -e  # Exit on error

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common-lib.sh"

# Kubernetes VM Names
CONTROL_PLANE="controlplane"
NODE01="node01"
NODE02="node02"
NODE03="node03"

# SSH Key paths
SSH_KEY_NAME="id_rsa_provisioning"
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
SSH_PUB_KEY_PATH="$SSH_KEY_PATH.pub"

# Cloud-init and inventory paths
CLOUD_INIT_TEMPLATE="$SCRIPT_DIR/../multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$SCRIPT_DIR/../multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$SCRIPT_DIR/../ansible/inventories/kubernetes.yml"
DEFAULTS_FILE="$SCRIPT_DIR/../ansible/defaults/kubernetes.yml"

# Default resource values
CP_CPU=2
CP_MEM="2G"
CP_DISK="20G"
WORKER_CPU=2
WORKER_MEM="2G"
WORKER_DISK="20G"

# Load resource values from defaults file if it exists
if [ -f "$DEFAULTS_FILE" ] && command -v python3 >/dev/null && python3 -c "import yaml" 2>/dev/null; then
    echo "Loading VM resource settings from defaults file..."
    # Extract the VM resource values using Python
    RESOURCES=$(python3 -c "
import yaml
try:
    with open('$DEFAULTS_FILE', 'r') as f:
        vars = yaml.safe_load(f)
        cp_cpu = vars.get('control_plane_cpus', 2)
        cp_mem = vars.get('control_plane_memory', '2G')
        cp_disk = vars.get('control_plane_disk', '20G')
        worker_cpu = vars.get('worker_cpus', 2)
        worker_mem = vars.get('worker_memory', '2G')
        worker_disk = vars.get('worker_disk', '20G')
        print(f'{cp_cpu} {cp_mem} {cp_disk} {worker_cpu} {worker_mem} {worker_disk}')
except Exception as e:
    print('2 2G 20G 2 2G 20G')  # Default values if anything fails
")
    read CP_CPU CP_MEM CP_DISK WORKER_CPU WORKER_MEM WORKER_DISK <<< "$RESOURCES"
    
    echo "Control plane resources: $CP_CPU CPUs, $CP_MEM memory, $CP_DISK disk"
    echo "Worker node resources: $WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk"
else
    echo "Using default VM resource settings"
    echo "Control plane resources: $CP_CPU CPUs, $CP_MEM memory, $CP_DISK disk"
    echo "Worker node resources: $WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk"
fi

# Check dependencies
check_dependencies || exit 1

# Ensure SSH key exists
ensure_ssh_key "$SSH_KEY_PATH" || exit 1

# Process cloud-init template
prepare_cloud_init "$CLOUD_INIT_TEMPLATE" "$CLOUD_INIT_PROCESSED" "$SSH_PUB_KEY_PATH" || exit 1

# Check if VMs exist
echo "Checking for existing VMs..."
CP_EXISTS=false
NODE01_EXISTS=false
NODE02_EXISTS=false
NODE03_EXISTS=false

if multipass info "$CONTROL_PLANE" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$CONTROL_PLANE' exists"
    CP_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$CONTROL_PLANE' does not exist"
fi

if multipass info "$NODE01" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE01' exists"
    NODE01_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE01' does not exist"
fi

if multipass info "$NODE02" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE02' exists"
    NODE02_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE02' does not exist"
fi

if multipass info "$NODE03" &>/dev/null; then
    echo -e "${GREEN}✓${NC} VM '$NODE03' exists"
    NODE03_EXISTS=true
else
    echo -e "${YELLOW}⚠${NC} VM '$NODE03' does not exist"
fi

# Create VMs if they don't exist
if [[ "$CP_EXISTS" == "false" || "$NODE01_EXISTS" == "false" || 
      "$NODE02_EXISTS" == "false" || "$NODE03_EXISTS" == "false" ]]; then
    echo "Creating Kubernetes VMs with Multipass..."
    echo "This may take several minutes. Please be patient..."
    
    # Create VMs that don't exist
    if [[ "$CP_EXISTS" == "false" ]]; then
        echo "Creating control plane VM: $CONTROL_PLANE ($CP_CPU CPUs, $CP_MEM memory, $CP_DISK disk)"
        multipass launch --name "$CONTROL_PLANE" --cpus "$CP_CPU" --memory "$CP_MEM" --disk "$CP_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$NODE01_EXISTS" == "false" ]]; then
        echo "Creating worker node VM: $NODE01 ($WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk)"
        multipass launch --name "$NODE01" --cpus "$WORKER_CPU" --memory "$WORKER_MEM" --disk "$WORKER_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$NODE02_EXISTS" == "false" ]]; then
        echo "Creating worker node VM: $NODE02 ($WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk)"
        multipass launch --name "$NODE02" --cpus "$WORKER_CPU" --memory "$WORKER_MEM" --disk "$WORKER_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    if [[ "$NODE03_EXISTS" == "false" ]]; then
        echo "Creating worker node VM: $NODE03 ($WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk)"
        multipass launch --name "$NODE03" --cpus "$WORKER_CPU" --memory "$WORKER_MEM" --disk "$WORKER_DISK" --cloud-init "$CLOUD_INIT_PROCESSED"
    fi
    
    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 15
fi

echo "Extracting IP addresses..."
# Extract IPs
CP_IP=$(multipass info "$CONTROL_PLANE" | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE01_IP=$(multipass info "$NODE01" | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE02_IP=$(multipass info "$NODE02" | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE03_IP=$(multipass info "$NODE03" | grep "IPv4" | head -n 1 | awk '{print $2}')

# Verify IPs were extracted successfully
if [ -z "$CP_IP" ] || [ -z "$NODE01_IP" ] || [ -z "$NODE02_IP" ] || [ -z "$NODE03_IP" ]; then
    echo -e "${RED}✗ Error:${NC} Failed to extract IP addresses from multipass."
    echo "Please verify that VMs are running using 'multipass list'"
    exit 1
fi

# Print the IPs to verify
echo "Control Plane IP: $CP_IP"
echo "Node01 IP: $NODE01_IP"
echo "Node02 IP: $NODE02_IP"
echo "Node03 IP: $NODE03_IP"

echo "Generating Ansible inventory..."
# Create directory for inventory file if it doesn't exist
mkdir -p "$(dirname "$INVENTORY_FILE")"

# Create inventory file
cat > "$INVENTORY_FILE" << EOF
---
all:
  children:
    k8s_cluster:
      children:
        control_plane:
          hosts:
            controlplane:
              ansible_host: $CP_IP
        workers:
          hosts:
            node01:
              ansible_host: $NODE01_IP
            node02:
              ansible_host: $NODE02_IP
            node03:
              ansible_host: $NODE03_IP
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
PLAYBOOK="$SCRIPT_DIR/../ansible/playbooks/kubernetes.yml"
if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${RED}✗ Error:${NC} Ansible playbook not found at $PLAYBOOK"
    exit 1
fi

echo "Running Ansible playbook for Kubernetes deployment..."
echo "This will take some time. Please be patient..."

if ansible-playbook -i "$INVENTORY_FILE" "$PLAYBOOK"; then
    echo -e "${GREEN}✓${NC} Ansible playbook completed successfully"
else
    echo -e "${RED}✗ Error:${NC} Ansible playbook failed"
    exit 1
fi

echo -e "${GREEN}✓${NC} Kubernetes environment setup complete."
echo "Control Plane: $CP_IP"
echo "Workers: $NODE01_IP, $NODE02_IP, $NODE03_IP"
echo ""
echo "To access the cluster, run:"
echo "multipass shell $CONTROL_PLANE"
echo "And then: kubectl get nodes"
