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

run "datasets_and_staging_tables" {
  command = apply

  assert {
    # jsondecode on both sides: compares the columns, not the file's spacing.
    condition = alltrue([
      for name, t in google_bigquery_table.staging :
      jsondecode(t.schema) == jsondecode(file("files/schemas/${name}.json"))
    ])
    error_message = "Every staging table must use its own schema file."
  }
}

run "cleaned_views" {
  command = apply

  assert {
    condition = alltrue([
      for t in concat(values(google_bigquery_table.cleaned), [google_bigquery_table.content]) :
      t.dataset_id == "content_cleaned"
    ])
    error_message = "Every cleaned view must be in content_cleaned."
  }

  assert {
    # Expected values written out, so a wrong placeholder in bigquery.tf fails.
    condition = alltrue([
      for t in concat(values(google_bigquery_table.cleaned), [google_bigquery_table.content]) :
      t.view[0].query == templatefile("templates/cleaned/${t.table_id}.sql.tftpl", {
        project         = "content-demo-sim"
        staging_dataset = "content_staging"
        cleaned_dataset = "content_cleaned"
      })
    ])
    error_message = "Every cleaned view must use its own template, with the project and dataset names filled in."
  }

  assert {
    condition = alltrue([
      for t in concat(values(google_bigquery_table.cleaned), [google_bigquery_table.content]) :
      !t.view[0].use_legacy_sql
    ])
    error_message = "Every cleaned view needs GoogleSQL: the templates fail as legacy SQL."
  }
}

run "analysis_views" {
  command = apply

  assert {
    condition = alltrue([
      for t in google_bigquery_table.analysis :
      t.dataset_id == "content_analysis"
    ])
    error_message = "Every analysis view must be in content_analysis."
  }

  assert {
    # templatefile() accepts the unused staging_dataset key.
    condition = alltrue([
      for t in google_bigquery_table.analysis :
      t.view[0].query == templatefile("templates/analysis/${t.table_id}.sql.tftpl", {
        project         = "content-demo-sim"
        staging_dataset = "content_staging"
        cleaned_dataset = "content_cleaned"
      })
    ])
    error_message = "Every analysis view must use its own template, with the project and dataset names filled in."
  }

  assert {
    condition = alltrue([
      for t in google_bigquery_table.analysis :
      !t.view[0].use_legacy_sql
    ])
    error_message = "Every analysis view needs GoogleSQL: the templates fail as legacy SQL."
  }
}
