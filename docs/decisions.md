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

<br>

## Python

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **Based on the original [Jupyter ETL notebooks](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline/tree/main/ETL):** their unwrap and HTML cleaning steps, simplified | The logic already worked on the real Wix exports | The text becomes one line: paragraph breaks are lost |
| **Python only unwraps and cleans:** all joins, renames and lookups are SQL (steps 6 and 7) | Every transformation stays visible and testable in BigQuery; the function needs one library | A change in the analysis needs SQL, not Python |
| **A count mismatch logs an `ERROR` and goes on** | A retry cannot fix the source file; the loaded rows show what arrived | A cut-off export is loaded; someone must watch the `ERROR` logs |
| **Every step overwrites its output (idempotent)** | A second run gives the same files and tables, with no duplicates | No history: an earlier output is gone |
