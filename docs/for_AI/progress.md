# Progress

The build log. The [plan](https://github.com/beatanemeth/gcp-content-intelligence-platform_planning/tree/main/rebuild_plan) says what should happen; this file says what did. Deviations from the plan are recorded here, not in the plan.

> Authorship note: written by Claude Code from the build steps.

<br>

## Status

**2026-10-12:** the simulated build is complete.

**2026-10-20:** the real run on GCP is complete (step 9, part 2). Every check of the plan passed; 3 findings below. The project is kept for more runs and is deleted before the Free Trial ends (2027-01-19).

**Next:** fix finding 1 in `scripts/bootstrap.sh` together with the next deployment, which also proves the fix on real GCP.

<br>

## Merged branches

| PR  | Branch                            | Step      |
| --- | --------------------------------- | --------- |
| #1  | `chore/repository-and-dummy-data` | 1         |
| #2  | `feature/terraform-skeleton`      | 2         |
| #3  | `feature/python-cleaning`         | 3         |
| #4  | `feature/bigquery-staging`        | 4         |
| #5  | `feature/service-accounts`        | 5a        |
| #6  | `feature/function-and-trigger`    | 5b        |
| #7  | `feature/cleaned-views`           | 6         |
| #8  | `feature/analysis-views`          | 7         |
| #9  | `docs/full-dataset-run`           | 8         |
| #10 | `docs/runbook`                    | 9, part 1 |

<br>

## Deviations by step

All checks are simulated; the checks and their limits are in `tests/README.md`.

### Step 1: repository, dummy data, pre-commit

- **Python 3.10.12 venv, not 3.14:** 3.14 is not installed on the laptop. CI and the function stay on 3.14.
- **`CLAUDE.md` commands grow each step:** the plan adds them in step 8; the "Commands" section now starts in step 1.

### Step 2: Terraform skeleton and the 2 buckets

- **Lock file for `linux_amd64` only:** another platform needs `terraform providers lock -platform=<platform>`.

### Step 3: Python cleaning

- **Python 3.10.12 on the laptop (the maintainer's decision):** no 3.11+ syntax; CI checks 3.14. Ruff targets `py314`.
- **Function `requirements.txt` in commit 1:** `requirements-dev.txt` includes it with `-r`.
- **Ruff 0.16.10 kept:** 0.17.0 was out at build time. Ruff also formats Python code blocks in Markdown.

### Step 4: BigQuery datasets, staging tables, data checks

- **Dataset `description`:** each dataset gets the text from the `datasets` local.
- **`averageRating` as `FLOAT`:** a rating such as 4.5 would fail a load into `INTEGER`.
- **`missing_titles` also counts an empty title.**
- **`tomap()` in test assertions:** an object never equals a map.

### Step 5a: service accounts and grants

- **Names not in the plan:** the `project_roles` keys, the grant resources (`runtime_data`, `runtime_staging`, `build_code_reader`) and 2 display names.
- **Project-level grants tested as a set of `"<role> <member>"` pairs:** an extra, missing or swapped grant fails.
- **`override_resource` per instance** works, though the Terraform docs do not mention instance keys.

### Step 5b: function, trigger, upload script

- **`Z` replaced by `+00:00` before `fromisoformat` (needed):** Python 3.10 cannot read `Z`.
- **`timezone.utc` with `# noqa: UP017` (needed):** `datetime.UTC` needs 3.11.
- **`google-cloud-bigquery==3.46.1`, not 3.45.2:** step 4 already pinned it; the pin moved to the function's `requirements.txt`.
- **`depends_on` on whole resources:** the function waits for all project-level grants, including the runtime's `jobUser`.
- **One `override_resource` per account in `function.tftest.hcl`:** shared defaults would let a swapped account pass.
- **`upload_data.sh` changes to the repository root first:** it then works from any folder.

### Step 6: cleaned views

- **Whole table paths quoted in `check_views.py` (needed):** the emulator never returns on a path quoted in 2 parts.
- **No VS Code settings committed:** the editor tip stays a per-user setting.

### Step 7: analysis views

- **`top_posts_per_category` partitions by category ID, not label.**
- **`report()` in `check_views.py`:** one helper prints every check's line.
- **`--results` sorts by the first 2 columns:** the CSV files are the same on every run.
- **Open:** "proof that the check can fail" was never recorded for this step.

### Step 8: full dataset run

- **No `ERROR` for `members`:** this export states `_totalCount: 8`, so the totals match. The plan expected 9. `test_main.py` still covers the mismatch path.

### Step 9, part 1: Part A stand-in and runbook

- **Order: billing, APIs, then budget (needed):** the budget call needs its API enabled first.
- **`--billing-project` on the budget commands (needed):** the Billing Budget API is charged to a quota project.
- **Versioning with `buckets update`, on every run (needed):** `buckets create` has no versioning flag.
- **`--calendar-period=month` (explicit):** the reference states no default.

### Step 9, part 2: the real run (2026-10-20)

A personal GCP project on the Free Trial, billing account in USD. The dummy data first, then the full dataset.

| Check in the plan                          | Result                                                                                         |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| Google accepts every resource              | 31 resources, after one rerun of `apply` (finding 2)                                           |
| No drift                                   | The second `plan`: "No changes"                                                                |
| The build account reads its code           | The function deployed; status ready in the console                                             |
| Eventarc delivers; only `_READY` does work | 6 log lines, records = rows; the first NDJSON file in the same second as the marker             |
| The loads are strict and complete          | `data_checks.sql`: 75, 6, 11, 5, 12, 5; 0 everywhere else                                       |
| The views work in real BigQuery            | Rows in all 4 analysis views                                                                   |
| Full dataset                               | 113, 9, 17, 8, 18, 8 in the logs and the data checks; 0 everywhere else                        |
| Simulation and reality agree               | All 4 analysis views the same as the step 8 CSV files, apart from 2 output formats (finding 3) |
| `destroy` removes everything               | 31 destroyed; besides the state bucket, 2 objects Google created itself remain (below)         |

**Findings:**

- **Finding 1, a bug in `bootstrap.sh`:** `gcloud storage service-agent` prints the email with a line break and 2 spaces in front; `$( )` keeps them, so the `pubsub.publisher` grant fails with "does not exist". Granted by hand with `| tr -d '[:space:]'`. The fix is the next branch.
- **Finding 2, a Google-side delay:** the first `apply` failed on the function: "Permission denied while using the Eventarc Service Agent". The same `apply` 5 minutes later created the remaining 2 resources. No code change.
- **Finding 3, output formats only:** the simulation's CSV files end lines with `\r\n` (Python's `csv`), `bq` with `\n`; `bq --format=csv` prints timestamps without milliseconds. BigQuery stores them: 26 of 27 rows in `top_posts_per_category` have milliseconds, the 27th is exactly 0 ms in the export, in both.

**Deviations from the plan and the runbook:**

- **Log text:** the plan expects `File loaded`; the function logs `<group>/<file>: N records written, N rows loaded`.
- **Left after `destroy`:** the bucket `gcf-v2-sources-<project-number>-<region>` and the Artifact Registry repository `gcf-artifacts` (the function's images). Cloud Run functions creates both, outside Terraform; deleting the project removes them.
- **Default service accounts with Editor:** Google created the Compute Engine and App Engine default accounts, both with `roles/editor`. The pipeline does not use them; a company's organisation policy usually blocks these grants.
- **`gcloud config set project` moved to step 2 of the runbook:** before the project exists, `gcloud` warns.
- **Project kept:** step 11 (delete the project) waits for more runs; each run is steps 5 to 10.
- **`BUDGET_AMOUNT` stays fixed at 10:** a Hungarian billing account is in USD; HUF is not a Cloud Billing currency.
