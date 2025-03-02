# Infrastructure CLI Tool

A user-friendly CLI tool for provisioning and managing infrastructure components, with a focus on Kubernetes clusters.

## Installation

> **Important**: This tool has only been tested on Ubuntu 24.04 and WSL Ubuntu 24.04. There is no guarantee it will work on other operating systems.

### Quick Install (Ubuntu)

```bash
./install.sh
```

This installs the CLI tool to `~/.local/bin` and provides PATH configuration instructions if needed.

### Manual Install

Find the appropriate binary for your platform in the `bin` directory:

```bash
# Example for Linux/AMD64
cp bin/linux_amd64/provision ~/.local/bin/
chmod +x ~/.local/bin/provision
```

Available binaries:
- Linux: `bin/linux_amd64/provision` or `bin/linux_arm64/provision`
- macOS: `bin/darwin_amd64/provision` or `bin/darwin_arm64/provision`
- Windows: `bin/windows_amd64/provision.exe`

## Usage

Run the command to start the interactive CLI:

```bash
provision
```

The tool will guide you through:
1. Choosing an operation (provision or cleanup)
2. Selecting what to provision/cleanup (Kubernetes or PostgreSQL)
3. Configuring settings or using defaults
4. Confirming and executing the operation

### Example: Provision Kubernetes

```
$ provision

? What would you like to do? provision
? What would you like to provision? Kubernetes Cluster

Current default settings:
Kubernetes Version: 1.32
Pod CIDR: 192.168.0.0/16
Service CIDR: 10.96.0.0/16
CNI Plugin: calico
Control Plane: 4 CPUs, 8G Memory, 40G Disk
Worker Nodes: 4 CPUs, 8G Memory, 40G Disk

? Do you want to use these default settings? Yes
? Do you want to proceed? Yes

Running provisioning script...
```

### Example: Clean Up

```
$ provision

? What would you like to do? cleanup
? What would you like to clean up? Kubernetes Cluster
? Are you sure you want to clean up Kubernetes Cluster? Yes

Starting Kubernetes cluster cleanup...
Cleanup completed successfully
```

## Requirements

- **Host OS**: Ubuntu 24.04 or WSL Ubuntu 24.04 (tool has only been tested on these platforms)
- Ansible (for provisioning operations)
- Multipass (for VM creation)
- SSH client tools

## Development

### Project Structure

- `cmd/provision/` - Main CLI code
  - `cmd/` - Command definitions using Cobra
  - `kubernetes/` - Kubernetes-specific functionality
  - `interactive/` - User interaction utilities
  - `ansible/` - Ansible wrapper functions
  - `config/` - Configuration management

### Building the CLI

To modify or extend the CLI tool:

1. Make changes to the Go code
2. Build binaries for all platforms:
   ```bash
   ./scripts/build-release.sh
   ```

### Adding New Commands

1. Create a new command file in `cmd/provision/cmd/`
2. Register the command in `cmd/provision/cmd/root.go`
3. Implement the command functionality

### Testing

Run the tests with:

```bash
cd cli
go test ./...
```
