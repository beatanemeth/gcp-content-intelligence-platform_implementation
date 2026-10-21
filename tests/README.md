# Tests and simulation

> Authorship note: see the root README.

Every check in this file runs on the laptop, and every result is **simulated**. One real run on GCP (2026-10-20) confirmed them; see "What the real run confirmed".

**Purpose of this file:** the one place that explains how the simulation works and where it stops. A reader who wants to rerun the checks, or trust them, starts here.

<br>

## Simulated Part A values

Made up; they point to nothing real. Part B is built against them, so the real deployment needs no code change.

| Value            | Simulated value            |
| ---------------- | -------------------------- |
| **Project ID**   | `content-demo-sim`         |
| **Region**       | `europe-west1`             |
| **State bucket** | `content-demo-sim-tfstate` |

<br>

## What checks what

| Layer     | Simulated with                               | Real equivalent                      |
| --------- | -------------------------------------------- | ------------------------------------ |
| Terraform | `terraform test`, mocked `google` provider   | `terraform apply`, `gcloud` describe |
| Python    | pytest, fake bucket, BigQuery client, events | The function's logs after an upload  |
| BigQuery  | `goccy/bigquery-emulator` `0.8.1` in Docker  | `bq load`, `bq query` on each view   |

- **Mocked service accounts:** the provider checks an IAM member's format before any call, so every test gives the mocked accounts a valid `member`.
- **Emulator checks:** `check_staging.py` and `check_views.py`; see "The checks" below.
- **Laptop only:** the emulator never runs in CI. Commands: `CLAUDE.md`.

<br>

## The checks

### Staging checks

Loads the 6 NDJSON files into a local BigQuery emulator, then runs the data checks. Needs Docker and the NDJSON files from the Python checks.

- **The load:** each file goes into its staging table with the table's strict schema, as a real load would.
- **The checks:** [scripts/data_checks.sql](../scripts/data_checks.sql), one row per check and table. Expected: every row `ok`, exit code 0.
- **A hanging script:** a stopped emulator looks like a slow query. Check `docker ps` first.
- **`--counts full`:** expects the full dataset's counts (113, 9, 17, 8, 18 and 8). The real exports sit in the git-ignored `data/raw/` and are not in this repository; run `main.py data/raw .build/ndjson` first, on a fresh emulator.

| Check               | Question                                                                            | Expected                                  |
| ------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------- |
| `row_count`         | Did every record arrive?                                                            | The record counts: 75, 6, 11, 5, 12 and 5 |
| `duplicate_keys`    | Does any `_id` appear twice?                                                        | 0                                         |
| `orphan_references` | Does every category, tag, author and article category ID exist in its lookup table? | 0                                         |
| `missing_titles`    | Does every post and article have a title? An empty title counts as missing          | 0                                         |

### View checks

Creates the 3 cleaned views and the 4 analysis views in the same emulator. Checks the cleaned views' rows against the staging tables, and that every analysis view returns rows. Run it after `check_staging.py`, with the emulator still running: it keeps the loaded tables in memory only.

- **The same SQL as Terraform:** the script fills in the templates in `terraform/modules/content_pipeline/templates/` with the same values as `bigquery.tf`. It creates `blog_posts`, `articles` and `content`, then the 4 analysis views: Terraform's order.
- **`--results <folder>`:** after the checks, writes `<folder>/<view>.csv` for each analysis view, with a header row. Simulated results; `.build/` is git-ignored.
- **Expected values from staging,** not fixed numbers. Expected: every row `ok`, exit code 0.

| Check                  | View                     | Expected                                   |
| ---------------------- | ------------------------ | ------------------------------------------ |
| `row_count`            | `blog_posts`, `articles` | The staging table's row count (75, 12)     |
| `distinct_ids`         | `blog_posts`, `articles` | The staging table's row count: no ID twice |
| `missing_article_text` | `articles`               | 0                                          |
| `row_count`            | `content`                | Posts + articles (87)                      |
| `empty_names`          | `content`                | 0 empty category or tag names              |
| `has_rows`             | Each analysis view       | At least 1 row                             |

<br>

## What the real run confirmed

**Real GCP, 2026-10-20:** the runbook on a personal project; the dummy data, then the full dataset. Details: `docs/for_AI/progress.md`, step 9, part 2.

| Simulated here                                | Real GCP result                                                                 |
| --------------------------------------------- | ------------------------------------------------------------------------------- |
| `terraform test`: 31 resources, mocked        | Google accepted all 31; the second `plan` showed no drift                       |
| IAM grants as names only                      | The roles were enough: the build read its code, the trigger reached the function, the runtime loaded BigQuery |
| `handle_event` on fake events                 | Eventarc delivered; only `_READY` did work; records = rows in every log line     |
| Staging checks: 75, 6, 11, 5, 12, 5           | The same; full dataset 113, 9, 17, 8, 18, 8; 0 in every other check             |
| View checks and the step 8 CSV files          | The same numbers in all 4 analysis views                                        |

<br>

## What the simulation cannot prove

- **IAM:** that the roles hold the permissions each job needs; propagation delays; the build account's condition.
- **Function:** real Eventarc delivery and retries; real load jobs; build, memory and timeout limits.
- **Views:** that real BigQuery returns the same numbers (time zones, `SPLIT`, window order on ties); query cost.

**Found only by the real run:**

- **`gcloud` output format:** `gcloud storage service-agent` prints the email with leading whitespace, which broke a grant in `bootstrap.sh`. ShellCheck checks the script, not a command's output.
- **Google-managed service agents:** Eventarc's own agent was not ready on the first `apply`; a rerun 5 minutes later passed. A mocked provider has no such agents.
- **Output formats:** `bq` writes CSV with `\n` line endings and timestamps without milliseconds; the simulation writes `\r\n` and keeps the milliseconds. The values are the same.
- **Resources outside Terraform:** Cloud Run functions creates a source bucket and an Artifact Registry repository; Google adds 2 default service accounts with Editor. `destroy` does not remove them.

<br>

## Emulator quirks

| Quirk                                                                     | Handling                                        |
| ------------------------------------------------------------------------- | ----------------------------------------------- |
| Creating an existing dataset answers `500`; the client retries for 10 min | The emulator creates `content_staging` at start |
| A repeated `--dataset` flag keeps only the last value                     | `check_views.py` creates the other 2 datasets   |
| A stopped container looks like a slow query                               | When a script hangs, check `docker ps`          |
| A path quoted in 2 parts never returns                                    | Quote the whole path, as the templates do       |
| Unknown field and missing `REQUIRED` `_id` load without error             | `tests/function/test_schemas.py` checks both    |
