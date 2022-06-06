# data "google_service_account" "owner_project" {
#   account_id = var.service_account
# }
# # Collect client config for GCP
data "google_client_config" "current" {
}

terraform {
  required_version = ">= 1.1.0"
  backend "remote" {}
}
resource "google_compute_network" "container_network" {
  count = var.default_network ? 0 : 1
  name = "${var.gke_cluster}-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "container_subnetwork" {
  count = var.default_network ? 0 : 1
  name          = "${var.gke_cluster}-subnetwork"
  description   = "auto-created subnetwork for cluster \"${var.gke_cluster}\""
  region        = var.gcp_region
  ip_cidr_range = "10.2.0.0/16"
  network       = google_compute_network.container_network.0.self_link
}

data "google_container_engine_versions" "k8sversion" {
  project = var.gcp_project
  location       = var.regional_k8s ? var.gcp_region : var.gcp_zone
  version_prefix = "${var.k8s_version}."
}

resource "google_container_cluster" "primary" {
  # New comment
  # provider = google-beta
  # project = var.gcp_project
  name     = var.gke_cluster
  location = var.regional_k8s ? var.gcp_region : var.gcp_zone
  node_version = data.google_container_engine_versions.k8sversion.latest_node_version
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = var.default_gke ? false : true
  initial_node_count       = var.default_gke ? var.numnodes : 1
  # network = google_compute_network.vpc_network.self_link
  network = google_compute_network.container_network.0.self_link
  subnetwork = google_compute_subnetwork.container_subnetwork.0.self_link
  min_master_version = data.google_container_engine_versions.k8sversion.latest_master_version
  master_auth {
    # username = ""
    # password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
  node_config {
    shielded_instance_config {
      enable_secure_boot = true
    }
    machine_type = var.node_type
    disk_type = "pd-ssd"
    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = [
      "${var.owner}-gke"
    ]
  }
  enable_intranode_visibility = true
  network_policy {
    enabled = true
  }
  # pod_security_policy_config {
  #   enabled = true
  # }
}


resource "google_container_node_pool" "primary_nodes" {
  count = var.default_gke ? 0 : 1
  name       = "${var.gke_cluster}-node-pool"
  location = google_container_cluster.primary.location
  #version = data.google_container_engine_versions.k8sversion.latest_node_version
  # location   = var.regional_k8s == true ? var.gcp_region : var.gcp_zone
  cluster    = google_container_cluster.primary.name
  node_count = var.numnodes

  node_config {
    machine_type = var.node_type
    disk_type = "pd-ssd"
    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    tags = [
      "${var.owner}-gke"
    ]
  }
  # autoscaling {
  #   min_node_count = 0
  #   max_node_count = var.nodes*2
  # }
}

resource "google_storage_bucket_object" "kubeconfig" {
  count = var.config_bucket != "" ? 1 : 0
  name   = "${var.gke_cluster}-kubeconfig-${formatdate("YYMMDD_HHmm",timestamp())}.yml"
#   content = nonsensitive(module.gke.kubeconfig)
  content = templatefile("${path.root}/templates/kubeconfig.yaml", {
    cluster_name = google_container_cluster.primary.endpoint,
    endpoint =  google_container_cluster.primary.endpoint,
    user_name ="admin",
    cluster_ca = google_container_cluster.primary.master_auth.0.cluster_ca_certificate,
    client_cert = google_container_cluster.primary.master_auth.0.client_certificate,
    client_cert_key = google_container_cluster.primary.master_auth.0.client_key,
    # user_password = google_container_cluster.primary.master_auth.0.password,
    user_password = "",
    oauth_token = nonsensitive(data.google_client_config.current.access_token)
  })
  bucket = var.config_bucket
}