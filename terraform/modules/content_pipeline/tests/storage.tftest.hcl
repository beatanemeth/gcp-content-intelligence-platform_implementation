mock_provider "google" {
  # The provider checks the member format before any call; a random mock value fails.
  mock_resource "google_service_account" {
    defaults = {
      member = "serviceAccount:mock@content-demo-sim.iam.gserviceaccount.com"
    }
  }
}

# Simulated Part A values.
variables {
  project_id = "content-demo-sim"
  region     = "europe-west1"
}

run "buckets" {
  command = apply

  assert {
    condition = alltrue([
      for b in [google_storage_bucket.data, google_storage_bucket.source] :
      b.uniform_bucket_level_access && b.public_access_prevention == "enforced"
    ])
    error_message = "Both buckets need uniform access and public access prevention."
  }

  # upload_data.sh reads this output; the source bucket here would break the upload.
  assert {
    condition     = output.data_bucket_name == google_storage_bucket.data.name
    error_message = "The data_bucket_name output must name the data bucket."
  }
}
