resource "local_file" "dkp_2_install_md" {
  filename = "dkp_2_install.md"

  depends_on = [aws_instance.registry]

  provisioner "local-exec" {
    command = "chmod 644 dkp_2_install.md"
  }
  content = <<EOF
# Student Handbook ${var.cluster_name}

## Cluster Details

Bootstrap Node:
{aws_instance.registry[0].public_ip}

Control Plane Nodes:

```
%{ for index, cp in aws_instance.control_plane ~}
    ${cp.private_ip}:
%{ endfor ~}
```

Worker Nodes:
```
%{ for index, wk in aws_instance.worker ~}
    ${wk.private_ip}:
%{ endfor ~}
```

Control Plane LoadBalancer:
```
${aws_elb.konvoy_control_plane.dns_name} 
```

ssh-key:
```
${trimprefix(var.ssh_private_key_file, "../")}
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
kubectl create secret generic ${var.cluster_name}-ssh-key --from-file=ssh-privatekey=/home/centos/${trimprefix(var.ssh_private_key_file, "../")}
```

Now, create the pre-provisioned inventory resources

```
kubectl apply -f /home/centos/provision/${var.cluster_name}-preprovisioned_inventory.yaml
```

Create the manifest files for deploying the konvoy to the cluster
> Note: The --os-hint=flatcar flag in the following command is required to indicate that that the os of the instances being deployed to is flatcar

```
./dkp create cluster preprovisioned --cluster-name ${var.cluster_name} --control-plane-endpoint-host ${aws_elb.konvoy_control_plane.dns_name} --os-hint=flatcar --control-plane-replicas 1 --worker-replicas 4 --dry-run -o yaml > deploy-dkp-${var.cluster_name}.yaml
```

Update all occurances of cloud-provider="" to cloud-provider=aws. This is needed because we will be leveraging aws provider capabilities in this lab for things like services of type LoadBalancer and persistent volumes.

```
sed -i 's/cloud-provider\:\ \"\"/cloud-provider\:\ \"aws\"/' deploy-dkp-${var.cluster_name}.yaml

sed -i 's/konvoy.d2iq.io\/csi\:\ local-volume-provisioner/konvoy.d2iq.io\/csi\:\ aws-ebs/' deploy-dkp-${var.cluster_name}.yaml

sed -i 's/konvoy.d2iq.io\/provider\:\ preprovisioned/konvoy.d2iq.io\/provider\:\ aws/' deploy-dkp-student1-dkp.yaml

```

Finally apply the deploy manifest to the bootstrap cluster to trigger the cluster deployment

```
kubectl apply -f deploy-dkp-${var.cluster_name}.yaml
```

Run the following commands to view the status of the deployment

```
./dkp describe cluster -c ${var.cluster_name}
kubectl logs -f -n cappp-system deploy/cappp-controller-manager
```

After 5 minutes or so if there is no critical error in the above, run the following command to get the admin kubeconfig of the provisioned DKP cluster

```
./dkp get kubeconfig -c ${var.cluster_name} > admin.conf
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
export VERSION=${var.kommander_version}
helm repo add kommander https://mesosphere.github.io/kommander/charts
helm repo update
helm install -n kommander --create-namespace kommander-bootstrap kommander/kommander-bootstrap --version=${var.kommander_version} --set certManager=$(kubectl get ns cert-manager > /dev/null 2>&1 && echo "false" || echo "true")
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
EOF
}