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

## Python

| Decision | Why | What it costs |
| -------- | --- | ------------- |
| **Based on the original [Jupyter ETL notebooks](https://github.com/beatanemeth/Wix-Content-Intelligence-Pipeline/tree/main/ETL):** their unwrap and HTML cleaning steps, simplified | The logic already worked on the real Wix exports | The text becomes one line: paragraph breaks are lost |
| **Python only unwraps and cleans:** all joins, renames and lookups are SQL (steps 6 and 7) | Every transformation stays visible and testable in BigQuery; the function needs one library | A change in the analysis needs SQL, not Python |
| **A count mismatch logs an `ERROR` and goes on** | A retry cannot fix the source file; the loaded rows show what arrived | A cut-off export is loaded; someone must watch the `ERROR` logs |
| **Every step overwrites its output (idempotent)** | A second run gives the same files and tables, with no duplicates | No history: an earlier output is gone |
