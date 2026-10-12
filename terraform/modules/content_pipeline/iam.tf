resource "google_service_account" "pipeline" {
  for_each = local.service_accounts

  account_id   = "${local.feature}-${each.key}"
  display_name = each.value
  project      = var.project_id
}

# *_iam_member only: binding and policy resources would overwrite grants made
# outside this module.

# objectUser, not objectCreator: overwriting processed/ needs delete.
resource "google_storage_bucket_iam_member" "runtime_data" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectUser"
  member = google_service_account.pipeline["runtime"].member
}

resource "google_bigquery_dataset_iam_member" "runtime_staging" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.layer["staging"].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.pipeline["runtime"].member
}

resource "google_project_iam_member" "pipeline" {
  for_each = local.project_roles

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.pipeline[each.value.account].member
}

# Google's code buckets appear only on first deploy, so grant on the project and
# scope it with a condition.
resource "google_project_iam_member" "build_code_reader" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = google_service_account.pipeline["build"].member

  # Trailing / so a bucket with the same prefix does not match.
  condition {
    title       = "content-build-code-buckets-only"
    description = "Read objects in the function's code buckets only."
    expression  = <<-EOT
      resource.name.startsWith("projects/_/buckets/gcf-v2-sources-") ||
      resource.name.startsWith("projects/_/buckets/gcf-v2-uploads-") ||
      resource.name.startsWith("projects/_/buckets/run-sources-") ||
      resource.name.startsWith("projects/_/buckets/${google_storage_bucket.source.name}/")
    EOT
  }
}
