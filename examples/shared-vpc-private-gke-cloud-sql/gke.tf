/// Service account setup
// Create GKE admin service accounts.
locals {
  gke_host_project_id = "${google_project.host_project.project_id}"
  gke_project_id = "${google_project.service_project_2.project_id}"
  gke_project_number = "${google_project.service_project_2.number}"
  gke_region = "${var.region}"
  gke_network = "${google_compute_network.shared_network.self_link}"
  gke_subnet = "${module.shared_network_gke.self_link}"
  gke_pod_range = "${module.shared_network_gke.secondary_range_names[0]}"
  gke_service_range = "${module.shared_network_gke.secondary_range_names[1]}"
  gke_master_authorized_subnet = "${google_compute_subnetwork.shared_network.ip_cidr_range}"
}

resource "google_service_account" "gcp_gke_service_account_app" {
  project = "${local.gke_project_id}"
  account_id = "gke-cluster-app"
  display_name = "GKE Cluser App"
}

resource "google_project_iam_member" "gcp_container_app_iam_member_1" {
  project = "${local.gke_project_id}"
  role = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account_app.email}"
  depends_on = [
    "google_service_account.gcp_gke_service_account_app",
  ]
}

resource "google_project_iam_member" "gcp_container_app_iam_member_2" {
  project = "${local.gke_project_id}"
  role = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account_app.email}"
  depends_on = [
    "google_service_account.gcp_gke_service_account_app",
  ]
}

resource "google_service_account" "gcp_gke_service_account" {
  project = "${local.gke_project_id}"
  account_id = "gke-cluster-admin"
  display_name = "GKE Cluser Admin"
}

// Assign container-admin role to GKE service account
resource "google_project_iam_member" "gcp_container_admin_iam_member" {
  project = "${local.gke_project_id}"
  role = "roles/container.admin"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account.email}"

  depends_on = [
    "google_service_account.gcp_gke_service_account",
  ]
}

// Assign storage-object-viewer role to GKE service account
resource "google_project_iam_member" "gcp_storage_object_viewer_iam_member" {
  project = "${local.gke_project_id}"
  role = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account.email}"

  depends_on = [
    "google_service_account.gcp_gke_service_account",
  ]
}

// Assign log writer role to GKE service account
resource "google_project_iam_member" "gcp_log_writer_iam_member" {
  project = "${local.gke_project_id}"
  role = "roles/logging.logWriter"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account.email}"

  depends_on = [
    "google_service_account.gcp_gke_service_account",
  ]
}

// Assign monitoring role to GKE service account
resource "google_project_iam_member" "gcp_monitoring_iam_member" {
  project = "${local.gke_project_id}"
  role = "roles/monitoring.metricWriter"
  member = "serviceAccount:${google_service_account.gcp_gke_service_account.email}"

  depends_on = [
    "google_service_account.gcp_gke_service_account",
  ]
}

resource "google_project_iam_member" "gcp_gke_default_service_account_container_hostServiceAgentUser" {
  project = "${local.gke_host_project_id}"
  member = "serviceAccount:service-${local.gke_project_number}@container-engine-robot.iam.gserviceaccount.com"
  role = "roles/container.hostServiceAgentUser"
}

resource "google_project_iam_member" "gcp_gke_default_service_account_compute_networkUser" {
  project = "${local.gke_host_project_id}"
  member = "serviceAccount:service-${local.gke_project_number}@container-engine-robot.iam.gserviceaccount.com"
  role = "roles/compute.networkUser"
}

resource "google_project_iam_member" "gcp_gke_create_service_account_compute_networkUser" {
  project = "${local.gke_host_project_id}"
  member = "serviceAccount:${local.gke_project_number}@cloudservices.gserviceaccount.com"
  role = "roles/compute.networkUser"
}

/// GKE setup
resource "google_container_cluster" "gke_cluster" {
  name = "gke-cluster-1"

  region = "${local.gke_region}"
  initial_node_count = "1"
  project = "${local.gke_project_id}"

  remove_default_node_pool = true

  network = "${local.gke_network}"
  subnetwork = "${local.gke_subnet}"

  
    
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "${local.gke_master_authorized_subnet}"
      display_name = "shared-network-hosts"
    }
  }

  logging_service = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  ip_allocation_policy {
    cluster_secondary_range_name = "${local.gke_pod_range}"
    services_secondary_range_name = "${local.gke_service_range}"
  }

  private_cluster_config {
    enable_private_endpoint = "true"
    enable_private_nodes = "true"
    master_ipv4_cidr_block = "192.168.128.0/28"
  }

  depends_on = [
    "module.shared_network_gke",
    "google_project_iam_member.gcp_gke_default_service_account_compute_networkUser",
    "google_project_iam_member.gcp_gke_default_service_account_container_hostServiceAgentUser",
    "google_project_iam_member.gcp_gke_create_service_account_compute_networkUser"
  ]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name = "node-pool-1"
  region = "${local.gke_region}"
  cluster = "${google_container_cluster.gke_cluster.name}"

  project = "${local.gke_project_id}"

  node_count = "1"

  node_config {
    preemptible = false
    machine_type = "n1-standard-1"

    //  service_account = "${google_service_account.gcp_gke_service_account.email}"
    metadata {
      disable-legacy-endpoints = "true"
    }
  }
}
