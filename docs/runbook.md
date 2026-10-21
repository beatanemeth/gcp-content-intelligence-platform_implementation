# Runbook for real GCP

> **Run on 2026-10-20:** written in step 9, part 1; run by the maintainer in part 2. The results are in `docs/for_AI/progress.md`. The commands change a real GCP project and cost money; the maintainer runs them by hand.

> Authorship note: see the root README.

Every command runs from the repository root. Replace `<project-id>` and `<billing-account-id>` with the real values. The steps as a diagram: [deployment steps](../assets/deployment_steps.png).

| When       | Step | Command                                                                                                                                                                                              |
| ---------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Once       | 1    | `gcloud auth login`; `gcloud auth application-default login`                                                                                                                                         |
| Once       | 2    | `PROJECT_ID=<project-id> BILLING_ACCOUNT=<billing-account-id> scripts/bootstrap.sh`; then `gcloud config set project <project-id>` and `gcloud auth application-default set-quota-project <project-id>` |
| Once       | 3    | `cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars`, the same for `backend.hcl.example`; fill in `project_id` and `bucket` (`<project-id>-tfstate`) |
| Once       | 4    | `terraform -chdir=terraform/environments/dev init -backend-config=backend.hcl`                                                                                                                       |
| Every run  | 5    | `terraform -chdir=terraform/environments/dev plan`, then `terraform -chdir=terraform/environments/dev apply`                                                                                         |
| Every run  | 6    | `scripts/upload_data.sh` (dummy data) or `scripts/upload_data.sh data/raw` (full dataset)                                                                                                            |
| Every run  | 7    | `gcloud functions logs read content-transform --region=europe-west1 --limit=50`                                                                                                                      |
| Every run  | 8    | `bq query --use_legacy_sql=false < scripts/data_checks.sql`                                                                                                                                          |
| Every run  | 9    | `bq query --use_legacy_sql=false 'SELECT * FROM content_analysis.tag_frequency ORDER BY uses DESC LIMIT 10'`; the same for the other views in `content_cleaned` and `content_analysis`               |
| Every run  | 10   | `terraform -chdir=terraform/environments/dev destroy`                                                                                                                                                |
| At the end | 11   | `gcloud projects delete <project-id>`: removes Part A too, and stops all cost                                                                                                                        |

- **The second login asks for consent:** tick "Select all"; without the `cloud-platform` scope, the login fails.
- **Step 2 stops at `6. Cloud Storage service agent` ("does not exist"):** finding 1 of the real run (`progress.md`), until it is fixed. Grant the role by hand with the agent's email trimmed: `gcloud storage service-agent --project=<project-id> | tr -d '[:space:]'`.
- **The first `apply` may fail on a permission:** a new grant can take a minute to reach Cloud Build and Eventarc. The real run failed once on the Eventarc service agent; the same `apply` 5 minutes later finished.
- **After `destroy`:** the bucket `gcf-v2-sources-...` and the repository `gcf-artifacts` remain; Cloud Run functions created them. Step 11 removes them.
- **`terraform init` with the backend:** from now on, the state lives in the bucket, not on the laptop. `-backend=false` is only for the simulation.
- **The Claude Code settings deny these commands** on purpose: the maintainer runs them by hand.
