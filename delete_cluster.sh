##As a convention USERID will be the current dir name
export USERID=${PWD##*/}
export CLUSTER_NAME=$USERID-dka100
echo Are you sure you want to delete the cluster? Enter cluster name $CLUSTER_NAME to confirm deletion:
read CONFIRM
if [[ $CONFIRM == $CLUSTER_NAME ]]; 
then
   echo Deleting Cluster $CLUSTER_NAME
   terraform -chdir=provision/ destroy --auto-approve -var-file ../$USERID.tfvars
else
   echo "Skipping"
fi
