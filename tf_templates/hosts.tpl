[netcoreapp]
${node_ip_addresses}

[all:vars]
ansible_user=${ansible_user}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'