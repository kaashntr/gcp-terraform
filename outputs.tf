output "public_ip" {
  value = google_compute_address.public_instance_static_ip.address
}
output "private_instance_ips" {
  description = "Internal IPs of private instances"
  value = [
    for instance in module.private_instance.instances_details :
    instance.network_interface[0].network_ip
  ]
}


