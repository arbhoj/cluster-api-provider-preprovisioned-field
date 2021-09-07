
# Deploy DKP on pre-provisioned AWS Infrastructure

## Deploy Infrastructure 
1. Configure AWS Credentials
2. Set cluster name
```
export USERID=$USER
export TF_VAR_cluster_name=$USERID-dkp20
```
3. Generate key pair with the same name as the cluster
```
ssh-keygen -q -t rsa -N '' -f $TF_VAR_cluster_name <<<y 2>&1 >/dev/null
```
4. Initialize terrafom
```
terraform -chdir=provision init
```
5. Set environment variables
> Note: Set the owner and expiration tags and the ami images as required.

```
export TF_VAR_tags='{"owner":"abhoj","expiration":"32h"}'
export TF_VAR_aws_region="us-east-1"
export TF_VAR_aws_availability_zones='["us-east-1b"]' # We currently only support one subnet and one az to keep things simple
export TF_VAR_node_ami=ami-0e6702240b9797e12
export TF_VAR_registry_ami=ami-0686851c4e7b1a8e1
export TF_VAR_ssh_username=core #default user is centos 
export TF_VAR_create_iam_instance_profile=true
export TF_VAR_ssh_private_key_file=../$TF_VAR_cluster_name
export TF_VAR_ssh_public_key_file=../$TF_VAR_cluster_name.pub
```

6. Load ssh private key into ssh-agent

```
eval `ssh-agent`
ssh-add $TF_VAR_cluster_name
```

7. Apply terraform

```
terraform -chdir=provision apply -auto-approve
```

This will provision the cluster and provide an output like this:
```
control_plane_public_ips = [
  "52.12.47.139",
  "34.219.172.160",
  "54.218.104.166",
]
kube_apiserver_address = "tf-lb-20210902024015538800000001-534661084.us-west-2.elb.amazonaws.com"
registry_ip = [
  "18.237.199.174",
]
worker_public_ips = [
  "54.185.70.218",
  "54.203.84.24",
  "35.163.32.229",
  "52.34.221.5",
]
```

## Configure Infrastructure and Prepare to run konvoy-image-builer
 
###  Build inventory files
  > Note: We will automate these soon but for now just create them manually using the values from terraform output
          
 We are currenty creating two independent inventory files 
 1. inventory.yaml that will be used for the actual cluster and also the konvoy-image-builder
 2. inventory_registry.yaml that is just used for setting registry up. Made sense to keep this separate as we want to keep the same inventory for konvoy-image-builder
 
 Examples:
 inventory.yaml (same format as that used by konvoy-image-builder)
```
all:
  vars:
    ansible_user: core
    ansible_ssh_key_name: ./arvindbhoj-dkp20
    ansible_python_interpreter: /opt/bin/python #Note: This is just for flatcar. The default /usr/bin/python should work for rhel/centos
    python_path: /opt/bin/builder-env/site-packages #Note: This is just for flatcar. The default /usr/lib64/python2.7/site-packages should work for rhel/centos
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
  hosts:
    52.12.47.139:
    34.219.172.160:
    54.218.104.166:
    54.185.70.218:
    54.203.84.24:
    35.163.32.229:
    52.34.221.5:

```

  inventory_registry.yaml

```
all:
  vars:
    ansible_user: centos
    ansible_ssh_key_name: ./arvindbhoj-dkp20
registry:
  hosts:
    18.237.199.174:
```

### Run playbook to configure Image Registry 

This playbook will:
- Intall required packages like docker, wget etc. on the registry server
- Configure docker to be run without sudo
- Generate self signed certs for the registry container
- Start the registry container 
> Once the process to push DKP images to the registry server is more refined we will include that option as well

```
ansible-playbook -i inventory_registry.yaml ansible/image_registry_setup.yaml
```

### Run playbook to configure disks for localvolumes
This playbook will configure and mount the disks to be used by the localvolumeprovisioner

```
ansible-playbook -i inventory_registry.yaml ansible/configure_disks.yaml
```

Push images to the registry. Note: Currently only Kommander images are packaged

> Note: Do this on the registry server
```
export VERSION=v2.0.0
wget "https://downloads.mesosphere.com/kommander/airgapped/${VERSION}/kommander_image_bundle_${VERSION}_linux_amd64.tar" -O kommander-image-bundle.tar

export REGISTRY_URL=<REGISTRY_SERVER_PRIVATE_IP>:5000
export AIRGAPPED_TAR_FILE=kommander-image-bundle.tar
```

Create and execute the following script

