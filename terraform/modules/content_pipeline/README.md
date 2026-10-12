# Module: content_pipeline

> Authorship note: see the root README.

Part B of the story: the content pipeline as a standalone Terraform module. It creates only what the pipeline uses and changes nothing in Part A.

**Purpose of this file:** the module's contract. What a caller must provide, what they get back, what the module creates, and what it does not. Design reasoning belongs in `docs/decisions.md`; the code and its tests are the detail.

<br>

## What it needs from Part A

- **Project** with billing linked.
- **10 APIs enabled:** `storage`, `cloudfunctions`, `run`, `cloudbuild`, `artifactregistry`, `eventarc`, `pubsub`, `bigquery`, `iam`, `cloudresourcemanager`. The module enables none: a `destroy` could switch them off for every other feature.
- **Cloud Storage service agent** holds `roles/pubsub.publisher`.
- **Team B** holds `Owner` on the project.

<br>

## Inputs and outputs

| Name               | Kind   | Description                                                |
| ------------------ | ------ | ---------------------------------------------------------- |
| `project_id`       | Input  | ID of the GCP project that Part A provides                 |
| `region`           | Input  | Region for every regional resource, such as `europe-west1` |
| `data_bucket_name` | Output | Name of the data bucket; the upload script reads it        |
| `function_name`    | Output | Name of the function; filters its logs after an upload     |

No defaults: a missing input stops `plan` at once. No provider block: the caller configures `google`.

<br>

## What it creates

| File          | Creates                                                              |
| ------------- | -------------------------------------------------------------------- |
| `storage.tf`  | Data bucket and source bucket                                        |
| `bigquery.tf` | 3 datasets, 6 staging tables, 3 cleaned views, 4 analysis views      |
| `iam.tf`      | 3 service accounts (build, trigger, runtime) and their grants        |
| `function.tf` | The code zip, the `content-transform` function, its Eventarc trigger |

- **Fixed names:** `<project_id>-content-...` or `content...`. A second copy in the same project would fail.
- **`destroy` removes everything,** data included.

---

### Analysis views: the 4 questions

One view in `content_analysis` per question. Each SQL file opens with its question and the exact definition of its metric.

| View                     | Question                                                                                                | SQL technique       |
| ------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------- |
| `content_per_month`      | How much content was published in each calendar month, per content type, and what is the running total? | Running total       |
| `tag_frequency`          | Which tags and keywords are used most, per content type?                                                | `CROSS JOIN UNNEST` |
| `top_posts_per_category` | Which 3 posts have the most views in each category, and who wrote them?                                 | Ranking             |
| `article_text_stats`     | How long are the articles on average, per category?                                                     | Text measure        |

---

### Service accounts and grants

One account per job, no keys. Each role on the smallest scope that works.

| Account | Role                            | Scope                     | Allows                              |
| ------- | ------------------------------- | ------------------------- | ----------------------------------- |
| runtime | `roles/storage.objectUser`      | Data bucket               | Read `raw/`, overwrite `processed/` |
| runtime | `roles/bigquery.dataEditor`     | `content_staging`         | Replace the staging tables' rows    |
| runtime | `roles/bigquery.jobUser`        | Project                   | Start load jobs                     |
| trigger | `roles/eventarc.eventReceiver`  | Project                   | Receive events                      |
| trigger | `roles/run.invoker`             | The function's service    | Call the function                   |
| build   | `roles/artifactregistry.writer` | Project                   | Push the built image                |
| build   | `roles/logging.logWriter`       | Project                   | Write the build logs                |
| build   | `roles/storage.objectViewer`    | Project, with a condition | Read the source code only           |

- **The build condition** (`content-build-code-buckets-only`): Google copies the code into its own buckets (`gcf-v2-sources-...`, `gcf-v2-uploads-...`, `run-sources-...`), which exist only after the first deploy. The condition allows only those prefixes and the source bucket.
- **`*_iam_member` only:** a `*_iam_binding` or `*_iam_policy` would remove access that Team A or another feature has granted.

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

## Test

The files in `tests/` run the module against a mocked `google` provider; nothing reaches GCP. The `archive` provider is real: it zips the code on the laptop.

```bash
cd terraform/modules/content_pipeline
terraform init -backend=false
terraform test
```
