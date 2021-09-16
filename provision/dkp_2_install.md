# Student Handbook student1-dkp

## Cluster Details

Bootstrap Node:
{aws_instance.registry[0].public_ip}

Control Plane Nodes:

```
    10.0.191.210:
      ansible_host: 18.236.218.207
      node_pool: control
```

Worker Nodes:
```
    10.0.138.182:
      ansible_host: 54.218.246.205
      node_pool: worker
    10.0.77.181:
      ansible_host: 54.185.65.42
      node_pool: worker
    10.0.232.161:
      ansible_host: 54.149.93.234
      node_pool: worker
    10.0.121.171:
      ansible_host: 54.149.134.41
      node_pool: worker
```

Control Plane LoadBalancer:
```
tf-lb-20210916042904750500000006-1922352621.us-west-2.elb.amazonaws.com 
```

ssh-key:
```
student1-dkp
```
## Prepare the Machines

First step is to build the pre-provisioned servers for them to be cluster api compliant

Run the following from the [konvoy-image-builder](https://github.com/mesosphere/konvoy-image-builder) dir

```
cd /home/centos/konvoy-image-builder
./konvoy-image provision --inventory-file /home/centos/provision/inventory.yaml  images/generic/flatcar.yaml #Select a yaml depending on the operating system of the cluster
```

## Deploy DKP Base

Next we deploy DKP base cluster on the servers

> Note: Run these from the directory where DKP binary has been downloaded

```
cd /home/centos
```

First create a bootstrap cluster

```
./dkp create bootstrap
```

Once bootstrap cluster is created add the secret containing the private key to connect to the hosts

```
kubectl create secret generic student1-dkp-ssh-key --from-file=ssh-privatekey=/home/centos/student1-dkp
```

Now, create the pre-provisioned inventory resources

```
kubectl apply -f /home/centos/provision/student1-dkp-preprovisioned_inventory.yaml
```

Create the manifest files for deploying the konvoy to the cluster
> Note: The --os-hint=flatcar flag in the following command is required to indicate that that the os of the instances being deployed to is flatcar

```
./dkp create cluster preprovisioned --cluster-name student1-dkp --control-plane-endpoint-host tf-lb-20210916042904750500000006-1922352621.us-west-2.elb.amazonaws.com --os-hint=flatcar --control-plane-replicas 1 --worker-replicas 4 --dry-run -o yaml > deploy-dkp-student1-dkp.yaml
```

Update all occurances of cloud-provider="" to cloud-provider=aws. This is needed because we will be leveraging aws provider capabilities in this lab for things like services of type LoadBalancer and persistent volumes.

```
sed -i 's/cloud-provider\:\ \"\"/cloud-provider\:\ \"aws\"/' deploy-dkp-student1-dkp.yaml

sed -i 's/konvoy.d2iq.io\/csi\:\ local-volume-provisioner/konvoy.d2iq.io\/csi\:\ aws-ebs/' deploy-dkp-student1-dkp.yaml

sed -i 's/konvoy.d2iq.io\/provider\:\ preprovisioned/konvoy.d2iq.io\/provider\:\ aws/' deploy-dkp-student1-dkp.yaml

```

Finally apply the deploy manifest to the bootstrap cluster to trigger the cluster deployment

```
kubectl apply -f deploy-dkp-student1-dkp.yaml
```

Run the following commands to view the status of the deployment

```
./dkp describe cluster -c student1-dkp
kubectl logs -f -n cappp-system deploy/cappp-controller-manager
```

After 5 minutes or so if there is no critical error in the above, run the following command to get the admin kubeconfig of the provisioned DKP cluster

```
./dkp get kubeconfig -c student1-dkp > admin.conf
chmod 600 admin.conf
```

Now we can connect to the deployed cluster via kubectl.
Set admin.conf as the current KUBECONFIG
> Note: Alternatively use the alias k instead as that is already configured to run kubectl with this config file

```
export KUBECONFIG=$(pwd)/admin.conf
```

Now to do a final check run the following to make sure all the nodes in the DKP cluster are in Ready state

```
kubectl get nodes
```

## Deploy Kommander
Once the base cluster has been deployed, it's ready to deploy addon components to it. We do this using the `kommander-bootstrap` helm chart. Hence, the next step is to deploy this helm chart.

```
export VERSION=v2.0.0
helm repo add kommander https://mesosphere.github.io/kommander/charts
helm repo update
helm install -n kommander --create-namespace kommander-bootstrap kommander/kommander-bootstrap --version=v2.0.0 --set certManager=$(kubectl get ns cert-manager > /dev/null 2>&1 && echo "false" || echo "true")
```

This can take a while to get deployed. So open another shell and run the following commands to watch things come up.
> Note: The helm chart command succeeds much before all the components are deployes as the bulk of them run as a post hook.

```
watch kubectl get pods -A

watch kubectl get helmreleases -A
```

Once the cluster is deployed (i.e. at least the traefik and dex deployments are complete) run the following to get the details of the cluster.
> Note: This is just running a few kubectl commands to get the details from the cluster

```
./get_cluster_details.sh
```
