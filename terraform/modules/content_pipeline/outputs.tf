output "data_bucket_name" {
  description = "Name of the data bucket; the upload script (step 5b) reads it."
  value       = google_storage_bucket.data.name
}

output "dataset_ids" {
  description = "Dataset ID per layer (staging, cleaned, analysis)."
  value       = { for layer, dataset in google_bigquery_dataset.layer : layer => dataset.dataset_id }
}

output "function_name" {
  description = "Name of the function; filters its logs after an upload."
  value       = google_cloudfunctions2_function.transform.name
}
