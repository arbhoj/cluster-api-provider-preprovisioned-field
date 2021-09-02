
# AWS Cluster Builder for deploying DKP

## Steps 
1. Configure AWS Credentials
2. Set cluster name
```
TF_VAR_cluster_name=$USER-dkp20
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
export TF_VAR_node_ami=ami-0e6702240b9797e12
export TF_VAR_registry_ami=ami-0686851c4e7b1a8e1
export TF_VAR_ssh_username=core #default user is centos 
export TF_VAR_create_iam_instance_profile=true
export TF_VAR_ssh_private_key_file=../$TF_VAR_cluster_name
export TF_VAR_ssh_public_key_file=../$TF_VAR_cluster_name.pub
```
6. Apply terraform

```
terraform -chdir=provision apply -auto-approve
```
This will provision the cluster and provide an output like this:


