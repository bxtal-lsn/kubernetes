# Install kubeadm for Kubernetes version 1.32

## Prerquisites
- A compatible Linux host
- 2 GB or more of RAM per machine
- 2 CPUs or more for control plane machines.
- Full network connectivity between all machines in the cluster (public or private network is fine).
- Unique hostname, MAC address, and product_uuid for every node.
  - Verify the `MAC address` and `product_uuid` are unique for every node 
    You can get the `MAC address` of the network interfaces using the command `ip link` or `ifconfig -a` 
    The `product_uuid `can be checked by using the command `sudo cat /sys/class/dmi/id/product_uuid` 
    It is very likely that hardware devices will have unique addresses, although some virtual machines may have identical values. 
    Kubernetes uses these values to uniquely identify the nodes in the cluster. 
    If these values are not unique to each node, the installation process may fail.
- Certain ports are open on your machines:

### Control plane 

|Protocol|Direction|Port Range|Purpose|Used By|
|---|---|---|---|---|
|TCP|Inbound|6443|Kubernetes API server|All|
|TCP|Inbound|2379-2380|etcd server client API|kube-apiserver, etcd|
|TCP|Inbound|10250|Kubelet API|Self, Control plane|
|TCP|Inbound|10259|kube-scheduler|Self|
|TCP|Inbound|10257|kube-controller-manager|Self|
Although etcd ports are included in control plane section,  
you can also host your own etcd cluster externally or on custom ports.

### Worker node(s)
|Protocol|Direction|Port Range|Purpose|	Used By |
|---|---|---|---|---|
|TCP|Inbound|10250|Kubelet API|Self, Control plane |
|TCP|Inbound|10256|kube-proxy|Self, Load balancers |
|TCP|Inbound|30000-32767|NodePort Services†|All|
† Default port range for NodePort Services.

All default port numbers can be overridden.   
When custom ports are used those ports need to be open instead of defaults mentioned here.

One common example is API server port that is sometimes switched to 443. 
Alternatively, the default port is kept as is and API server is put behind a load balancer that listens on 443 
and routes the requests to API server on the default port.

### Check required ports
These required ports need to be open in order for Kubernetes components to communicate with each other.   
You can use tools like netcat to check if a port is open. For example:  
```bash
nc 127.0.0.1 6443 -v
```
The pod network plugin you use may also require certain ports to be open.  
Since this differs with each pod network plugin,  
please see the documentation for the plugins about what port(s) those need.

## Swap Configuration
The default behavior of a kubelet is to fail to start if swap memory is detected on a node.  
This means that swap should either be disabled or tolerated by kubelet.  

- To tolerate swap, add `failSwapOn:` false to kubelet configuration or as a command line argument. 
  Note: even if `failSwapOn: false` is provided, workloads wouldn't have swap access by default. 
  This can be changed by setting a `swapBehavior`, again in the kubelet configuration file. 
  To use swap, set a `swapBehavior` other than the default `NoSwap ` setting. 

- To disable swap, `sudo swapoff -a` can be used to disable swapping temporarily. 
  To make this change persistent across reboots, make sure swap is disabled in config files like `/etc/fstab`, `systemd.swap`
  depending how it was configured on your system

## Install Container Runtime
Use containerd

Make sure to remove anything docker/container related installations
```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
```

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

```bash
sudo apt-get install containerd.io
```

## Install kubeadm, kubelet, and kubectl
You will install these packages on all of your machines:

- `kubeadm`: the command to bootstrap the cluster.
- `kubelet`: the component that runs on all of the machines in your cluster and does things like starting pods and containers.
- `kubectl`: the command line util to talk to your cluster.

1. Update the apt package index and install packages needed to use the Kubernetes apt repository:

```bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
```

2. Download the public signing key for the Kubernetes package repositories.  
The same signing key is used for all repositories so you can disregard the version in the URL:

```bash
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```
3. Add the appropriate Kubernetes apt repository.  
  Please note that this repository have packages only for Kubernetes 1.32;  
  for other Kubernetes minor versions, you need to change the Kubernetes minor version in the URL to match your desired minor version 
  (you should also check that you are reading the documentation for the version of Kubernetes that you plan to install).

```bash
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
```
4. Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

(Optional) Enable the kubelet service before running kubeadm:
```bash
sudo systemctl enable --now kubelet
```
The kubelet is now restarting every few seconds, as it waits in a crashloop for kubeadm to tell it what to do.
