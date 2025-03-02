# Infrastructure CLI Tool

A simple interactive CLI tool for managing infrastructure provisioning and cleanup. This tool replaces the existing scripts with a more user-friendly interface while maintaining compatibility with the Ansible playbooks.

## Installation

### Option 1: Quick Install (Linux/macOS)

Run the installation script:

```bash
./install.sh
```

This will install the CLI tool to `~/.local/bin` and provide instructions if you need to update your PATH.

### Option 2: Manual Install

1. Find the appropriate binary for your platform in the `bin` directory:
   - Linux/AMD64: `bin/linux_amd64/provision`
   - Linux/ARM64: `bin/linux_arm64/provision`
   - macOS/AMD64: `bin/darwin_amd64/provision`
   - macOS/ARM64: `bin/darwin_arm64/provision`
   - Windows: `bin/windows_amd64/provision.exe`

2. Copy it to a location in your PATH:
   ```bash
   # Example for Linux/macOS
   cp bin/linux_amd64/provision ~/.local/bin/
   chmod +x ~/.local/bin/provision
   ```

## Usage

Simply run the command to start the interactive CLI:

```bash
provision
```

You'll be guided through a series of prompts to:

1. Choose an operation (provision or cleanup)
2. Select what to provision/cleanup (Kubernetes or PostgreSQL)
3. Configure settings or use defaults
4. Confirm and execute the operation

### Example: Provisioning Kubernetes

```
$ provision

? What would you like to do? provision
? What would you like to provision? Kubernetes Cluster

Current default settings:
Kubernetes Version: 1.28
Pod CIDR: 192.168.0.0/16
Service CIDR: 10.96.0.0/16
CNI Plugin: calico
Control Plane: 2 CPUs, 4G Memory, 20G Disk
Worker Nodes: 2 CPUs, 4G Memory, 20G Disk

? Do you want to use these default settings? Yes
? Do you want to proceed? Yes

Running provisioning script...
```

### Example: Cleaning Up

```
$ provision

? What would you like to do? cleanup
? What would you like to clean up? Kubernetes Cluster
? Are you sure you want to clean up Kubernetes Cluster? Yes

Starting Kubernetes cluster cleanup...
Cleanup completed successfully
```

## Requirements

- Ansible (for provisioning operations)
- Multipass (for VM creation)

## Developing the CLI Tool

If you want to modify or extend the CLI tool:

1. Make changes to the Go code in the `cmd/provision` directory
2. Run the build script to rebuild binaries:
   ```bash
   ./scripts/build-release.sh
   ```
