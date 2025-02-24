# Kubernetes Cluster Deployment with Ansible

This repository contains Ansible playbooks to set up a Kubernetes cluster on existing Ubuntu 24.04 VMs.

## Prerequisites

1. Three Ubuntu 24.04 (Noble Numbat) VMs running
2. SSH access to all VMs
3. Ansible installed on your control machine
4. Sudo access configured on all VMs

## Repository Structure

```
kubernetes-ansible/
├── inventory.yml                # Inventory file with VM information
├── main.yml                     # Main playbook with task orchestration
├── tasks/
│   ├── setup-hosts.yml          # Configure /etc/hosts
│   ├── update-dns.yml           # Configure DNS
│   ├── ssh.yml                  # Configure SSH settings
│   ├── setup-kernel.yml         # Configure kernel modules and sysctl
│   ├── node-setup.yml           # Install Kubernetes components
│   ├── control-plane-init.yml   # Initialize control plane
│   └── worker-join.yml          # Join worker nodes to cluster
└── README.md
```

## Configuration Steps

1. Clone this repository:
   ```bash
   git clone <repository-url>
   cd kubernetes-ansible
   ```

2. Install required Ansible collections:
   ```bash
   ansible-galaxy collection install community.general
   ```

3. Edit `inventory.yml` and update the IP addresses of your VMs:
   ```yaml
   controlplane:
     ansible_host: 192.168.1.X   # Replace with your control plane IP
   node01:
     ansible_host: 192.168.1.Y   # Replace with your first worker node IP
   node02:
     ansible_host: 192.168.1.Z   # Replace with your second worker node IP
   ```

4. Update the SSH credentials in the inventory file:
   ```yaml
   vars:
     ansible_user: ubuntu        # Replace with your SSH user
     # Use one of these depending on your authentication method:
     # ansible_ssh_private_key_file: ~/.ssh/id_rsa
     # ansible_ssh_pass: your_password
   ```

## Deployment

You can deploy the entire cluster at once:

```bash
ansible-playbook -i inventory.yml main.yml
```

Or run deployment incrementally using tags:

```bash
# 1. Configure hosts, DNS, SSH, and kernel
ansible-playbook -i inventory.yml main.yml --tags common

# 2. Install Kubernetes components on all nodes
ansible-playbook -i inventory.yml main.yml --tags k8s-setup

# 3. Initialize control plane
ansible-playbook -i inventory.yml main.yml --tags control-plane

# 4. Join worker nodes
ansible-playbook -i inventory.yml main.yml --tags workers
```

## Iterative Testing Approach

To methodically test the deployment step by step:

### 1. Test Basic Connectivity

```bash
# Verify SSH access to all nodes
ansible -i inventory.yml all -m ping
```

### 2. Test Basic System Configuration

```bash
# Apply common configuration to control plane only
ansible-playbook -i inventory.yml main.yml --tags common --limit controlplane

# Verify hosts file configuration
ansible -i inventory.yml controlplane -m command -a "cat /etc/hosts"

# Verify DNS configuration
ansible -i inventory.yml controlplane -m command -a "systemctl status systemd-resolved"
```

### 3. Test Kernel Configuration

```bash
# Verify kernel modules
ansible -i inventory.yml controlplane -m command -a "lsmod | grep -E 'overlay|br_netfilter'"

# Verify sysctl settings
ansible -i inventory.yml controlplane -m command -a "sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward"
```

### 4. Test Kubernetes Components

```bash
# Install Kubernetes components on control plane
ansible-playbook -i inventory.yml main.yml --tags k8s-setup --limit controlplane

# Verify containerd is running
ansible -i inventory.yml controlplane -m command -a "systemctl status containerd"

# Verify Kubernetes binaries
ansible -i inventory.yml controlplane -m command -a "kubectl version --client"
```

### 5. Initialize Control Plane

```bash
# Initialize control plane
ansible-playbook -i inventory.yml main.yml --tags control-plane

# Verify control plane initialization
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"
```

### 6. Join Worker Nodes One by One

```bash
# Join first worker node
ansible-playbook -i inventory.yml main.yml --tags workers --limit node01

# Verify first worker joined
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"

# Join second worker node
ansible-playbook -i inventory.yml main.yml --tags workers --limit node02

# Verify all nodes
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes"
```

### 7. Test Network Plugin

```bash
# Check Flannel pods
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -n kube-system | grep flannel"

# Deploy test application
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf create deployment nginx --image=nginx"
ansible -i inventory.yml controlplane -m command -a "kubectl --kubeconfig=/etc/kubernetes/admin.conf expose deployment nginx --port=80 --type=NodePort"
```

### 8. Debugging Common Issues

If any step fails, try these debugging commands:

```bash
# Check service logs
ansible -i inventory.yml <node> -m command -a "journalctl -xeu <service-name>"

# Example for kubelet
ansible -i inventory.yml node01 -m command -a "journalctl -xeu kubelet"

# Check network connectivity
ansible -i inventory.yml controlplane -m command -a "ping -c 1 {{ hostvars['node01']['ansible_host'] }}"
```

### 9. Reset if Needed

To reset a node and start fresh:

```bash
# Reset kubeadm
ansible -i inventory.yml <node> -m command -a "kubeadm reset -f"

# Clean up directories
ansible -i inventory.yml <node> -m command -a "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube"
```

## Key Components

- **Kernel Configuration**: Sets up required kernel modules (overlay, br_netfilter) and sysctl settings
- **Container Runtime**: Installs and configures containerd with systemd cgroup driver
- **Kubernetes**: Installs kubelet, kubeadm, and kubectl
- **Networking**: Configures Flannel as the CNI plugin with pod CIDR 10.244.0.0/16

## Ubuntu 24.04 Specific Notes

- This playbook has been adjusted for Ubuntu 24.04 (Noble Numbat)
- The containerd installation includes a fallback to the Docker repository if the default package isn't available
- Kernel module loading includes error handling for modules that might be built into the kernel
- DNS configuration is specifically adjusted for systemd-resolved in Ubuntu 24.04

## Validation

After deployment, verify your cluster:

```bash
ssh <your-user>@<controlplane-ip>
kubectl get nodes
```

You should see all nodes in the `Ready` state:

```
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   10m   v1.28.x
node01         Ready    <none>          8m    v1.28.x
node02         Ready    <none>          8m    v1.28.x
```

## Troubleshooting

If nodes don't join the cluster or show issues:

1. Check connectivity between nodes: `ping <node-ip>`
2. Verify firewall allows required ports (6443, 10250)
3. Review logs on problematic nodes: `journalctl -xeu kubelet`
4. Verify DNS resolution: `nslookup controlplane`

## Cleanup

To reset a node and remove Kubernetes:

```bash
sudo kubeadm reset
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni
sudo apt-get autoremove -y
sudo rm -rf ~/.kube /etc/kubernetes /var/lib/kubelet /var/lib/etcd
```
