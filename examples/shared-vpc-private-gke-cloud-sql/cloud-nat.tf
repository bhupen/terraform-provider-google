/*
resource "google_compute_router" "router" {
  project = "${google_project.host_project.project_id}"
  name = "router"
  region = "${var.region}"
  network = "${google_compute_network.shared_network.self_link}"
  bgp {
    asn = 64514
  }
}

resource "google_compute_address" "address" {
  project = "${google_project.host_project.project_id}"
  count = 2
  name = "nat-external-address-${count.index}"
  region = "${var.region}"
}

resource "google_compute_router_nat" "advanced-nat" {
  project = "${google_project.host_project.project_id}"
  name = "nat-1"
  router = "${google_compute_router.router.name}"
  region = "${var.region}"
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = "${google_compute_address.address.*.self_link}"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  subnetwork {
    name = "${google_compute_subnetwork.shared_network.self_link}"
    source_ip_ranges_to_nat = [
      "ALL_IP_RANGES"]
  }
  */
/* log_config  {
     filter = "TRANSLATIONS_ONLY"
     enable = true
   }*//*

}*/
