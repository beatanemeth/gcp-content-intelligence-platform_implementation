output "data_bucket_name" {
  description = "Name of the data bucket; the upload script (step 5b) reads it."
  value       = module.content_pipeline.data_bucket_name
}

output "dataset_ids" {
  description = "Dataset ID per layer (staging, cleaned, analysis)."
  value       = module.content_pipeline.dataset_ids
}
