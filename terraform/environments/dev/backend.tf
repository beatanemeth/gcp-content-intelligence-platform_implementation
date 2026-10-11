# A backend block cannot read variables, so the bucket (Part A's state bucket)
# comes from backend.hcl: terraform init -backend-config=backend.hcl.
# The simulation runs terraform init -backend=false and needs no bucket.
terraform {
  backend "gcs" {
    prefix = "content-pipeline"
  }
}
