# Module: content_pipeline

Part B of the story: the content pipeline as a standalone Terraform module. It creates only what the pipeline uses and changes nothing in Part A.

- **Fixed names:** every resource name is `<project_id>-content-...` or starts with `content`. The module is not configurable beyond its 2 inputs.
- **One copy per project:** a second call in the same project would try to create the same names and fail.
- **No provider block:** the caller configures the `google` provider.

<br>

## What it needs from Part A

None of it is needed for the simulated checks.

- **Project** with billing linked.
- **10 APIs enabled:** `storage`, `cloudfunctions`, `run`, `cloudbuild`, `artifactregistry`, `eventarc`, `pubsub`, `bigquery`, `iam`, `cloudresourcemanager`. The module enables none: a `destroy` could switch them off for every other feature in the project.
- **Cloud Storage service agent** holds `roles/pubsub.publisher`, so a finished upload can publish an event.
- **Team B** holds `Owner` on the project.

<br>

## Inputs

| Name         | Type     | Default | Description                                                    |
| ------------ | -------- | ------- | -------------------------------------------------------------- |
| `project_id` | `string` | None    | ID of the GCP project that Part A provides                     |
| `region`     | `string` | None    | GCP region for every regional resource, such as `europe-west1` |

No defaults: a missing value stops `plan` at once.

## Outputs

| Name               | Description                                                   |
| ------------------ | ------------------------------------------------------------- |
| `data_bucket_name` | Name of the data bucket; the upload script (step 5b) reads it |
| `dataset_ids`      | Dataset ID per layer: `staging`, `cleaned`, `analysis`        |

<br>

## Resources

### Buckets

| Resource                       | Name                          | Holds                                                     |
| ------------------------------ | ----------------------------- | --------------------------------------------------------- |
| `google_storage_bucket.data`   | `<project_id>-content-data`   | Uploads (`raw/`) and the function's output (`processed/`) |
| `google_storage_bucket.source` | `<project_id>-content-source` | The function's code zip (step 5b)                         |

- **Both buckets:** uniform bucket-level access, public access prevention enforced, soft delete off, `force_destroy = true`.

### BigQuery

One dataset per layer (medallion pattern), in `var.region`, the data bucket's location: a load job reads only from a bucket in the dataset's location.

| Resource                                     | Name               | Holds                                              |
| -------------------------------------------- | ------------------ | -------------------------------------------------- |
| `google_bigquery_dataset.layer["staging"]`  | `content_staging`  | The data as delivered: the 6 staging tables        |
| `google_bigquery_dataset.layer["cleaned"]`  | `content_cleaned`  | Prepared data, as views (step 6)                   |
| `google_bigquery_dataset.layer["analysis"]` | `content_analysis` | Answers, as views (step 7)                         |

- **Staging tables:** `google_bigquery_table.staging`, one per NDJSON file and with the same name: `blog_posts`, `blog_categories`, `blog_tags`, `members`, `articles`, `article_categories`.
- **Strict schemas:** `files/schemas/<table>.json`, with the Wix field names unchanged. `REQUIRED` only for `_id`; arrays `REPEATED`; nested objects `RECORD`; dates `TIMESTAMP`. A wrong type or an unknown field fails the load.
- **`destroy` removes everything:** `delete_contents_on_destroy = true` on the datasets, `deletion_protection = false` on the tables.
- **No partitioning or clustering:** about 130 records; every query already costs the minimum.

### Service accounts and grants

One service account per job, so a bug or a leak in one job opens only that job's doors. No keys: Google issues a short-lived token on each run.

| Resource                                       | Account ID        | Job                                                  |
| ---------------------------------------------- | ----------------- | ---------------------------------------------------- |
| `google_service_account.pipeline["build"]`    | `content-build`   | Turns the function's source code into a running service |
| `google_service_account.pipeline["trigger"]`  | `content-trigger` | Delivers the "file uploaded" event to the function   |
| `google_service_account.pipeline["runtime"]`  | `content-runtime` | Runs the function: reads uploads, writes NDJSON, loads BigQuery |

Each role on the smallest scope that works; the project only when nothing smaller exists.

| Account | Role                            | Scope                                | Allows                                            |
| ------- | ------------------------------- | ------------------------------------ | ------------------------------------------------- |
| runtime | `roles/storage.objectUser`      | Data bucket                          | Read `raw/`, overwrite `processed/`; the load job reads `processed/` |
| runtime | `roles/bigquery.dataEditor`     | `content_staging`                    | Replace the staging tables' rows                  |
| runtime | `roles/bigquery.jobUser`        | Project                              | Start load jobs: a job belongs to a project       |
| trigger | `roles/eventarc.eventReceiver`  | Project                              | Receive events: no smaller scope exists           |
| build   | `roles/artifactregistry.writer` | Project                              | Push the built image                              |
| build   | `roles/logging.logWriter`       | Project                              | Write the build logs                              |
| build   | `roles/storage.objectViewer`    | Project, with a condition            | Read the source code only                         |

- **The build account's condition** (`content-build-code-buckets-only`): Google copies the source code into its own buckets (`gcf-v2-sources-...`, `gcf-v2-uploads-...`, `run-sources-...`), which exist only after the first deploy. The condition allows only those prefixes and the source bucket, so the grant cannot reach the data bucket or the state bucket.
- **`*_iam_member` only:** each grant adds one member to one role. A `*_iam_binding` or `*_iam_policy` would remove the access that Team A or another feature has granted.
- **`run.invoker`:** the trigger account's 8th grant targets the function's service, so it comes with the function (step 5b).

### Labels

- **On every resource that supports them:** `feature = "content-pipeline"`, `managed_by = "terraform"`. The datasets add `layer = "<layer>"`, so the bill shows the cost per layer.

<br>

## Usage

```hcl
module "content_pipeline" {
  source = "../../modules/content_pipeline"

  project_id = var.project_id
  region     = var.region
}
```

The `dev` root module (`terraform/environments/dev/`) makes this call.

<br>

## Simulated test

`tests/storage.tftest.hcl` (the buckets), `tests/bigquery.tftest.hcl` (the datasets and staging tables) and `tests/iam.tftest.hcl` (the service accounts and grants) run the module against a mocked `google` provider. Nothing reaches GCP.

- **The mocked `member`:** the provider checks an IAM member's format (`serviceAccount:...`) before any call, so the mocked accounts need a valid `member` instead of a random string. `storage` and `bigquery` give all 3 accounts one value (`mock_resource`); `iam` gives each account its own (`override_resource`), so it can tell which account got which role.

```bash
cd terraform/modules/content_pipeline
terraform init -backend=false
terraform test
```
