// Terraform configuration to provision Artifact Registry + Service Account for GitHub Actions
// - Enables Artifact Registry API
// - Creates a Docker-format Artifact Registry repository
// - Creates a service account for GitHub CI/CD
// - Grants the service account roles/artifactregistry.writer on the repository
// - Creates a service account key and outputs it as a sensitive value
// USAGE: fill variables (project_id, region/location, repo_id). Run `terraform init` -> `terraform apply`.

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  // Option A (recommended for automation): set GOOGLE_CREDENTIALS env var
  // Option B: set credentials_file variable to the path of a service-account JSON used to run terraform
  // credentials = file(var.credentials_file)
}

variable "project_id" {
  description = "GCP project id where resources will be created"
  type        = string
}

variable "region" {
  description = "GCP default region (used by provider)"
  type        = string
  default     = "asia-south1"
}

variable "location" {
  description = "Location for Artifact Registry repository (region), e.g. asia-south1"
  type        = string
  default     = "asia-south1"
}

variable "repo_id" {
  description = "Artifact Registry repository id (name)"
  type        = string
  default     = "my-app-repo"
}

variable "sa_account_id" {
  description = "Service account account_id (short name) for the GitHub CI/CD SA"
  type        = string
  default     = "github-cicd"
}

// Enable APIs required
resource "google_project_service" "artifact_registry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  project = var.project_id
  service = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

// Create Artifact Registry repo (Docker format)
resource "google_artifact_registry_repository" "repo" {
  project       = var.project_id
  location      = var.location
  repository_id = var.repo_id
  description   = "Docker repository for ${var.repo_id}"
  format        = "DOCKER"

  depends_on = [
    google_project_service.artifact_registry
  ]
}

// Create service account for GitHub Actions
resource "google_service_account" "github_cicd" {
  account_id   = var.sa_account_id
  display_name = "GitHub CI/CD service account"
  project      = var.project_id
}

// Grant artifactregistry.writer role on the repository to the SA
resource "google_artifact_registry_repository_iam_member" "sa_writer" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.repo.repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_cicd.email}"

  depends_on = [
    google_artifact_registry_repository.repo,
    google_service_account.github_cicd
  ]
}

# Give service account permission to run builds
resource "google_project_iam_binding" "cloudbuild_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"

  members = [
    "serviceAccount:${google_service_account.github_cicd.email}",
  ]
}

// (Optional) Grant additional role if you need storage permission; uncomment if needed
// resource "google_project_iam_member" "sa_storage_admin" {
//   project = var.project_id
//   role    = "roles/storage.admin"
//   member  = "serviceAccount:${google_service_account.github_cicd.email}"
// }

// Create a service account key for use in GitHub Actions
resource "google_service_account_key" "github_cicd_key" {
  service_account_id = google_service_account.github_cicd.name
  lifecycle {
    prevent_destroy = false
  }
}




// Outputs
output "service_account_email" {
  description = "The email of the GitHub CI/CD service account"
  value       = google_service_account.github_cicd.email
}

output "artifact_registry_repo" {
  description = "Artifact Registry repository resource name (for docker push)"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${var.repo_id}"
}

output "service_account_key_json" {
  description = "The JSON private key for the service account (sensitive)\nUse this value to create a GitHub secret named GCP_SA_KEY"
  value       = google_service_account_key.github_cicd_key.private_key
  sensitive   = true
}
