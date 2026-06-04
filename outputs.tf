output "artifact_registry_repository" {
  value = google_artifact_registry_repository.pawit.name
}

output "api_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "booking_bff_url" {
  value = google_cloud_run_v2_service.booking_bff.uri
}

output "hospital_url" {
  value = google_cloud_run_v2_service.hospital.uri
}

output "pet_parent_url" {
  value = google_cloud_run_v2_service.pet_parent.uri
}

output "marketing_url" {
  value = google_cloud_run_v2_service.marketing.uri
}
