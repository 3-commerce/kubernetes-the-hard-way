# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/etcd-io/etcd). In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

## Prerequisites

The commands in this lab must be run on each controller instance: `controller-0`, `controller-1`, and `controller-2`. Login to each controller instance using the `gcloud` command. Example:

```
gcloud compute ssh controller-0
```

### Running commands in parallel with tmux

[tmux](https://tmux.github.io/) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](./01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [etcd](https://github.com/etcd-io/etcd) GitHub project:

```
curl --location --remote-name --time-cond etcd-v3.5.9-linux-amd64.tar.gz \
  https://github.com/etcd-io/etcd/releases/download/v3.5.9/etcd-v3.5.9-linux-amd64.tar.gz
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
tar --extract --file etcd-v3.5.9-linux-amd64.tar.gz --verbose

sudo cp etcd-v3.5.9-linux-amd64/etcd* /usr/local/bin/
```

### Configure the etcd Server

```
sudo mkdir --parents /etc/etcd /var/lib/etcd

sudo chmod 0700 /etc/etcd/ /var/lib/etcd/

sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:

```
INTERNAL_IP="$(curl --silent --header 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)"
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:

```
ETCD_NAME="$(hostname --short)"
```

Create the `etcd.service` systemd unit file:

```
sudo mkdir --parents /usr/local/lib/systemd/system

cat <<EOF | sudo tee /usr/local/lib/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/etcd-io/etcd

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file /etc/etcd/kubernetes.pem \\
  --key-file /etc/etcd/kubernetes-key.pem \\
  --peer-cert-file /etc/etcd/kubernetes.pem \\
  --peer-key-file /etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file /etc/etcd/ca.pem \\
  --peer-trusted-ca-file /etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir /var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the etcd Server

```
sudo systemctl enable --now etcd
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## Verification

List the etcd cluster members:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --cacert /etc/etcd/ca.pem \
  --cert /etc/etcd/kubernetes.pem \
  --endpoints https://127.0.0.1:2379 \
  --key /etc/etcd/kubernetes-key.pem
```

> output

```
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379, false
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379, false
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379, false
```

Next: [Bootstrapping the Kubernetes Control Plane](./08-bootstrapping-kubernetes-controllers.md)
