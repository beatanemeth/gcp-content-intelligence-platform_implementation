# Two buckets, so the function's runtime account (step 5a) can write data but
# never touch the function's code. IAM is granted per bucket, so the bucket is
# the boundary.

# Uploads (raw/) and the function's output (processed/).
resource "google_storage_bucket" "data" {
  name     = "${var.project_id}-${local.feature}-data"
  project  = var.project_id
  location = var.region

  # destroy removes the bucket even with files in it; the data lives on the laptop.
  force_destroy = true

  uniform_bucket_level_access = true
  # No file can ever be made public, not even by an Owner's mistake.
  public_access_prevention = "enforced"

  # Off: replaced or deleted files are not kept (and billed) for 7 days, and
  # destroy leaves nothing behind. Every file can be uploaded again.
  soft_delete_policy {
    retention_duration_seconds = 0
  }

  labels = local.labels
}

# The function's code zip (step 5b).
resource "google_storage_bucket" "source" {
  name     = "${var.project_id}-${local.feature}-source"
  project  = var.project_id
  location = var.region

  # The zip is built from the repository; nothing in the bucket is unique.
  force_destroy = true

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  soft_delete_policy {
    retention_duration_seconds = 0
  }

  labels = local.labels
}
