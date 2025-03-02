# Kubernetes Local Development Environment

## Overview

This project provides automation scripts to create and manage local Kubernetes development environments using Multipass VMs. It enables developers to quickly set up fully functional Kubernetes clusters for testing, development, and learning purposes on their local machines.

## Features

- **Kubernetes Cluster**: Automated setup of a multi-node Kubernetes cluster with one control plane and multiple worker nodes
- **Modular Design**: Clean separation of provisioning, configuration, and application deployment
- **Local Storage**: Integration with Rancher's Local Path Provisioner for persistent storage
- **Minimal Requirements**: Runs on your local machine using lightweight Multipass VMs
- **Full Automation**: Simple commands to provision, configure, and clean up environments
- **Production-like Setup**: Mirrors real-world configurations for realistic testing

## Prerequisites

- [Multipass](https://canonical.com/multipass/install) - for VM provisioning
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) - for configuration automation
- SSH tools (OpenSSH client)
- Python 3 (required by Ansible)

## Getting Started

### Setting Up Kubernetes Cluster

```bash
# Create and provision a Kubernetes cluster
./scripts/provision-kubernetes.sh

# To access the cluster
multipass shell controlplane
kubectl get nodes
```

### Cleaning Up

```bash
# Remove Kubernetes VMs
./scripts/cleanup-kubernetes.sh
```

## Architecture

### Kubernetes Environment

- **Control Plane (controlplane)**: Manages the Kubernetes cluster
- **Worker Nodes (node01, node02, node03)**: Run your containerized applications
- **Networking**: Configured with Calico CNI plugin (v3.29.1)
- **Storage**: Local Path Provisioner for development persistent volumes

## Configuration

Customize cluster settings by modifying:

- `ansible/defaults/kubernetes.yml` - for Kubernetes configurations
- VM resources are configurable (CPU, memory, disk)
- Network settings, DNS, and more can be adjusted

## Technical Details

The project uses Ansible for configuration management with a modular structure:

- **Playbooks**: Orchestrate the entire setup process
- **Tasks**: Modular, reusable configuration steps
- **Inventories**: Automatically generated during provisioning

Kubernetes setup includes:
- Container runtime (containerd) configuration
- Kubernetes components (kubelet, kubeadm, kubectl)
- CNI networking (Calico v3.29.1)
- Storage provisioning (Rancher Local Path Provisioner)
- Comprehensive validation and testing

## Troubleshooting

If you encounter issues:

1. Check the Ansible logs for detailed error messages
2. Verify VM status with `multipass list`
3. Ensure all prerequisites are properly installed
4. For Kubernetes-specific issues, shell into the control plane and use `kubectl` to investigate
