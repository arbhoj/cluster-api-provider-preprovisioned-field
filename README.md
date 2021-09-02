
# AWS Cluster Builder for deploying DKP

## Steps 
1. Configure AWS Credentials
2. Set cluster name
```
export TF_VAR_cluster_name=$USER-dkp20
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
export TF_VAR_aws_availability_zones=["us-east-1a"]
export TF_VAR_node_ami=ami-0e6702240b9797e12
export TF_VAR_registry_ami=ami-0686851c4e7b1a8e1
export TF_VAR_ssh_username=core #default user is centos 
export TF_VAR_create_iam_instance_profile=true
export TF_VAR_ssh_private_key_file=../$TF_VAR_cluster_name
export TF_VAR_ssh_public_key_file=../$TF_VAR_cluster_name.pub
```

6. 

eval `ssh-agent`
ssh-add $TF_VAR_cluster_name

7. Apply terraform

```
terraform -chdir=provision apply -auto-approve
```
This will provision the cluster and provide an output like this:

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
