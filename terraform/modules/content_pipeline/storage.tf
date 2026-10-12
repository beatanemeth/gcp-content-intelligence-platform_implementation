# Two buckets: IAM is granted per bucket, so the runtime can write data but not code.
resource "google_storage_bucket" "data" {
  name     = "${var.project_id}-${local.feature}-data"
  project  = var.project_id
  location = var.region

  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  labels = local.labels
}

resource "google_storage_bucket" "source" {
  name     = "${var.project_id}-${local.feature}-source"
  project  = var.project_id
  location = var.region

  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  labels = local.labels
}
