resource "local_file" "ansible_inventory" {
  filename = "${var.inventory_path}"

  depends_on = [aws_instance.worker]

  provisioner "local-exec" {
    command = "chmod 644 ${var.inventory_path}"
  }
  content = <<EOF
all:
  vars:
    ansible_python_interpreter: ${var.ansible_python_interpreter}
    ansible_user: ${var.ssh_username}
    ansible_port: 22
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_ssh_key_name: ${var.ssh_private_key_file}
    registry_server: "${aws_instance.registry[0].private_ip}:5000" #Note: Use the private ip of the registry server
hosts:
%{ for index, cp in aws_instance.control_plane ~}
  ${cp.private_ip}:
    ansible_host: ${cp.public_ip}
    node_pool: control
%{ endfor ~}
%{ for index, wk in aws_instance.worker ~}
  ${wk.private_ip}:
    ansible_host: ${wk.public_ip}
    node_pool: worker
%{ endfor ~}
EOF
}


