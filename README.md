# Kubernetes Local Development Environment
Only tested on Ubuntu-24.04 wsl

## Quick Start

```bash
# Please install golang v1.22 or greater before starting
sudo apt install golang

# Option 1: Using CLI tool (recommended)
./cli/build.sh              # build CLI tool in project 
./provision-cli provision     # Run interactive provisioning in project root

# Option 2: Using scripts directly
./scripts/provision-kubernetes.sh   # Create Kubernetes cluster

# Access your cluster
multipass shell controlplane
kubectl get nodes
```

## Overview

This project provides tools to create and manage local Kubernetes development environments using Multipass VMs. It enables you to quickly set up fully functional Kubernetes clusters on your local machine for testing, development, or learning.

## Installation

### Prerequisites

- **Host OS**: Ubuntu 24.04 or WSL Ubuntu 24.04 (scripts have only been tested on these platforms)
- [Multipass](https://canonical.com/multipass/install) - for VM provisioning
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) - for configuration
- SSH tools (OpenSSH client)
- Python 3
- Golang v1.22 or greater (is currently used for building binary)

### CLI Tool (Recommended)

It is currently required to have golang v1.22 or greater to build the provision-cli.
On Ubuntu 24.04 you can just run `sudo apt install golang`
The CLI tool provides a user-friendly interface for managing your environments:

```bash
# build CLI tool
./cli/build.sh

# The installer adds the binary to project root
# Run the tool
./provision-cli provision
```

[CLI Documentation](./cli/README.md) - Detailed CLI usage and development

### Manual Scripts

Alternatively, you can use the scripts directly:

```bash
# Create Kubernetes cluster
./scripts/provision-kubernetes.sh

# Clean up Kubernetes VMs
./scripts/cleanup-kubernetes.sh
```

## Using Your Kubernetes Cluster

After provisioning, you can access your cluster:

```bash
# Connect to control plane node
multipass shell controlplane

# Check cluster status
kubectl get nodes
kubectl get pods -A
```

## Architecture

- **1 Control Plane + 3 Worker Nodes**: Fully functional Kubernetes cluster
- **Calico CNI**: For pod networking (v3.29.1)
- **Local Path Provisioner**: For persistent storage
- **Customizable Resources**: Adjust CPU, memory, and disk in `ansible/defaults/kubernetes.yml`

## Features

- **Production-like Setup**: Mimics real-world cluster structure
- **Local Storage**: Support for PersistentVolumes via Local Path Provisioner
- **Modular Design**: Clean separation of provisioning and configuration
- **Full Automation**: Simple commands to provision, configure, and clean up

## Configuration

Customize the cluster by modifying:

- `ansible/defaults/kubernetes.yml` - Kubernetes and VM settings
- VM resources (CPU, memory, disk)
- Network settings, CNI plugin, and more

## Troubleshooting

If you encounter issues:

1. Check Ansible logs for detailed error messages
2. Verify VM status with `multipass list`
3. For Kubernetes issues, use `kubectl` commands on the control plane
4. Ensure all prerequisites are properly installed
5. **Note**: This project has only been tested on Ubuntu 24.04 and WSL Ubuntu 24.04. Using other operating systems may result in compatibility issues.
6. In case you get an authentication error when running something like `multipass list`

```
list failed: The client is not authenticated with the Multipass service.
Please use 'multipass authenticate' before proceeding.
```

`multipass authenticate`

```
Please enter passphrase: 
authenticate failed: Passphrase is not set. Please `multipass set 
local.passphrase` with a trusted client.
```
`multipass set local.passphrase`

```
Please enter passphrase: 
Please re-enter passphrase: 
set failed: The client is not authenticated with the Multipass service.
Please use 'multipass authenticate' before proceeding.
```

This may not even work when using sudo.

The following workaround should help get out of this situation:

```
cat ~/snap/multipass/current/data/multipass-client-certificate/multipass_cert.pem | sudo tee -a /var/snap/multipass/common/data/multipassd/authenticated-certs/multipass_client_certs.pem > /dev/null
snap restart multipass
```
You may need sudo with this last command: `sudo snap restart multipass.`

At this point, your client should be authenticated with the Multipass service.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

[MIT License](LICENSE)
