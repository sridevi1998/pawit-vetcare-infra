variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Google Cloud region"
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment label"
  type        = string
  default     = "production"
}

variable "allowed_origins" {
  description = "Frontend origins allowed by the API CORS policy"
  type        = list(string)
  default     = []
}

variable "api_image" {
  description = "Container image for pawit-vetcare-api. Defaults to the local Artifact Registry repository."
  type        = string
  default     = null
}

variable "booking_bff_image" {
  description = "Container image for pawit-vetcare-booking-bff. Defaults to the local Artifact Registry repository."
  type        = string
  default     = null
}

variable "hospital_image" {
  description = "Container image for pawit-vetcare-hospital. Defaults to the local Artifact Registry repository."
  type        = string
  default     = null
}

variable "pet_parent_image" {
  description = "Container image for pawit-vetcare-pet-parent. Defaults to the local Artifact Registry repository."
  type        = string
  default     = null
}

variable "marketing_image" {
  description = "Container image for pawit-vetcare-marketing. Defaults to the local Artifact Registry repository."
  type        = string
  default     = null
}

variable "api_min_instances" {
  description = "Minimum API Cloud Run instances"
  type        = number
  default     = 0
}

variable "api_max_instances" {
  description = "Maximum API Cloud Run instances"
  type        = number
  default     = 10
}

variable "network_name" {
  description = "VPC network name for private Cloud SQL and serverless egress"
  type        = string
  default     = "pawit-private"
}

variable "vpc_connector_cidr" {
  description = "CIDR range for the Serverless VPC Access connector"
  type        = string
  default     = "10.8.0.0/28"
}

variable "database_instance_name" {
  description = "Cloud SQL PostgreSQL instance name"
  type        = string
  default     = "pawit-postgres"
}

variable "database_name" {
  description = "Application PostgreSQL database name"
  type        = string
  default     = "pawit"
}

variable "database_user" {
  description = "Application PostgreSQL database user"
  type        = string
  default     = "pawit_app"
}

variable "database_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-1-3840"
}

variable "database_availability_type" {
  description = "Cloud SQL availability type"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.database_availability_type)
    error_message = "database_availability_type must be ZONAL or REGIONAL."
  }
}
