# Tests and simulation

Authorship note: see the root README.

No real GCP project is used. Every check runs on the laptop, and every result is **simulated**.

**Purpose of this file:** the one place that explains how the simulation works and where it stops. A reader who wants to rerun the checks, or trust them, starts here.

<br>

## Simulated Part A values

Made up; they point to nothing real. Part B is built against them, so the real deployment needs no code change.

| Value          | Simulated value            |
| -------------- | -------------------------- |
| **Project ID** | `content-demo-sim`         |
| **Region**     | `europe-west1`             |
| **State bucket** | `content-demo-sim-tfstate` |

<br>

## What checks what

| Layer     | Simulated with                              | Real equivalent                          |
| --------- | ------------------------------------------- | ---------------------------------------- |
| Terraform | `terraform test`, mocked `google` provider  | `terraform apply`, `gcloud` describe     |
| Python    | pytest, fake bucket, BigQuery client, events | The function's logs after an upload      |
| BigQuery  | `goccy/bigquery-emulator` `0.8.1` in Docker | `bq load`, `bq query` on each view       |

- **Mocked service accounts:** the provider checks an IAM member's format before any call, so every test gives the mocked accounts a valid `member`.
- **Emulator checks:** `check_staging.py` loads the 6 NDJSON files and runs `helpers/data_checks.sql`; `check_views.py` builds the views from the same templates as Terraform. Expected values come from staging, so one script serves the dummy and the full dataset.
- **Laptop only:** the emulator never runs in CI. Commands: `CLAUDE.md`.

<br>

## What the simulation cannot prove

- **IAM:** that the roles hold the permissions each job needs; propagation delays; the build account's condition.
- **Function:** real Eventarc delivery and retries; real load jobs; build, memory and timeout limits.
- **Views:** that real BigQuery returns the same numbers (time zones, `SPLIT`, window order on ties); query cost.

<br>

## Emulator quirks

| Quirk                                                                      | Handling                                                   |
| -------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Creating an existing dataset answers `500`; the client retries for 10 min  | The emulator creates `content_staging` at start            |
| A repeated `--dataset` flag keeps only the last value                      | `check_views.py` creates the other 2 datasets              |
| A stopped container looks like a slow query                                | When a script hangs, check `docker ps`                     |
| A path quoted in 2 parts never returns                                     | Quote the whole path, as the templates do                  |
| Unknown field and missing `REQUIRED` `_id` load without error              | `tests/function/test_schemas.py` checks both               |
