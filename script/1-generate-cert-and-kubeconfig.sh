#!/usr/bin/env bash

KUBERNETES_PUBLIC_ADDRESS="10.240.0.8,35.213.165.254"
KUBERNETES_PRIVATE_ADDRESS="10.240.0.9,10.240.0.10,10.240.0.11"

fCAcert() {
  echo "########## CREATING CA Cert ##########"

cat > a-ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "87600h"
      }
    }
  }
}
EOF

cat > a-ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "Kubernetes",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ],
  "ca": {
    "expiry": "262980h"
  }
}
EOF

  cfssl gencert -initca a-ca-csr.json | cfssljson -bare ca
}

fADMINcert() {
  echo "########## CREATING Admin Cert ##########"

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "system:masters",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
}

fKUBELETcert() {
  echo "########## CREATING Kubelet Cert ##########"

INSTANCE="worker-2"
EXTERNAL_IP="35.213.169.124"
INTERNAL_IP="10.240.0.13"

cat > ${INSTANCE}-csr.json <<EOF
{
  "CN": "system:node:${INSTANCE}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "system:nodes",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -hostname "${INSTANCE},${EXTERNAL_IP},${INTERNAL_IP}" -profile kubernetes "${INSTANCE}-csr.json" | cfssljson -bare "${INSTANCE}"
}

fCONTROLLERcert() {
  echo "########## CREATING Controller Cert ##########"

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "system:kube-controller-manager",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
}

fKUBEPROXYcert() {
  echo "########## CREATING Kube Proxy Cert ##########"

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "system:node-proxier",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
}

fKUBESCHEDULERcert() {
  echo "########## CREATING Kube Scheduler Cert ##########"

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "system:kube-scheduler",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
}

fKUBEAPISERVERcert() {
  echo "########## CREATING Kube API Server Cert ##########"

KUBERNETES_HOSTNAMES="kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local"

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "Kubernetes",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -hostname=10.32.0.1,${KUBERNETES_PRIVATE_ADDRESS},${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
}

fSERVICEACCOUNTcert() {
  echo "########## CREATING Kube Service Account Cert ##########"
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "Kubernetes",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes service-account-csr.json | cfssljson -bare service-account
}

fCALICOcert() {
  echo "########## CREATING Calico Cert ##########"
cat > calico-csr.json <<EOF
{
  "CN": "calico-cni",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "ID",
      "L": "Central Jakarta",
      "O": "Kubernetes",
      "OU": "K8S THW",
      "ST": "DKI Jakarta"
    }
  ]
}
EOF

  cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=a-ca-config.json -profile=kubernetes calico-csr.json | cfssljson -bare calico
}


fKUBELETconfig() {
  INSTANCE="worker-2"

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority ca.pem \
    --embed-certs \
    --kubeconfig "${INSTANCE}.kubeconfig" \
    --server "https://${KUBERNETES_PUBLIC_ADDRESS}:6443"

  kubectl config set-credentials "system:node:${INSTANCE}" \
    --client-certificate "${INSTANCE}.pem" \
    --client-key "${INSTANCE}-key.pem" \
    --embed-certs \
    --kubeconfig "${INSTANCE}.kubeconfig"

  kubectl config set-context default \
    --cluster "kubernetes-the-hard-way" \
    --kubeconfig "${INSTANCE}.kubeconfig" \
    --user "system:node:${INSTANCE}"

  kubectl config use-context default \
    --kubeconfig "${INSTANCE}.kubeconfig"
}

fKUBEPROXYconfig() {
  kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority ca.pem \
  --embed-certs \
  --kubeconfig kube-proxy.kubeconfig \
  --server "https://${KUBERNETES_PUBLIC_ADDRESS}:6443"

  kubectl config set-credentials system:kube-proxy \
  --client-certificate kube-proxy.pem \
  --client-key kube-proxy-key.pem \
  --embed-certs \
  --kubeconfig kube-proxy.kubeconfig

  kubectl config set-context default \
  --cluster kubernetes-the-hard-way \
  --kubeconfig kube-proxy.kubeconfig \
  --user system:kube-proxy

  kubectl config use-context default \
  --kubeconfig kube-proxy.kubeconfig
}

fCONTROLMANAGERconfig() {
  kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority ca.pem \
  --embed-certs \
  --kubeconfig kube-controller-manager.kubeconfig \
  --server https://127.0.0.1:6443

  kubectl config set-credentials system:kube-controller-manager \
  --client-certificate kube-controller-manager.pem \
  --client-key kube-controller-manager-key.pem \
  --embed-certs \
  --kubeconfig kube-controller-manager.kubeconfig

  kubectl config set-context default \
  --cluster kubernetes-the-hard-way \
  --kubeconfig kube-controller-manager.kubeconfig \
  --user system:kube-controller-manager

  kubectl config use-context default \
  --kubeconfig kube-controller-manager.kubeconfig
}

fKUBESCHEDULERconfig() {
  kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority ca.pem \
  --embed-certs \
  --kubeconfig kube-scheduler.kubeconfig \
  --server https://127.0.0.1:6443

  kubectl config set-credentials system:kube-scheduler \
  --client-certificate kube-scheduler.pem \
  --client-key kube-scheduler-key.pem \
  --embed-certs \
  --kubeconfig kube-scheduler.kubeconfig

  kubectl config set-context default \
  --cluster kubernetes-the-hard-way \
  --kubeconfig kube-scheduler.kubeconfig \
  --user system:kube-scheduler

  kubectl config use-context default \
  --kubeconfig kube-scheduler.kubeconfig
}

fADMINconfig() {
  kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority ca.pem \
  --embed-certs \
  --kubeconfig admin.kubeconfig \
  --server https://127.0.0.1:6443

  kubectl config set-credentials admin \
  --client-certificate admin.pem \
  --client-key admin-key.pem \
  --embed-certs \
  --kubeconfig admin.kubeconfig

  kubectl config set-context default \
  --cluster kubernetes-the-hard-way \
  --kubeconfig admin.kubeconfig \
  --user admin

  kubectl config use-context default \
  --kubeconfig admin.kubeconfig
}

fCALICOconfig() {
  kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority ca.pem \
  --embed-certs \
  --kubeconfig cni.kubeconfig \
  --server https://127.0.0.1:6443

  kubectl config set-credentials calico-cni \
  --client-certificate calico.pem \
  --client-key calico-key.pem \
  --embed-certs \
  --kubeconfig cni.kubeconfig

  kubectl config set-context default \
  --cluster kubernetes-the-hard-way \
  --kubeconfig cni.kubeconfig \
  --user calico-cni

  kubectl config use-context default \
  --kubeconfig cni.kubeconfig
}


# fCAcert
# fADMINcert
# fKUBELETcert
# fCONTROLLERcert
# fKUBEPROXYcert
# fKUBESCHEDULERcert
# fKUBEAPISERVERcert
# fSERVICEACCOUNTcert
# fCALICOcert

# fKUBELETconfig
# fKUBEPROXYconfig
# fCONTROLMANAGERconfig
# fKUBESCHEDULERconfig
# fADMINconfig
# fCALICOconfig
