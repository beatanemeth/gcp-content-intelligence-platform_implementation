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
