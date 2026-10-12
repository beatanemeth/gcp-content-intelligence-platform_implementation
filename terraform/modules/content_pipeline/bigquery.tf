resource "google_bigquery_dataset" "layer" {
  for_each = local.datasets

  dataset_id  = "${local.feature}_${each.key}"
  project     = var.project_id
  description = each.value
  # Load jobs need the bucket and the dataset in the same location.
  location = var.region

  delete_contents_on_destroy = true

  labels = merge(local.labels, { layer = each.key })
}

resource "google_bigquery_table" "staging" {
  for_each = local.staging_tables

  dataset_id = google_bigquery_dataset.layer["staging"].dataset_id
  project    = var.project_id
  table_id   = each.key

  schema = file("${path.module}/files/schemas/${each.key}.json")

  deletion_protection = false

  labels = local.labels
}

locals {
  sql_placeholders = {
    project         = var.project_id
    staging_dataset = google_bigquery_dataset.layer["staging"].dataset_id
    cleaned_dataset = google_bigquery_dataset.layer["cleaned"].dataset_id
  }
}

resource "google_bigquery_table" "cleaned" {
  for_each = local.cleaned_views

  dataset_id = google_bigquery_dataset.layer["cleaned"].dataset_id
  project    = var.project_id
  table_id   = each.key

  view {
    query          = templatefile("${path.module}/templates/cleaned/${each.key}.sql.tftpl", local.sql_placeholders)
    use_legacy_sql = false
  }

  deletion_protection = false

  labels = local.labels

  # BigQuery validates the SQL at create time; Terraform cannot see references
  # inside it.
  depends_on = [google_bigquery_table.staging]
}

# Separate block: content reads blog_posts and articles, and a for_each instance
# cannot depend on its siblings.
resource "google_bigquery_table" "content" {
  dataset_id = google_bigquery_dataset.layer["cleaned"].dataset_id
  project    = var.project_id
  table_id   = "content"

  view {
    query          = templatefile("${path.module}/templates/cleaned/content.sql.tftpl", local.sql_placeholders)
    use_legacy_sql = false
  }

  deletion_protection = false

  labels = local.labels

  depends_on = [google_bigquery_table.cleaned]
}

resource "google_bigquery_table" "analysis" {
  for_each = local.analysis_views

  dataset_id = google_bigquery_dataset.layer["analysis"].dataset_id
  project    = var.project_id
  table_id   = each.key

  view {
    query          = templatefile("${path.module}/templates/analysis/${each.key}.sql.tftpl", local.sql_placeholders)
    use_legacy_sql = false
  }

  deletion_protection = false

  labels = local.labels

  depends_on = [google_bigquery_table.cleaned, google_bigquery_table.content]
}
