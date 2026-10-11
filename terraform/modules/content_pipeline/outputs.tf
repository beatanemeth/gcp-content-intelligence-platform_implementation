output "data_bucket_name" {
  description = "Name of the data bucket; the upload script (step 5b) reads it."
  value       = google_storage_bucket.data.name
}
