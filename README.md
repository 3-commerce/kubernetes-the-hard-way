# Kubernetes The Hard Way

This tutorial walks you through setting up Kubernetes the hard way. This guide is not for people looking for a fully automated command to bring up a Kubernetes cluster. If that's you then check out [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine), or the [Getting started](https://kubernetes.io/docs/setup/) section of the Kubernetes documentation.

Kubernetes The Hard Way is optimized for learning, which means taking the long route to ensure you understand each task required to bootstrap a Kubernetes cluster.

> The results of this tutorial should not be viewed as production ready, and may receive limited support from the community, but don't let that stop you from learning!

## Copyright

<a rel="license" href="https://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.

## Target Audience

The target audience for this tutorial is someone planning to support a production Kubernetes cluster and wants to understand how everything fits together.

## Cluster Details

Kubernetes The Hard Way guides you through bootstrapping a highly available Kubernetes cluster with end-to-end encryption between components and RBAC authentication.

* [etcd](https://github.com/etcd-io/etcd) v3.5.9
* [containerd](https://github.com/containerd/containerd) v1.7.3
  * [runc](https://github.com/opencontainers/runc) v1.1.8
  * [cni-plugins](https://github.com/containernetworking/plugins) v1.3.0
* [kubernetes](https://github.com/kubernetes/kubernetes) v1.27.4
* [coredns](https://github.com/coredns/coredns) v1.10.1

## Labs

This tutorial assumes you have access to the [Google Cloud Platform (GCP)](https://cloud.google.com). While GCP is used for basic infrastructure requirements the lessons learned in this tutorial can be applied to other platforms.

* [Prerequisites](./docs/01-prerequisites.md)
* [Installing the Client Tools](./docs/02-client-tools.md)
* [Provisioning Compute Resources](./docs/03-compute-resources.md)
* [Provisioning the CA and Generating TLS Certificates](./docs/04-certificate-authority.md)
* [Generating Kubernetes Configuration Files for Authentication](./docs/05-kubernetes-configuration-files.md)
* [Generating the Data Encryption Config and Key](./docs/06-data-encryption-keys.md)
* [Bootstrapping the etcd Cluster](./docs/07-bootstrapping-etcd.md)
* [Bootstrapping the Kubernetes Control Plane](./docs/08-bootstrapping-kubernetes-controllers.md)
* [Bootstrapping the Kubernetes Worker Nodes](./docs/09-bootstrapping-kubernetes-workers.md)
* [Configuring kubectl for Remote Access](./docs/10-configuring-kubectl.md)
* [Provisioning Pod Network Routes](./docs/11-pod-network-routes.md)
* [Deploying the DNS Cluster Add-on](./docs/12-dns-addon.md)
* [Smoke Test](./docs/13-smoke-test.md)
* [Cleaning Up](./docs/14-cleanup.md)