```
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly AIRGAPPED_TAR_FILE=${AIRGAPPED_TAR_FILE:-"kommander-image-bundle.tar"}
readonly REGISTRY_URL=${REGISTRY_URL?"Need to set REGISTRY_URL. E.g: 10.23.45.67:5000"}

docker load <"${AIRGAPPED_TAR_FILE}"

while read -r IMAGE; do
    echo "Processing ${IMAGE}"
    REGISTRY_IMAGE="$(echo "${IMAGE}" | sed -E "s/^(quay|gcr|ghcr|docker).io/${REGISTRY_URL}/")"
    docker tag "${IMAGE}" "${REGISTRY_IMAGE}"
    docker push "${REGISTRY_IMAGE}"
done < <(tar xfO "${AIRGAPPED_TAR_FILE}" "index.json" | grep -oP '(?<="io.containerd.image.name":").*?(?=",)')

```

### Run konvoy-image-builder
This will setup the cluster nodes with all the required packages

Sample run command leveraging the inventory file created in the last section and getting everything setup (e.g. containerd service, kubelet service etc.) for clusterapi to deploy against flatcar

```
 ./konvoy-image provision --inventory-file ../cluster-api-provider-preprovisioned-field/inventory.yaml  images/generic/flatcar.yaml 
```

