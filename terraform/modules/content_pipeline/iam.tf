# One account per job (build, trigger, runtime): a bug or a leak in one job opens
# only that job's doors. The runtime account handles the data but cannot touch
# the code; the build account reads the code but not the data.
#
# No google_service_account_key: Google issues a short-lived token on each run,
# so no key file exists to leak or rotate.

resource "google_service_account" "pipeline" {
  for_each = local.service_accounts

  account_id   = "${local.feature}-${each.key}"
  display_name = each.value
  project      = var.project_id
}

# Every grant is *_iam_member: it adds one member to one role and leaves every
# other member alone. A *_iam_binding or *_iam_policy would replace the members
# that Team A or another feature has granted.
#
# run.invoker (trigger account) targets the function's service, so it lives in
# function.tf (step 5b).

# Runtime: read raw/ and overwrite processed/; the load job also reads
# processed/ as this account. objectUser, not objectCreator: an overwrite needs
# storage.objects.delete.
resource "google_storage_bucket_iam_member" "runtime_data" {
  bucket = google_storage_bucket.data.name
  role   = "roles/storage.objectUser"
  member = google_service_account.pipeline["runtime"].member
}

# Runtime: replace the staging tables' rows. Only content_staging, so the
# cleaned and analysis layers stay out of reach.
resource "google_bigquery_dataset_iam_member" "runtime_staging" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.layer["staging"].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_service_account.pipeline["runtime"].member
}

# Runtime: start load jobs. Trigger: receive events from Eventarc.
resource "google_project_iam_member" "pipeline" {
  for_each = local.project_roles

  project = var.project_id
  role    = each.value.role
  member  = google_service_account.pipeline[each.value.account].member
}
