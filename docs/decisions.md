# Decisions

The main design decisions, one table per topic. The full reasoning lives in the [planning repository](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning).

<br>

## The story

| Decision                                                                                       | Why                                                                                         | What it costs                                                                    |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **Part A and Part B:** the platform (Part A) is separate from the pipeline feature (Part B)    | Mirrors a real company: a platform team runs the shared basics; a feature team adds to them | Part B depends on values it does not create; they must be handed over and agreed |
| **Ownership rule:** "Would a second feature need it?" Yes: Part A. No: Part B                  | One clear test decides where each resource belongs                                          | Shared items such as the enabled APIs stay outside the module                    |
| **Part B changes nothing in Part A:** it only adds its own resources and permissions           | The feature can be added and removed without risk to other features                         | The module cannot enable APIs or fix a missing platform setting itself           |

<br>

## Simulation

| Decision                                                                                  | Why                                                                   | What it costs                                                                          |
| ----------------------------------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Simulation instead of real GCP:** a mocked Google provider, a BigQuery emulator, fakes | No GCP project is needed; every check runs on the laptop and in CI    | Simulated results can differ from real GCP; a real deployment (step 9) confirms them |
| **Labelled results:** every simulated result says so                                     | A reader never mistakes a laptop check for a cloud result             | More wording in the docs                                                               |
| **Mocked provider for Terraform:** `terraform test` with `mock_provider "google"` | Proves the names, arguments, labels and references Terraform would send | Proves nothing GCP decides: permissions, quotas, API errors |
| **BigQuery emulator for the staging load:** `goccy/bigquery-emulator` in Docker | The real schema files, load settings and data checks run against the BigQuery API on the laptop | It loads an unknown field (dropped) and a missing `REQUIRED` `_id`; a pytest test covers both. It never runs in CI |

<br>

## Terraform

| Decision                                                                                            | Why                                                                                                    | What it costs                                                        |
| --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------- |
| **2 inputs only:** `project_id` and `region`, no defaults in the module                             | Part A hands over exactly these; a missing value stops `plan` instead of building in the wrong project | Names and settings cannot be changed by the caller                   |
| **The `content` prefix and 2 labels:** `feature = "content-pipeline"`, `managed_by = "terraform"`   | The feature's resources and costs are easy to find and filter in a shared project                      | One copy of the module per project                                   |
| **2 buckets:** data and source                                                                      | IAM is granted per bucket; the function's runtime account can write data but never touch its own code  | One more bucket to create and secure                                 |
| **`destroy` removes everything:** `force_destroy = true`, soft delete off                           | The data lives on the laptop and can be uploaded again; nothing is left behind or billed               | A `destroy` deletes every uploaded and processed file without asking |
| **CI runs offline checks only:** `fmt`, `validate`, `terraform test` with a mocked provider, TFLint | No GCP credentials in GitHub; checks are free and repeatable                                           | CI cannot catch errors that only a real `apply` shows (step 9)       |

<br>

## BigQuery

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **3 layers (medallion pattern):** `content_staging` (tables), `content_cleaned` and `content_analysis` (views) | Each layer has one job: data as delivered, prepared data, answers. A layer label shows its cost | 3 datasets to manage instead of 1 |
| **Strict staging schemas with the Wix field names:** `REQUIRED` only for `_id`; no unknown field, no bad record | A wrong type or an unexpected field fails the load loudly, instead of loading bad data quietly | A new Wix field stops the load until its schema is updated |
| **`averageRating` as `FLOAT`:** every value is 0 today | A rating such as 4.5 would fail the whole load into an `INTEGER` column | None: `FLOAT` also accepts whole numbers |
| **Data checks in SQL:** row counts, duplicate IDs, broken references, missing titles | BigQuery checks each row's shape, not the relations between rows | A manual step after each load (`bq query`) |
| **No partitioning or clustering** | About 130 records; every query already costs the minimum | To add if the data grows to many GB |
| **Cleaned layer as views, not tables** | A view stores no data and is up to date after every load; at about 130 records every query costs the minimum | Each query runs the joins again; to change into tables if the data grows |
| **Categories and tags as nested lists** (`ARRAY` of `STRUCT`), one `ARRAY` subquery each | BigQuery's native model: one row per post, no bridge tables; a post without tags keeps its row; no row multiplication | A query on one tag needs `UNNEST` |
| **View SQL in template files; only project and dataset placeholders** | The SQL reads as normal BigQuery SQL; the emulator check uses the same files | Table names inside the SQL are invisible to Terraform |
| **`depends_on` per layer:** staging tables, then `blog_posts` and `articles`, then `content` in its own block | BigQuery checks a view's SQL at creation; Terraform sees no reference in a SQL string, and creates one `for_each` block's items in parallel | The order is written by hand; a new view must be added to it |

