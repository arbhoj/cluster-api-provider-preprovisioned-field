

terraform -chdir=deploy/infra init

export TF_VAR_tags='{"owner":"abhoj","expiration":"32h"}'
export AWS_REGION=us-west-2
export TF_VAR_node_ami=ami-0e6702240b9797e12
export TF_VAR_ssh_key_name=flatcar-konvoy #created key pair by hand in aws portal and then used ssh-agent to load the key locally
export TF_VAR_ssh_username=core #default user is centos so had to override 
export TF_VAR_create_iam_instance_profile=true
