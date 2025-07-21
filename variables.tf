variable "project_id" {
  description = "GCP project ID"
  type = string
}
variable "region" {
  description = "GCP region"
  type = string
}
variable "service_account" {
  description = "SA for compute instances"
  type = string
}
variable "google_apis_to_enable" {
  description = "List of API to enable"
  type = list(string)
}
variable "api_disable_on_destroy" {
  description = "API disable on destroy option switch"
  type = bool
  default = false
}
variable "vpc_name" {
  description = "Name of google VPC"
  type = string
}
variable "routing_mode" {
  description = "Routing mode GLOBAL or REGIONAL"
  type = string
}
variable "router_name" {
  description = "NAT router name"
  type = string
}
variable "nat_gw_name" {
  description = "Name of NAT gateway"
  type = string
}
variable "zone" {
  description = "Zone for instance"
  type = string
}
variable "public_instances_num" {
  description = "Public instances number"
  type = number
  default = 1
}
variable "private_instances_num" {
  description = "Private instances number"
  type = number
  default = 2
}
variable "public_instance_hostname" {
  description = "Public instances hostname"
  type = string
}
variable "private_instance_hostname" {
  description = "Public instances hostname"
  type = string
}
variable "deletion_protection" {
  description = "Delete protection"
  type = bool
}
variable "public_network_tier" {
  description = "Network tier"
  type = string
}
variable "private_network_tier" {
  description = "Network tier"
  type = string
}
variable "master_scopes_list" {
  description = "List of OAuth scopes strings for instance template"
  type = list(string)
}
variable "worker_scopes_list" {
  description = "List of OAuth scopes strings for instance template"
  type = list(string)
}
variable "ingress_tcp_allow_ports" {
  description = "TCP ports to allow"
  type = list(string)
}
variable "ingress_udp_allow_ports" {
  description = "UDP ports to allow"
  type = list(string)
}
variable "source_image_family" {
  description = "Source image family"
  type = string
}
variable "source_image_project" {
  description = "Source image project"
  type = string
}
variable "disk_size" {
  description = "Size of disk for vms (in GB)"
  type = number
}
variable "ssh_user" {
  description = "User which will be used to connect to vms"
  type = string
}
variable "ssh_private_key_dest" {
  description = "Destination for ssh privet key"
  type = string
}
variable "machine_type" {
  description = "Type of GCP instances"
  type = string
}