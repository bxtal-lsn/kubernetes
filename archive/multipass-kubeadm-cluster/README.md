# Install Multipass

```bash
sudo apt update
sudo apt upgrade
sudo snap install multipass
```

To fast-track to build multiple instances from the cloudinit.yaml file run e.g.
```bash
./launch-instances.sh cp1 worker1 worker2 worker3 worker4
```
Then skip ahead to `# Install and Configure Network Plugin 'Calico'` further down in this file

# Launch
## Launch basic instance
```bash
multipass launch --name worker-01
```

## Launch instance with defined resources
```bash
multipass launch --name worker-02 --disk 20G --memory 8G --cpus 2
```

## Launch instance with defined resources and cloudinit
create a yaml file which defines the intial state of the ubuntu instance
for example `cloudinit.yaml`

and run a launch command like this after you have created the subsequent file
```bash
multipass launch --name cp1 --cloud-init cloudinit.yaml --disk 20G --memory 8G --cpus 2
```

```yaml
#cloud-config
package_update: true
package_upgrade: true

write_files:
  - path: /etc/modules-load.d/containerd.conf
    content: |
      overlay
      br_netfilter
  - path: /etc/sysctl.d/99-kubernetes-cri.conf
    content: |
      net.bridge.bridge-nf-call-iptables = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward = 1

runcmd:
  # Disable swap
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab

  # Load necessary modules
  - modprobe overlay
  - modprobe br_netfilter

  # Apply sysctl params
  - sysctl --system

  # Remove conflicting packages
  - for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove -y $pkg; done

  # Install required packages
  - apt-get install -y ca-certificates curl gpg apt-transport-https

  # Add Docker GPG key
  - mkdir -p -m 0755 /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc

  # Add Docker repository
  - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo ${UBUNTU_CODENAME:-$VERSION_CODENAME}) stable" | tee /etc/apt/sources.list.d/docker.list

  # Update package lists
  - apt-get update

  # Install containerd
  - apt-get install -y containerd.io

  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default | tee /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd

  # Add Kubernetes GPG key
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

  # Add Kubernetes repository
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
 
  # Update package lists
  - apt-get update

  # Install kubelet, kubeadm, and kubectl
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl

  # Enable kubelet service
  - systemctl enable --now kubelet

  # pull kubeadm related image
  - sudo kubeadm config images pull
```

When the control plane instance is running, you have to install a network plugin  
from a third party provider.

# Install and Configure Network Plugin 'Calico'

Shell into the control plane instance with `multipass shell <instance-name>` and run

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
watch kubectl get pods -n calico-system
```
Wait until all the pods are up and running.  

Afterwards run 
```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```
It should return something like
```bash
node/<your-hostname> untainted
```

Then taint the control plane to not get any schedules, only the workers
```bash
kubectl taint nodes <control-plane-name-or-ip> node-role.kubernetes.io/control-plane=:NoSchedule
```

Confirm that you have a node running in your cluster
```bash
kubectl get nodes -o wide
```
It should return something like this
```bash
NAME              STATUS   ROLES    AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION    CONTAINER-RUNTIME
<your-hostname>   Ready    master   52m   v1.12.2   10.128.0.28   <none>        Ubuntu 18.04.1 LTS   4.15.0-1023-gcp   docker://18.6.1
```
Perhaps remove the load balancer label from the list of backend servers
```bash
kubectl label nodes --all node.kubernetes.io/exclude-from-external-load-balancers-
```

# Adding Linux Worker Nodes
Run the same `cloudinit.yaml` file as the control plane instance.
For example 
```bash
multipass launch --name worker1 --cloud-init cloudinit.yaml --disk 20G --memory 8G --cpus 2
```
When the instance is ready, shell into the instance with `multipass shell worker1` and run
```bash
sudo kubeadm join --token <token> <control-plane-host>:<control-plane-port> --discovery-token-ca-cert-hash sha256:<hash>
```

[Important]
To get the exact information for the join run
```bash
multipass shell <controlplane-name> 
```
When inside, run
```bash
sudo kubeadm token create --print-join-command
```

The information/token was generated with the kubeadm init command.  
If you need to recover the information, shell into `multipass shell cp1`  
and run 
```bash
# Run this on a control plane node
sudo kubeadm token list
```

If you do not want to shell into the control plane you should be able to run (from dev pc)
```bash
multipass exec cp1 sudo kubeadm token list
```
which should return something like this
```bash
TOKEN                     TTL         EXPIRES                USAGES                   DESCRIPTION               EXTRA GROUPS
evv51i.5p35yitsiva6sjer   23h         2025-02-05T20:52:23Z   authentication,signing   The default bootstrap token generated by 'kubeadm init'.   system:bootstrappers:kubeadm:default-node-token
```

By default, node join tokens expire after 24 hours.  
If you are joining a node to the cluster after the current token has expired, 
you can create a new token by running the following command on the control plane node:
```bash
# Run this on a control plane node
sudo kubeadm token create
```
The output is similar to this:
```bash
5didvk.d09sbcov8ph2amjw
```

If you don't have the value of `--discovery-token-ca-cert-hash`,  
you can get it by running the following commands on the control plane node:

```bash
# Run this on a control plane node
sudo cat /etc/kubernetes/pki/ca.crt | openssl x509 -pubkey  | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```

The output is similar to:
```bash
8cb2de97839780a412b93877f8507ad6c94f73add17d5d7058e91741c9d5ec78
```

The output of the kubeadm join command should look something like:
```bash
[preflight] Running pre-flight checks

... (log output of join workflow) ...

Node join complete:
* Certificate signing request sent to control-plane and response
  received.
* Kubelet informed of new secure connection details.


Run 'kubectl get nodes' on control-plane to see this machine join.
```
A few seconds later, you should notice this node in the output from kubectl get nodes.  
(for example, run kubectl on a control plane node).

[Note]
As the cluster nodes are usually initialized sequentially,  
the CoreDNS Pods are likely to all run on the first control plane node.  
To provide higher availability,  
please rebalance the CoreDNS Pods with 
```bash
kubectl -n kube-system rollout restart deployment coredns 
```
after at least one new node is joined.
