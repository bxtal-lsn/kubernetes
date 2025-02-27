#!/bin/bash
# provision-kubernetes.sh - Creates and configures a Kubernetes environment

# Set variables
CONTROL_PLANE="controlplane"
NODE01="node01"
NODE02="node02"
NODE03="node03"
SSH_KEY_FILE="$(pwd)/multipass/cloud-init/ssh_key.txt"
CLOUD_INIT_TEMPLATE="$(pwd)/multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$(pwd)/multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$(pwd)/ansible/inventories/kubernetes.yml"

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
    multipass launch --name $CONTROL_PLANE --cpus 2 --memory 2G --disk 20G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE01 --cpus 2 --memory 2G --disk 20G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE02 --cpus 2 --memory 2G --disk 20G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $NODE03 --cpus 2 --memory 2G --disk 20G --cloud-init "$CLOUD_INIT_PROCESSED"

    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 10
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
ansible-playbook -i "$INVENTORY_FILE" kubernetes/main.yml

echo "Kubernetes environment setup complete."
echo "Control Plane: $CP_IP"
echo "Workers: $NODE01_IP, $NODE02_IP, $NODE03_IP"
echo ""
echo "To access the cluster, run:"
echo "multipass shell $CONTROL_PLANE"
echo "And then: kubectl get nodes"
