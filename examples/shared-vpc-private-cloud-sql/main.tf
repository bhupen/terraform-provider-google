# https://cloud.google.com/vpc/docs/shared-vpc

provider "google" {
  region = "${var.region}"
  credentials = "${file("${var.credentials_file_path}")}"
}

provider "google-beta" {
  region = "${var.region}"
  credentials = "${file("${var.credentials_file_path}")}"
}


provider "random" {}

resource "random_id" "host_project_name" {
  byte_length = 8
}

resource "random_id" "service_project_1_name" {
  byte_length = 8
}

resource "random_id" "service_project_2_name" {
  byte_length = 8
}

resource "random_id" "standalone_project_name" {
  byte_length = 8
}

resource "random_id" "private_DB_name" {
  byte_length = 8
}

resource "random_id" "public_DB_name" {
  byte_length = 8
}


# The project which owns the VPC.
resource "google_project" "host_project" {
  name = "Host Project"
  project_id = "tf-vpc-${random_id.host_project_name.hex}"
  /*
    org_id = "${var.org_id}"
  */
  billing_account = "${var.billing_account_id}"
  folder_id = "${var.folder_id}"
  auto_create_network = "false"

}

resource "google_project_service" "gcp_project_service" {
  project = "${google_project.host_project.project_id}"
  service = "servicenetworking.googleapis.com"
  depends_on = [
    "google_project.host_project",
    "google_project_service.host_project"]
  disable_on_destroy = true
}

resource "google_project_service" "gcp_project_service_proj1" {
  project = "${google_project.service_project_1.project_id}"
  service = "servicenetworking.googleapis.com"
  depends_on = [
    "google_project.host_project",
    "google_project_service.host_project"]
  disable_on_destroy = true
}

resource "google_project_service" "gcp_project_service_proj2" {
  project = "${google_project.service_project_2.project_id}"
  service = "servicenetworking.googleapis.com"
  depends_on = [
    "google_project.host_project",
    "google_project_service.host_project"]
  disable_on_destroy = true
}

# One project which will use the VPC.
resource "google_project" "service_project_1" {
  name = "Service Project 1"
  project_id = "tf-vpc-${random_id.service_project_1_name.hex}"
  /*
    org_id = "${var.org_id}"
  */
  billing_account = "${var.billing_account_id}"
  folder_id = "${var.folder_id}"
  auto_create_network = "false"

}

# The other project which will use the VPC.
resource "google_project" "service_project_2" {
  name = "Service Project 2"
  project_id = "tf-vpc-${random_id.service_project_2_name.hex}"
  /*
    org_id = "${var.org_id}"
  */
  billing_account = "${var.billing_account_id}"
  folder_id = "${var.folder_id}"
  auto_create_network = "false"

}

# A project which will not use the VPC, for the sake of demonstration.
resource "google_project" "standalone_project" {
  name = "Standalone Project"
  project_id = "tf-vpc-${random_id.standalone_project_name.hex}"
  /*
    org_id = "${var.org_id}"
  */
  billing_account = "${var.billing_account_id}"
  folder_id = "${var.folder_id}"
  auto_create_network = "false"

}

# Compute service needs to be enabled for all four new projects.
resource "google_project_service" "host_project" {
  project = "${google_project.host_project.project_id}"
  service = "compute.googleapis.com"
  disable_on_destroy = true
  provisioner "local-exec" {
    when="destroy"
    command = <<EOF
    for i in `gcloud beta services list --project ${self.project} | grep -v NAME | cut -f 1 -d ' ' `
    do
      gcloud services disable --project ${self.project} $i
    done
EOF
  }
}

resource "google_project_service" "service_project_1" {
  project = "${google_project.service_project_1.project_id}"
  service = "compute.googleapis.com"
  disable_on_destroy = true
  provisioner "local-exec" {
    when="destroy"
    command = <<EOF
    for i in `gcloud beta services list --project ${self.project} | grep -v NAME | cut -f 1 -d ' ' `
    do
      gcloud services disable --project ${self.project} $i
    done
EOF
  }
}

resource "google_project_service" "service_project_2" {
  project = "${google_project.service_project_2.project_id}"
  service = "compute.googleapis.com"
  disable_on_destroy = true
  provisioner "local-exec" {
    when="destroy"
    command = <<EOF
    for i in `gcloud beta services list --project ${self.project} | grep -v NAME | cut -f 1 -d ' ' `
    do
      gcloud services disable --project ${self.project} $i
    done
EOF
  }
}

resource "google_project_service" "standalone_project" {
  project = "${google_project.standalone_project.project_id}"
  service = "compute.googleapis.com"
  disable_on_destroy = true
}

