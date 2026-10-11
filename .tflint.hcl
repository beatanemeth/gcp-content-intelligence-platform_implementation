# One config for every Terraform folder. Pass it by full path
# (--config "$(pwd)/.tflint.hcl"): a relative path is looked up in each folder.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
  version = "0.15.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

plugin "google" {
  enabled = true
  version = "0.40.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"

  # Deep checking calls the GCP APIs; the checks stay offline.
  deep_check = false
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
