#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to check dependencies
check_dependencies() {
    echo "Checking dependencies..."
    
    # Check if multipass is installed
    if command -v multipass &> /dev/null; then
        MULTIPASS_VERSION=$(multipass version | head -n1)
        echo -e "${GREEN}✓${NC} Multipass is installed: $MULTIPASS_VERSION"
    else
        echo -e "${RED}✗ Error:${NC} multipass is not installed."
        echo "  Please install Multipass from the official site:"
        echo "  https://canonical.com/multipass/install"
        return 1
    fi
    
    # Check if ansible is installed
    if command -v ansible-playbook &> /dev/null; then
        ANSIBLE_VERSION=$(ansible --version | head -n1)
        echo -e "${GREEN}✓${NC} Ansible is installed: $ANSIBLE_VERSION"
    else
        echo -e "${RED}✗ Error:${NC} ansible is not installed."
        echo "  Please install Ansible from the official documentation:"
        echo "  https://docs.ansible.com/ansible/latest/installation_guide/index.html"
        return 1
    fi
    
    # Check if ssh-keygen is available
    if command -v ssh-keygen &> /dev/null; then
        SSH_VERSION=$(ssh -V 2>&1)
        echo -e "${GREEN}✓${NC} SSH tools are installed: $SSH_VERSION"
    else
        echo -e "${RED}✗ Error:${NC} ssh-keygen is not available."
        echo "  Please install OpenSSH client tools."
        echo "  For Ubuntu/Debian: sudo apt install openssh-client -y"
        return 1
    fi
    
    # Check for Python3 (needed by Ansible)
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        echo -e "${GREEN}✓${NC} Python3 is installed: $PYTHON_VERSION"
    else
        echo -e "${RED}✗ Error:${NC} python3 is not installed."
        echo "  Python3 is required for Ansible to function properly."
        echo "  For Ubuntu/Debian: sudo apt install python3 -y"
        return 1
    fi
    
    # Verify multipass can run (sometimes requires virtualization support)
    if multipass version &> /dev/null; then
        echo -e "${GREEN}✓${NC} Multipass is functioning correctly"
    else
        echo -e "${RED}✗ Error:${NC} multipass is installed but may not be functioning correctly."
        echo "  Please ensure virtualization is enabled in your BIOS settings."
        echo "  For more information, visit: https://canonical.com/multipass/docs/troubleshooting"
        return 1
    fi
    
    echo -e "${GREEN}✓${NC} All dependencies are satisfied!"
    echo
    return 0
}

# Function to ensure SSH key exists
ensure_ssh_key() {
    local ssh_key_path=$1
    local ssh_pub_key_path="$ssh_key_path.pub"
    
    echo "Checking for provisioning SSH key..."
    
    # Create .ssh directory if it doesn't exist
    if [ ! -d "$HOME/.ssh" ]; then
        echo "Creating .ssh directory..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo -e "${GREEN}✓${NC} Created .ssh directory with secure permissions"
    else
        echo -e "${GREEN}✓${NC} .ssh directory exists"
    fi
    
    # Generate provisioning SSH key if it doesn't exist
    if [ ! -f "$ssh_key_path" ]; then
        echo "Generating new SSH key for provisioning at $ssh_key_path"
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N "" -C "multipass_provisioning_key"
        
        # Verify key generation succeeded
        if [ ! -f "$ssh_key_path" ] || [ ! -f "$ssh_pub_key_path" ]; then
            echo -e "${RED}✗ Error:${NC} SSH key generation failed."
            return 1
        fi
        echo -e "${GREEN}✓${NC} Generated new SSH key for provisioning"
    else
        echo -e "${GREEN}✓${NC} Using existing SSH key at $ssh_key_path"
    fi
    
    # Ensure correct permissions
    chmod 600 "$ssh_key_path"
    chmod 644 "$ssh_pub_key_path"
    echo -e "${GREEN}✓${NC} SSH key permissions set correctly"
    
    echo
    return 0
}

# Function to prepare cloud-init file from template
prepare_cloud_init() {
    local template_path=$1
    local processed_path=$2
    local ssh_pub_key_path=$3
    local ssh_key_dir=$(dirname "$template_path")
    
    echo "Preparing cloud-init configuration..."
    
    # Create directory for cloud-init files if it doesn't exist
    mkdir -p "$ssh_key_dir"
    
    # Copy SSH public key to cloud-init directory
    cp "$ssh_pub_key_path" "$ssh_key_dir/ssh_key.txt"
    echo -e "${GREEN}✓${NC} SSH public key copied to cloud-init directory"
    
    # Read SSH key
    SSH_KEY=$(cat "$ssh_key_dir/ssh_key.txt")
    
    # Process the cloud-init template and replace the placeholder
    sed "s|\$SSH_PUBLIC_KEY|$SSH_KEY|g" "$template_path" > "$processed_path"
    echo -e "${GREEN}✓${NC} Cloud-init file prepared at $processed_path"
    
    return 0
}

# Function to extract IP address from multipass VM
get_vm_ip() {
    local vm_name=$1
    
    # Extract IP using multipass info command
    local ip=$(multipass info "$vm_name" | grep "IPv4" | head -n 1 | awk '{print $2}')
    
    # Verify IP was extracted successfully
    if [ -z "$ip" ]; then
        echo -e "${RED}✗ Error:${NC} Failed to extract IP address for VM: $vm_name"
        return 1
    fi
    
    echo "$ip"
    return 0
}

# Function to check if a VM exists
check_vm_exists() {
    local vm_name=$1
    
    if multipass info "$vm_name" &>/dev/null; then
        echo -e "${GREEN}✓${NC} VM '$vm_name' exists"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} VM '$vm_name' does not exist"
        return 1
    fi
}
