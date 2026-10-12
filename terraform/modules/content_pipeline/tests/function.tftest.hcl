# Only Google is mocked; the archive provider really zips the code.
mock_provider "google" {}

# Distinct values per account, so a swapped account fails.
override_resource {
  target = google_service_account.pipeline["build"]
  values = {
    id     = "projects/content-demo-sim/serviceAccounts/content-build@content-demo-sim.iam.gserviceaccount.com"
    email  = "content-build@content-demo-sim.iam.gserviceaccount.com"
    member = "serviceAccount:content-build@content-demo-sim.iam.gserviceaccount.com"
  }
}

override_resource {
  target = google_service_account.pipeline["trigger"]
  values = {
    id     = "projects/content-demo-sim/serviceAccounts/content-trigger@content-demo-sim.iam.gserviceaccount.com"
    email  = "content-trigger@content-demo-sim.iam.gserviceaccount.com"
    member = "serviceAccount:content-trigger@content-demo-sim.iam.gserviceaccount.com"
  }
}

override_resource {
  target = google_service_account.pipeline["runtime"]
  values = {
    id     = "projects/content-demo-sim/serviceAccounts/content-runtime@content-demo-sim.iam.gserviceaccount.com"
    email  = "content-runtime@content-demo-sim.iam.gserviceaccount.com"
    member = "serviceAccount:content-runtime@content-demo-sim.iam.gserviceaccount.com"
  }
}

# Simulated Part A values.
variables {
  project_id = "content-demo-sim"
  region     = "europe-west1"
}

run "function_and_trigger" {
  command = apply

  assert {
    condition = (
      google_storage_bucket_object.function_source.bucket == "content-demo-sim-content-source" &&
      google_storage_bucket_object.function_source.name == "function-source-${data.archive_file.function.output_md5}.zip"
    )
    error_message = "The zip must be in the source bucket, with its hash in the name."
  }

  assert {
    condition = (
      google_cloudfunctions2_function.transform.build_config[0].source[0].storage_source[0].bucket == "content-demo-sim-content-source" &&
      google_cloudfunctions2_function.transform.build_config[0].source[0].storage_source[0].object == google_storage_bucket_object.function_source.name
    )
    error_message = "The build must read the uploaded zip from the source bucket."
  }

  assert {
    condition = (
      google_cloudfunctions2_function.transform.build_config[0].service_account == google_service_account.pipeline["build"].id &&
      google_cloudfunctions2_function.transform.service_config[0].service_account_email == google_service_account.pipeline["runtime"].email &&
      google_cloudfunctions2_function.transform.event_trigger[0].service_account_email == google_service_account.pipeline["trigger"].email
    )
    error_message = "Build, runtime and trigger must each use their own account (build by id)."
  }

  assert {
    condition     = google_cloudfunctions2_function.transform.service_config[0].ingress_settings == "ALLOW_INTERNAL_ONLY"
    error_message = "Only internal traffic (Eventarc) may reach the function."
  }

  assert {
    condition = google_cloudfunctions2_function.transform.service_config[0].environment_variables == tomap({
      PROJECT_ID      = "content-demo-sim"
      STAGING_DATASET = "content_staging"
      BQ_LOCATION     = "europe-west1"
    })
    error_message = "The function needs exactly PROJECT_ID, STAGING_DATASET and BQ_LOCATION."
  }

  assert {
    condition = (
      google_cloudfunctions2_function.transform.event_trigger[0].event_type == "google.cloud.storage.object.v1.finalized" &&
      google_cloudfunctions2_function.transform.event_trigger[0].retry_policy == "RETRY_POLICY_RETRY"
    )
    error_message = "The trigger must fire on finished uploads, with retries on."
  }

  assert {
    condition = [
      for f in google_cloudfunctions2_function.transform.event_trigger[0].event_filters : "${f.attribute}=${f.value}"
    ] == ["bucket=content-demo-sim-content-data"]
    error_message = "The trigger must filter on the data bucket only."
  }

  assert {
    condition = (
      google_cloud_run_v2_service_iam_member.trigger_invoker.name == google_cloudfunctions2_function.transform.service_config[0].service &&
      google_cloud_run_v2_service_iam_member.trigger_invoker.role == "roles/run.invoker" &&
      google_cloud_run_v2_service_iam_member.trigger_invoker.member == google_service_account.pipeline["trigger"].member
    )
    error_message = "The trigger account needs run.invoker on the function's service."
  }
}
