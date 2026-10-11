# Simulation

No real GCP project is used. Every cloud check runs on the laptop, and every simulated result is labelled as simulated.

<br>

## Why simulate

- **No GCP project:** the pipeline is built and checked without credentials or cost.
- **Part B needs only Part A's values:** the module is built against the values the platform would hand over, not against the platform itself.
- **No code change later:** a real deployment (step 9) swaps the simulated values for real ones.

<br>

## Simulated Part A values

Made up; they point to nothing real.

| Value                 | Simulated value            | Enters Part B as                   |
| --------------------- | -------------------------- | ---------------------------------- |
| **Project ID**        | `content-demo-sim`         | `project_id` in `terraform.tfvars` |
| **Region**            | `europe-west1`             | `region` in `terraform.tfvars`     |
| **State bucket name** | `content-demo-sim-tfstate` | `bucket` in `backend.hcl`          |

### Derived names

| Resource          | Name                              |
| ----------------- | --------------------------------- |
| **Data bucket**   | `content-demo-sim-content-data`   |
| **Source bucket** | `content-demo-sim-content-source` |

### The real Part A (step 9)

For a real deployment, [`helpers/bootstrap.sh`](../helpers/bootstrap.sh) stands in for Team A. Run once, by hand; it is never run here.

```bash
PROJECT_ID=<project-id> BILLING_ACCOUNT=<billing-account-id> helpers/bootstrap.sh
```

| Order | Creates                                   | Why in this order                                     |
| ----- | ----------------------------------------- | ----------------------------------------------------- |
| 1     | The project; Team B's `Owner` comes with it | Everything else lives in it                         |
| 2     | The billing link                          | Most APIs need billing                                |
| 3     | The 10 APIs and the Billing Budget API    | The budget call needs its API enabled                 |
| 4     | A budget: 10 per month, alerts at 50, 90 and 100 % | Guards the cost; alerts only, never stops spending |
| 5     | The state bucket `<project-id>-tfstate`: `europe-west1`, versioning, uniform access, public access prevention | `terraform init` needs it |
| 6     | `roles/pubsub.publisher` for the Cloud Storage service agent | Eventarc's Cloud Storage trigger needs it |

- **Safe to run again:** each step checks whether its result exists, or is a no-op when it does.
- **Then Part B:** [docs/runbook.md](../docs/runbook.md), step 3.

<br>

## Labelling rule

Every simulated result, in this file, `progress.md` or `README.md`, is labelled as **simulated**. Later steps add their simulated checks below.

<br>

## Simulated checks

| Step | What it builds            | Real check                                                 | Simulated check                                                               | Result (simulated)                               |
| ---- | ------------------------- | ---------------------------------------------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------ |
| 2    | The module, the 2 buckets | `terraform apply`, `terraform output`, `terraform destroy` | `fmt`, `validate`, TFLint; `terraform test` with the mocked `google` provider | 2026-10-11: 1 run passed; TFLint reports nothing |
| 3    | The cleaning functions    | None: already local                                        | None needed: pytest, Ruff, the command line                                   | Not simulated. 2026-10-11: 19 tests passed; 6 NDJSON files |
| 4    | 3 datasets, 6 staging tables, data checks | `terraform apply`; `bq load`; `bq query --use_legacy_sql=false < helpers/data_checks.sql` | `terraform test` with the mocked provider; `check_staging.py` on the BigQuery emulator; `test_schemas.py` | 2026-10-11: 2 runs passed; 26 tests passed; emulator: every check ok |
| 5a   | 3 service accounts, 7 grants | `terraform apply`; `gcloud projects get-iam-policy`; the function's first deploy (step 9) | `terraform test` with the mocked provider; `iam.tftest.hcl` checks each account's roles and scopes | 2026-10-11: 3 runs passed; TFLint reports nothing |
| 5b   | The function, its trigger, the 8th grant, the upload script | `terraform apply`; `helpers/upload_data.sh`; the function's logs; `bq query` on the staging tables | `terraform test` with the mocked provider; pytest with fake clients and fake events; the upload script with fake `terraform` and `gcloud`; ShellCheck | 2026-10-11: 4 runs passed; 39 tests passed; upload order correct; ShellCheck reports nothing |
| 6    | 3 cleaned views | `terraform apply`; `bq query` on each view | `terraform test` with the mocked provider; `check_views.py` on the BigQuery emulator | 2026-10-11: 5 runs passed; emulator: every check ok (75, 12 and 87 rows) |
| 7    | 4 analysis views | `terraform apply`; `bq query` on each view | `terraform test` with the mocked provider; `check_views.py` on the BigQuery emulator; one hand check | 2026-10-11: 6 runs passed; emulator: every check ok (53, 89, 18 and 5 rows); hand check matches |
| 8    | No code: the full dataset | The real run (step 9): upload `data/raw`, then `data_checks.sql` and the views | `main.py`, `check_staging.py --counts full` and `check_views.py --results` on the real exports, on a fresh emulator | 2026-10-11: counts as planned; emulator: every check ok (113, 18 and 131 rows; 64, 128, 27 and 5 view rows) |
| 9    | Part A stand-in script, runbook | `helpers/bootstrap.sh`, then [docs/runbook.md](../docs/runbook.md) | ShellCheck only: the script changes the cloud | 2026-10-11: ShellCheck reports nothing; never run |

