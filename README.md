
# AWS Cluster Builder for deploying DKP

## Steps 
1. Configure AWS Credentials
2. Create ssh key in aws
3. Load key in ssh-agent
```
eval `ssh-agent`
ssh-add path/to/private/key
```
4. Initialize terrafom
```
terraform -chdir=deploy/infra init
```
3. Set environment variables
> Note: Set the owner and expiration tags and the ami image as required. Also update the ssh key file info

```
export TF_VAR_cluster_name=$USER-konvoy
export TF_VAR_tags='{"owner":"abhoj","expiration":"32h"}'
export TF_VAR_node_ami=ami-0e6702240b9797e12
export TF_VAR_ssh_key_name=flatcar-konvoy #created key pair by hand in aws portal and then used ssh-agent to load the key locally
export TF_VAR_ssh_username=core #default user is centos so had to override 
export TF_VAR_create_iam_instance_profile=true
export TF_VAR_ssh_private_key_file=flatcar-konvoy.pem
```
4. Apply terraform

```
terraform -chdir=deploy/infra apply -auto-approve
```
