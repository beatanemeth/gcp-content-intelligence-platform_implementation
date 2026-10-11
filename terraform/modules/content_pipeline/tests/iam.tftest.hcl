# Simulated check: the mocked provider replaces apply, output and destroy in real
# GCP. Every resource "succeeds" on the laptop; computed values get random strings.
mock_provider "google" {}

# The provider checks an IAM member's format (serviceAccount:...) before any
# call, so a random string fails the grants. One value per account, so the test
# can tell which account got which role.
override_resource {
  target = google_service_account.pipeline["build"]
  values = { member = "serviceAccount:content-build@content-demo-sim.iam.gserviceaccount.com" }
}

override_resource {
  target = google_service_account.pipeline["trigger"]
  values = { member = "serviceAccount:content-trigger@content-demo-sim.iam.gserviceaccount.com" }
}

override_resource {
  target = google_service_account.pipeline["runtime"]
  values = { member = "serviceAccount:content-runtime@content-demo-sim.iam.gserviceaccount.com" }
}

# The values Part A would hand over (simulated; they point to nothing real).
variables {
  project_id = "content-demo-sim"
  region     = "europe-west1"
}

run "service_accounts_and_grants" {
  command = apply

  assert {
    condition = tomap({ for job, a in google_service_account.pipeline : job => a.account_id }) == tomap({
      build   = "content-build"
      trigger = "content-trigger"
      runtime = "content-runtime"
    })
    error_message = "The 3 accounts must be content-build, content-trigger and content-runtime."
  }

  assert {
    condition     = alltrue([for a in google_service_account.pipeline : a.project == "content-demo-sim"])
    error_message = "Every account must be in the given project."
  }

  assert {
    condition = (
      google_storage_bucket_iam_member.runtime_data.bucket == "content-demo-sim-content-data" &&
      google_storage_bucket_iam_member.runtime_data.role == "roles/storage.objectUser" &&
      google_storage_bucket_iam_member.runtime_data.member == google_service_account.pipeline["runtime"].member
    )
    error_message = "The runtime account needs objectUser on the data bucket only."
  }

  assert {
    condition = (
      google_bigquery_dataset_iam_member.runtime_staging.dataset_id == "content_staging" &&
      google_bigquery_dataset_iam_member.runtime_staging.role == "roles/bigquery.dataEditor" &&
      google_bigquery_dataset_iam_member.runtime_staging.member == google_service_account.pipeline["runtime"].member
    )
    error_message = "The runtime account needs dataEditor on content_staging only."
  }

  assert {
    # The set holds "<role> <member>" pairs: any extra, missing or swapped grant fails.
    condition = toset([for g in google_project_iam_member.pipeline : "${g.role} ${g.member}"]) == toset([
      "roles/bigquery.jobUser serviceAccount:content-runtime@content-demo-sim.iam.gserviceaccount.com",
      "roles/eventarc.eventReceiver serviceAccount:content-trigger@content-demo-sim.iam.gserviceaccount.com",
      "roles/artifactregistry.writer serviceAccount:content-build@content-demo-sim.iam.gserviceaccount.com",
      "roles/logging.logWriter serviceAccount:content-build@content-demo-sim.iam.gserviceaccount.com",
    ])
    error_message = "Exactly the 4 project-level roles, each to its own account."
  }

  assert {
    condition = (
      google_project_iam_member.build_code_reader.role == "roles/storage.objectViewer" &&
      google_project_iam_member.build_code_reader.member == google_service_account.pipeline["build"].member
    )
    error_message = "The build account needs objectViewer on the project."
  }

  assert {
    condition = alltrue([
      for allowed in [
        "projects/_/buckets/gcf-v2-sources-",
        "projects/_/buckets/gcf-v2-uploads-",
        "projects/_/buckets/run-sources-",
        "projects/_/buckets/content-demo-sim-content-source/",
      ] : strcontains(google_project_iam_member.build_code_reader.condition[0].expression, "\"${allowed}\"")
    ])
    error_message = "The build condition must allow Google's 3 code buckets and the source bucket with its trailing /."
  }

  assert {
    condition     = !strcontains(google_project_iam_member.build_code_reader.condition[0].expression, "content-demo-sim-content-data")
    error_message = "The build condition must not reach the data bucket."
  }
}