### Mocked service accounts (step 5a)

The mocked provider gives every computed value a random string, but the provider checks an IAM member's format (`serviceAccount:...`) before any call, so the grants would fail. Every test file gives the mocked accounts a valid `member`: `mock_resource` with one value for all 3 in `storage` and `bigquery`; one `override_resource` per account in `iam`.

**What the simulation cannot prove:** that the roles hold the permissions each job needs, IAM propagation delays (a new grant can take minutes to work), and that the build account's condition really lets the build read its code. A real deployment (step 9) shows them.

### The function and its trigger (step 5b)

- **`function.tftest.hcl`:** the `archive` provider is real, so the code is zipped on the laptop; only the Google provider is mocked. One `override_resource` per account gives each its own `id`, `email` and `member`, so a swapped account fails the test.
- **Fake clients (`tests/function/test_handle_event.py`):** a fake bucket holds the dummy exports under `raw/<group>/` in a dict; the fake BigQuery client records each load, and its load job counts the lines of the processed file as loaded rows.
- **Fake events:** `CloudEvent` objects with the attributes Eventarc sends (`type`, `source`, `time`) and the `bucket` and `name` data. Each test sets the event's age.
- **Upload order (run once, not committed):** fake `terraform` and `gcloud` scripts first on `PATH`, which only print their arguments. Result: each group's files, then its marker. With a failing `gcloud`, the script stops before the marker.

**What the simulation cannot prove:** real Eventarc delivery and retries, real load jobs, the function's real build, memory and timeout limits. A real deployment (step 9) shows them.

### The analysis views (step 7)

- **`has_rows`:** the analysis views have no staging number to match, so the check is that each returns at least 1 row. An empty answer means a broken join or filter.
- **Hand check (run once):** the tag "Massa" has `uses` 59 in `tag_frequency`; its `_id` appears 59 times in `data/dummy/blogs/blog_posts.json`:

  ```bash
  grep -o 265c28ea-0879-4955-825f-f87c44df8a13 data/dummy/blogs/blog_posts.json | wc -l
  ```

- **`--results <folder>`:** the CSV files hold emulator output, so they are simulated results. `.build/` is git-ignored; the full dataset's results are in [`README.md`](../README.md#results-simulated) (step 8).

**What the simulation cannot prove:** that real BigQuery gives the same numbers (time zones, `SPLIT`, window order on ties), and the real cost of each query. A real deployment (step 9) shows them.


### The full dataset (step 8)

The real Wix exports, in the git-ignored `data/raw/`, through the same commands as steps 3 to 7. Run on 2026-10-11.

