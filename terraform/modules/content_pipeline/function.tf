data "archive_file" "function" {
  type        = "zip"
  source_dir  = var.function_source_dir
  output_path = "${path.root}/.build/content-function.zip"
  excludes    = ["__pycache__"]
}

# Content hash in the name forces a redeploy on code change.
resource "google_storage_bucket_object" "function_source" {
  name   = "function-source-${data.archive_file.function.output_md5}.zip"
  bucket = google_storage_bucket.source.name
  source = data.archive_file.function.output_path
}

resource "google_cloudfunctions2_function" "transform" {
  name     = "${local.feature}-transform"
  project  = var.project_id
  location = var.region
  labels   = local.labels

  build_config {
    runtime     = "python314"
    entry_point = "handle_event"
    # Expects the full resource name, not the email.
    service_account = google_service_account.pipeline["build"].id

    source {
      storage_source {
        bucket = google_storage_bucket.source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    # Cost cap; events over the limit are retried.
    max_instance_count    = 2
    min_instance_count    = 0
    available_memory      = "256M"
    timeout_seconds       = 300 # the function waits for its load jobs
    ingress_settings      = "ALLOW_INTERNAL_ONLY"
    service_account_email = google_service_account.pipeline["runtime"].email

    environment_variables = {
      PROJECT_ID      = var.project_id
      STAGING_DATASET = google_bigquery_dataset.layer["staging"].dataset_id
      BQ_LOCATION     = google_bigquery_dataset.layer["staging"].location
    }
  }

  # Also fires on processed/ writes; handle_event filters to raw/<group>/_READY.
  event_trigger {
    event_type     = "google.cloud.storage.object.v1.finalized"
    trigger_region = var.region
    # handle_event drops events older than 15 minutes, which bounds the retries.
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = google_service_account.pipeline["trigger"].email

    event_filters {
      attribute = "bucket"
      value     = google_storage_bucket.data.name
    }
  }

  # The function does not reference its grants, so order them explicitly.
  depends_on = [
    google_project_iam_member.pipeline,
    google_project_iam_member.build_code_reader,
  ]
}

# Targets the function's Cloud Run service, so it lives here, not in iam.tf.
resource "google_cloud_run_v2_service_iam_member" "trigger_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloudfunctions2_function.transform.service_config[0].service
  role     = "roles/run.invoker"
  member   = google_service_account.pipeline["trigger"].member
}
