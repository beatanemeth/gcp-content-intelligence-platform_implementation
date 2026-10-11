# Minimum versions only: the root module that calls this module pins the range.
# Terraform 1.7 added mock providers, which the simulated tests need.
terraform {
  required_version = ">= 1.7"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 8.0"
    }
    # Zips the function's code on the laptop.
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}
