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