# Enable shared VPC hosting in the host project.
resource "google_compute_shared_vpc_host_project" "host_project" {
  project = "${google_project.host_project.project_id}"
  depends_on = [
    "google_project_service.host_project"]
}

resource "google_project_service" "host_project_sqladmin_service" {
  project = "${google_project.host_project.project_id}"
  service = "sqladmin.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "service_project_1_sqladmin_service" {
  project = "${google_project.service_project_1.project_id}"
  service = "sqladmin.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "service_project_2_sqladmin_service" {
  project = "${google_project.service_project_2.project_id}"
  service = "sqladmin.googleapis.com"
  disable_on_destroy = true
}

resource "google_project_service" "standalone_project_sqladmin_service" {
  project = "${google_project.standalone_project.project_id}"
  service = "sqladmin.googleapis.com"
  disable_on_destroy = true
}

# Enable shared VPC in the two service projects - explicitly depend on the host
# project enabling it, because enabling shared VPC will fail if the host project
# is not yet hosting.
resource "google_compute_shared_vpc_service_project" "service_project_1" {
  host_project = "${google_project.host_project.project_id}"
  service_project = "${google_project.service_project_1.project_id}"

  depends_on = [
    "google_compute_shared_vpc_host_project.host_project",
    "google_project_service.service_project_1",
  ]
}

resource "google_compute_shared_vpc_service_project" "service_project_2" {
  host_project = "${google_project.host_project.project_id}"
  service_project = "${google_project.service_project_2.project_id}"

  depends_on = [
    "google_compute_shared_vpc_host_project.host_project",
    "google_project_service.service_project_2",
  ]
}

# Create the hosted network.
resource "google_compute_network" "shared_network" {
  name = "shared-network"
  auto_create_subnetworks = "false"
  project = "${google_compute_shared_vpc_host_project.host_project.project}"

  depends_on = [
    "google_compute_shared_vpc_service_project.service_project_1",
    "google_compute_shared_vpc_service_project.service_project_2",
  ]
}

resource "google_compute_subnetwork" "shared_network" {
  ip_cidr_range = "10.128.0.0/20"
  name = "shared-network"
  network = "${google_compute_network.shared_network.self_link}"
  project = "${google_compute_shared_vpc_host_project.host_project.project}"
}

# Allow the hosted network to be hit over ICMP, SSH, and HTTP.
resource "google_compute_firewall" "shared_network" {
  name = "allow-ssh-and-icmp"
  network = "${google_compute_network.shared_network.self_link}"
  project = "${google_compute_network.shared_network.project}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [
      "22",
      "80"]
  }

}

resource "google_compute_firewall" "shared_network_deny_cloud_sql_access" {
  name = "deny-direct-cloud-sql-access"
  network = "${google_compute_network.shared_network.self_link}"
  project = "${google_compute_network.shared_network.project}"
  direction = "EGRESS"
  destination_ranges = [
    "${var.peering_cidr_range}/${var.peering_cidr_prefix}"]

  deny {
    protocol = "tcp"
    ports = [
      "3306",
      "5432"]
  }
}

# Create a standalone network with the same firewall rules.
resource "google_compute_network" "standalone_network" {
  name = "standalone-network"
  auto_create_subnetworks = "true"
  project = "${google_project.standalone_project.project_id}"
  depends_on = [
    "google_project_service.standalone_project"]
}

resource "google_compute_firewall" "standalone_network" {
  name = "allow-ssh-and-icmp"
  network = "${google_compute_network.standalone_network.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = [
      "22",
      "80"]
  }

  project = "${google_project.standalone_project.project_id}"
}

resource "google_compute_global_address" "private_ip_address" {
  provider = "google-beta"
  name = "private-ip-address"
  purpose = "VPC_PEERING"
  address_type = "INTERNAL"
  address = "${var.peering_cidr_range}"
  prefix_length = "${var.peering_cidr_prefix}"
  network = "${google_compute_network.shared_network.self_link}"
  project = "${google_project.host_project.id}"
  depends_on = [
    "google_project_service.host_project",
    "google_project_service.gcp_project_service",
    "google_project_service.gcp_project_service_proj1",
    "google_project_service.gcp_project_service_proj2",
    "google_project_service.host_project_sqladmin_service",
    "google_project_service.service_project_1_sqladmin_service",
    "google_project_service.service_project_2_sqladmin_service",
    "google_project_service.standalone_project_sqladmin_service"
  ]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = "google-beta"
  network = "${google_compute_network.shared_network.self_link}"
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    "${google_compute_global_address.private_ip_address.name}"]
}

