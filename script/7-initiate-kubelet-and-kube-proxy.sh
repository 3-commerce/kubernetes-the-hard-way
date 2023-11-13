#!/usr/bin/env bash

apt update

apt install -y conntrack ipset socat

swapon --show

swapoff --all

curl --location \
  --remote-name --time-cond containerd-1.7.3-linux-amd64.tar.gz https://github.com/containerd/containerd/releases/download/v1.7.3/containerd-1.7.3-linux-amd64.tar.gz \
  --remote-name --time-cond containerd.service https://raw.githubusercontent.com/containerd/containerd/v1.7.3/containerd.service \
  --output runc --time-cond runc https://github.com/opencontainers/runc/releases/download/v1.1.8/runc.amd64 \
  --remote-name --time-cond cni-plugins-linux-amd64-v1.3.0.tgz https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz \
  --remote-name --time-cond crictl-v1.27.1-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.1/crictl-v1.27.1-linux-amd64.tar.gz \
  --remote-name --time-cond kube-proxy https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kube-proxy \
  --remote-name --time-cond kubectl https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubectl \
  --remote-name --time-cond kubelet https://dl.k8s.io/release/v1.27.4/bin/linux/amd64/kubelet

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kube-proxy \
  /var/lib/kubelet \
  /var/lib/kubernetes \
  /var/run/kubernetes

tar -xzvf containerd-1.7.3-linux-amd64.tar.gz --directory /usr/local/

mkdir -p /usr/local/lib/systemd/system

cp containerd.service /usr/local/lib/systemd/system/

install --mode 0755 runc /usr/local/sbin/

tar -xzvf crictl-v1.27.1-linux-amd64.tar.gz

tar -xzvf cni-plugins-linux-amd64-v1.3.0.tgz --directory /opt/cni/bin/

install --mode 0755 crictl kube-proxy kubectl kubelet /usr/local/bin/

POD_CIDR="10.200.12.0/24"
CLUSTER_CIDR="10.200.0.0/16"

cat > /etc/cni/net.d/10-containerd-net.conflist <<EOF
{
 "cniVersion": "1.0.0",
 "name": "containerd-net",
 "plugins": [
   {
     "type": "bridge",
     "bridge": "cni0",
     "isGateway": true,
     "ipMasq": true,
     "promiscMode": true,
     "ipam": {
       "type": "host-local",
       "ranges": [
         [{
           "subnet": "${POD_CIDR}"
         }]
       ],
       "routes": [
         { "dst": "0.0.0.0/0" }
       ]
     }
   },
   {
     "type": "portmap",
     "capabilities": {"portMappings": true},
     "externalSetMarkChain": "KUBE-MARK-MASQ"
   }
 ]
}
EOF

mkdir -p /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml

cp "${HOSTNAME}-key.pem" "${HOSTNAME}.pem" /var/lib/kubelet/

cp "${HOSTNAME}.kubeconfig" /var/lib/kubelet/kubeconfig

cp ca.pem /var/lib/kubernetes/

cat > /var/lib/kubelet/kubelet-config.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

cat > /usr/local/lib/systemd/system/kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config /var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint unix:///var/run/containerd/containerd.sock \\
  --kubeconfig /var/lib/kubelet/kubeconfig \\
  --register-node \\
  --v 2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cp kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

cat > /var/lib/kube-proxy/kube-proxy-config.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

cat > /usr/local/lib/systemd/system/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config /var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable containerd.service
systemctl start containerd.service

systemctl enable kubelet.service
systemctl start kubelet.service

systemctl enable kube-proxy.service
systemctl start kube-proxy.service

