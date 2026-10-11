provider "google" {
  project = var.project_id
  region  = var.region
}

module "content_pipeline" {
  source = "../../modules/content_pipeline"

  project_id = var.project_id
  region     = var.region
}
