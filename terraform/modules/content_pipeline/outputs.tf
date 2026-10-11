output "data_bucket_name" {
  description = "Name of the data bucket; the upload script (step 5b) reads it."
  value       = google_storage_bucket.data.name
}

output "dataset_ids" {
  description = "Dataset ID per layer (staging, cleaned, analysis)."
  value       = { for layer, dataset in google_bigquery_dataset.layer : layer => dataset.dataset_id }
}
