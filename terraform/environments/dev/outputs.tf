output "data_bucket_name" {
  description = "Name of the data bucket; the upload script (step 5b) reads it."
  value       = module.content_pipeline.data_bucket_name
}

output "function_name" {
  description = "Name of the function; filters its logs after an upload."
  value       = module.content_pipeline.function_name
}
