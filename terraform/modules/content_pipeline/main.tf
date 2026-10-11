locals {
  # Every GCP name starts with this prefix, so the feature's resources are easy
  # to spot in a project that other features share.
  feature = "content"

  # Goes on every resource that supports labels.
  labels = {
    feature    = "content-pipeline" # filter this feature's resources and costs
    managed_by = "terraform"        # tells others not to change it by hand
  }
}
