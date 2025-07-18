# Bootstrapping the Kubernetes Control Plane

In this lab you will bootstrap the Kubernetes control plane across three compute instances and configure it for high availability. You will also create an external load balancer that exposes the Kubernetes API Servers to remote clients. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

## Prerequisites

The commands in this lab must be run on each controller instance: `controller-0`, `controller-1`, and `controller-2`. Login to each controller instance using the `gcloud` command. Example:

```
gcloud compute ssh controller-0
```

### Running commands in parallel with tmux

[tmux](https://tmux.github.io/) can be used to run commands on multiple compute instances at the same time. See the [Running commands in parallel with tmux](./01-prerequisites.md#running-commands-in-parallel-with-tmux) section in the Prerequisites lab.

## Provision the Kubernetes Control Plane

Create the Kubernetes configuration directory:

```
sudo mkdir --parents /etc/kubernetes/config
```

### Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

```
curl --location \
  --remote-name --time-cond kube-apiserver \
  https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-apiserver \
  --remote-name --time-cond kube-controller-manager \
  https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-controller-manager \
  --remote-name --time-cond kube-scheduler \
  https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-scheduler \
  --remote-name --time-cond kubectl \
  https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl
```

Install the Kubernetes binaries:

```
sudo install --mode 0755 kube-apiserver kube-controller-manager \
  kube-scheduler kubectl /usr/local/bin/
```

### Configure the Kubernetes API Server

```
sudo mkdir --parents /var/lib/kubernetes

sudo cp \
  ca-key.pem ca.pem \
  kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  encryption-config.yaml \
  /var/lib/kubernetes/
```

The instance internal IP address will be used to advertise the API Server to members of the cluster. Retrieve the internal IP address for the current compute instance:

```
INTERNAL_IP="$(curl --silent --header 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)"

REGION="$(curl --silent --header 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/project/attributes/google-compute-default-region)"

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe \
  kubernetes-the-hard-way --region "${REGION}"  --format 'value(address)')
```

Create the `kube-apiserver.service` systemd unit file:

```
sudo mkdir --parents /usr/local/lib/systemd/system

cat <<EOF | sudo tee /usr/local/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address ${INTERNAL_IP} \\
  --allow-privileged \\
  --apiserver-count 3 \\
  --audit-log-maxage 30 \\
  --audit-log-maxbackup 3 \\
  --audit-log-maxsize 100 \\
  --audit-log-path /var/log/audit.log \\
  --authorization-mode Node,RBAC \\
  --bind-address 0.0.0.0 \\
  --client-ca-file /var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile /var/lib/kubernetes/ca.pem \\
  --etcd-certfile /var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile /var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl 1h \\
  --encryption-provider-config /var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority /var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate /var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key /var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config 'api/all=true' \\
  --service-account-key-file /var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file /var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \\
  --service-cluster-ip-range 10.32.0.0/24 \\
  --service-node-port-range 30000-32767 \\
  --tls-cert-file /var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file /var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-preferred-address-types InternalIP,ExternalIP,Hostname \\
  --v 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Controller Manager

Copy the `kube-controller-manager` kubeconfig into place:

```
sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/
```

Create the `kube-controller-manager.service` systemd unit file:

```
cat <<EOF | sudo tee /usr/local/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address 0.0.0.0 \\
  --cluster-cidr 10.200.0.0/16 \\
  --cluster-name kubernetes \\
  --cluster-signing-cert-file /var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file /var/lib/kubernetes/ca-key.pem \\
  --kubeconfig /var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect \\
  --root-ca-file /var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file /var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range 10.32.0.0/24 \\
  --use-service-account-credentials \\
  --v 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Scheduler

Copy the `kube-scheduler` kubeconfig into place:

```
sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/
```

Create the `kube-scheduler.yaml` configuration file:

```
cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/kubernetes/kube-scheduler.kubeconfig
leaderElection:
  leaderElect: true
EOF
```

Create the `kube-scheduler.service` systemd unit file:

```
cat <<EOF | sudo tee /usr/local/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config /etc/kubernetes/config/kube-scheduler.yaml \\
  --v 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Controller Services

```
sudo systemctl enable --now kube-apiserver kube-controller-manager kube-scheduler
```

> Allow up to 10 seconds for the Kubernetes API Server to fully initialize.

### Enable HTTP Health Checks

A [Google Network Load Balancer](https://cloud.google.com/load-balancing/docs/network) will be used to distribute traffic across the three API servers and allow each API server to terminate TLS connections and validate client certificates. The network load balancer only supports HTTP health checks which means the HTTPS endpoint exposed by the API server cannot be used. As a workaround the nginx webserver can be used to proxy HTTP health checks. In this section nginx will be installed and configured to accept HTTP health checks on port `80` and proxy the connections to the API server on `https://127.0.0.1:6443/healthz`.

> The `/healthz` API server endpoint does not require authentication by default.

Install a basic web server to handle HTTP health checks:

```
sudo apt-get install --yes nginx

cat <<EOF | sudo tee /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

sudo ln --symbolic \
  /etc/nginx/sites-available/kubernetes.default.svc.cluster.local \
  /etc/nginx/sites-enabled/

sudo systemctl restart nginx
```

### Verification

```
kubectl cluster-info --kubeconfig admin.kubeconfig
```

> output

```
Kubernetes control plane is running at https://127.0.0.1:6443
```

Test the nginx HTTP health check proxy:

```
curl --header 'Host: kubernetes.default.svc.cluster.local' --include \
  http://127.0.0.1/healthz
```

> output

```
HTTP/1.1 200 OK
Server: nginx/1.18.0 (Ubuntu)
Date: Wed, 26 Jul 2023 13:35:08 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive
Audit-Id: d87ab78c-776b-42f9-950c-42c7b6060e7f
Cache-Control: no-cache, private
X-Content-Type-Options: nosniff
X-Kubernetes-Pf-Flowschema-Uid: bb5f446a-26d9-4f6e-a18f-d40546253482
X-Kubernetes-Pf-Prioritylevel-Uid: 34a0ffbd-2fd0-44b8-b7ab-d9c883cabb34

ok
```

> Remember to run the above commands on each controller node: `controller-0`, `controller-1`, and `controller-2`.

## RBAC for Kubelet Authorization

In this section you will configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

> This tutorial sets the Kubelet `--authorization-mode` flag to `Webhook`. Webhook mode uses the [SubjectAccessReview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access) API to determine authorization.

The commands in this section will effect the entire cluster and only need to be run once from one of the controller nodes.

```
gcloud compute ssh controller-0
```

Create the `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#role-and-clusterrole) with permissions to access the Kubelet API and perform most common tasks associated with managing pods:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig --filename -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

The Kubernetes API Server authenticates to the Kubelet as the `kubernetes` user using the client certificate as defined by the `--kubelet-client-certificate` flag.

Bind the `system:kube-apiserver-to-kubelet` ClusterRole to the `kubernetes` user:

```
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig --filename -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

## The Kubernetes Frontend Load Balancer

In this section you will provision an external load balancer to front the Kubernetes API Servers. The `kubernetes-the-hard-way` static IP address will be attached to the resulting load balancer.

> The compute instances created in this tutorial will not have permission to complete this section. **Run the following commands from the same machine used to create the compute instances**.

### Provision a Network Load Balancer

Create the external load balancer network resources:

```
KUBERNETES_PUBLIC_ADDRESS="$(gcloud compute addresses describe kubernetes-the-hard-way \
  --format 'value(address)')"

gcloud compute http-health-checks create kubernetes \
  --description 'Kubernetes Health Check' \
  --host kubernetes.default.svc.cluster.local \
  --request-path /healthz

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-health-check \
  --allow tcp \
  --network kubernetes-the-hard-way \
  --source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16

gcloud compute target-pools create kubernetes-target-pool \
  --http-health-check kubernetes

gcloud compute target-pools add-instances kubernetes-target-pool \
 --instances controller-0,controller-1,controller-2

gcloud compute forwarding-rules create kubernetes-forwarding-rule \
  --address "${KUBERNETES_PUBLIC_ADDRESS}" \
  --ports 6443 \
  --target-pool kubernetes-target-pool
```

### Verification

> The compute instances created in this tutorial will not have permission to complete this section. **Run the following commands from the same machine used to create the compute instances**.

Retrieve the `kubernetes-the-hard-way` static IP address:

```
KUBERNETES_PUBLIC_ADDRESS="$(gcloud compute addresses describe kubernetes-the-hard-way \
  --format 'value(address)')"
```

Make a HTTP request for the Kubernetes version info:

```
curl --cacert ca.pem "https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version"
```

> output

```
{
  "major": "1",
  "minor": "27",
  "gitVersion": "v1.27.4",
  "gitCommit": "fa3d7990104d7c1f16943a67f11b154b71f6a132",
  "gitTreeState": "clean",
  "buildDate": "2023-07-19T12:14:49Z",
  "goVersion": "go1.20.6",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```

Next: [Bootstrapping the Kubernetes Worker Nodes](./09-bootstrapping-kubernetes-workers.md)
