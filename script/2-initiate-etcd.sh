#!/usr/bin/env bash

ENCRYPTION_KEY="$(head -c 32 /dev/urandom | base64)"

cat > encryption-config.yaml <<EOF
apiVersion: v1
kind: EncryptionConfig
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

curl --location --remote-name --time-cond etcd-v3.5.9-linux-amd64.tar.gz \
  https://github.com/etcd-io/etcd/releases/download/v3.5.9/etcd-v3.5.9-linux-amd64.tar.gz

tar -xzvf etcd-v3.5.9-linux-amd64.tar.gz

cp etcd-v3.5.9-linux-amd64/etcd* /usr/local/bin/

mkdir -p /etc/etcd /var/lib/etcd

chmod 0700 /etc/etcd/ /var/lib/etcd/

cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

INTERNAL_IP="10.240.0.11"
ETCD_NAME="$(hostname --short)"

mkdir -p /usr/local/lib/systemd/system

cat > /usr/local/lib/systemd/system/etcd.service <<EOF
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
  --initial-cluster controller-1=https://10.240.0.9:2380,controller-2=https://10.240.0.10:2380,controller-3=https://${INTERNAL_IP}:2380 \\
  --initial-cluster-state new \\
  --data-dir /var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd.service
systemctl start etcd.service

# Check ETCD

ETCDCTL_API=3 etcdctl member list \
  --cacert /etc/etcd/ca.pem \
  --cert /etc/etcd/kubernetes.pem \
  --endpoints https://127.0.0.1:2379 \
  --key /etc/etcd/kubernetes-key.pem
