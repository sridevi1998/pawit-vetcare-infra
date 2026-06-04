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
  database_url    = "postgres://${var.database_user}:${urlencode(random_password.database_user.result)}@${google_sql_database_instance.postgres.private_ip_address}:5432/${var.database_name}?sslmode=disable"
}

resource "google_project_service" "required" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "vpcaccess.googleapis.com",
  ])

  service            = each.key
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "pawit" {
  location      = var.region
  repository_id = "pawit"
  description   = "PawIt VetCare container images"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_compute_network" "private" {
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "private" {
  name          = "${var.network_name}-${var.region}"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.private.id
  region        = var.region
}

resource "google_compute_global_address" "private_service_connect" {
  name          = "pawit-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.private.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_connect.name]
}

resource "google_vpc_access_connector" "serverless" {
  name          = "pawit-serverless"
  region        = var.region
  network       = google_compute_network.private.name
  ip_cidr_range = var.vpc_connector_cidr

  depends_on = [google_project_service.required]
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

resource "random_password" "database_user" {
  length  = 32
  special = false
}

resource "google_sql_database_instance" "postgres" {
  name             = var.database_instance_name
  database_version = "POSTGRES_17"
  region           = var.region

  settings {
    tier              = var.database_tier
    availability_type = var.database_availability_type
    disk_autoresize   = true
    disk_size         = 20
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.private.id
      enable_private_path_for_google_cloud_services = true
    }
  }

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "app" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app" {
  name     = var.database_user
  instance = google_sql_database_instance.postgres.name
  password = random_password.database_user.result
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = local.database_url
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

    vpc_access {
      connector = google_vpc_access_connector.serverless.id
      egress    = "PRIVATE_RANGES_ONLY"
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
            version = google_secret_manager_secret_version.database_url.version
          }
        }
      }
    }
  }
}

resource "google_cloud_run_v2_job" "migrate" {
  name     = "pawit-vetcare-migrate"
  location = var.region

  template {
    template {
      service_account = google_service_account.api.email
      max_retries     = 0
      timeout         = "600s"

      vpc_access {
        connector = google_vpc_access_connector.serverless.id
        egress    = "PRIVATE_RANGES_ONLY"
      }

      containers {
        image = local.api_image

        command = ["/app/pawit-migrate"]
        args    = ["up"]

        env {
          name  = "PAWIT_ENV"
          value = var.environment
        }

        env {
          name  = "PAWIT_ALLOW_DEV_AUTH"
          value = "false"
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
              version = google_secret_manager_secret_version.database_url.version
            }
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
        container_port = 8080
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