<br>

## IAM

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **3 service accounts, one per job:** build, trigger, runtime | A bug or a leak in one job opens only that job's doors: the runtime account cannot touch the code; the build account cannot read the data | 3 accounts and their grants to manage instead of 1 |
| **Each role on the smallest scope:** bucket or dataset first; the project only when the permission exists nowhere lower | The runtime account can change `content_staging` but not the cleaned and analysis layers | 4 grants stay project-wide: `jobUser`, `eventReceiver`, `artifactregistry.writer`, `logWriter` |
| **Predefined roles, not custom ones** | Google updates them when an API changes | Some permissions go unused; IAM Recommender can show them after real runs (step 9) |
| **A condition on the build account's `objectViewer`:** only Google's code buckets and the source bucket | Google's code buckets exist only after the first deploy, so no bucket-level grant is possible | A CEL expression to maintain; only a real deployment proves it lets the build read its code |
| **`*_iam_member` only:** never `*_iam_binding` or `*_iam_policy` | Each grant only adds; nothing removes the access that Team A or another feature has granted | Access granted by hand outside Terraform stays unnoticed |
| **No service account keys** | Google issues a short-lived token on each run; no key file exists to leak or rotate | None |

<br>

## Python

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **Based on the original [Jupyter ETL notebooks](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline/tree/main/ETL):** their unwrap and HTML cleaning steps, simplified | The logic already worked on the real Wix exports | The text becomes one line: paragraph breaks are lost |
| **Python only unwraps and cleans:** all joins, renames and lookups are SQL (steps 6 and 7) | Every transformation stays visible and testable in BigQuery; the function needs one library | A change in the analysis needs SQL, not Python |
| **A count mismatch logs an `ERROR` and goes on** | A retry cannot fix the source file; the loaded rows show what arrived | A cut-off export is loaded; someone must watch the `ERROR` logs |
| **Every step overwrites its output (idempotent)** | A second run gives the same files and tables, with no duplicates | No history: an earlier output is gone |

<br>

## Function and trigger

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **Upload from the laptop, not from the Wix API** | The exports already exist as files; no API key or scheduler in the cloud | A person runs `helpers/upload_data.sh`; nothing is automatic |
| **A `_READY` marker per group, uploaded last in a separate command** | A group has several files; the marker says "complete", so the group is processed once, not once per file | 14 events per upload; 12 of them end at once |
| **A Cloud Run function, built from source by Terraform** | Terraform zips, uploads and deploys the code; no image to build or push by hand | The first deploy needs Cloud Build, Artifact Registry and their grants |
| **Events older than 15 minutes are dropped** | A retry keeps the original event time; an older event is a permanent failure, and returning without an error ends days of retries | A problem that lasts longer than 15 minutes needs a new upload |
| **2 instances at most; internal ingress only** | Caps the cost; events rejected at the limit come back through retries. Only Eventarc can call the function, not the internet | A large upload waits for a free instance |
| **No `time_sleep` after the grants** | Simpler code; a slow grant fails at most the first `apply` | The first real `apply` may need a second run |
