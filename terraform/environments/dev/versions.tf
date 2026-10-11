# The root module sets the upper limit: ~> allows new minor versions, never the
# next major one. The lock file records the exact versions and checksums.
terraform {
  required_version = "~> 1.16"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.6"
    }
  }
}
