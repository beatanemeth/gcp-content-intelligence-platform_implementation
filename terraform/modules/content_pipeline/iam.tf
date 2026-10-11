# One account per job (build, trigger, runtime): a bug or a leak in one job opens
# only that job's doors. The runtime account handles the data but cannot touch
# the code; the build account reads the code but not the data.
#
# No google_service_account_key: Google issues a short-lived token on each run,
# so no key file exists to leak or rotate.

resource "google_service_account" "pipeline" {
  for_each = local.service_accounts

  account_id   = "${local.feature}-${each.key}"
  display_name = each.value
  project      = var.project_id
}
