terraform {
  required_version = ">= 1.3.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ───────────────
# VPC Network
# ───────────────
#resource "google_compute_network" "vpc_network" {
#  name                    = "${var.cluster_name}-vpc"
#  auto_create_subnetworks = true
#}

# ───────────────
# GKE Cluster
# ───────────────
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Disable the default node pool to create our own
  remove_default_node_pool = true
  initial_node_count       = 1

  network = google_compute_network.vpc_network.name

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {}
}

# ───────────────
# GKE Node Pool
# ───────────────
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name

  node_count = var.node_count

  node_config {
    machine_type = var.machine_type

    disk_size_gb = 20           # can be 20–50 GB for dev workloads
    disk_type    = "pd-standard" # or "pd-ssd" if you need SSD

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
    labels = {
      env = "prod"
    }
    tags = ["gke-node"]
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}
