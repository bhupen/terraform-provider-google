resource "random_id" "private_DB_name" {
  byte_length = 8
}

resource "random_id" "public_DB_name" {
  byte_length = 8
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
    "google_project_service.service_project_2_sqladmin_service",
    "google_project_service.service_project_1_sqladmin_service",
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
  depends_on = [
    "google_service_networking_connection.private_vpc_connection"]
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
