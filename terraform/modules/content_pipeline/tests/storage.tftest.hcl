# Simulated check: the mocked provider replaces apply, output and destroy in real
# GCP. Every resource "succeeds" on the laptop; computed values get random strings.
mock_provider "google" {
  # The provider checks an IAM member's format (serviceAccount:...) before any
  # call, so a random string fails the grants. One valid value for all 3 accounts.
  mock_resource "google_service_account" {
    defaults = {
      member = "serviceAccount:mock@content-demo-sim.iam.gserviceaccount.com"
    }
  }
}

# The values Part A would hand over (simulated; they point to nothing real).
variables {
  project_id = "content-demo-sim"
  region     = "europe-west1"
}

run "buckets" {
  command = apply

  assert {
    condition     = google_storage_bucket.data.name == "content-demo-sim-content-data"
    error_message = "Data bucket name must be <project_id>-content-data."
  }

  assert {
    condition     = google_storage_bucket.source.name == "content-demo-sim-content-source"
    error_message = "Source bucket name must be <project_id>-content-source."
  }

  assert {
    condition = alltrue([
      for b in [google_storage_bucket.data, google_storage_bucket.source] :
      b.project == "content-demo-sim" && b.location == "europe-west1"
    ])
    error_message = "Both buckets must be in the given project and region."
  }

  assert {
    condition = alltrue([
      for b in [google_storage_bucket.data, google_storage_bucket.source] :
      b.force_destroy && b.uniform_bucket_level_access && b.public_access_prevention == "enforced"
    ])
    error_message = "Both buckets need force_destroy, uniform access and public access prevention."
  }

  assert {
    condition = alltrue([
      for b in [google_storage_bucket.data, google_storage_bucket.source] :
      b.soft_delete_policy[0].retention_duration_seconds == 0
    ])
    error_message = "Soft delete must be off on both buckets."
  }

  assert {
    condition = alltrue([
      for b in [google_storage_bucket.data, google_storage_bucket.source] :
      b.labels["feature"] == "content-pipeline" && b.labels["managed_by"] == "terraform"
    ])
    error_message = "Both buckets need the feature and managed_by labels."
  }

  assert {
    condition     = output.data_bucket_name == "content-demo-sim-content-data"
    error_message = "The data_bucket_name output must pass on the data bucket's name."
  }
}
