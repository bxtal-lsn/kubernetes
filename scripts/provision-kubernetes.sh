#!/bin/bash
# provision-kubernetes.sh - Creates and configures a Kubernetes environment

set -e  # Exit on error

# Set variables
CONTROL_PLANE="controlplane"
NODE01="node01"
NODE02="node02"
NODE03="node03"
SSH_KEY_FILE="$(pwd)/multipass/cloud-init/ssh_key.txt"
CLOUD_INIT_TEMPLATE="$(pwd)/multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$(pwd)/multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$(pwd)/ansible/inventories/kubernetes.yml"
DEFAULTS_FILE="$(pwd)/ansible/defaults/kubernetes.yml"

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
    # Default values if we can't load from the defaults file
    CP_CPU=2
    CP_MEM="2G"
    CP_DISK="20G"
    WORKER_CPU=2
    WORKER_MEM="2G"
    WORKER_DISK="20G"
    
    echo "Using default VM resource settings"
    echo "Control plane resources: $CP_CPU CPUs, $CP_MEM memory, $CP_DISK disk"
    echo "Worker node resources: $WORKER_CPU CPUs, $WORKER_MEM memory, $WORKER_DISK disk"
fi

# Check if any VMs already exist
VM_EXISTS=false
if multipass info $CONTROL_PLANE &>/dev/null || \
   multipass info $NODE01 &>/dev/null || \
   multipass info $NODE02 &>/dev/null || \
   multipass info $NODE03 &>/dev/null; then
   VM_EXISTS=true
fi

if [ "$VM_EXISTS" = true ]; then
    echo "Some Kubernetes VMs already exist, proceeding to Ansible configuration..."
else
    # Verify SSH key file exists
    if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "Error: SSH key file not found at $SSH_KEY_FILE"
        echo "Please create this file with your public SSH key."
        exit 1
    fi

    # Read SSH key
    SSH_KEY=$(cat "$SSH_KEY_FILE")

    # Process the cloud-init template and replace the placeholder
    sed "s|\$SSH_PUBLIC_KEY|$SSH_KEY|g" "$CLOUD_INIT_TEMPLATE" > "$CLOUD_INIT_PROCESSED"

    echo "Creating Kubernetes VMs with Multipass..."
    # Control plane gets more resources
    multipass launch --name $CONTROL_PLANE --cpus $CP_CPU --memory $CP_MEM --disk $CP_DISK --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE01 --cpus $WORKER_CPU --memory $WORKER_MEM --disk $WORKER_DISK --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE02 --cpus $WORKER_CPU --memory $WORKER_MEM --disk $WORKER_DISK --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE03 --cpus $WORKER_CPU --memory $WORKER_MEM --disk $WORKER_DISK --cloud-init "$CLOUD_INIT_PROCESSED"

    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 15
fi

echo "Extracting IP addresses..."
# Extract IPs correctly
CP_IP=$(multipass info $CONTROL_PLANE | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE01_IP=$(multipass info $NODE01 | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE02_IP=$(multipass info $NODE02 | grep "IPv4" | head -n 1 | awk '{print $2}')
NODE03_IP=$(multipass info $NODE03 | grep "IPv4" | head -n 1 | awk '{print $2}')

# Print the IPs to verify
echo "Control Plane IP: $CP_IP"
echo "Node01 IP: $NODE01_IP"
echo "Node02 IP: $NODE02_IP"
echo "Node03 IP: $NODE03_IP"

echo "Generating Ansible inventory..."
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
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
EOF

echo "Verifying inventory file contents:"
cat "$INVENTORY_FILE"

echo "Running Ansible playbook for Kubernetes deployment..."
ansible-playbook -i "$INVENTORY_FILE" ansible/playbooks/kubernetes.yml

echo "Kubernetes environment setup complete."
echo "Control Plane: $CP_IP"
echo "Workers: $NODE01_IP, $NODE02_IP, $NODE03_IP"
echo ""
echo "To access the cluster, run:"
echo "multipass shell $CONTROL_PLANE"
echo "And then: kubectl get nodes"
