provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_artifact_registry_repository" "pawit" {
  location      = var.region
  repository_id = "pawit"
  description   = "PawIt VetCare container images"
  format        = "DOCKER"
}

resource "google_secret_manager_secret" "jwt_signing_key" {
  secret_id = "pawit-jwt-signing-key"
  replication {
    auto {}
  }
}