# Create a VM which hosts a web page stating its identity ("VM1")
resource "google_compute_instance" "project_1_vm" {
  name = "tf-project-1-vm"
  project = "${google_project.service_project_1.project_id}"
  machine_type = "f1-micro"
  zone = "${var.region_zone}"

  boot_disk {
    initialize_params {
      image = "projects/gce-uefi-images/global/images/family/ubuntu-1804-lts"
    }
  }

  metadata_startup_script = "VM_NAME=VM1\n${file("scripts/install-vm.sh")}"

  network_interface {
    /*
        network = "${google_compute_network.shared_network.self_link}"
    */
    subnetwork = "${google_compute_subnetwork.shared_network.self_link}"
    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly"]
  }

  depends_on = [
    "google_project_service.service_project_1",
    "google_compute_subnetwork.shared_network"]
}

# Create a VM which hosts a web page demonstrating the example networking.
resource "google_compute_instance" "project_2_vm" {
  name = "tf-project-2-vm"
  machine_type = "f1-micro"
  project = "${google_project.service_project_2.project_id}"
  zone = "${var.region_zone}"

  boot_disk {
    initialize_params {
      image = "projects/gce-uefi-images/global/images/family/ubuntu-1804-lts"
    }
  }

  metadata_startup_script = <<EOF
VM1_EXT_IP=${google_compute_instance.project_1_vm.network_interface.0.access_config.0.nat_ip}
ST_VM_EXT_IP=${google_compute_instance.standalone_project_vm.network_interface.0.access_config.0.nat_ip}
VM1_INT_IP=${google_compute_instance.project_1_vm.network_interface.0.address}
ST_VM_INT_IP=${google_compute_instance.standalone_project_vm.network_interface.0.address}
${file("scripts/install-network-page.sh")}
EOF

  network_interface {
    /*
        network = "${google_compute_network.shared_network.self_link}"
    */
    subnetwork = "${google_compute_subnetwork.shared_network.self_link}"
    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly"]
  }

  depends_on = [
    "google_project_service.service_project_2",
    "google_compute_subnetwork.shared_network"]
}

# Create a VM which hosts a web page stating its identity ("standalone").
resource "google_compute_instance" "standalone_project_vm" {
  name = "tf-standalone-vm"
  machine_type = "f1-micro"
  project = "${google_project.standalone_project.project_id}"
  zone = "${var.region_zone}"

  boot_disk {
    initialize_params {
      image = "projects/gce-uefi-images/global/images/family/ubuntu-1804-lts"
    }
  }

  metadata_startup_script = "VM_NAME=standalone\n${file("scripts/install-vm.sh")}"

  network_interface {
    network = "${google_compute_network.standalone_network.self_link}"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/compute.readonly"]
  }

  depends_on = [
    "google_project_service.standalone_project",
    "google_compute_subnetwork.shared_network"]
}


resource "google_sql_database_instance" "instance" {
  provider = "google-beta"
  depends_on = [
    "google_service_networking_connection.private_vpc_connection",
    "google_compute_global_address.private_ip_address",
    "google_project_service.gcp_project_service_proj2",
    "google_project_service.service_project_2_sqladmin_service"

  ]
  name = "private1-${random_id.private_DB_name.hex}"
  region = "us-central1"
  project = "${google_project.service_project_2.id}"
  database_version = "POSTGRES_9_6"
  settings {
    tier = "db-custom-2-12288"
    ip_configuration {
      ipv4_enabled = "false"
      private_network = "${google_compute_network.shared_network.self_link}"
    }
  }
}


resource "google_sql_database_instance" "instance-1" {
  provider = "google-beta"
  depends_on = ["google_service_networking_connection.private_vpc_connection"]
  name = "public-${random_id.public_DB_name.hex}"
  region = "us-central1"
  project = "${google_project.service_project_2.id}"
  database_version = "POSTGRES_9_6"
  settings {
    tier = "db-custom-2-12288"
  }
}


resource "null_resource" "destroy-vpc-to-services-peering" {
  provisioner "local-exec" {
    when = "destroy"

    command = <<EOF
    gcloud compute networks peerings delete cloudsql-mysql-googleapis-com \
    --network ${google_compute_network.shared_network.name} \
    --project=${google_project.host_project.project_id} --quiet
    gcloud compute networks peerings delete cloudsql-postgres-googleapis-com \
    --network ${google_compute_network.shared_network.name} \
    --project=${google_project.host_project.project_id} --quiet
    gcloud compute networks peerings delete servicenetworking-googleapis-com \
    --network ${google_compute_network.shared_network.name} \
    --project=${google_project.host_project.project_id} --quiet
EOF
  }
}
