# Installation
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

---

# Cheat Sheet
## **1. Images (Pull, List, Remove)**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Pull an image | `docker pull busybox` | `sudo ctr images pull docker.io/library/busybox:latest` |
| List images | `docker images` | `sudo ctr images list` |
| Remove an image | `docker rmi busybox` | `sudo ctr images rm docker.io/library/busybox:latest` |

---

## **2. Containers (Run, List, Stop, Remove)**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Run a container (interactive) | `docker run -it busybox sh` | `sudo ctr run --rm --tty docker.io/library/busybox:latest my-container sh` |
| Run a container (detached) | `docker run -d busybox` | `sudo ctr run -d --tty docker.io/library/busybox:latest my-container sh` |
| List running containers | `docker ps` | `sudo ctr tasks ls` |
| Stop a running container | `docker stop my-container` | `sudo ctr tasks kill my-container` |
| Remove a stopped container | `docker rm my-container` | `sudo ctr containers delete my-container` |

---

## **3. Container Execution (Attach, Exec, Logs)**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Attach to a running container | `docker attach my-container` | `sudo ctr tasks exec --tty my-container sh` |
| Execute a command inside a container | `docker exec -it my-container sh` | `sudo ctr tasks exec --tty my-container sh` |
| View container logs | `docker logs my-container` | **Not directly available in `ctr`** (use `crictl logs <container-id>` if using Kubernetes) |

---

## **4. Container Lifecycle Management**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Restart a container | `docker restart my-container` | `sudo ctr tasks kill -s SIGTERM my-container && sudo ctr run -d --tty docker.io/library/busybox:latest my-container sh` |
| Pause a container | `docker pause my-container` | **Not directly supported** |
| Unpause a container | `docker unpause my-container` | **Not directly supported** |

---

## **5. Volumes & Networking**
Unlike Docker, `containerd` does **not** manage networking or volumes directly. You need to use **CNI (Container Network Interface)** for networking and manually mount host volumes when running a container.

For example, in Docker:
```sh
docker run -v /host/path:/container/path busybox
```
In `containerd`, you must specify the mount manually:
```sh
sudo ctr run --mount type=bind,src=/host/path,dst=/container/path,options=rbind:rw docker.io/library/busybox:latest my-container sh
```

---

## **6. Checking System Info**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Show system info | `docker info` | `sudo ctr version && sudo ctr plugins ls` |

---

## **7. Removing Everything (Clean Up)**
| Action | Docker | containerd (`ctr`) |
|--------|--------|------------------|
| Remove all stopped containers | `docker container prune` | `sudo ctr containers list -q | xargs -r sudo ctr containers delete` |
| Remove all images | `docker image prune -a` | `sudo ctr images list -q | xargs -r sudo ctr images rm` |

---

### **Summary**
- `ctr` is more **low-level** than Docker, so it lacks built-in networking, volume management, and logging.
- You must manually handle networking using **CNI**.
- For Kubernetes workloads, you usually use `crictl` instead of `ctr`.
- `containerd` focuses purely on running containers; it does not replace Docker Compose or Swarm.

