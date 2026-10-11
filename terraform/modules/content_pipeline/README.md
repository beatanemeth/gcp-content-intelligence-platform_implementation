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

<br>

## Resources

### Buckets

| Resource                       | Name                          | Holds                                                     |
| ------------------------------ | ----------------------------- | --------------------------------------------------------- |
| `google_storage_bucket.data`   | `<project_id>-content-data`   | Uploads (`raw/`) and the function's output (`processed/`) |
| `google_storage_bucket.source` | `<project_id>-content-source` | The function's code zip (step 5b)                         |

- **Both buckets:** uniform bucket-level access, public access prevention enforced, soft delete off, `force_destroy = true`.
- **Labels on every resource that supports them:** `feature = "content-pipeline"`, `managed_by = "terraform"`.

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

`tests/storage.tftest.hcl` runs the module against a mocked `google` provider. Nothing reaches GCP.

```bash
cd terraform/modules/content_pipeline
terraform init -backend=false
terraform test
```
