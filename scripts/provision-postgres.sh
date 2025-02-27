#!/bin/bash
# provision-postgres.sh - Creates and configures a PostgreSQL environment

# Set variables
PRIMARY_NAME="pg-primary"
REPLICA1_NAME="pg-replica1"
REPLICA2_NAME="pg-replica2"
LB_NAME="pg-lb"
SSH_KEY_FILE="$(pwd)/multipass/cloud-init/ssh_key.txt"
CLOUD_INIT_TEMPLATE="$(pwd)/multipass/cloud-init/common.yaml"
CLOUD_INIT_PROCESSED="$(pwd)/multipass/cloud-init/common_processed.yaml"
INVENTORY_FILE="$(pwd)/ansible/inventories/postgres.yml"

# Check if any VMs already exist
VM_EXISTS=false
if multipass info $PRIMARY_NAME &>/dev/null || \
   multipass info $REPLICA1_NAME &>/dev/null || \
   multipass info $REPLICA2_NAME &>/dev/null || \
   multipass info $LB_NAME &>/dev/null; then
   VM_EXISTS=true
fi

if [ "$VM_EXISTS" = true ]; then
    echo "Some PostgreSQL VMs already exist, proceeding to Ansible configuration..."
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

    echo "Creating PostgreSQL VMs with Multipass..."
    multipass launch --name $PRIMARY_NAME --cpus 1 --mem 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $REPLICA1_NAME --cpus 1 --mem 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $REPLICA2_NAME --cpus 1 --mem 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"
    multipass launch --name $LB_NAME --cpus 1 --mem 1G --disk 5G --cloud-init "$CLOUD_INIT_PROCESSED"

    # Remove processed file after use
    rm "$CLOUD_INIT_PROCESSED"
    
    # Give VMs a moment to initialize
    echo "Waiting for VMs to initialize..."
    sleep 10
fi

echo "Extracting IP addresses..."
# Extract IPs correctly
PRIMARY_IP=$(multipass info pg-primary | grep "IPv4" | head -n 1 | awk '{print $2}')
REPLICA1_IP=$(multipass info pg-replica1 | grep "IPv4" | head -n 1 | awk '{print $2}')
REPLICA2_IP=$(multipass info pg-replica2 | grep "IPv4" | head -n 1 | awk '{print $2}')
LB_IP=$(multipass info pg-lb | grep "IPv4" | head -n 1 | awk '{print $2}')

# Print the IPs to verify
echo "Primary IP: $PRIMARY_IP"
echo "Replica1 IP: $REPLICA1_IP"
echo "Replica2 IP: $REPLICA2_IP"
echo "Load Balancer IP: $LB_IP"

echo "Generating Ansible inventory..."
# Create inventory file - using a simpler format to avoid issues
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
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "Verifying inventory file contents:"
cat "$INVENTORY_FILE"

echo "Running Ansible playbook..."
ansible-playbook -i "$INVENTORY_FILE" ansible/playbooks/postgres.yml

echo "PostgreSQL environment is ready!"
echo "Primary: $PRIMARY_IP"
echo "Replicas: $REPLICA1_IP, $REPLICA2_IP"
echo "Load Balancer: $LB_IP"
