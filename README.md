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
- Required Google APIs for Artifact Registry, Cloud Run, Cloud SQL, Secret Manager, Service Networking, and VPC Access
- A private VPC, private service networking range, and Serverless VPC Access connector
- Cloud SQL PostgreSQL 17 with private IP only, automated backups, and point-in-time recovery
- Application database/user and a generated database password
- Service accounts for API, booking BFF, hospital, pet-parent, and marketing services
- Secret Manager secrets for `pawit-jwt-signing-key` and `pawit-database-url`
- A generated `pawit-database-url` secret version for the private Cloud SQL database
- Generated Liquibase JDBC URL, database username, and database password secrets
- Cloud Run services for:
  - `pawit-vetcare-api`
  - `pawit-vetcare-booking-bff`
  - `pawit-vetcare-hospital`
  - `pawit-vetcare-pet-parent`
  - `pawit-vetcare-marketing`
- A Cloud Run migration job: `pawit-vetcare-migrate`
- Public Cloud Run invoker bindings for the service front doors
- URL outputs for each Cloud Run service

Container images default to:

```txt
<region>-docker.pkg.dev/<project_id>/pawit/<service-name>:latest
```

Override any image with the matching Terraform variable, such as `api_image`,
`liquibase_image`, `hospital_image`, or `marketing_image`.

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

Terraform creates the `pawit-database-url` secret version from the private Cloud
SQL instance, application database, and generated database password.

Terraform also creates the Liquibase-specific secrets consumed by the migration
job:

- `pawit-liquibase-jdbc-url`
- `pawit-database-username`
- `pawit-database-password`

After images are pushed and Terraform is applied, run the migration job before
sending production traffic to the API:

```sh
gcloud run jobs execute pawit-vetcare-migrate --region asia-south1 --wait
```

## Local Verification

```sh
terraform fmt -check -diff
terraform init -backend=false
terraform validate
```
