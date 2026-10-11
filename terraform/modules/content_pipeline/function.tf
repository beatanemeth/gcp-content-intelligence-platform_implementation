# Terraform deploys the code itself: it zips files/function/, uploads the zip to
# the source bucket and creates the function from it. No manual gcloud step.

# Built on the laptop at plan time; .build/ is git-ignored.
data "archive_file" "function" {
  type        = "zip"
  source_dir  = "${path.module}/files/function"
  output_path = "${path.root}/.build/content-function.zip"
  excludes    = ["__pycache__"]
}

# The zip's hash is in the name: a code change gives a new name, so Terraform
# replaces the object and redeploys the function. With a fixed name, Terraform
# would not see the change.
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function.output_path
}

# A Cloud Run function, built from source: Cloud Build turns the zip into a
# container image and Cloud Run runs it.
resource "google_cloudfunctions2_function" "transform" {
  name     = "${local.feature}-transform"
  project  = var.project_id
  location = var.region
  labels   = local.labels

  build_config {
    runtime     = "python314"
    entry_point = "handle_event"
    # The build wants the account's full resource name (id), not its email.
    service_account = google_service_account.pipeline["build"].id

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    # 2 at most caps the cost; events rejected at the limit come back through
    # retries. 0 at least: nothing runs, and nothing costs, while idle.
    max_instance_count = 2
    min_instance_count = 0
    available_memory   = "256M"
    timeout_seconds    = 300 # the function waits for its load jobs
    # Only Google Cloud (Eventarc) can reach the function, not the internet.
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    service_account_email = google_service_account.pipeline["runtime"].email

    # Settings come from Terraform, never hard-coded in main.py.
    environment_variables = {
      PROJECT_ID      = var.project_id
      STAGING_DATASET = google_bigquery_dataset.layer["staging"].dataset_id
      BQ_LOCATION     = google_bigquery_dataset.layer["staging"].location
    }
  }

  # Fires on every finished upload in the data bucket, including the function's
  # own processed/ files; handle_event keeps only the raw/<group>/_READY markers.
  event_trigger {
    event_type     = "google.cloud.storage.object.v1.finalized"
    trigger_region = var.region # same region as the bucket
    # Events rejected at the 2-instance limit, or failed by a temporary error,
    # come back. handle_event drops an event older than 15 minutes, which ends
    # the retries.
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.pipeline["trigger"].email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.data.name
    }
  }

  # Terraform orders resources by their references. The function refers to the
  # accounts, not to their grants, so without depends_on the build could start
  # before its grants exist and fail. The whole resource is the unit of a
  # dependency: pipeline holds the build's 2 project roles and the trigger's
  # eventReceiver (and the runtime's jobUser, which does no harm).
  # A new grant can still take a minute to take effect in real GCP: if the first
  # apply fails on a permission, run apply again. No time_sleep: it happens at
  # most once.
  depends_on = [
    google_project_iam_member.pipeline,
    google_project_iam_member.build_code_reader,
  ]
}

# The 8th grant: the trigger account may call the function. It targets the Cloud
# Run service behind the function, which exists only after the function; the
# reference also makes Terraform create the grant after the function.
resource "google_cloud_run_v2_service_iam_member" "trigger_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.transform.service_config[0].service
  role     = "roles/run.invoker"
  member   = google_service_account.pipeline["trigger"].member
}
