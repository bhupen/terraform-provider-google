locals {
  region = "${var.region}"
  subnetwork = "${google_compute_subnetwork.shared_network.name}"
  subnetwork_project = "${google_project.host_project.project_id}"
  subnetwork_self_link = "${google_compute_subnetwork.shared_network.self_link}"
  gce_ssh_user = "ubuntu"
  gce_ssh_pub_key_file = "keys.pub"
  source_image = "cna-g-pre-proj-csql-mgmt/cloud-sql-proxy-2019-05-07-044351"
  project = "${google_project.service_project_1.project_id}"
}

resource "google_compute_instance_template" "private_instance" {

  name_prefix = "cloud-sql-"
  description = "Cloud SQL Proxy"

  instance_description = "Cloud SQL Proxy"
  machine_type = "n1-standard-1"


  project = "${local.project}"

  scheduling {
    automatic_restart = true
    on_host_maintenance = "MIGRATE"
    preemptible = false
  }

  disk {
    boot = true
    auto_delete = true
    source_image = "${local.source_image}"
    disk_size_gb = "20"
    disk_type = "pd-standard"
  }


  network_interface {
    subnetwork_project = "${local.subnetwork_project}"
    subnetwork = "${local.subnetwork}"
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    sshKeys = "${local.gce_ssh_user}:${file(local.gce_ssh_pub_key_file)}\nbhupendra_khanolkar:${file("keys1.pub")}"

    enable-oslogin = "FALSE"
  }

  depends_on = [
    "google_project_iam_binding.service-project-1-network-user"]
}

resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name = "cloud-sql-ig"

  base_instance_name = "cloud-sql"
  instance_template = "${google_compute_instance_template.private_instance.self_link}"
  region = "${local.region}"

  project = "${local.project}"

}

resource "google_compute_region_autoscaler" "autoscaler" {
  name = "cloud-sql"
  region = "${local.region}"
  project = "${local.project}"


  target = "${google_compute_region_instance_group_manager.instance_group_manager.self_link}"

  autoscaling_policy {
    max_replicas = "5"
    min_replicas = "3"
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_region_backend_service" "lb" {
  name = "cloud-sql"
  protocol = "TCP"
  timeout_sec = 10
  session_affinity = "CLIENT_IP"

  project = "${local.project}"


  backend {
    group = "${google_compute_region_instance_group_manager.instance_group_manager.instance_group}"
  }

  health_checks = [
    "${google_compute_health_check.lb-health-check.self_link}"]
}


resource "google_compute_health_check" "lb-health-check" {
  name = "cloud-sql"
  check_interval_sec = 5
  timeout_sec = 5

  project = "${local.project}"


  tcp_health_check {
    port = "22"
  }
}

resource "google_compute_forwarding_rule" "lb-forwarding-rule" {
  name = "cloud-sql"
  load_balancing_scheme = "INTERNAL"
  ip_address = "10.35.1.100"
  project = "${local.project}"

  ports = [
    "22"]
  subnetwork = "${local.subnetwork_self_link}"
  backend_service = "${google_compute_region_backend_service.lb.self_link}"
}