[Link for konvoy-image-builder](https://github.com/mesosphere/konvoy-image-builder)


### Run playbook to configure registry mirrors in containerd 

> Note: There are several ways to configure registry mirrors including setting it in clusterapi resource including KubeadmControlPlane resource. Use this if more control is required or if there is a need to set it outside of the kubeadm process


```
ansible-playbook -i inventory.yaml ansible/update_containerd.yaml
```

## Setup Bootstrap Cluster
This step will configure the bootstrap KIND cluster to deploy konvoy. 
- Download the latest dkp package and extract in a directory
 
  [DKP Releases](https://github.com/mesosphere/konvoy2/releases)

- Run the bootstrap cluster create command

```
./dkp create bootstrap
```

## Deploy DKP

1. Export Environment Variables

> Note: Replace the IPs with the Public IPs from the Deploy Infrastraucture step
```
export CLUSTER_NAME=$TF_VAR_cluster_name
export CONTROL_PLANE_1_ADDRESS="18.236.239.93"
export WORKER_1_ADDRESS="54.190.241.83"
export WORKER_2_ADDRESS="54.190.114.122"
export WORKER_3_ADDRESS="18.236.232.157"
export WORKER_4_ADDRESS="34.221.29.40"
export LOAD_BALANCER="tf-lb-20210830230135201100000001-537345892.us-west-2.elb.amazonaws.com"
export SSH_USER="core" #or centos if deploying on centos/rhel
export SSH_PRIVATE_KEY_SECRET_NAME="$TF_VAR_cluster_name-ssh-key"
```

2. Create a secret in the KIND cluster containing ssh key to connect to the nodes

> Note: Use the private key generated in the first step

```
kubectl create secret generic $CLUSTER_NAME-ssh-key --from-file=ssh-privatekey=<path-to-ssh-private-key>
``` 

3. Create the preprovisioned inventory file and apply to the KIND cluster

```
cat <<EOF > preprovisioned_inventory.yaml
---
apiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1
kind: PreprovisionedInventory
metadata:
  name: $CLUSTER_NAME-control-plane
  labels:
    cluster.x-k8s.io/cluster-name: $CLUSTER_NAME
spec:
  hosts:
    # Create as many of these as needed to match your infrastructure
    - address: $CONTROL_PLANE_1_ADDRESS
    - address: $CONTROL_PLANE_2_ADDRESS
    - address: $CONTROL_PLANE_3_ADDRESS
  sshConfig:
    port: 22
    # This is the username used to connect to your infrastructure. This user must be root or
    # have the ability to use sudo without a password
    user: $SSH_USER
    privateKeyRef:
      # This is the name of the secret you created in the previous step. It must exist in the same
      # namespace as this inventory object.
      name: $SSH_PRIVATE_KEY_SECRET_NAME
      namespace: default
---
apiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1
kind: PreprovisionedInventory
metadata:
  name: $CLUSTER_NAME-md-0
spec:
  hosts:
    - address: $WORKER_1_ADDRESS
    - address: $WORKER_2_ADDRESS
    - address: $WORKER_3_ADDRESS
    - address: $WORKER_4_ADDRESS
  sshConfig:
    port: 22
    user: $SSH_USER
    privateKeyRef:
      name: $SSH_PRIVATE_KEY_SECRET_NAME
      namespace: default
EOF

kubectl apply -f preprovisioned_inventory.yaml
```

4. Generate the manifest file that contains the dkp cluster deployment spec

Sample run with a hint --os-hint=flag required to deploy to flatcar
```
./dkp create cluster preprovisioned --cluster-name ${CLUSTER_NAME} --control-plane-endpoint-host $LOAD_BALANCER --os-hint=flatcar --control-plane-replicas 1 --worker-replicas 4 --dry-run -o yaml > deploy-dkp.yaml
```

5. Update the generated manifest file to set cloud-provider to aws


```

```

6. Deploy DKP Base Cluster

Deploy DKP Base Cluster by applying the following to the KIND cluster
```
kubectl apply -f deploy-dkp.yaml
```

Watch the status and make sure there are no errors

```
./dkp describe cluster -c $CLUSTER_NAME

kubectl logs -f -n cappp-system deploy/cappp-controller-manager

```

Get DKP cluster's kubeconfig file

```
./dkp get kubeconfig -c $CLUSTER_NAME > admin.conf
```

7. Deploy Kommander 
Once the base cluser is ready deploy Kommander

Set the DKP cluster's kubeconfig file retrieved in the last step as the current kubeconfig

```
export KUBECONFIG=./admin.conf
```

Deploy awsebscsiprovisioner helm chart if not using localvolumeprovisioner (which is deployed by default in a preprovisioned cluster and set as the default storage class).

Sample values.yaml for 
```
cat <<EOF > awsebscsiprovisioner_values.yaml
---
resizer:
  enabled: true
snapshotter:
  enabled: true
provisioner:
  enableVolumeScheduling: true
storageclass:
  isDefault: true
  reclaimPolicy: Delete
  volumeBindingMode: WaitForFirstConsumer
  type: gp2
  fstype: ext4
  iopsPerGB: null
  encrypted: false
  kmsKeyId: null
  allowedTopologies: []
  # - matchLabelExpressions:
  #   - key: topology.ebs.csi.aws.com/zone
  #     values:
  #     - us-west-2a
  #     - us-west-2b
  #     - us-west-2c
  allowVolumeExpansion: true
# replicas of the CSI-Controller
replicas: 1
statefulSetCSIController:
# if you want to use kube2iam or kiam roles define it here as podAnnotation for the CSI-Controller (statefulSet)
  podAnnotations: {}
statefulSetCSISnapshotController:
  # if you want to use kube2iam or kiam roles define it here as podAnnotation for the CSI-Snapshot-Controller (statefulSet)
  podAnnotations: {}
# Extra volume tags to attach to each dynamically provisioned volume.
# ---
# extraVolumeTags:
#   key1: value1
#   key2: value2
extraVolumeTags: {}
EOF

```
Run the following to deploy the helm chart
```
helm repo add d2iq-stable https://mesosphere.github.io/charts/stable  
helm repo update
helm install awsebscsiprovisioner d2iq-stable/awsebscsiprovisioner --values awsebscsiprovisioner_values.yaml 
```
Unset localvolumeprovisioner as the defult storage class if not using it
```
kubectl patch sc localvolumeprovisioner -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

Download the kommander image
```
export VERSION=v2.0.0
wget "https://mesosphere.github.io/kommander/charts/kommander-bootstrap-${VERSION}.tgz"
```
Set values.yaml for Kommander Helm Chart
Kommander is deployed using a helm chart so the first thing we need to do is configure the values.yaml for it.

> Note: Remove the airgapped section if not using a local registry. 
```
export GOARCH=amd64
export CERT_MANAGER=$(kubectl get ns cert-manager > /dev/null 2>&1 && echo "false" || echo "true")
cat <<EOF > values-airgapped.yaml
airgapped:
  enabled: true
  helmMirror:
    image:
      tag: ${VERSION}-${GOARCH}
certManager: ${CERT_MANAGER}
authorizedlister:
  image:
    tag: ${VERSION}-${GOARCH}
webhook:
  image:
    tag: ${VERSION}-${GOARCH}
bootstrapper:
  containers:
    manager:
      image:
        tag: ${VERSION}-${GOARCH}
controller:
  containers:
    manager:
      image:
        tag: ${VERSION}-${GOARCH}
fluxOperator:
  containers:
    manager:
      image:
        tag: ${VERSION}-${GOARCH}
gitrepository:
  image:
    tag: ${VERSION}-${GOARCH}
appmanagement:
  containers:
    manager:
      image:
        repository: mesosphere/kommander2-appmanagement
        tag: ${VERSION}-${GOARCH}

EOF

```

Deploy kommander helm chart

```
helm install -n kommander --create-namespace kommander-bootstrap kommander-bootstrap-${VERSION}.tgz --values values-airgapped.yaml

```

Watch all the pods get deployed

```
watch kubectl get pods -n kommander
```

Once the chart is deployed it will display details on getting the kommander portal endpoint and login information

ENJOY!!!
