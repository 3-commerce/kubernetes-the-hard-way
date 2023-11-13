#!/usr/bin/env bash

mkdir -p /etc/kubernetes/config

curl --location \
  --remote-name --time-cond kube-apiserver https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-apiserver \
  --remote-name --time-cond kube-controller-manager https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-controller-manager \
  --remote-name --time-cond kube-scheduler https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-scheduler \
  --remote-name --time-cond kubectl https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl

install --mode 0755 kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

mkdir --parents /var/lib/kubernetes

cp ca-key.pem ca.pem kubernetes-key.pem kubernetes.pem \
	service-account-key.pem service-account.pem encryption-config.yaml /var/lib/kubernetes

INTERNAL_IP="10.240.0.9"
KUBERNETES_PUBLIC_ADDRESS="35.213.165.254"

mkdir -p /usr/local/lib/systemd/system

cat > /usr/local/lib/systemd/system/kube-apiserver.service <<EOF
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
  --etcd-servers https://10.240.0.9:2379,https://10.240.0.10:2379,https://10.240.0.11:2379 \\
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

systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl start kube-apiserver.service