| Step | Command | Result (simulated) |
| ---- | ------- | ------------------ |
| Clean | `python terraform/modules/content_pipeline/files/function/main.py data/raw .build/ndjson` | 6 `INFO` lines, no `ERROR` |
| Count | `wc -l .build/ndjson/*/*.ndjson` | 113, 9, 17, 8, 18 and 8 lines |
| Staging | `python simulation/check_staging.py --counts full`, on a fresh emulator | All 18 checks `ok` |
| Views | `python simulation/check_views.py --results .build/results-simulated` | All 11 checks `ok`; 4 CSV files |

- **Fresh emulator:** it keeps tables in memory, so a container that held the dummy data is stopped first.
- **Cases the dummy data does not have:** 2 posts without tags (`tagIds` empty), and all 113 still reach `blog_posts`; `empty_names` is 0, so every category name comes from `label`.
- **The source total check:** this export states `_totalCount: 8` for its 8 members, so no `ERROR`. The plan expected a stated total of 9 from an older export.
- **Publishing rule:** only the analysis views' results leave the laptop, in [`README.md`](../README.md#results-simulated), with author names replaced ("Author 1"). No record is copied.

**What the simulation cannot prove:** that real BigQuery gives the same numbers on the full dataset. The real run (step 9) compares its views with these CSV files.

<br>

## BigQuery emulator

**Tool:** [`goccy/bigquery-emulator`](https://github.com/goccy/bigquery-emulator) `0.8.1`, in Docker. It speaks the BigQuery API on `localhost:9050`. Laptop only: it never runs in CI.

```bash
# Terminal 1
docker run --rm -p 9050:9050 ghcr.io/goccy/bigquery-emulator:0.8.1 \
    --project=content-demo-sim --dataset=content_staging

# Terminal 2: after main.py has written .build/ndjson/
python simulation/check_staging.py
```

**`check_views.py`** (steps 6 and 7): run after `check_staging.py`, with the emulator still running; it keeps the loaded tables in memory only.

- **Same SQL as Terraform:** fills in `templates/cleaned/*.sql.tftpl` and `templates/analysis/*.sql.tftpl` with `string.Template(...).substitute(...)`: the same `${name}` syntax as `templatefile()`, and it also fails on a missing placeholder. The values match `local.sql_placeholders` in `bigquery.tf`.
- **Terraform's order:** creates `content_cleaned` if missing, then `blog_posts`, `articles`, `content`; then `content_analysis` if missing, then the 4 analysis views. Each view is deleted and created again on every run, so a changed SQL file takes effect.
- **Both checks always run:** the cleaned checks, then `has_rows`, so one report shows every failure; exit code 1 on any.
- **Expected values from staging,** not fixed numbers, so the same script works for the full dataset (step 8): 113, 18 and 131 rows.

**`check_staging.py`:** loads the 6 NDJSON files with their schema files (`NEWLINE_DELIMITED_JSON`, `WRITE_TRUNCATE`, strict defaults), runs `helpers/data_checks.sql`, and exits with 1 on any mismatch. `--counts full` switches to the full dataset's counts (step 8).

### Quirks

| Quirk                                                                                    | Handling                                                                         |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Creating an existing dataset answers `500`, not `409`; the client retries for 10 minutes | The emulator creates `content_staging` at start (`--dataset`); the script never creates it |
| A repeated `--dataset` flag keeps only the last value                                    | Only `content_staging` at start; `check_views.py` creates the other 2 datasets |
| A stopped container looks like a slow query, not an error                               | When a script hangs, check `docker ps` first                                     |
| A path quoted in 2 parts (`` `project.dataset`.table ``) never returns; real BigQuery accepts it | `check_views.py` quotes the whole path; the templates already do                 |

### What it enforces

| Bad input                                                         | Real BigQuery    | Emulator           | Covered by                       |
| ----------------------------------------------------------------- | ---------------- | ------------------ | -------------------------------- |
| Wrong type, bad `TIMESTAMP`, single value in a `REPEATED` column  | Load fails       | Load fails         | The emulator                     |
| One bad row among good rows                                       | Whole load fails | Same               | The emulator                     |
| Unknown field                                                     | Load fails       | **Loads; dropped** | `tests/function/test_schemas.py` |
| Missing `REQUIRED` `_id`                                          | Load fails       | **Loads**          | `tests/function/test_schemas.py` |
