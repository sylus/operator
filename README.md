# MinIO Operator [![Docker Pulls](https://img.shields.io/docker/pulls/minio/k8s-operator.svg?maxAge=604800)](https://hub.docker.com/r/minio/k8s-operator)

<a href="https://min.io"> <img src=https://raw.githubusercontent.com/minio/minio/master/.github/logo.svg width="600px"/> </a>

MinIO provides Kubernetes-native high performance object storage for private and
public cloud infrastructure (Hybrid Cloud). The MinIO API maintains compatibility
with the S3-API to simplify migration of applications onto MinIO Object Storage.

## Table of Contents

* [Architecture](https://github.com/minio/operator#Architecture)
* [Create a MinIO Tenant](https://github.com/minio/operator#Create-a-MinIO-Tenant)
* [Expand a MinIO Tenant](https://github.com/minio/operator#Expand-a-MinIO-Tenant)
* [Kubernetes Cluster Configuration](https://github.com/minio/operator#Kubernetes-Cluster-Configuration)

# Architecture

Each MinIO Tenant represents an independent MinIO Object Store service within
the Kubernetes cluster. The following diagram describes the architecture of as
MinIO Tenant deployed into Kubernetes:

IMAGE

MinIO provides multiple methods for accessing and managing the MinIO Tenant:

## MinIO Console

The MinIO Console provides a graphical user interface (GUI) for interacting with
MinIO Tenants. 

IMAGE

MinIO Tenant administrators can perform a variety of tasks through the Console,
including user creation, policy configuration, and bucket replication. The
Console also provides a high level view of Tenant health, usage, and healing
status.

For more complete documentation on using the MinIO Console, see the 
[MinIO Console Github Repository](https://github.com/minio/console).

## MinIO Operator and `kubectl` Plugin

The MinIO Operator extends the Kubernetes API to support deploying MinIO-specific
resources as a Tenant in a Kubernetes cluster.

The MinIO `kubectl minio` plugin wraps the Operator to provide a simplified interface
for deploying and managing MinIO Tenants in a Kubernetes cluster through the
`kubectl` command line tool.

# Create a MinIO Tenant

This procedure creates a 4-node MinIO Tenant suitable for evaluation and 
early development using MinIO for object storage.

- MinIO requires Kubernetes version 1.17.0 or later.

- This procedure assumes the cluster contains a 
  [namespace](https://github.com/minio/operator#create-a-namespace) for
  the MinIO Tenant.

- This procedure assumes the cluster contains a
  [`StorageClass`](https://github.com/minio/operator#default-storage-class)
  for the MinIO Tenant Persistent Volume Claims (`PVC`).

## 1) Install the MinIO Operator

### Install using `kubectl krew`

Run the following command to install the MinIO Operator and Plugin using `krew`:

```sh
   kubectl krew update
   kubectl krew install minio
```

Run the following command to initialize the Operator:

```sh
kubectl minio init

```

## 2) Create a New Tenant

The following `kubectl minio` command creates a MinIO Tenant with 4 nodes, 16
volumes, and a total capacity  of 16Ti. This configuration requires
*at least* 16 
[Persistent Volumes](https://github.com/minio/operator#Local-Persistent-Volumes).

```sh
   kubectl minio tenant create \
      --name minio-tenant1
      --servers 4
      --volumes 16
      --capacity 16Ti
      --namespace minio-tenant1
```

- The `--name` field specifies the name of the MinIO Tenant and as the prefix for resources
  deployed as part of the Tenant.

- The `--servers` field indicates the number of `minio` pods to deploy into the cluster.
  The cluster *must* have at least one available Node per `minio` pod. 

- The `--volumes` field indicates the total number of volumes in the Tenant. MinIO
  generates a Persistent Volume Claim (`PVC`) for each volume and evenly distributes
  volumes across each `minio` pod. The example above results in 4 volumes per `minio` pod.

- The `--capacity` field indicates the total capacity of the cluster. MinIO determines the
  amount of storage to request for each `pvc` by dividing the specified capacity by the
  total number of volumes in the server. The example above results in 1Ti requested
  capacity per volume.

- The `--namespace` field indicates the namespace onto which MinIO deploys the Tenant. 
  If omitted, MinIO uses the `Default` namespace.

## 3) Connect to the Tenant

MinIO outputs credentials for connecting to the MinIO Tenant as part of the creation
process:

```sh
MinIO Tenant 'minio-tenant1' created

Username: admin 
Password: abcd1234-abcd-1234-abcd-1234abcd1234

Web interface access: 
	$ kubectl port-forward svc/minio-tenant1-console 9443:9443
	Point browser to https://localhost:9443

Object storage access: 
	$ kubectl port-forward svc/minio 9000:9000
	$ mc alias set tenant1 https://localhost:9000 admin abcd1234-abcd-1234-abcd-1234abcd1234
```

The `kubectl port-forward` command temporarily forwards traffic
from the local host to the MinIO Tenant. 

- The `Web interface access` opens the MinIO Console interface for interacting
  with and managing the MinIO Tenant.

- The `Object storage access` provides both the classic MinIO web interface *and* general 
  API access to the MinIO Object Store.

Applications inside the Kubernetes cluster can access the MinIO Tenant through either the
web interface service (`minio-tenant1-console`) *or* the object storage service
(`miniol`). 

Applications outside of the Kubernetes cluster require the Kubernetes
administrator to expose the service using Kubernetes resources like 
[Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) or a
[Load Balancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer). 

# Expand a MinIO Tenant

MinIO supports expanding an existing MinIO Tenant onto additional hosts and storage.

- MinIO requires Kubernetes version 1.17.0 or later.

- This procedure assumes the cluster contains a 
  [namespace](https://github.com/minio/operator#create-a-namespace) for
  the MinIO Tenant.

- This procedure assumes the cluster contains a
  [`StorageClass`](https://github.com/minio/operator#default-storage-class)
  for the MinIO Tenant Persistent Volume Claims (`PVC`).

The following `kubectl minio` command expands a MinIO Tenant with an additional
4 nodes, 16 volumes, and added capacity of 16Ti. This configuration requires
*at least* 16 [Persistent Volumes](https://github.com/minio/operator#Local-Persistent-Volumes).

```sh

   kubectl minio tenant expand \
      --name minio-tenant1 \
      --servers 4 \
      --volumes 16 \
      --capacity 16Ti

```

- The `--name` field specifies the name of the existing MinIO Tenant to expand.

- The `--servers` field indicates the number of `minio` pods to deploy into the cluster.
  The cluster *must* have at least one available Node per `minio` pod. 

- The `--volumes` field indicates the total number of volumes in the Tenant. MinIO
  generates a Persistent Volume Claim (`PVC`) for each volume and evenly distributes
  volumes across each `minio` pod. The example above results in 4 volumes per `minio` pod.

- The `--capacity` field indicates the total capacity of the cluster. MinIO determines the
  amount of storage to request for each `pvc` by dividing the specified capacity by the
  total number of volumes in the server. The example above results in 1Ti requested
  capacity per volume.


# Kubernetes Cluster Configuration

## Default Storage Class

The MinIO Kubernetes Plugin (`kubectl minio`) automatically generates
Persistent Volume Claims (`PVC`) as part of deploying a MinIO Tenant. 
The plugin defaults to creating each `PVC` with the `local-storage`
storage class.

The following 
[`Storage Class`](https://kubernetes.io/docs/concepts/storage/storage-classes/) 
object contains the appropriate fields for use with the MinIO Plugin:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

The `StorageClass` *must* have `volumeBindingMode` set to `WaitForFirstConsumer`.

## Local Persistent Volumes

MinIO automatically creates Persistent Volume Claims (PVC) as part of Tenant creation.
Ensure the cluster at least one 
[Persistent Volume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
for each PVC MinIO requests.

You can estimate the number of PVC by multiplying the number of nodes in the 
Tenant by the number of drives per node. For example, a 4-node Tenant with
4 drives per node requires 16 PVC and therefore 16 PV.

MinIO *strongly recommends* using locally-attached storage for each PV for
object storage performance. MinIO recommends the following CSI drivers for
creating local PV:

- [Local Persistent Volume](https://kubernetes.io/docs/concepts/storage/volumes/#local)
- [OpenEBS Local PV](https://docs.openebs.io/docs/next/localpv.html)

## Create a Namespace

MinIO supports no more than *one* MinIO Tenant per Namespace. The following
`kubectl` command creates a new namespace for the MinIO Tenant.

```sh
kubectl create namespace minio-tenant1
```

# License

Use of MinIO Operator is governed by the GNU AGPLv3 or later, found in the [LICENSE](./LICENSE) file.

# Explore Further

- [Create a MinIO Tenant](https://github.com/minio/operator#create-a-minio-instance).
- [TLS for MinIO Tenant](https://github.com/minio/operator/blob/master/docs/tls.md).
- [Examples for MinIO Tenant Settings](https://github.com/minio/operator/blob/master/docs/examples.md)
- [Custom Hostname Discovery](https://github.com/minio/operator/blob/master/docs/custom-name-templates.md).
- [Apply PodSecurityPolicy](https://github.com/minio/operator/blob/master/docs/pod-security-policy.md).
- [Deploy MinIO Tenant with Console](https://github.com/minio/operator/blob/master/docs/console.md).
- [Deploy MinIO Tenant with KES](https://github.com/minio/operator/blob/master/docs/kes.md).
