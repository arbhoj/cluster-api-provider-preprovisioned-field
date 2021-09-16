##As a convention USERID will be the current dir name
export USERID=${PWD##*/}

terraform -chdir=provision apply -auto-approve -var-file ../$USERID.tfvars


