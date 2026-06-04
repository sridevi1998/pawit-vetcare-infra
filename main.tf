provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  artifact_registry_base = "${var.region}-docker.pkg.dev/${var.project_id}/pawit"

  api_image         = coalesce(var.api_image, "${local.artifact_registry_base}/pawit-vetcare-api:latest")
  booking_bff_image = coalesce(var.booking_bff_image, "${local.artifact_registry_base}/pawit-vetcare-booking-bff:latest")
  hospital_image    = coalesce(var.hospital_image, "${local.artifact_registry_base}/pawit-vetcare-hospital:latest")
  pet_parent_image  = coalesce(var.pet_parent_image, "${local.artifact_registry_base}/pawit-vetcare-pet-parent:latest")
  marketing_image   = coalesce(var.marketing_image, "${local.artifact_registry_base}/pawit-vetcare-marketing:latest")

  allowed_origins = join(",", var.allowed_origins)
}

resource "google_artifact_registry_repository" "pawit" {
  location      = var.region
  repository_id = "pawit"
  description   = "PawIt VetCare container images"
  format        = "DOCKER"
}

resource "google_service_account" "api" {
  account_id   = "pawit-api"
  display_name = "PawIt API Cloud Run service account"
}

resource "google_service_account" "booking_bff" {
  account_id   = "pawit-booking-bff"
  display_name = "PawIt booking BFF Cloud Run service account"
}

resource "google_service_account" "hospital" {
  account_id   = "pawit-hospital"
  display_name = "PawIt hospital portal Cloud Run service account"
}

resource "google_service_account" "pet_parent" {
  account_id   = "pawit-pet-parent"
  display_name = "PawIt pet-parent portal Cloud Run service account"
}

resource "google_service_account" "marketing" {
  account_id   = "pawit-marketing"
  display_name = "PawIt marketing site Cloud Run service account"
}

resource "google_secret_manager_secret" "jwt_signing_key" {
  secret_id = "pawit-jwt-signing-key"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "pawit-database-url"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "api_jwt_reader" {
  secret_id = google_secret_manager_secret.jwt_signing_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_database_reader" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_cloud_run_v2_service" "api" {
  name     = "pawit-vetcare-api"
  location = var.region

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = var.api_min_instances
      max_instance_count = var.api_max_instances
    }

    containers {
      image = local.api_image

      ports {
        container_port = 8080
      }

      env {
        name  = "PAWIT_ENV"
        value = var.environment
      }

      env {
        name  = "PAWIT_ALLOW_DEV_AUTH"
        value = "false"
      }

      env {
        name  = "PAWIT_ALLOWED_ORIGINS"
        value = local.allowed_origins
      }

      env {
        name = "PAWIT_JWT_SIGNING_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_signing_key.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "PAWIT_DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_service" "booking_bff" {
  name     = "pawit-vetcare-booking-bff"
  location = var.region

  template {
    service_account = google_service_account.booking_bff.email

    containers {
      image = local.booking_bff_image

      ports {
        container_port = 8080
      }
    }
  }
}

resource "google_cloud_run_v2_service" "hospital" {
  name     = "pawit-vetcare-hospital"
  location = var.region

  template {
    service_account = google_service_account.hospital.email

    containers {
      image = local.hospital_image

      ports {
        container_port = 3000
      }

      env {
        name  = "NEXT_PUBLIC_PAWIT_API_BASE_URL"
        value = google_cloud_run_v2_service.api.uri
      }
    }
  }
}

resource "google_cloud_run_v2_service" "pet_parent" {
  name     = "pawit-vetcare-pet-parent"
  location = var.region

  template {
    service_account = google_service_account.pet_parent.email

    containers {
      image = local.pet_parent_image

      ports {
        container_port = 8080
      }

      env {
        name  = "VITE_API_BASE_URL"
        value = "${google_cloud_run_v2_service.api.uri}/api/v1"
      }
    }
  }
}

resource "google_cloud_run_v2_service" "marketing" {
  name     = "pawit-vetcare-marketing"
  location = var.region

  template {
    service_account = google_service_account.marketing.email

    containers {
      image = local.marketing_image

      ports {
        container_port = 3000
      }

      env {
        name  = "NEXT_PUBLIC_HOSPITAL_APP_URL"
        value = google_cloud_run_v2_service.hospital.uri
      }

      env {
        name  = "NEXT_PUBLIC_PET_PARENT_APP_URL"
        value = google_cloud_run_v2_service.pet_parent.uri
      }

      env {
        name  = "NEXT_PUBLIC_BOOKING_URL"
        value = google_cloud_run_v2_service.booking_bff.uri
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "api_public" {
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "booking_bff_public" {
  location = google_cloud_run_v2_service.booking_bff.location
  name     = google_cloud_run_v2_service.booking_bff.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "hospital_public" {
  location = google_cloud_run_v2_service.hospital.location
  name     = google_cloud_run_v2_service.hospital.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "pet_parent_public" {
  location = google_cloud_run_v2_service.pet_parent.location
  name     = google_cloud_run_v2_service.pet_parent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "marketing_public" {
  location = google_cloud_run_v2_service.marketing.location
  name     = google_cloud_run_v2_service.marketing.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
