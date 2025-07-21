[all:vars]
ansible_user=${ansible_user}
k3s_server_ip=${k3s_server_ip[0]}

[servers]
${bastion_ip}

[agents]
%{ for ip in private_ips ~}
${ip} ansible_ssh_common_args='-o ProxyJump=${ansible_user}@${bastion_ip}'
%{ endfor ~}
