terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.43.0"
    }
  }
  backend "gcs" {
    bucket  = "remote-tfstate"
    prefix  = "terraform/state"
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
}

provider "google-beta" {
  project     = var.project_id
  region      = var.region
}

resource "google_project_service" "apis" {
  for_each           = toset(var.google_apis_to_enable)
  service            = each.key
  disable_on_destroy = var.api_disable_on_destroy
}
#-###########################
#   Networking
#-###########################
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 11.1"
  project_id   = var.project_id
  network_name = var.vpc_name
  routing_mode = var.routing_mode
  subnets = [
    {
      subnet_name           = "public"
      subnet_ip             = "10.0.1.0/24"
      subnet_region         = var.region
      subnet_private_access = true
    },
    {
      subnet_name           = "private"
      subnet_ip             = "10.0.2.0/24"
      subnet_region         = var.region
      subnet_private_access = true
    }
  ]
  ingress_rules = [
    {
      name                    = "allow-k3s-internal"
      source_ranges           = ["0.0.0.0/0"]
      target_tags             = ["k3s-master", "k3s-worker"]
      allow = [
        {
          protocol = "tcp"
          ports    = var.ingress_tcp_allow_ports
        },
        {
          protocol = "udp"
          ports    = var.ingress_udp_allow_ports
        }
      ]
    },
    {
      name          = "allow-ssh"
      source_ranges = ["10.0.0.0/8","31.41.69.234/32"]
      target_tags   = ["k3s-master", "k3s-worker"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  ]

  egress_rules = [
    {
      name               = "all-egress"
      destination_ranges = ["0.0.0.0/0"]
      allow = [
        {
          protocol = "all"
        }
      ]
    }
  ]
}

resource "google_compute_address" "nat_static_ip" {
  name   = "nat-ip"
  region = var.region
}

module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 7.0"
  name    = var.router_name
  project = var.project_id
  network = module.vpc.network_name
  region  = var.region

  nats = [{
    name                               = var.nat_gw_name
    source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
    nat_ips                            = [google_compute_address.nat_static_ip.self_link]
    subnetworks = [
      {
        name                     = module.vpc.subnets_names[1]
        source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
      }
    ]
  }]
}
#-###########################
#   Instances
#-###########################
resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_openssh
  filename = "${var.ssh_private_key_dest}/id_ed25519"
  file_permission = "0600"
}

module "k3s_master_sa" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.5.4"

  project_id  = var.project_id
  names = ["k3s-master-sa"]
  display_name = "K3s Master Node Service Account"
}

module "k3s_worker_sa" {
  source  = "terraform-google-modules/service-accounts/google"
  version = "~> 4.5.4"

  project_id  = var.project_id
  names = ["k3s-worker-sa"]
  display_name = "K3s Worker Node Service Account"
}

module "public_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"
  region               = var.region
  project_id           = var.project_id
  subnetwork           = module.vpc.subnets_names[0]
  subnetwork_project   = var.project_id
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  disk_size_gb         = var.disk_size  
  machine_type         = var.machine_type
  service_account      = {
    email = module.k3s_master_sa.email
    scopes = var.master_scopes_list
  }
  tags                 = ["k3s-master"]
  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}"
  }
}

module "private_instance_template" {
  source  = "terraform-google-modules/vm/google//modules/instance_template"
  version = "~> 13.0"
  region               = var.region
  project_id           = var.project_id
  subnetwork           = module.vpc.subnets_names[1]
  subnetwork_project   = var.project_id
  source_image_family  = var.source_image_family
  source_image_project = var.source_image_project
  disk_size_gb         = var.disk_size
  service_account      = {
    email = module.k3s_worker_sa.email
    scopes = var.worker_scopes_list
  }
  tags                 = ["k3s-worker"]
  metadata = {
    ssh-keys = "${var.ssh_user}:${tls_private_key.ssh_key.public_key_openssh}"
  }
}

resource "google_compute_address" "public_instance_static_ip" {
  name   = "public-ip"
  region = var.region
}

module "public_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region              = var.region
  zone                = var.zone
  subnetwork          = module.vpc.subnets_names[0]
  subnetwork_project  = var.project_id
  num_instances       = var.public_instances_num
  hostname            = var.public_instance_hostname
  instance_template   = module.public_instance_template.self_link
  deletion_protection = var.deletion_protection

  access_config = [{
    nat_ip       = google_compute_address.public_instance_static_ip.address
    network_tier = var.public_network_tier
  }, ]
}

module "private_instance" {
  source  = "terraform-google-modules/vm/google//modules/compute_instance"
  version = "~> 13.0"

  region              = var.region
  zone                = var.zone
  subnetwork          = module.vpc.subnets_names[1]
  subnetwork_project  = var.project_id
  num_instances       = var.private_instances_num
  hostname            = var.private_instance_hostname
  instance_template   = module.private_instance_template.self_link
  deletion_protection = var.deletion_protection
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    bastion_ip     = google_compute_address.public_instance_static_ip.address
    k3s_server_ip  = [for instance in module.public_instance.instances_details : instance.network_interface[0].network_ip]
    private_ips    = [for instance in module.private_instance.instances_details : instance.network_interface[0].network_ip]
    ansible_user   = var.ssh_user
  })
}
