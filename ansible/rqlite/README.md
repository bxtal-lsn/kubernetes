# Rqlite

Go to `https://github.com/rqlite/rqlite/releases`
This presupposes you use `Rqlite v8.36.11`
The service user you use is `ubuntu`

```bash
version="v8.36.11"
curl -L https://github.com/rqlite/rqlite/releases/download/"$version"/rqlite-"$version"-linux-amd64.tar.gz -o rqlite-"$version"-linux-amd64.tar.gz
tar xvfz rqlite-"$version"-linux-amd64.tar.gz
cd rqlite-"$version"-linux-amd64
sudo cp  rq* /usr/local/bin/
cd
rm -r rqlite-"$version"-linux-amd64.tar.gz rqlite-"$version"-linux-amd64
```

Create a service for initial leader node at `sudo vim /etc/systemd/system/rqlited.service`
```conf
[Unit]
Description=rqlite distributed SQLite node
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/local/bin/rqlited -node-id <1, 2, 3, etc> -http-addr <machine-id>:4001 -raft-addr <machine-id>:4002 /home/ubuntu/data
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```


Create a service for joining nodes at `sudo vim /etc/systemd/system/rqlited.service`
```conf
[Unit]
Description=rqlite distributed SQLite node
After=network.target

[Service]
Type=simple
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/local/bin/rqlited -node-id <1, 2, 3, etc> -http-addr <machine-id>:4001 -raft-addr <machine-id>:4002 -join <initial-machine-ip>:4002 /home/ubuntu/data
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```


Prepare directory and permissions
```bash
mkdir -p /home/ubuntu/data

sudo chown -R ubuntu:ubuntu /home/ubuntu/data
```

start and enable service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now rqlited
```

check status
```bash
sudo systemctl status rqlited
```


from your dev machine which has access to all machines (or one of the nodes) run
```bash
# On any node
rqlite -H <any-node-ip>
```


