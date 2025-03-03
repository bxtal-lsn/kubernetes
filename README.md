# Kubernetes Local Development Environment
Only tested on Ubuntu-24.04 wsl

## Quick Start

```bash
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

### CLI Tool (Recommended)

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

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

[MIT License](LICENSE)
