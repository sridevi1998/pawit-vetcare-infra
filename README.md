# PawIt VetCare Infrastructure

Terraform foundation for serverless PawIt VetCare on Google Cloud.

## Target Resources

- Cloud Run services
- Artifact Registry
- Cloud SQL PostgreSQL 17 with private IP
- Memorystore Redis
- Secret Manager
- HTTPS load balancer
- VPC connector and private service networking
- IAM service accounts

## Current Terraform Slice

This repo currently provisions:

- One Docker Artifact Registry repository: `pawit`
- Service accounts for API, booking BFF, hospital, pet-parent, and marketing services
- Secret Manager secrets for `pawit-jwt-signing-key` and `pawit-database-url`
- Cloud Run services for:
  - `pawit-vetcare-api`
  - `pawit-vetcare-booking-bff`
  - `pawit-vetcare-hospital`
  - `pawit-vetcare-pet-parent`
  - `pawit-vetcare-marketing`
- Public Cloud Run invoker bindings for the service front doors
- URL outputs for each Cloud Run service

Container images default to:

```txt
<region>-docker.pkg.dev/<project_id>/pawit/<service-name>:latest
```

Override any image with the matching Terraform variable, such as `api_image`,
`hospital_image`, or `marketing_image`.

## Required Inputs

```hcl
project_id      = "your-gcp-project-id"
region          = "asia-south1"
allowed_origins = [
  "https://hospital.example.com",
  "https://parents.example.com",
  "https://www.example.com",
]
```

Before applying production services, add secret versions for:

- `pawit-jwt-signing-key`
- `pawit-database-url`

## Local Verification

```sh
terraform fmt -check -diff
terraform init -backend=false
terraform validate
```
