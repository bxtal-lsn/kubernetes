# Infrastructure Development Environment

## Quick Start

```bash
# Option 1: Using CLI tool (recommended)
./cli/install.sh          # Install the CLI tool
provision                 # Run interactive provisioning

# Option 2: Using scripts directly
./scripts/provision-kubernetes.sh   # Create Kubernetes cluster
./scripts/provision-rqlite.sh       # Create rqlite cluster

# Access your Kubernetes cluster
multipass shell controlplane
kubectl get nodes

# Access your rqlite cluster
rqlite -H <rqlite1-ip>
```

## Overview

This project provides tools to create and manage local development environments using Multipass VMs. It enables you to quickly set up fully functional infrastructure for testing, development, or learning, including:

- Kubernetes clusters
- rqlite distributed SQLite clusters

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
# Install CLI tool
./cli/install.sh

# The installer adds the binary to ~/.local/bin
# Make sure this is in your PATH
export PATH="$PATH:$HOME/.local/bin"

# Run the tool
provision
```

[CLI Documentation](./cli/README.md) - Detailed CLI usage and development

### Manual Scripts

Alternatively, you can use the scripts directly:

```bash
# Create Kubernetes cluster
./scripts/provision-kubernetes.sh

# Create rqlite cluster
./scripts/provision-rqlite.sh

# Clean up Kubernetes VMs
./scripts/cleanup-kubernetes.sh

# Clean up rqlite VMs
./scripts/cleanup-rqlite.sh
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

## Using Your rqlite Cluster

After provisioning, you can access your rqlite cluster:

```bash
# Install rqlite client locally (if needed)
# Go to https://github.com/rqlite/rqlite/releases to download

# Connect to the cluster (replace with your leader node IP)
rqlite -H <rqlite1-ip>

# Or connect to a node directly
multipass shell rqlite1
rqlite
```

### rqlite Architecture

- **3-Node Cluster**: Distributed SQLite database with leader-follower replication
- **Leader-Follower Model**: Node 1 is the leader, nodes 2 and 3 are followers
- **Default Ports**: HTTP API on port 4001, Raft consensus on port 4002

## Architecture

### Kubernetes Cluster
- **1 Control Plane + 3 Worker Nodes**: Fully functional Kubernetes cluster
- **Calico CNI**: For pod networking (v3.29.1)
- **Local Path Provisioner**: For persistent storage

### rqlite Cluster
- **3 Node Cluster**: Distributed SQLite database
- **Leader-Follower Replication**: Raft consensus protocol
- **HTTP API**: RESTful interface for database operations

## Features

- **Production-like Setup**: Mimics real-world infrastructure
- **Local Storage**: Support for persistent data
- **Modular Design**: Clean separation of provisioning and configuration
- **Full Automation**: Simple commands to provision, configure, and clean up

## Configuration

Customize the environments by modifying:

- `ansible/defaults/kubernetes.yml` - Kubernetes and VM settings
- `ansible/defaults/rqlite.yml` - rqlite and VM settings

## Troubleshooting

If you encounter issues:

1. Check Ansible logs for detailed error messages
2. Verify VM status with `multipass list`
3. Ensure all prerequisites are properly installed
4. **Note**: This project has only been tested on Ubuntu 24.04 and WSL Ubuntu 24.04. Using other operating systems may result in compatibility issues.

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

[MIT License](LICENSE)
