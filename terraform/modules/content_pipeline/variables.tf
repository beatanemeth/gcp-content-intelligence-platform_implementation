variable "project_id" {
  type        = string
  description = "ID of the GCP project that Part A provides; every resource is created in it."
}

variable "region" {
  type        = string
  description = "GCP region for every regional resource, for example europe-west1."
}

variable "function_source_dir" {
  type        = string
  description = "Folder with the function's main.py and requirements.txt; zipped at plan."
}
