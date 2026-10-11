# for_each, not count: each dataset and table is addressed by name
# (layer["staging"]), not by position, so removing one never renames the others.

resource "google_bigquery_dataset" "layer" {
  for_each = local.datasets

  dataset_id  = "${local.feature}_${each.key}"
  project     = var.project_id
  description = each.value
  # Same location as the data bucket: a load job reads only from a bucket in the
  # dataset's location. A dataset cannot move; a new location replaces it.
  location = var.region

  # destroy removes the dataset with its tables; the data lives on the laptop.
  delete_contents_on_destroy = true

  # The layer label shows the cost per layer on the bill.
  labels = merge(local.labels, { layer = each.key })
}

resource "google_bigquery_table" "staging" {
  for_each = local.staging_tables

  # The reference also tells Terraform to create the dataset first.
  dataset_id = google_bigquery_dataset.layer["staging"].dataset_id
  project    = var.project_id
  table_id   = each.key

  schema = file("${path.module}/files/schemas/${each.key}.json")

  # A Terraform-only lock, on by default: BigQuery itself does not know it.
  # Off, so destroy can remove the table.
  deletion_protection = false

  labels = local.labels
}

locals {
  # The only placeholders in the view templates. Table and view names stay in the
  # SQL itself, so each file reads as normal BigQuery SQL.
  sql_placeholders = {
    project         = var.project_id
    staging_dataset = google_bigquery_dataset.layer["staging"].dataset_id
    cleaned_dataset = google_bigquery_dataset.layer["cleaned"].dataset_id
  }
}

# A view is a google_bigquery_table with a view block: it stores no data and runs
# its SQL on every query.
resource "google_bigquery_table" "cleaned" {
  for_each = local.cleaned_views

  dataset_id = google_bigquery_dataset.layer["cleaned"].dataset_id
  project    = var.project_id
  table_id   = each.key

  view {
    query = templatefile("${path.module}/templates/cleaned/${each.key}.sql.tftpl", local.sql_placeholders)
    # The API's default is legacy SQL; the templates are GoogleSQL.
    use_legacy_sql = false
  }

  # Same Terraform-only lock as the staging tables.
  deletion_protection = false

  labels = local.labels

  # BigQuery checks a view's SQL when it creates the view, so every table the SQL
  # reads must already exist. Terraform cannot see table names inside a string,
  # only references in HCL, so depends_on gives the order.
  depends_on = [google_bigquery_table.staging]
}

# Its own block, not a third for_each item: Terraform creates all items of one
# for_each block in parallel, and content reads the other two views.
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
