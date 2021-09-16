##As a convention USERID will be the current dir name
export USERID=${PWD##*/}

export CLUSTER_NAME=$USERID-dkp

##Generate ssh keys for the cluster
ssh-keygen -q -t rsa -N '' -f $CLUSTER_NAME <<<y 2>&1 >/dev/null

##Generate tfvars file
cat <<EOF > $USERID.tfvars
tags = {
  "owner" : "$USER",
  "expiration" : "32h"
}
aws_region = "us-east-1"
aws_availability_zones = ["us-east-1c"]
node_ami = "ami-048e383eb95db98c4"
registry_ami = "ami-00e87074e52e6c9f9"
ansible_python_interpreter = "/opt/bin/python"
ssh_username = "core"
create_iam_instance_profile = true
cluster_name = "$CLUSTER_NAME"
ssh_private_key_file = "../$CLUSTER_NAME"
ssh_public_key_file = "../$CLUSTER_NAME.pub"
create_extra_worker_volumes = true
extra_volume_size = 10
EOF

terraform -chdir=provision init
