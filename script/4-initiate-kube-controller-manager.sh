#!/usr/bin/env bash

cp kube-controller-manager.kubeconfig /var/lib/kubernetes/

mkdir -p /usr/local/lib/systemd/system

cat > /usr/local/lib/systemd/system/kube-controller-manager.service <<EOF
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

systemctl daemon-reload
systemctl enable kube-controller-manager.service
systemctl start kube-controller-manager.service
