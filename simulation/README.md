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

**`check_staging.py`:** loads the 6 NDJSON files with their schema files (`NEWLINE_DELIMITED_JSON`, `WRITE_TRUNCATE`, strict defaults), runs `helpers/data_checks.sql`, and exits with 1 on any mismatch. `--counts full` switches to the full dataset's counts (step 8).

### Quirks

| Quirk                                                                                    | Handling                                                                         |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Creating an existing dataset answers `500`, not `409`; the client retries for 10 minutes | The emulator creates `content_staging` at start (`--dataset`); the script never creates it |
| A repeated `--dataset` flag keeps only the last value                                    | Only `content_staging` at start; step 6 creates the other 2 datasets in its script |
| A stopped container looks like a slow query, not an error                               | When a script hangs, check `docker ps` first                                     |

### What it enforces

| Bad input                                                         | Real BigQuery    | Emulator           | Covered by                       |
| ----------------------------------------------------------------- | ---------------- | ------------------ | -------------------------------- |
| Wrong type, bad `TIMESTAMP`, single value in a `REPEATED` column  | Load fails       | Load fails         | The emulator                     |
| One bad row among good rows                                       | Whole load fails | Same               | The emulator                     |
| Unknown field                                                     | Load fails       | **Loads; dropped** | `tests/function/test_schemas.py` |
| Missing `REQUIRED` `_id`                                          | Load fails       | **Loads**          | `tests/function/test_schemas.py` |
