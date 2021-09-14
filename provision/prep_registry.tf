resource "null_resource" "custom_ansible_registry_playbook" {
  provisioner "local-exec" {
    command = "sleep 60; ansible-playbook -i ansible-playbook -i inventory_registry.yaml ./../ansible/image_registry_setup.yaml"

 }
  depends_on = [
    local_file.ansible_registry_inventory,
  ]
} 
