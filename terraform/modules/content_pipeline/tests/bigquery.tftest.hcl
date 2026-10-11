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

run "datasets_and_staging_tables" {
  command = apply

  assert {
    # tomap: a { ... } literal or { for ... } expression is an object, and an
    # object never equals a map.
    condition = tomap({ for layer, d in google_bigquery_dataset.layer : layer => d.dataset_id }) == tomap({
      staging  = "content_staging"
      cleaned  = "content_cleaned"
      analysis = "content_analysis"
    })
    error_message = "The 3 datasets must be content_staging, content_cleaned and content_analysis."
  }

  assert {
    condition = alltrue([
      for d in google_bigquery_dataset.layer :
      d.project == "content-demo-sim" && d.location == "europe-west1" && d.delete_contents_on_destroy
    ])
    error_message = "Every dataset must be in the given project and region, with delete_contents_on_destroy."
  }

  assert {
    condition = alltrue([
      for layer, d in google_bigquery_dataset.layer :
      d.labels["feature"] == "content-pipeline" && d.labels["managed_by"] == "terraform" && d.labels["layer"] == layer
    ])
    error_message = "Every dataset needs the feature, managed_by and layer labels."
  }

  assert {
    condition     = length(google_bigquery_table.staging) == 6
    error_message = "There must be 6 staging tables, one per NDJSON file."
  }

  assert {
    condition = alltrue([
      for name, t in google_bigquery_table.staging :
      t.dataset_id == "content_staging" && t.project == "content-demo-sim" && t.table_id == name
    ])
    error_message = "Every staging table must be in content_staging, named after its NDJSON file."
  }

  assert {
    # jsondecode on both sides: compares the columns, not the file's spacing.
    condition = alltrue([
      for name, t in google_bigquery_table.staging :
      jsondecode(t.schema) == jsondecode(file("files/schemas/${name}.json"))
    ])
    error_message = "Every staging table must use its own schema file."
  }

  assert {
    condition = alltrue([
      for t in google_bigquery_table.staging :
      !t.deletion_protection && t.labels["feature"] == "content-pipeline" && t.labels["managed_by"] == "terraform"
    ])
    error_message = "Every staging table needs deletion_protection off and the feature and managed_by labels."
  }

  assert {
    # The output is a { for ... } expression, which is an object, too.
    condition = tomap(output.dataset_ids) == tomap({
      staging  = "content_staging"
      cleaned  = "content_cleaned"
      analysis = "content_analysis"
    })
    error_message = "The dataset_ids output must map each layer to its dataset."
  }
}

run "cleaned_views" {
  command = apply

  assert {
    condition = toset(concat(
      [for t in google_bigquery_table.cleaned : t.table_id], [google_bigquery_table.content.table_id]
    )) == toset(["blog_posts", "articles", "content"])
    error_message = "The cleaned views must be blog_posts, articles and content."
  }

  assert {
    condition = alltrue([
      for t in concat(values(google_bigquery_table.cleaned), [google_bigquery_table.content]) :
      t.dataset_id == "content_cleaned" && t.project == "content-demo-sim"
    ])
    error_message = "Every cleaned view must be in content_cleaned."
  }

  assert {
    # The expected values, written out: a wrong placeholder in bigquery.tf fails.
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
      !t.view[0].use_legacy_sql && !t.deletion_protection
      && t.labels["feature"] == "content-pipeline" && t.labels["managed_by"] == "terraform"
    ])
    error_message = "Every cleaned view needs GoogleSQL, deletion_protection off and the feature and managed_by labels."
  }
}

run "analysis_views" {
  command = apply

  assert {
    condition = toset([for t in google_bigquery_table.analysis : t.table_id]) == toset([
      "content_per_month", "tag_frequency", "top_posts_per_category", "article_text_stats"
    ])
    error_message = "The analysis views must be content_per_month, tag_frequency, top_posts_per_category and article_text_stats."
  }

  assert {
    condition = alltrue([
      for t in google_bigquery_table.analysis :
      t.dataset_id == "content_analysis" && t.project == "content-demo-sim"
    ])
    error_message = "Every analysis view must be in content_analysis."
  }

  assert {
    # The analysis templates use only project and cleaned_dataset; templatefile()
    # accepts extra keys, so the same map as in cleaned_views works.
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
      !t.view[0].use_legacy_sql && !t.deletion_protection
      && t.labels["feature"] == "content-pipeline" && t.labels["managed_by"] == "terraform"
    ])
    error_message = "Every analysis view needs GoogleSQL, deletion_protection off and the feature and managed_by labels."
  }
}
